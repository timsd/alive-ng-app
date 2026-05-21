// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:appwrite/appwrite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';

/// Service for managing profile picture cleanup and storage optimization
class ProfileCleanupService {
  static final Databases _databases = Databases(appwriteClient);
  static final Storage _storage = Storage(appwriteClient);
  static final Logger _logger = Logger('ProfileCleanupService');

  // Cleanup settings
  static const int _retentionDays = 2;
  static const int _maxFileSize = 5 * 1024 * 1024; // 5MB
  static const List<String> _allowedExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.webp'
  ];

  /// Initialize cleanup service and schedule periodic cleanup
  // Replace initializeCleanupService with a web-safe no-op when running on web
  Future<void> initializeCleanupService() async {
    if (kIsWeb) {
      // No-op on web
      return;
    }
    try {
      // Run initial cleanup
      await cleanupOldProfilePictures();

      // Schedule periodic cleanup (this would typically be done with a background service)
      // For now, we'll just log that it should be scheduled
      await _logCleanupActivity('Cleanup service initialized', 'info');
    } catch (e) {
      _logger.error('Failed to initialize cleanup service: $e');
      await _logCleanupActivity(
          'Failed to initialize cleanup service: $e', 'error');
      // Don't crash the app initialization if cleanup fails
    }
  }

  /// Clean up old profile pictures from Appwrite Storage
  Future<void> cleanupOldProfilePictures() async {
    try {
      final cutoffDate =
          DateTime.now().subtract(const Duration(days: _retentionDays));
      int deletedCount = 0;
      int errorCount = 0;

      // Get all users to check their profile pictures
      final users = await _databases.listDocuments(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.usersCollectionId,
        queries: [Query.limit(100)],
      );
      final activeProfileFileIds = <String>{};

      // Collect currently active profile picture URLs
      for (final userDoc in users.documents) {
        for (final field in ['avatar_url', 'photo_url', 'profilePictureUrl']) {
          final profilePictureUrl = userDoc.data[field] as String?;
          final fileId = _extractFileIdFromUrl(profilePictureUrl);
          if (fileId != null) {
            activeProfileFileIds.add(fileId);
          }
        }
      }

      final listResult = await _storage.listFiles(
        bucketId: AppwriteBackendConfig.profileFilesBucketId,
        queries: [Query.limit(100)],
      );

      for (final item in listResult.files) {
        try {
          final createdTime = DateTime.tryParse(item.$createdAt);

          if (createdTime != null && createdTime.isBefore(cutoffDate)) {
            // Check if this file is still being used by any user
            if (!activeProfileFileIds.contains(item.$id)) {
              await _storage.deleteFile(
                bucketId: AppwriteBackendConfig.profileFilesBucketId,
                fileId: item.$id,
              );
              deletedCount++;
              await _logCleanupActivity(
                'Deleted old profile picture: ${item.name}',
                'info',
              );
            }
          }
        } catch (e) {
          errorCount++;
          await _logCleanupActivity(
            'Error processing file ${item.name}: $e',
            'error',
          );
        }
      }
      await _cleanupLocalCache();
      await _logCleanupActivity(
        'Cleanup completed: $deletedCount files deleted, $errorCount errors',
        'info',
      );
    } catch (e) {
      _logger.error('Error in profile picture cleanup: $e');
      await _logCleanupActivity(
          'Error in profile picture cleanup: $e', 'error');
      throw StorageException('Error in profile picture cleanup',
          originalError: e);
    }
  }

  /// Upload new profile picture with automatic cleanup of old one
  Future<String> uploadProfilePicture(
    String userId,
    File imageFile, {
    String? oldProfilePictureUrl,
  }) async {
    try {
      // Validate file
      await _validateImageFile(imageFile);

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _getFileExtension(imageFile.path);
      final fileName = '${userId}_$timestamp$extension';
      final filePath = 'profile-pictures/$fileName';
      final bytes = await imageFile.readAsBytes();

      // Upload new profile picture
      final file = await _storage.createFile(
        bucketId: AppwriteBackendConfig.profileFilesBucketId,
        fileId: ID.unique(),
        file: InputFile.fromBytes(
          bytes: bytes,
          filename: fileName,
          contentType: _getContentType(extension),
        ),
      );
      final downloadUrl = _appwriteFileUrl(
        AppwriteBackendConfig.profileFilesBucketId,
        file.$id,
      );

      // Update user document with new profile picture URL
      await _databases.updateDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.usersCollectionId,
        documentId: userId,
        data: {
          'avatar_url': downloadUrl,
          'photo_url': downloadUrl,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      );

      // Delete old profile picture if it exists
      if (oldProfilePictureUrl != null && oldProfilePictureUrl.isNotEmpty) {
        await _deleteOldProfilePicture(oldProfilePictureUrl);
      }

      await _logCleanupActivity(
        'New profile picture uploaded for user $userId: $filePath',
        'info',
      );

      return downloadUrl;
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Failed to upload profile picture for user $userId', e);
      await _logCleanupActivity(
        'Failed to upload profile picture for user $userId: $e',
        'error',
      );
      throw DatabaseException('Failed to upload profile picture',
          originalError: e);
    }
  }

  /// Delete old profile picture from storage
  Future<void> _deleteOldProfilePicture(String profilePictureUrl) async {
    try {
      final fileId = _extractFileIdFromUrl(profilePictureUrl);
      if (fileId != null) {
        await _storage.deleteFile(
          bucketId: AppwriteBackendConfig.profileFilesBucketId,
          fileId: fileId,
        );
        await _logCleanupActivity(
          'Deleted old profile picture: $fileId',
          'info',
        );
      }
    } catch (e) {
      // Don't throw error for old file deletion failures
      _logger
          .warning('Failed to delete old profile picture $profilePictureUrl');
      await _logCleanupActivity(
        'Failed to delete old profile picture $profilePictureUrl: $e',
        'warning',
      );
    }
  }

  /// Extract Appwrite file ID from an Appwrite Storage URL.
  String? _extractFileIdFromUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final pathSegments = uri.pathSegments;
    final fileIndex = pathSegments.indexOf('files');
    if (fileIndex == -1 || fileIndex + 1 >= pathSegments.length) return null;
    return pathSegments[fileIndex + 1];
  }

  /// Validate image file before upload
  Future<void> _validateImageFile(File imageFile) async {
    // Check if file exists
    if (!await imageFile.exists()) {
      throw ValidationException('Image file does not exist');
    }

    // Check file size
    final fileSize = await imageFile.length();
    if (fileSize > _maxFileSize) {
      throw ValidationException(
          'Image file is too large. Maximum size is ${_maxFileSize ~/ (1024 * 1024)}MB');
    }

    // Check file extension
    final extension = _getFileExtension(imageFile.path).toLowerCase();
    if (!_allowedExtensions.contains(extension)) {
      throw ValidationException(
          'Invalid file type. Allowed types: ${_allowedExtensions.join(', ')}');
    }
  }

  /// Get file extension from path
  String _getFileExtension(String filePath) {
    final lastDotIndex = filePath.lastIndexOf('.');
    if (lastDotIndex != -1) {
      return filePath.substring(lastDotIndex);
    }
    return '';
  }

  /// Get content type for file extension
  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// Clean up local cache files
  static Future<void> _cleanupLocalCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/profile_pictures_cache');

      if (await cacheDir.exists()) {
        final cutoffDate = DateTime.now().subtract(const Duration(days: 1));

        await for (final entity in cacheDir.list()) {
          if (entity is File) {
            final stat = await entity.stat();
            if (stat.modified.isBefore(cutoffDate)) {
              await entity.delete();
            }
          }
        }
      }
    } catch (e) {
      _logger.warning('Failed to cleanup local cache');
      await _logCleanupActivity('Failed to cleanup local cache: $e', 'warning');
    }
  }

  /// Log cleanup activity
  static Future<void> _logCleanupActivity(String message, String type) async {
    try {
      await _databases.createDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.adminNotificationsCollectionId,
        documentId: ID.unique(),
        data: {
          'type': 'profile_cleanup_$type',
          'title': 'Profile cleanup',
          'message': message,
          'priority': type == 'error' ? 'high' : 'normal',
          'is_read': false,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
      if (type == 'error') {
        _logger.error(message);
      } else {
        _logger.info(message);
      }
    } catch (e) {
      // Just log to console if we can't write to Appwrite
      _logger.error('Failed to log cleanup activity: $e');
    }
  }

  static String _appwriteFileUrl(String bucketId, String fileId) {
    return '${AppwriteBackendConfig.endpoint}/storage/buckets/'
        '$bucketId/files/$fileId/view'
        '?project=${AppwriteBackendConfig.projectId}';
  }

  /// Get cleanup statistics
  Future<Map<String, dynamic>> getCleanupStats() async {
    try {
      // Get total number of profile pictures
      final listResult = await _storage.listFiles(
        bucketId: AppwriteBackendConfig.profileFilesBucketId,
        queries: [Query.limit(100)],
      );
      final totalFiles = listResult.files.length;

      // Get recent cleanup logs
      final logs = await _databases.listDocuments(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.adminNotificationsCollectionId,
        queries: [
          Query.startsWith('type', 'profile_cleanup_'),
          Query.orderDesc('created_at'),
          Query.limit(10),
        ],
      );

      final recentLogs = logs.documents.map((doc) => doc.data).toList();

      // Calculate storage usage (approximate)
      final totalSize = listResult.files.fold<int>(
        0,
        (sum, file) => sum + file.sizeOriginal,
      );

      return {
        'totalFiles': totalFiles,
        'totalSizeBytes': totalSize,
        'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
        'retentionDays': _retentionDays,
        'maxFileSizeMB': _maxFileSize ~/ (1024 * 1024),
        'allowedExtensions': _allowedExtensions,
        'recentLogs': recentLogs,
      };
    } catch (e) {
      _logger.error('Failed to get cleanup stats', e);
      await _logCleanupActivity('Failed to get cleanup stats: $e', 'error');
      throw DatabaseException('Failed to get cleanup stats', originalError: e);
    }
  }

  /// Force cleanup of all unused profile pictures
  Future<void> forceCleanupUnusedPictures() async {
    try {
      int deletedCount = 0;

      // Get all users to check their profile pictures
      final users = await _databases.listDocuments(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.usersCollectionId,
        queries: [Query.limit(100)],
      );
      final activeProfileFileIds = <String>{};

      // Collect currently active profile picture URLs
      for (final userDoc in users.documents) {
        for (final field in ['avatar_url', 'photo_url', 'profilePictureUrl']) {
          final profilePictureUrl = userDoc.data[field] as String?;
          final fileId = _extractFileIdFromUrl(profilePictureUrl);
          if (fileId != null) {
            activeProfileFileIds.add(fileId);
          }
        }
      }

      final listResult = await _storage.listFiles(
        bucketId: AppwriteBackendConfig.profileFilesBucketId,
        queries: [Query.limit(100)],
      );

      for (final item in listResult.files) {
        try {
          if (!activeProfileFileIds.contains(item.$id)) {
            await _storage.deleteFile(
              bucketId: AppwriteBackendConfig.profileFilesBucketId,
              fileId: item.$id,
            );
            deletedCount++;
            await _logCleanupActivity(
              'Force deleted unused profile picture: ${item.name}',
              'info',
            );
          }
        } catch (e) {
          await _logCleanupActivity(
            'Error force deleting file ${item.name}: $e',
            'error',
          );
        }
      }

      await _logCleanupActivity(
        'Force cleanup completed: $deletedCount unused files deleted',
        'info',
      );
    } catch (e) {
      _logger.error('Force cleanup failed', e);
      await _logCleanupActivity('Force cleanup failed: $e', 'error');
      throw DatabaseException('Force cleanup failed', originalError: e);
    }
  }

  /// Schedule periodic cleanup (to be called by a background service)
  Future<void> schedulePeriodicCleanup() async {
    // This would typically be implemented with a background service
    // or cloud function that runs periodically
    await _logCleanupActivity(
      'Periodic cleanup scheduled (implementation depends on platform)',
      'info',
    );
  }
}

