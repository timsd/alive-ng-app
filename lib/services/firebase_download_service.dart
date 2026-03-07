import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../utils/logger.dart';
import '../utils/app_exception.dart';

/// Service for handling all downloads from Firebase Storage with caching and error handling
class FirebaseDownloadService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final Dio _dio = Dio();
  static final Logger _logger = Logger('FirebaseDownloadService');

  // Cache settings
  static const int _cacheExpirationDays = 7;
  static const int _maxCacheSize = 100 * 1024 * 1024; // 100MB
  static const String _cacheDirectoryName = 'firebase_downloads_cache';

  /// Initialize the download service
  static Future<void> initializeDownloadService() async {
    try {
      // Configure Dio
      _dio.options.connectTimeout = const Duration(seconds: 30);
      _dio.options.receiveTimeout = const Duration(seconds: 60);
      _dio.options.sendTimeout = const Duration(seconds: 30);

      // Clean up old cache files
      await _cleanupOldCacheFiles();

      _logger.info('Firebase Download Service initialized successfully');
    } catch (e) {
      _logger.error('Error initializing Firebase Download Service', e);
      rethrow;
    }
  }

  /// Download file from Firebase Storage with caching
  static Future<DownloadResult> downloadFile({
    required String storagePath,
    String? customFileName,
    bool useCache = true,
    Function(double)? onProgress,
  }) async {
    try {
      // Validate that the path is from Firebase Storage
      if (!_isValidFirebaseStoragePath(storagePath)) {
        throw ValidationException(
            'Invalid Firebase Storage path: $storagePath');
      }

      final fileName = customFileName ?? _extractFileNameFromPath(storagePath);
      final cacheKey = _generateCacheKey(storagePath);

      // Check cache first if enabled
      if (useCache) {
        final cachedFile = await _getCachedFile(cacheKey, fileName);
        if (cachedFile != null) {
          return DownloadResult(
            file: cachedFile,
            fileName: fileName,
            fileSize: await cachedFile.length(),
            fromCache: true,
            downloadUrl: await _getDownloadUrl(storagePath),
          );
        }
      }

      // Download from Firebase Storage
      final downloadUrl = await _getDownloadUrl(storagePath);
      final file = await _downloadFromUrl(
        downloadUrl,
        fileName,
        cacheKey,
        onProgress: onProgress,
      );

      return DownloadResult(
        file: file,
        fileName: fileName,
        fileSize: await file.length(),
        fromCache: false,
        downloadUrl: downloadUrl,
      );
    } catch (e) {
      throw NetworkException('Failed to download file from $storagePath',
          originalError: e);
    }
  }

  /// Download file data as bytes
  static Future<Uint8List> downloadFileAsBytes({
    required String storagePath,
    bool useCache = true,
  }) async {
    try {
      final result = await downloadFile(
        storagePath: storagePath,
        useCache: useCache,
      );

      return await result.file.readAsBytes();
    } catch (e) {
      throw NetworkException(
          'Failed to download file as bytes from $storagePath',
          originalError: e);
    }
  }

  /// Get download URL for Firebase Storage path
  static Future<String> getDownloadUrl(String storagePath) async {
    try {
      if (!_isValidFirebaseStoragePath(storagePath)) {
        throw ValidationException(
            'Invalid Firebase Storage path: $storagePath');
      }

      return await _getDownloadUrl(storagePath);
    } catch (e) {
      throw NetworkException('Failed to get download URL for $storagePath',
          originalError: e);
    }
  }

  /// Check if file exists in Firebase Storage
  static Future<bool> fileExists(String storagePath) async {
    try {
      if (!_isValidFirebaseStoragePath(storagePath)) {
        return false;
      }

      final ref = _storage.ref().child(storagePath);
      await ref.getMetadata();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get file metadata from Firebase Storage
  static Future<FileMetadata?> getFileMetadata(String storagePath) async {
    try {
      if (!_isValidFirebaseStoragePath(storagePath)) {
        return null;
      }

      final ref = _storage.ref().child(storagePath);
      final metadata = await ref.getMetadata();

      return FileMetadata(
        name: metadata.name,
        size: metadata.size ?? 0,
        contentType: metadata.contentType ?? '',
        timeCreated: metadata.timeCreated,
        updated: metadata.updated,
        md5Hash: metadata.md5Hash,
        customMetadata: metadata.customMetadata ?? {},
      );
    } catch (e) {
      _logger.error('Error getting file metadata', e);
      throw StorageException('Failed to get file metadata', originalError: e);
    }
  }

  /// Clear download cache
  static Future<void> clearCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
      _logger.info('Download cache cleared successfully');
    } catch (e) {
      _logger.error('Error clearing download cache', e);
      rethrow;
    }
  }

  /// Get cache statistics
  static Future<CacheStats> getCacheStats() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (!await cacheDir.exists()) {
        return const CacheStats(
          totalFiles: 0,
          totalSizeBytes: 0,
          oldestFile: null,
          newestFile: null,
        );
      }

      int totalFiles = 0;
      int totalSize = 0;
      DateTime? oldestDate;
      DateTime? newestDate;

      await for (final entity in cacheDir.list()) {
        if (entity is File) {
          totalFiles++;
          final stat = await entity.stat();
          totalSize += stat.size;

          if (oldestDate == null || stat.modified.isBefore(oldestDate)) {
            oldestDate = stat.modified;
          }
          if (newestDate == null || stat.modified.isAfter(newestDate)) {
            newestDate = stat.modified;
          }
        }
      }

      return CacheStats(
        totalFiles: totalFiles,
        totalSizeBytes: totalSize,
        oldestFile: oldestDate,
        newestFile: newestDate,
      );
    } catch (e) {
      _logger.error('Error getting cache stats', e);
      throw StorageException('Failed to get cache stats', originalError: e);
    }
  }

  /// Validate Firebase Storage path
  static bool _isValidFirebaseStoragePath(String path) {
    // Check if it's a valid Firebase Storage path
    if (path.isEmpty) return false;

    // Should not contain invalid characters
    final invalidChars = ['..', '//', '\\'];
    for (final char in invalidChars) {
      if (path.contains(char)) return false;
    }

    // Should not start with /
    if (path.startsWith('/')) return false;

    return true;
  }

  /// Get download URL from Firebase Storage
  static Future<String> _getDownloadUrl(String storagePath) async {
    final ref = _storage.ref().child(storagePath);
    return await ref.getDownloadURL();
  }

  /// Download file from URL with caching
  static Future<File> _downloadFromUrl(
    String url,
    String fileName,
    String cacheKey, {
    Function(double)? onProgress,
  }) async {
    final cacheDir = await _getCacheDirectory();
    final cacheFile = File('${cacheDir.path}/$cacheKey');

    // Ensure cache directory exists
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    // Download file
    await _dio.download(
      url,
      cacheFile.path,
      onReceiveProgress: (received, total) {
        if (total != -1 && onProgress != null) {
          onProgress(received / total);
        }
      },
    );

    // Create metadata file
    await _createCacheMetadata(cacheKey, fileName, url);

    return cacheFile;
  }

  /// Get cached file if it exists and is valid
  static Future<File?> _getCachedFile(String cacheKey, String fileName) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final cacheFile = File('${cacheDir.path}/$cacheKey');
      final metadataFile = File('${cacheDir.path}/$cacheKey.meta');

      if (!await cacheFile.exists() || !await metadataFile.exists()) {
        return null;
      }

      // Check if cache is expired
      final stat = await cacheFile.stat();
      final expirationDate =
          DateTime.now().subtract(const Duration(days: _cacheExpirationDays));

      if (stat.modified.isBefore(expirationDate)) {
        // Cache expired, delete files
        await cacheFile.delete();
        await metadataFile.delete();
        return null;
      }

      return cacheFile;
    } catch (e) {
      _logger.error('Error getting cached file', e);
      throw StorageException('Failed to get cached file', originalError: e);
    }
  }

  /// Create cache metadata file
  static Future<void> _createCacheMetadata(
    String cacheKey,
    String fileName,
    String downloadUrl,
  ) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final metadataFile = File('${cacheDir.path}/$cacheKey.meta');

      final metadata = {
        'fileName': fileName,
        'downloadUrl': downloadUrl,
        'cachedAt': DateTime.now().toIso8601String(),
        'cacheKey': cacheKey,
      };

      await metadataFile.writeAsString(jsonEncode(metadata));
    } catch (e) {
      _logger.error('Failed to create cache metadata', e);
      // Non-fatal error, just log it
    }
  }

  /// Generate cache key for storage path
  static String _generateCacheKey(String storagePath) {
    final bytes = utf8.encode(storagePath);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Extract file name from storage path
  static String _extractFileNameFromPath(String storagePath) {
    final segments = storagePath.split('/');
    return segments.isNotEmpty ? segments.last : 'download';
  }

  /// Get cache directory
  static Future<Directory> _getCacheDirectory() async {
    final tempDir = await getTemporaryDirectory();
    return Directory('${tempDir.path}/$_cacheDirectoryName');
  }

  /// Clean up old cache files
  static Future<void> _cleanupOldCacheFiles() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (!await cacheDir.exists()) return;

      final expirationDate =
          DateTime.now().subtract(const Duration(days: _cacheExpirationDays));
      int deletedFiles = 0;
      int totalSize = 0;

      // Calculate current cache size and delete expired files
      await for (final entity in cacheDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          totalSize += stat.size;

          if (stat.modified.isBefore(expirationDate)) {
            await entity.delete();
            deletedFiles++;
            totalSize -= stat.size;
          }
        }
      }

      // If cache is still too large, delete oldest files
      if (totalSize > _maxCacheSize) {
        await _cleanupOldestFiles(totalSize - _maxCacheSize);
      }

      if (deletedFiles > 0) {
        _logger.info('Cleaned up $deletedFiles expired cache files');
      }
    } catch (e) {
      _logger.error('Error cleaning up cache files', e);
    }
  }

  /// Clean up oldest files to free space
  static Future<void> _cleanupOldestFiles(int bytesToFree) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final files = <FileSystemEntity>[];

      await for (final entity in cacheDir.list()) {
        if (entity is File) {
          files.add(entity);
        }
      }

      // Sort by modification date (oldest first)
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return aStat.modified.compareTo(bStat.modified);
      });

      int freedBytes = 0;
      int deletedFiles = 0;

      for (final file in files) {
        if (freedBytes >= bytesToFree) break;

        final stat = file.statSync();
        await file.delete();
        freedBytes += stat.size;
        deletedFiles++;

        // Also delete corresponding metadata file
        final metadataFile = File('${file.path}.meta');
        if (await metadataFile.exists()) {
          await metadataFile.delete();
        }
      }

      if (deletedFiles > 0) {
        _logger.info(
            'Deleted $deletedFiles old cache files to free ${freedBytes ~/ 1024}KB');
      }
    } catch (e) {
      _logger.error('Error cleaning up oldest files', e);
    }
  }
}

