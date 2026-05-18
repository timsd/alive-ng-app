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
    final file = await _storage.createFile(
      bucketId: AppwriteBackendConfig.chatFilesBucketId,
      fileId: ID.unique(),
      file: InputFile.fromBytes(
        bytes: bytes,
        filename: fileName,
        contentType: contentType,
      ),
    );

    return '${AppwriteBackendConfig.endpoint}/storage/buckets/'
        '${AppwriteBackendConfig.chatFilesBucketId}/files/${file.$id}/view'
        '?project=${AppwriteBackendConfig.projectId}';
  }
}
