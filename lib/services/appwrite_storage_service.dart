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
  }) async {
    final file = await _storage.createFile(
      bucketId: bucketId,
      fileId: ID.unique(),
      file: InputFile.fromBytes(
        bytes: bytes,
        filename: fileName,
        contentType: contentType,
      ),
    );

    return '${AppwriteBackendConfig.endpoint}/storage/buckets/'
        '$bucketId/files/${file.$id}/view'
        '?project=${AppwriteBackendConfig.projectId}';
  }
}