/// Download result model
class DownloadResult {
  final File file;
  final String fileName;
  final int fileSize;
  final bool fromCache;
  final String downloadUrl;

  const DownloadResult({
    required this.file,
    required this.fileName,
    required this.fileSize,
    required this.fromCache,
    required this.downloadUrl,
  });

  /// Get file size in human readable format
  String get fileSizeFormatted {
    if (fileSize < 1024) {
      return '${fileSize}B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }
}

/// File metadata model
class FileMetadata {
  final String name;
  final int size;
  final String contentType;
  final DateTime? timeCreated;
  final DateTime? updated;
  final String? md5Hash;
  final Map<String, String> customMetadata;

  const FileMetadata({
    required this.name,
    required this.size,
    required this.contentType,
    this.timeCreated,
    this.updated,
    this.md5Hash,
    required this.customMetadata,
  });

  /// Get file size in human readable format
  String get sizeFormatted {
    if (size < 1024) {
      return '${size}B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }
}

/// Cache statistics model
class CacheStats {
  final int totalFiles;
  final int totalSizeBytes;
  final DateTime? oldestFile;
  final DateTime? newestFile;

  const CacheStats({
    required this.totalFiles,
    required this.totalSizeBytes,
    this.oldestFile,
    this.newestFile,
  });

  /// Get total size in human readable format
  String get totalSizeFormatted {
    if (totalSizeBytes < 1024) {
      return '${totalSizeBytes}B';
    } else if (totalSizeBytes < 1024 * 1024) {
      return '${(totalSizeBytes / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }
}
