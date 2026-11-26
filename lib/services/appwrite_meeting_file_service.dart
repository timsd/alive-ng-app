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
      ).timeout(const Duration(seconds: 6));
      results = snapshot.rows.map(_rowData).toList();
    } catch (e) {
      _logger.warning('Cloud meeting files unavailable: $e');
    }

    // Merge with local offline meeting files (dedupe by row id, storage
    // file path and file name so a cloud-synced copy is never listed twice).
    final localFiles = await _getLocalMeetingFiles();
    final seenKeys = <String>{};
    for (final f in results) {
      for (final k in [f['id'], f['file_path'], f['file_name']]) {
        if (k != null && k.toString().isNotEmpty) seenKeys.add(k.toString());
      }
    }
    for (final local in localFiles) {
      final keys = [local['id'], local['file_path'], local['file_name']]
          .where((k) => k != null && k.toString().isNotEmpty)
          .map((k) => k.toString())
          .toList();
      if (keys.any(seenKeys.contains)) continue;
      results.add({...local, 'is_local_only': true});
      seenKeys.addAll(keys);
    }

    results.sort((a, b) {
      final aDate = a['created_at']?.toString() ?? '';
      final bDate = b['created_at']?.toString() ?? '';
      return bDate.compareTo(aDate);
    });

    return results;
  }

  /// Checks if minutes for the specified meeting room have already been saved
  /// within the given time window (default 4 hours) to prevent duplicate uploads.
  Future<Map<String, dynamic>?> findExistingMeetingMinutes({
    required String roomTitle,
    Duration window = const Duration(hours: 4),
  }) async {
    try {
      final files = await getMeetingFiles();
      final sanitizedTitle =
          roomTitle.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_').toLowerCase();
      final now = DateTime.now();

      for (final f in files) {
        final name = (f['file_name'] ?? '').toString().toLowerCase();
        final desc = (f['description'] ?? '').toString().toLowerCase();
        if ((name.contains('minutes') && name.contains(sanitizedTitle)) ||
            (desc.contains('minutes') && desc.contains(roomTitle.toLowerCase()))) {
          final createdAtStr = f['created_at']?.toString();
          if (createdAtStr != null) {
            final created = DateTime.tryParse(createdAtStr);
            if (created != null && now.difference(created).abs() <= window) {
              return f;
            }
          } else {
            return f;
          }
        }
      }
    } catch (e) {
      _logger.warning('Error checking existing minutes: $e');
    }
    return null;
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

  Future<void> _removeLocalMeetingFile({
    required String documentId,
    required String filePath,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await _getLocalMeetingFiles();
      final before = current.length;
      current.removeWhere((f) {
        final id = f['id']?.toString() ?? '';
        final path = f['file_path']?.toString() ?? '';
        final name = f['file_name']?.toString() ?? '';
        return (documentId.isNotEmpty &&
                (id == documentId || path == documentId || name == documentId)) ||
            (filePath.isNotEmpty && (path == filePath || id == filePath));
      });
      if (current.length != before) {
        await prefs.setString(_localMeetingFilesKey, jsonEncode(current));
      }
    } catch (e) {
      _logger.warning('Failed to remove local meeting file: $e');
    }
  }

  List<String> _ownerPermissions(String uploaderId) {
    // Confidential meeting minutes must require an authenticated user (never Role.any()).
    final perms = <String>[Permission.read(Role.users())];
    final looksReal = uploaderId.isNotEmpty &&
        uploaderId != 'alive-scribe' &&
        !uploaderId.startsWith('user_') &&
        !uploaderId.startsWith('leader_');
    if (looksReal) {
      perms.add(Permission.update(Role.user(uploaderId)));
      perms.add(Permission.delete(Role.user(uploaderId)));
    }
    return perms;
  }

  String _mimeTypeForExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'doc':
        return 'application/msword';
      case 'pdf':
        return 'application/pdf';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'md':
      case 'markdown':
        return 'text/markdown';
      case 'txt':
        return 'text/plain';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
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
      final fileType = fileName.contains('.')
          ? fileName.split('.').last.toLowerCase()
          : 'bin';
      final mimeType = _mimeTypeForExtension(fileType);
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
            contentType: mimeType,
          ),
          permissions: _ownerPermissions(uploaderId),
        );
        storageSucceeded = true;
      } catch (storageErr) {
        final errStr = storageErr.toString().toLowerCase();
        if (storageErr is TypeError ||
            errStr.contains('subtype of type') ||
            errStr.contains('minified:') ||
            errStr.contains('typeerror')) {
          _logger.info('File uploaded with ID $fileId (handled SDK deserialization quirk)');
          storageSucceeded = true;
        } else if (const {'pdf', 'png', 'jpg', 'jpeg', 'webp', 'mp3', 'mp4'}.contains(fileType)) {
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
                contentType: mimeType,
              ),
              permissions: _ownerPermissions(uploaderId),
            );
            storageSucceeded = true;
          } catch (secondaryErr) {
            final secStr = secondaryErr.toString().toLowerCase();
            if (secondaryErr is TypeError ||
                secStr.contains('subtype of type') ||
                secStr.contains('minified:') ||
                secStr.contains('typeerror')) {
              storageSucceeded = true;
            } else {
              _logger.warning('Secondary bucket also failed: $secondaryErr');
            }
          }
        } else {
          _logger.warning('Primary meeting_files bucket upload failed for .$fileType: $storageErr');
        }
      }

      final fileUrl = storageSucceeded
          ? getMeetingFileDownloadUrl(fileId, bucketId: uploadedBucketId, fileName: fileName)
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

      if (!storageSucceeded) {
        throw Exception(
          'Cloud file upload failed for "$fileName". Please check your connection and try again.',
        );
      }

      // Cache metadata only locally (never decode binary .docx/PDFs into SharedPreferences/localStorage)
      await _saveLocalMeetingFile({
        'id': fileId,
        ...rowData,
        'is_local_only': false,
      });

      bool dbSucceeded = false;
      try {
        await _tables.createRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.meetingFilesCollectionId,
          rowId: ID.unique(),
          data: rowData,
        );
        dbSucceeded = true;
      } catch (tableErr) {
        _logger.warning('TablesDB createRow note: $tableErr');
      }

      if (!dbSucceeded) {
        throw Exception(
          'File uploaded but metadata could not be saved for "$fileName". Please try again.',
        );
      }
    } catch (e) {
      _logger.error('Error uploading meeting file: $e');
      rethrow;
    }
  }

  String getMeetingFileDownloadUrl(
    String filePath, {
    String? bucketId,
    String? fileName,
  }) {
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      return filePath;
    }
    final targetBucket = bucketId ?? AppwriteBackendConfig.meetingFilesBucketId;
    final ext = (fileName ?? filePath).split('.').last.toLowerCase();
    // Office documents (.docx/.doc/.xlsx/.pptx) must use /download so browsers
    // save the binary archive rather than rendering raw PK ZIP bytes inline.
    final action = const {'docx', 'doc', 'xlsx', 'pptx'}.contains(ext) ? 'download' : 'view';
    return '${AppwriteBackendConfig.endpoint}/storage/buckets/'
        '$targetBucket/files/$filePath/$action'
        '?project=${AppwriteBackendConfig.projectId}';
  }

  Future<void> deleteMeetingFile(String documentId, String filePath) async {
    // 1. Best-effort removal of the stored binary (tries both buckets).
    //    Missing files (404) or legacy read-only files (401) must not block
    //    removing the listing itself.
    if (filePath.isNotEmpty &&
        !filePath.startsWith('http://') &&
        !filePath.startsWith('https://')) {
      for (final bucketId in [
        AppwriteBackendConfig.meetingFilesBucketId,
        AppwriteBackendConfig.contentMediaBucketId,
      ]) {
        try {
          await _storage.deleteFile(bucketId: bucketId, fileId: filePath);
          break;
        } on AppwriteException catch (e) {
          if (e.code == 404) continue;
          _logger.warning('Storage delete note ($bucketId): ${e.code} ${e.message}');
          break;
        } catch (e) {
          _logger.warning('Storage delete note ($bucketId): $e');
          break;
        }
      }
    }

    // 2. Always clear the offline cache copy so it never reappears.
    await _removeLocalMeetingFile(documentId: documentId, filePath: filePath);

    // 3. Remove the database record. The listing id may be a real row id
    //    (cloud) or a storage file id (offline-cached auto-saved minutes),
    //    so fall back to locating the row by file_path.
    Object? lastError;
    final candidateRowIds = <String>{};
    if (documentId.isNotEmpty) candidateRowIds.add(documentId);
    try {
      if (filePath.isNotEmpty) {
        final match = await _tables.listRows(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.meetingFilesCollectionId,
          queries: [Query.equal('file_path', filePath), Query.limit(5)],
        );
        candidateRowIds.addAll(match.rows.map((r) => r.$id));
      }
    } catch (e) {
      _logger.warning('Lookup by file_path note: $e');
    }

    var deletedAny = false;
    var allMissing = true;
    for (final rowId in candidateRowIds) {
      try {
        await _tables.deleteRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.meetingFilesCollectionId,
          rowId: rowId,
        );
        deletedAny = true;
        allMissing = false;
      } on AppwriteException catch (e) {
        if (e.code == 404) continue; // not a row id (e.g. storage id)
        allMissing = false;
        lastError = e;
      } catch (e) {
        allMissing = false;
        lastError = e;
      }
    }

    if (!deletedAny && !allMissing && lastError != null) {
      _logger.error('Error deleting meeting file', lastError);
      final code = lastError is AppwriteException ? lastError.code : null;
      throw DatabaseException(
        code == 401
            ? 'You do not have permission to delete this file'
            : 'Could not delete this file. Please try again.',
        originalError: lastError,
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
