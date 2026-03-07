import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';

/// Service for managing profile picture cleanup and storage optimization
class ProfileCleanupService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final Logger _logger = Logger('ProfileCleanupService');

  // Collections and paths
  static const String _usersCollection = 'users';
  static const String _profilePicturesPath = 'profile_pictures';
  static const String _cleanupLogsCollection = 'cleanup_logs';

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

  /// Clean up old profile pictures from Firebase Storage
  Future<void> cleanupOldProfilePictures() async {
    try {
      final cutoffDate =
          DateTime.now().subtract(const Duration(days: _retentionDays));
      int deletedCount = 0;
      int errorCount = 0;

      // Get all users to check their profile pictures
      final usersSnapshot = await _firestore.collection(_usersCollection).get();
      final activeProfilePictures = <String>{};

      // Collect currently active profile picture URLs
      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final profilePictureUrl = userData['profilePictureUrl'] as String?;
        if (profilePictureUrl != null && profilePictureUrl.isNotEmpty) {
          activeProfilePictures.add(_extractFilePathFromUrl(profilePictureUrl));
        }
      }

      // List all files in the profile pictures directory
      final storageRef = _storage.ref().child(_profilePicturesPath);
      final listResult = await storageRef.listAll();

      for (final item in listResult.items) {
        try {
          final metadata = await item.getMetadata();
          final createdTime = metadata.timeCreated;

          if (createdTime != null && createdTime.isBefore(cutoffDate)) {
            // Check if this file is still being used by any user
            final filePath = item.fullPath;
            if (!activeProfilePictures.contains(filePath)) {
              await item.delete();
              deletedCount++;
              await _logCleanupActivity(
                'Deleted old profile picture: $filePath',
                'info',
              );
            }
          }
        } catch (e) {
          errorCount++;
          await _logCleanupActivity(
            'Error processing file ${item.fullPath}: $e',
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
      final filePath = '$_profilePicturesPath/$fileName';

      // Upload new profile picture
      final storageRef = _storage.ref().child(filePath);
      final uploadTask = storageRef.putFile(
        imageFile,
        SettableMetadata(
          contentType: _getContentType(extension),
          customMetadata: {
            'userId': userId,
            'uploadedAt': DateTime.now().toIso8601String(),
            'originalName': imageFile.path.split('/').last,
          },
        ),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update user document with new profile picture URL
      await _firestore.collection(_usersCollection).doc(userId).update({
        'profilePictureUrl': downloadUrl,
        'profilePictureUpdatedAt': FieldValue.serverTimestamp(),
      });

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
      final filePath = _extractFilePathFromUrl(profilePictureUrl);
      if (filePath.isNotEmpty) {
        final storageRef = _storage.ref().child(filePath);
        await storageRef.delete();
        await _logCleanupActivity(
          'Deleted old profile picture: $filePath',
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

  /// Extract file path from Firebase Storage URL
  String _extractFilePathFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      // Firebase Storage URLs usually have the path after /o/
      // format: https://firebasestorage.googleapis.com/v0/b/[bucket]/o/[path]?alt=media...
      final oIndex = pathSegments.indexOf('o');
      if (oIndex != -1 && oIndex + 1 < pathSegments.length) {
        // The path is URL encoded, so we need to decode it
        return Uri.decodeComponent(pathSegments[oIndex + 1]);
      }
      return '';
    } catch (e) {
      _logger.error('Error extracting file path from URL: $e');
      return '';
    }
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
      await _firestore.collection(_cleanupLogsCollection).add({
        'message': message,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (type == 'error') {
        _logger.error(message);
      } else {
        _logger.info(message);
      }
    } catch (e) {
      // Just log to console if we can't write to Firestore
      _logger.error('Failed to log cleanup activity: $e');
    }
  }

  /// Get cleanup statistics
  Future<Map<String, dynamic>> getCleanupStats() async {
    try {
      // Get total number of profile pictures
      final storageRef = _storage.ref().child(_profilePicturesPath);
      final listResult = await storageRef.listAll();
      final totalFiles = listResult.items.length;

      // Get recent cleanup logs
      final logsSnapshot = await _firestore
          .collection(_cleanupLogsCollection)
          .where('service', isEqualTo: 'ProfileCleanupService')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      final recentLogs = logsSnapshot.docs.map((doc) => doc.data()).toList();

      // Calculate storage usage (approximate)
      int totalSize = 0;
      for (final item in listResult.items) {
        try {
          final metadata = await item.getMetadata();
          totalSize += metadata.size ?? 0;
        } catch (e) {
          // Skip files that can't be accessed
        }
      }

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
      final usersSnapshot = await _firestore.collection(_usersCollection).get();
      final activeProfilePictures = <String>{};

      // Collect currently active profile picture URLs
      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final profilePictureUrl = userData['profilePictureUrl'] as String?;
        if (profilePictureUrl != null && profilePictureUrl.isNotEmpty) {
          activeProfilePictures.add(_extractFilePathFromUrl(profilePictureUrl));
        }
      }

      // List all files in the profile pictures directory
      final storageRef = _storage.ref().child(_profilePicturesPath);
      final listResult = await storageRef.listAll();

      for (final item in listResult.items) {
        try {
          final filePath = item.fullPath;
          if (!activeProfilePictures.contains(filePath)) {
            await item.delete();
            deletedCount++;
            await _logCleanupActivity(
              'Force deleted unused profile picture: $filePath',
              'info',
            );
          }
        } catch (e) {
          await _logCleanupActivity(
            'Error force deleting file ${item.fullPath}: $e',
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
