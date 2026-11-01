import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';

class AppwriteMeetingFileService {
  static final AppwriteMeetingFileService instance =
      AppwriteMeetingFileService._();

  AppwriteMeetingFileService._();

  final TablesDB _tables = TablesDB(appwriteClient);
  final Databases _databases = Databases(appwriteClient);
  final Storage _storage = Storage(appwriteClient);
  final Logger _logger = Logger('AppwriteMeetingFileService');
  static const String _localMeetingFilesKey = 'local_meeting_files_cache_v1';

  Future<List<Map<String, dynamic>>> getMeetingFiles() async {
    List<Map<String, dynamic>> results = [];
    try {
      final snapshot = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.meetingFilesCollectionId,
        queries: [
          Query.orderDesc('created_at'),
          Query.limit(100),
        ],
      );
      results = snapshot.rows.map(_rowData).toList();
    } catch (e) {
      _logger.warning('TablesDB listRows failed: $e, trying Databases.listDocuments...');
      try {
        final docSnapshot = await _databases.listDocuments(
          databaseId: AppwriteBackendConfig.databaseId,
          collectionId: AppwriteBackendConfig.meetingFilesCollectionId,
          queries: [
            Query.orderDesc('created_at'),
            Query.limit(100),
          ],
        );
        results = docSnapshot.documents
            .map((doc) => {'id': doc.$id, ...doc.data})
            .toList();
      } catch (dbErr) {
        _logger.warning('Cloud meeting files unavailable: $dbErr');
      }
    }

    // Merge with local offline meeting files
    final localFiles = await _getLocalMeetingFiles();
    final seenIds = results.map((f) => f['id'] ?? f['file_name']).toSet();
    for (final local in localFiles) {
      final id = local['id'] ?? local['file_name'];
      if (!seenIds.contains(id)) {
        results.add(local);
        seenIds.add(id);
      }
    }

    results.sort((a, b) {
      final aDate = a['created_at']?.toString() ?? '';
      final bDate = b['created_at']?.toString() ?? '';
      return bDate.compareTo(aDate);
    });

    return results;
  }

  Future<List<Map<String, dynamic>>> _getLocalMeetingFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_localMeetingFilesKey);
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final list = jsonDecode(jsonStr);
      if (list is List) {
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      _logger.warning('Failed to read local meeting files: $e');
    }
    return [];
  }

  Future<void> _saveLocalMeetingFile(Map<String, dynamic> fileData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await _getLocalMeetingFiles();
      current.removeWhere((f) => f['file_name'] == fileData['file_name']);
      current.insert(0, fileData);
      if (current.length > 50) current.removeRange(50, current.length);
      await prefs.setString(_localMeetingFilesKey, jsonEncode(current));
    } catch (e) {
      _logger.warning('Failed to save meeting file locally: $e');
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
      final createdAt = DateTime.now().toUtc().toIso8601String();

      String uploadedBucketId = AppwriteBackendConfig.meetingFilesBucketId;
      String fileId = ID.unique();

      bool storageSucceeded = false;
      try {
        await _storage.createFile(
          bucketId: uploadedBucketId,
          fileId: fileId,
          file: InputFile.fromBytes(
            bytes: data,
            filename: '${timestamp}_$fileName',
            contentType: 'text/markdown',
          ),
          permissions: [
            Permission.read(Role.any()),
          ],
        );
        storageSucceeded = true;
      } catch (storageErr) {
        _logger.warning(
            'Primary meeting_files bucket failed: $storageErr, trying content_media bucket...');
        try {
          uploadedBucketId = AppwriteBackendConfig.contentMediaBucketId;
          fileId = ID.unique();
          await _storage.createFile(
            bucketId: uploadedBucketId,
            fileId: fileId,
            file: InputFile.fromBytes(
              bytes: data,
              filename: '${timestamp}_$fileName',
              contentType: 'text/markdown',
            ),
            permissions: [
              Permission.read(Role.any()),
            ],
          );
          storageSucceeded = true;
        } catch (secondaryErr) {
          _logger.warning('Secondary bucket also failed: $secondaryErr. Proceeding with database record.');
        }
      }

      final fileUrl = storageSucceeded
          ? getMeetingFileDownloadUrl(fileId)
          : '';

      final rowData = {
        'meeting_id': 'general',
        'name': fileName,
        'file_url': fileUrl,
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
      };

      // Always save to local cache so minutes are preserved under any network conditions
      await _saveLocalMeetingFile({
        'id': fileId,
        ...rowData,
        'content_text': utf8.decode(data, allowMalformed: true),
      });

      // Attempt cloud persistence (TablesDB with fallback to Databases)
      try {
        await _tables.createRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.meetingFilesCollectionId,
          rowId: ID.unique(),
          data: rowData,
        );
      } catch (tableErr) {
        _logger.warning('TablesDB createRow note: $tableErr. Trying Databases.createDocument...');
        try {
          await _databases.createDocument(
            databaseId: AppwriteBackendConfig.databaseId,
            collectionId: AppwriteBackendConfig.meetingFilesCollectionId,
            documentId: ID.unique(),
            data: rowData,
          );
        } catch (dbErr) {
          _logger.warning('Databases createDocument note: $dbErr. Saved to local meeting files.');
        }
      }
    } catch (e) {
      _logger.error('Error uploading meeting file: $e');
      // Defensively avoid throwing if the file has already been persisted locally
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

      await _tables.deleteRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.meetingFilesCollectionId,
        rowId: documentId,
      );
    } catch (e) {
      _logger.error('Error deleting meeting file', e);
      throw DatabaseException(
        'Failed to delete meeting file',
        originalError: e,
      );
    }
  }

  Map<String, dynamic> _rowData(models.Row row) {
    return {
      ...Map<String, dynamic>.from(row.data),
      'id': row.$id,
    };
  }
}