/// Profile picture upload result
class ProfilePictureUploadResult {
  final String downloadUrl;
  final String filePath;
  final int fileSizeBytes;
  final DateTime uploadedAt;

  const ProfilePictureUploadResult({
    required this.downloadUrl,
    required this.filePath,
    required this.fileSizeBytes,
    required this.uploadedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'downloadUrl': downloadUrl,
      'filePath': filePath,
      'fileSizeBytes': fileSizeBytes,
      'uploadedAt': uploadedAt.toIso8601String(),
    };
  }
}

/// Cleanup statistics model
class CleanupStats {
  final int totalFiles;
  final int totalSizeBytes;
  final double totalSizeMB;
  final int retentionDays;
  final int maxFileSizeMB;
  final List<String> allowedExtensions;
  final List<Map<String, dynamic>> recentLogs;

  const CleanupStats({
    required this.totalFiles,
    required this.totalSizeBytes,
    required this.totalSizeMB,
    required this.retentionDays,
    required this.maxFileSizeMB,
    required this.allowedExtensions,
    required this.recentLogs,
  });

  factory CleanupStats.fromMap(Map<String, dynamic> map) {
    return CleanupStats(
      totalFiles: map['totalFiles'] ?? 0,
      totalSizeBytes: map['totalSizeBytes'] ?? 0,
      totalSizeMB:
          double.tryParse(map['totalSizeMB']?.toString() ?? '0') ?? 0.0,
      retentionDays: map['retentionDays'] ?? 2,
      maxFileSizeMB: map['maxFileSizeMB'] ?? 5,
      allowedExtensions: List<String>.from(map['allowedExtensions'] ?? []),
      recentLogs: List<Map<String, dynamic>>.from(map['recentLogs'] ?? []),
    );
  }
}
