// ignore_for_file: deprecated_member_use

import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as appwrite_models;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';

/// Backwards-compatible storage facade.
///
/// Existing screens still import `FirebaseStorageService`, but this now writes
/// to Appwrite Storage so those workflows can migrate without a broad UI rename.
class FirebaseStorageService {
  static final FirebaseStorageService _instance =
      FirebaseStorageService._internal();
  factory FirebaseStorageService() => _instance;
  FirebaseStorageService._internal();

  static final Logger _logger = Logger('FirebaseStorageService');

  final Storage _storage = Storage(appwriteClient);

  static const String tractsPath = 'Tracts';
  static const String whatTheBibleSaysPath = 'Tracts/What_The_Bible_Says';
  static const String boardDocumentsPath = 'board_documents';

  Future<String?> uploadBoardDocument(
      Uint8List bytes, String fileName, String contentType) async {
    return _uploadBytes(
      bucketId: AppwriteBackendConfig.boardDocumentsBucketId,
      objectName: fileName,
      bytes: bytes,
      contentType: contentType,
      logLabel: 'board document',
    );
  }

  Future<String?> getBoardDocumentDownloadURL(String fileName) async {
    return _downloadUrl(
      AppwriteBackendConfig.boardDocumentsBucketId,
      _stableFileId(fileName),
    );
  }

  Future<List<AppwriteStorageReference>> getTractFiles() async {
    return _listBucket(
      AppwriteBackendConfig.tractFilesBucketId,
      legacyPrefix: tractsPath,
    );
  }

  Future<List<AppwriteStorageReference>> getWhatTheBibleSaysFiles() async {
    final refs = await getTractFiles();
    return refs
        .where((ref) => ref.fullPath.contains('What_The_Bible_Says'))
        .toList();
  }

  Future<String?> downloadTractPDF(String fileName) async {
    return getTractDownloadURL(fileName);
  }

  Future<String?> getTractDownloadURL(String fileName) async {
    return _downloadUrl(
      AppwriteBackendConfig.tractFilesBucketId,
      _stableFileId(_normalizeTractName(fileName)),
    );
  }

  Future<String?> uploadTractPDF(Uint8List bytes, String fileName) async {
    return uploadTractPDFFromBytes(bytes, fileName);
  }

  Future<String?> uploadTractPDFFromBytes(
      Uint8List bytes, String fileName) async {
    return _uploadBytes(
      bucketId: AppwriteBackendConfig.tractFilesBucketId,
      objectName: _normalizeTractName(fileName),
      bytes: bytes,
      contentType: 'application/pdf',
      logLabel: 'tract PDF',
    );
  }

  Future<bool> deleteTractPDF(String fileName) async {
    try {
      await _storage.deleteFile(
        bucketId: AppwriteBackendConfig.tractFilesBucketId,
        fileId: _stableFileId(_normalizeTractName(fileName)),
      );
      return true;
    } catch (e) {
      _logger.error('Error deleting tract PDF', e);
      throw StorageException('Failed to delete tract PDF', originalError: e);
    }
  }

  Future<String?> getLocalTractPath(String fileName) async => null;

  Future<bool> isTractDownloaded(String fileName) async => false;

  Future<int?> getTractFileSize(String fileName) async {
    final metadata = await getTractFileMetadata(fileName);
    return metadata?.size;
  }

  Future<AppwriteStorageMetadata?> getTractFileMetadata(String fileName) async {
    try {
      final file = await _storage.getFile(
        bucketId: AppwriteBackendConfig.tractFilesBucketId,
        fileId: _stableFileId(_normalizeTractName(fileName)),
      );
      return AppwriteStorageMetadata.fromFile(file);
    } catch (e) {
      _logger.error('Error getting tract file metadata', e);
      throw StorageException('Failed to get tract file metadata',
          originalError: e);
    }
  }

  Future<void> clearTractCache() async {}

  Future<int> getTractCacheSize() async => 0;

  Future<List<String>> syncTractFiles() async {
    try {
      return [];
    } catch (e) {
      _logger.error('Error syncing tract files', e);
      throw StorageException('Failed to sync tract files', originalError: e);
    }
  }

  Future<Map<int, String>> getWhatTheBibleSaysLessons() async {
    try {
      final files = await getWhatTheBibleSaysFiles();
      return _lessonUrls(files);
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error getting What the Bible Says lessons', e);
      throw StorageException('Failed to get What the Bible Says lessons',
          originalError: e);
    }
  }

  Future<Map<int, String>> downloadAllWhatTheBibleSaysLessons() async {
    try {
      final files = await getWhatTheBibleSaysFiles();
      return _lessonUrls(files);
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error downloading What the Bible Says lessons', e);
      throw StorageException('Failed to download What the Bible Says lessons',
          originalError: e);
    }
  }

