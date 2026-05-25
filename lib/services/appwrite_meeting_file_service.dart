// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';

class AppwriteMeetingFileService {
  static final AppwriteMeetingFileService instance =
      AppwriteMeetingFileService._();

  AppwriteMeetingFileService._();

  final Databases _databases = Databases(appwriteClient);
  final Storage _storage = Storage(appwriteClient);
  final Logger _logger = Logger('AppwriteMeetingFileService');

  Future<List<Map<String, dynamic>>> getMeetingFiles() async {
    try {
      final snapshot = await _databases.listDocuments(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.meetingFilesCollectionId,
        queries: [
          Query.orderDesc('created_at'),
          Query.limit(100),
        ],
      );
      return snapshot.documents.map(_documentData).toList();
    } catch (e) {
      _logger.error('Error getting meeting files', e);
      throw DatabaseException('Failed to get meeting files', originalError: e);
    }
  }

  Stream<List<Map<String, dynamic>>> getMeetingFilesStream() {
    return (() async* {
      yield await getMeetingFiles();
      yield* Stream.periodic(const Duration(seconds: 30))
          .asyncMap((_) => getMeetingFiles());
    })();
  }

  Future<void> uploadMeetingFileBytes(
    Uint8List data, {
    required String fileName,
    required String description,
    required String uploaderId,
    required String uploadedBy,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileType = fileName.split('.').last.toLowerCase();
      final fileId = ID.unique();
      final createdAt = DateTime.now().toUtc().toIso8601String();

      await _storage.createFile(
        bucketId: AppwriteBackendConfig.meetingFilesBucketId,
        fileId: fileId,
        file: InputFile.fromBytes(
          bytes: data,
          filename: '${timestamp}_$fileName',
        ),
      );

      await _databases.createDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.meetingFilesCollectionId,
        documentId: ID.unique(),
        data: {
          'meeting_id': 'general',
          'name': fileName,
          'file_url': getMeetingFileDownloadUrl(fileId),
          'file_path': fileId,
          'file_name': fileName,
          'file_type': fileType,
          'file_size': data.lengthInBytes,
          'description': description,
          'uploaded_by': uploadedBy,
          'uploader_id': uploaderId,
          'visibility': 'meeting',
          'uploaded_at': createdAt,
          'created_at': createdAt,
          'updated_at': createdAt,
        },
      );
    } catch (e) {
      _logger.error('Error uploading meeting file', e);
      throw DatabaseException('Failed to upload meeting file',
          originalError: e);
    }
  }

  String getMeetingFileDownloadUrl(String filePath) {
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      return filePath;
    }
    return '${AppwriteBackendConfig.endpoint}/storage/buckets/'
        '${AppwriteBackendConfig.meetingFilesBucketId}/files/$filePath/view'
        '?project=${AppwriteBackendConfig.projectId}';
  }

  Future<void> deleteMeetingFile(String documentId, String filePath) async {
    try {
      if (filePath.isNotEmpty &&
          !filePath.startsWith('http://') &&
          !filePath.startsWith('https://')) {
        try {
          await _storage.deleteFile(
            bucketId: AppwriteBackendConfig.meetingFilesBucketId,
            fileId: filePath,
          );
        } on AppwriteException catch (e) {
          if (e.code != 404) rethrow;
        }
      }

      await _databases.deleteDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.meetingFilesCollectionId,
        documentId: documentId,
      );
    } catch (e) {
      _logger.error('Error deleting meeting file', e);
      throw DatabaseException('Failed to delete meeting file',
          originalError: e);
    }
  }

  Map<String, dynamic> _documentData(dynamic document) {
    return {
      ...Map<String, dynamic>.from(document.data as Map),
      'id': document.$id,
    };
  }
}
