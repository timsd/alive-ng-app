import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';

class AppwriteStorageService {
  AppwriteStorageService._();

  static final AppwriteStorageService instance = AppwriteStorageService._();

  final Storage _storage = Storage(appwriteClient);

  /// Uploaded media is rendered with plain HTTP requests (e.g.
  /// `CachedNetworkImage`), which cannot carry the Appwrite session header.
  /// Without an explicit read permission the returned `/view` URL would 403
  /// and the freshly uploaded picture would never appear in the UI.
  static final List<String> _publicReadPermission = [
    Permission.read(Role.any()),
  ];

  static bool _isPermissionError(AppwriteException error) {
    final message = (error.message ?? '').toLowerCase();
    return message.contains('permission') || message.contains('forbidden');
  }

  Future<String> uploadChatFile({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    return _uploadFile(
      bucketId: AppwriteBackendConfig.chatFilesBucketId,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );
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
      permissions: _publicReadPermission,
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

    String fileId;
    try {
      final file = await _storage.createFile(
        bucketId: bucketId,
        fileId: ID.unique(),
        file: buildInput(),
        permissions: permissions,
      );
      fileId = file.$id;
    } on AppwriteException catch (e) {
      // Buckets with `fileSecurity` disabled reject file level permissions.
      // Fall back to the bucket defaults instead of failing the upload.
      if (permissions == null ||
          permissions.isEmpty ||
          !_isPermissionError(e)) {
        rethrow;
      }
      debugPrint(
          'File permissions rejected for bucket $bucketId; retrying with bucket defaults: $e');
      final file = await _storage.createFile(
        bucketId: bucketId,
        fileId: ID.unique(),
        file: buildInput(),
      );
      fileId = file.$id;
    }

    return '${AppwriteBackendConfig.endpoint}/storage/buckets/'
        '$bucketId/files/$fileId/view'
        '?project=${AppwriteBackendConfig.projectId}';
  }
}