  Future<Map<int, String>> _lessonUrls(
      List<AppwriteStorageReference> files) async {
    final lessons = <int, String>{};
    for (final ref in files) {
      final match = RegExp(r'lesson[_\s]*(\d+)', caseSensitive: false)
          .firstMatch(ref.name);
      if (match == null) continue;
      final lessonNumber = int.tryParse(match.group(1)!);
      if (lessonNumber != null && lessonNumber >= 1 && lessonNumber <= 11) {
        lessons[lessonNumber] = await ref.getDownloadURL();
      }
    }
    return lessons;
  }

  Future<String?> _uploadBytes({
    required String bucketId,
    required String objectName,
    required Uint8List bytes,
    required String contentType,
    required String logLabel,
  }) async {
    try {
      final fileId = _stableFileId(objectName);
      try {
        await _storage.deleteFile(bucketId: bucketId, fileId: fileId);
      } on AppwriteException catch (e) {
        if (e.code != 404) rethrow;
      }

      final file = await _storage.createFile(
        bucketId: bucketId,
        fileId: fileId,
        file: InputFile.fromBytes(
          bytes: bytes,
          filename: objectName.split('/').last,
          contentType: contentType,
        ),
      );
      return _downloadUrl(bucketId, file.$id);
    } catch (e) {
      _logger.error('Error uploading $logLabel', e);
      throw StorageException('Failed to upload $logLabel', originalError: e);
    }
  }

  Future<List<AppwriteStorageReference>> _listBucket(
    String bucketId, {
    String? legacyPrefix,
  }) async {
    try {
      final result = await _storage.listFiles(
        bucketId: bucketId,
        queries: [Query.limit(100)],
      );
      return result.files.map((file) {
        final path = _legacyPath(file.name, legacyPrefix);
        return AppwriteStorageReference(
          storage: _storage,
          bucketId: bucketId,
          fileId: file.$id,
          name: file.name,
          fullPath: path,
          metadata: AppwriteStorageMetadata.fromFile(file),
        );
      }).toList();
    } catch (e) {
      _logger.error('Error listing Appwrite files', e);
      throw StorageException('Failed to list files', originalError: e);
    }
  }

  String _normalizeTractName(String fileName) {
    final normalized = fileName.replaceAll('\\', '/');
    if (normalized.startsWith('$tractsPath/')) {
      return normalized.substring(tractsPath.length + 1);
    }
    return normalized;
  }

  String _legacyPath(String fileName, String? legacyPrefix) {
    if (legacyPrefix == null || fileName.startsWith('$legacyPrefix/')) {
      return fileName;
    }
    return '$legacyPrefix/$fileName';
  }

  String _stableFileId(String objectName) {
    final digest = sha1.convert(utf8.encode(objectName)).toString();
    return 'f_${digest.substring(0, 34)}';
  }

  static String appwriteFileUrl(String bucketId, String fileId) {
    return '${AppwriteBackendConfig.endpoint}/storage/buckets/'
        '$bucketId/files/$fileId/view'
        '?project=${AppwriteBackendConfig.projectId}';
  }

  static String? parseFileIdFromUrl(String downloadUrl) {
    final uri = Uri.tryParse(downloadUrl);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    final fileIndex = segments.indexOf('files');
    if (fileIndex == -1 || fileIndex + 1 >= segments.length) return null;
    return segments[fileIndex + 1];
  }

  String _downloadUrl(String bucketId, String fileId) {
    return appwriteFileUrl(bucketId, fileId);
  }
}

class AppwriteStorageReference {
  const AppwriteStorageReference({
    required Storage storage,
    required this.bucketId,
    required this.fileId,
    required this.name,
    required this.fullPath,
    required AppwriteStorageMetadata metadata,
  })  : _storage = storage,
        _metadata = metadata;

  final Storage _storage;
  final String bucketId;
  final String fileId;
  final String name;
  final String fullPath;
  final AppwriteStorageMetadata _metadata;

  Future<String> getDownloadURL() async {
    return FirebaseStorageService.appwriteFileUrl(bucketId, fileId);
  }

  Future<AppwriteStorageMetadata> getMetadata() async {
    try {
      final file = await _storage.getFile(bucketId: bucketId, fileId: fileId);
      return AppwriteStorageMetadata.fromFile(file);
    } catch (_) {
      return _metadata;
    }
  }
}

class AppwriteStorageMetadata {
  const AppwriteStorageMetadata({
    this.size,
    this.contentType,
    this.updated,
  });

  factory AppwriteStorageMetadata.fromFile(appwrite_models.File file) {
    return AppwriteStorageMetadata(
      size: file.sizeOriginal,
      contentType: file.mimeType,
      updated: DateTime.tryParse(file.$updatedAt),
    );
  }

  final int? size;
  final String? contentType;
  final DateTime? updated;
}
