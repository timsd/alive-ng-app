import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:appwrite/appwrite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../utils/logger.dart';

class VideoContentService {
  static final VideoContentService instance = VideoContentService._internal();
  VideoContentService._internal();

  final TablesDB _tables = TablesDB(appwriteClient);
  final Databases _databases = Databases(appwriteClient);
  final Storage _storage = Storage(appwriteClient);
  final Logger _logger = Logger('VideoContentService');

  static const String _localCacheKey = 'video_content_cache_v1';

  List<Map<String, dynamic>> _cachedVideos = [];

  List<Map<String, dynamic>> get currentVideos => List.unmodifiable(_cachedVideos);

  Future<List<Map<String, dynamic>>> loadVideos({bool forceRefresh = false}) async {
    // 1. Try local cache first for instant UI response
    if (!forceRefresh && _cachedVideos.isEmpty) {
      await _loadFromLocalCache();
    }

    // 2. Fetch fresh from Appwrite `videos` collection
    try {
      final rows = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.videosCollectionId,
        queries: [
          Query.orderDesc('created_at'),
          Query.limit(100),
        ],
      ).timeout(const Duration(seconds: 8));

      final items = rows.rows.map((r) => {
        ...Map<String, dynamic>.from(r.data),
        'id': r.$id,
        r'$id': r.$id,
      }).toList();

      if (items.isNotEmpty) {
        _cachedVideos = items;
        await _saveToLocalCache();
        return _cachedVideos;
      }
    } catch (e) {
      _logger.warning('TablesDB failed listing videos: $e, trying Databases fallback');
      try {
        final docs = await _databases.listDocuments(
          databaseId: AppwriteBackendConfig.databaseId,
          collectionId: AppwriteBackendConfig.videosCollectionId,
          queries: [
            Query.orderDesc('created_at'),
            Query.limit(100),
          ],
        ).timeout(const Duration(seconds: 8));

        final items = docs.documents.map((d) => {
          ...Map<String, dynamic>.from(d.data),
          'id': d.$id,
          r'$id': d.$id,
        }).toList();

        if (items.isNotEmpty) {
          _cachedVideos = items;
          await _saveToLocalCache();
          return _cachedVideos;
        }
      } catch (dbErr) {
        _logger.warning('Databases listing fallback also failed: $dbErr');
      }
    }

    if (_cachedVideos.isEmpty) {
      await _loadFromLocalCache();
    }
    return _cachedVideos;
  }

  Future<Map<String, dynamic>> saveVideo(Map<String, dynamic> videoData) async {
    final existingId = videoData['id']?.toString() ?? videoData[r'$id']?.toString();
    final now = DateTime.now().toUtc().toIso8601String();

    final dataToSave = Map<String, dynamic>.from(videoData)
      ..remove('id')
      ..remove(r'$id')
      ..remove(r'$collectionId')
      ..remove(r'$databaseId')
      ..remove(r'$permissions')
      ..remove(r'$createdAt')
      ..remove(r'$updatedAt');

    dataToSave['updated_at'] = now;

    if (existingId != null && existingId.isNotEmpty) {
      // Update existing
      try {
        final updated = await _tables.updateRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.videosCollectionId,
          rowId: existingId,
          data: dataToSave,
        );
        final item = {
          ...Map<String, dynamic>.from(updated.data),
          'id': updated.$id,
          r'$id': updated.$id,
        };
        _replaceInCache(item);
        return item;
      } catch (e) {
        _logger.warning('TablesDB update failed: $e, trying Databases fallback');
        final updatedDoc = await _databases.updateDocument(
          databaseId: AppwriteBackendConfig.databaseId,
          collectionId: AppwriteBackendConfig.videosCollectionId,
          documentId: existingId,
          data: dataToSave,
        );
        final item = {
          ...Map<String, dynamic>.from(updatedDoc.data),
          'id': updatedDoc.$id,
          r'$id': updatedDoc.$id,
        };
        _replaceInCache(item);
        return item;
      }
    } else {
      // Create new
      dataToSave['created_at'] = now;
      final newId = ID.unique();
      try {
        final created = await _tables.createRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.videosCollectionId,
          rowId: newId,
          data: dataToSave,
          permissions: [
            Permission.read(Role.any()),
            Permission.write(Role.users()),
          ],
        );
        final item = {
          ...Map<String, dynamic>.from(created.data),
          'id': created.$id,
          r'$id': created.$id,
        };
        _cachedVideos.insert(0, item);
        await _saveToLocalCache();
        return item;
      } catch (e) {
        _logger.warning('TablesDB create failed: $e, trying Databases fallback');
        final createdDoc = await _databases.createDocument(
          databaseId: AppwriteBackendConfig.databaseId,
          collectionId: AppwriteBackendConfig.videosCollectionId,
          documentId: newId,
          data: dataToSave,
          permissions: [
            Permission.read(Role.any()),
            Permission.write(Role.users()),
          ],
        );
        final item = {
          ...Map<String, dynamic>.from(createdDoc.data),
          'id': createdDoc.$id,
          r'$id': createdDoc.$id,
        };
        _cachedVideos.insert(0, item);
        await _saveToLocalCache();
        return item;
      }
    }
  }

  Future<bool> deleteVideo(String videoId) async {
    try {
      try {
        await _tables.deleteRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.videosCollectionId,
          rowId: videoId,
        );
      } catch (_) {
        await _databases.deleteDocument(
          databaseId: AppwriteBackendConfig.databaseId,
          collectionId: AppwriteBackendConfig.videosCollectionId,
          documentId: videoId,
        );
      }
      _cachedVideos.removeWhere((v) => (v['id'] == videoId || v[r'$id'] == videoId));
      await _saveToLocalCache();
      return true;
    } catch (e) {
      _logger.error('Failed to delete video $videoId: $e');
      return false;
    }
  }

  Future<String?> uploadMediaFile({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    final fileId = ID.unique();
    final bucketId = AppwriteBackendConfig.contentMediaBucketId;
    try {
      await _storage.createFile(
        bucketId: bucketId,
        fileId: fileId,
        file: InputFile.fromBytes(
          bytes: bytes,
          filename: filename,
          contentType: mimeType,
        ),
        permissions: [
          Permission.read(Role.any()),
        ],
      );

      final endpoint = AppwriteBackendConfig.endpoint;
      final projectId = AppwriteBackendConfig.projectId;
      return '$endpoint/storage/buckets/$bucketId/files/$fileId/view?project=$projectId';
    } catch (e) {
      _logger.error('Failed to upload media file to bucket $bucketId: $e');
      return null;
    }
  }

  void _replaceInCache(Map<String, dynamic> item) {
    final id = item['id'] ?? item[r'$id'];
    final idx = _cachedVideos.indexWhere((v) => (v['id'] == id || v[r'$id'] == id));
    if (idx != -1) {
      _cachedVideos[idx] = item;
    } else {
      _cachedVideos.insert(0, item);
    }
    _saveToLocalCache();
  }

  Future<void> _loadFromLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_localCacheKey);
      if (str != null && str.isNotEmpty) {
        final list = jsonDecode(str);
        if (list is List) {
          _cachedVideos = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (_) {}
  }

  Future<void> _saveToLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localCacheKey, jsonEncode(_cachedVideos));
    } catch (_) {}
  }
}

