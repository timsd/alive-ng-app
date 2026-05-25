// ignore_for_file: deprecated_member_use

import 'package:appwrite/appwrite.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../utils/logger.dart';

class AppwriteLibraryService {
  AppwriteLibraryService._internal();
  static final AppwriteLibraryService instance =
      AppwriteLibraryService._internal();

  final Databases _databases = Databases(appwriteClient);
  final Logger _logger = Logger('AppwriteLibraryService');

  Future<Map<String, dynamic>?> getBook(String idOrTitle) {
    return _getByIdOrTitle(AppwriteBackendConfig.booksCollectionId, idOrTitle);
  }

  Future<Map<String, dynamic>?> getArticle(String idOrTitle) {
    return _getByIdOrTitle(
      AppwriteBackendConfig.articlesCollectionId,
      idOrTitle,
    );
  }

  Future<Map<String, dynamic>?> getPodcastEpisode(String idOrTitle) {
    return _getByIdOrTitle(
      AppwriteBackendConfig.podcastEpisodesCollectionId,
      idOrTitle,
    );
  }

  Future<Map<String, dynamic>?> getVideo(String idOrTitle) {
    return _getByIdOrTitle(AppwriteBackendConfig.videosCollectionId, idOrTitle);
  }

  Future<Map<String, dynamic>?> _getByIdOrTitle(
    String collectionId,
    String idOrTitle,
  ) async {
    try {
      final doc = await _databases.getDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: collectionId,
        documentId: idOrTitle,
      );
      return _documentData(doc.data, doc.$id);
    } on AppwriteException catch (e) {
      if (e.code != 404) {
        _logger.error('Error reading $collectionId/$idOrTitle', e);
        rethrow;
      }
    }

    try {
      final docs = await _databases.listDocuments(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: collectionId,
        queries: [
          Query.equal('title', idOrTitle),
          Query.limit(1),
        ],
      );
      if (docs.documents.isEmpty) return null;
      final doc = docs.documents.first;
      return _documentData(doc.data, doc.$id);
    } on AppwriteException catch (e) {
      if (e.code == 404) return null;
      _logger.error('Error finding $collectionId by title', e);
      rethrow;
    }
  }

  Map<String, dynamic> _documentData(Map<String, dynamic> data, String id) {
    return {
      ...Map<String, dynamic>.from(data),
      'id': id,
    };
  }
}
