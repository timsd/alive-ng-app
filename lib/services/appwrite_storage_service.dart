import 'package:appwrite/appwrite.dart';
import 'package:appwrite/src/enums.dart';
import 'package:flutter/foundation.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';

class AppwriteStorageService {
  AppwriteStorageService._();

  static final AppwriteStorageService instance = AppwriteStorageService._();

  final Storage _storage = Storage(appwriteClient);

  Future<String> uploadChatFile({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    // Primary: dedicated chat files bucket.
    // Fallback: content media or profile files bucket to ensure resilient uploads
    // even if the primary bucket is undergoing maintenance, permission updates, or schema changes.
    final candidateBuckets = [
      AppwriteBackendConfig.chatFilesBucketId,
      AppwriteBackendConfig.contentMediaBucketId,
      AppwriteBackendConfig.profileFilesBucketId,
    ];

    Object? lastError;
    for (final bucketId in candidateBuckets) {
      try {
        return await _uploadFile(
          bucketId: bucketId,
          bytes: bytes,
          fileName: fileName,
          contentType: contentType,
        );
      } catch (e) {
        lastError = e;
        debugPrint(
            '[AppwriteStorageService] uploadChatFile failed for bucket $bucketId: $e, trying candidate fallback...');
      }
    }
    throw lastError ?? Exception('Failed to upload chat file to any storage bucket');
  }

  Future<String> uploadProfileFile({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    return _uploadFile(
      bucketId: AppwriteBackendConfig.profileFilesBucketId,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );
  }

  /// Uploads a new profile image and automatically cleans up the old one from Appwrite Storage.
  Future<String> replaceProfileFile({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    String? previousUrl,
  }) async {
    // 1. Upload new image first to ensure availability
    final newUrl = await uploadProfileFile(
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );

    // 2. Auto-delete old profile image if it exists and is an Appwrite storage file
    if (previousUrl != null &&
        previousUrl.isNotEmpty &&
        previousUrl != newUrl) {
      try {
        await deleteFileByUrl(previousUrl);
      } catch (e) {
        debugPrint('[AppwriteStorageService] Warning: Could not delete previous profile image: $e');
      }
    }

    return newUrl;
  }

  Future<String> uploadContentFile({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    return _uploadFile(
      bucketId: AppwriteBackendConfig.contentMediaBucketId,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );
  }

  Future<void> deleteFileByUrl(String fileUrl) async {
    final uri = Uri.tryParse(fileUrl);
    if (uri == null) return;
    final segments = uri.pathSegments;
    final bucketIndex = segments.indexOf('buckets');
    final fileIndex = segments.indexOf('files');
    if (bucketIndex == -1 ||
        fileIndex == -1 ||
        bucketIndex + 1 >= segments.length ||
        fileIndex + 1 >= segments.length) {
      return;
    }

    try {
      final bucketId = segments[bucketIndex + 1];
      final fileId = segments[fileIndex + 1];
      await _storage.deleteFile(
        bucketId: bucketId,
        fileId: fileId,
      );
      debugPrint('[AppwriteStorageService] Cleaned up previous profile file: $fileId from $bucketId');
    } catch (e) {
      debugPrint('[AppwriteStorageService] Error deleting file by URL ($fileUrl): $e');
    }
  }

  Future<String> _uploadFile({
    required String bucketId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    List<String>? permissions,
  }) async {
    final fileId = ID.unique();

    InputFile buildInput() => InputFile.fromBytes(
          bytes: bytes,
          filename: fileName,
          contentType: contentType,
        );

    // Primary: use appwriteClient.chunkedUpload directly to bypass the
    // Appwrite Flutter SDK 28.3 deserialization bug where models.File.fromMap crashes
    // with "TypeError: null: type 'minified:a0l' is not a subtype of type 'int'"
    // when self-hosted Appwrite (1.5/1.6/1.8) returns null for sizeActual/chunksTotal.
    try {
      final apiPath = '/storage/buckets/$bucketId/files';
      final apiParams = <String, dynamic>{
        'fileId': fileId,
        'file': buildInput(),
        if (permissions != null && permissions.isNotEmpty)
          'permissions': permissions,
      };
      final apiHeaders = <String, String>{
        'X-Appwrite-Project': appwriteClient.config['project'] ??
            AppwriteBackendConfig.projectId,
        'content-type': 'multipart/form-data',
        'accept': 'application/json',
      };

      final res = await appwriteClient.chunkedUpload(
        path: apiPath,
        params: apiParams,
        paramName: 'file',
        idParamName: 'fileId',
        headers: apiHeaders,
        method: HttpMethod.post,
      );

      final dynamic data = res.data;
      String resolvedId = fileId;
      if (data is Map) {
        final sid = data['\$id']?.toString();
        if (sid != null && sid.isNotEmpty) {
          resolvedId = sid;
        }
      }

      return '${AppwriteBackendConfig.endpoint}/storage/buckets/'
          '$bucketId/files/$resolvedId/view'
          '?project=${AppwriteBackendConfig.projectId}';
    } catch (e) {
      final eStr = e.toString().toLowerCase();
      // If direct chunkedUpload threw because permissions caused rejection, retry without permissions
      if (permissions != null && permissions.isNotEmpty) {
        try {
          debugPrint(
              '[AppwriteStorageService] Retrying chunkedUpload without permissions for bucket $bucketId due to: $e');
          final res = await appwriteClient.chunkedUpload(
            path: '/storage/buckets/$bucketId/files',
            params: <String, dynamic>{
              'fileId': fileId,
              'file': buildInput(),
            },
            paramName: 'file',
            idParamName: 'fileId',
            headers: <String, String>{
              'X-Appwrite-Project': appwriteClient.config['project'] ??
                  AppwriteBackendConfig.projectId,
              'content-type': 'multipart/form-data',
              'accept': 'application/json',
            },
            method: HttpMethod.post,
          );
          final dynamic data = res.data;
          String resolvedId = fileId;
          if (data is Map) {
            final sid = data['\$id']?.toString();
            if (sid != null && sid.isNotEmpty) {
              resolvedId = sid;
            }
          }
          return '${AppwriteBackendConfig.endpoint}/storage/buckets/'
              '$bucketId/files/$resolvedId/view'
              '?project=${AppwriteBackendConfig.projectId}';
        } catch (_) {}
      }

      debugPrint(
          '[AppwriteStorageService] Direct chunkedUpload failed: $e. Falling back to _storage.createFile with TypeError protection...');

      // Fallback: use _storage.createFile with TypeError tolerance
      try {
        final file = await _storage.createFile(
          bucketId: bucketId,
          fileId: fileId,
          file: buildInput(),
          permissions: permissions,
        );
        final resolvedId = file.$id.isNotEmpty ? file.$id : fileId;
        return '${AppwriteBackendConfig.endpoint}/storage/buckets/'
            '$bucketId/files/$resolvedId/view'
            '?project=${AppwriteBackendConfig.projectId}';
      } catch (err) {
        // If it's a TypeError (null cast to int in models.File.fromMap), the upload
        // on the server has already SUCCEEDED and fileId is the created file!
        final errStr = err.toString().toLowerCase();
        final isTypeMismatch = err is TypeError ||
            errStr.contains('subtype of type') ||
            errStr.contains('minified:') ||
            errStr.contains('typeerror');
        if (isTypeMismatch) {
          debugPrint(
              '[AppwriteStorageService] Caught SDK models.File deserialization bug ($err). File was successfully uploaded with ID: $fileId');
          return '${AppwriteBackendConfig.endpoint}/storage/buckets/'
              '$bucketId/files/$fileId/view'
              '?project=${AppwriteBackendConfig.projectId}';
        }

        // Retry without permissions if rejected
        if (permissions != null && permissions.isNotEmpty) {
          try {
            debugPrint(
                'Retrying upload without permissions for bucket $bucketId due to: $err');
            final file = await _storage.createFile(
              bucketId: bucketId,
              fileId: fileId,
              file: buildInput(),
            );
            final resolvedId = file.$id.isNotEmpty ? file.$id : fileId;
            return '${AppwriteBackendConfig.endpoint}/storage/buckets/'
                '$bucketId/files/$resolvedId/view'
                '?project=${AppwriteBackendConfig.projectId}';
          } catch (retryErr) {
            final retryStr = retryErr.toString().toLowerCase();
            if (retryErr is TypeError ||
                retryStr.contains('subtype of type') ||
                retryStr.contains('minified:') ||
                retryStr.contains('typeerror')) {
              return '${AppwriteBackendConfig.endpoint}/storage/buckets/'
                  '$bucketId/files/$fileId/view'
                  '?project=${AppwriteBackendConfig.projectId}';
            }
          }
        }
        rethrow;
      }
    }
  }
}
