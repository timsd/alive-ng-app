import 'package:appwrite/appwrite.dart';
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

    await _storage.deleteFile(
      bucketId: segments[bucketIndex + 1],
      fileId: segments[fileIndex + 1],
    );
  }

  Future<String> _uploadFile({
    required String bucketId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    List<String>? permissions,
  }) async {
    InputFile buildInput() => InputFile.fromBytes(
          bytes: bytes,
          filename: fileName,
          contentType: contentType,
        );

    final fileId = ID.unique();
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
    } catch (e) {
      // If permissions caused rejection or bucket has fileSecurity disabled, retry with bucket defaults
      if (permissions != null && permissions.isNotEmpty) {
        try {
          debugPrint(
              'Retrying upload without permissions for bucket $bucketId due to: $e');
          final file = await _storage.createFile(
            bucketId: bucketId,
            fileId: fileId,
            file: buildInput(),
          );
          final resolvedId = file.$id.isNotEmpty ? file.$id : fileId;
          return '${AppwriteBackendConfig.endpoint}/storage/buckets/'
              '$bucketId/files/$resolvedId/view'
              '?project=${AppwriteBackendConfig.projectId}';
        } catch (_) {}
      }
      rethrow;
    }
  }
}
