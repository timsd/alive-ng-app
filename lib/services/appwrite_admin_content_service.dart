// ignore_for_file: deprecated_member_use

import 'package:appwrite/appwrite.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';

class AppwriteAdminContentService {
  AppwriteAdminContentService._();
  static final AppwriteAdminContentService instance =
      AppwriteAdminContentService._();

  final Databases _databases = Databases(appwriteClient);

  Future<List<Map<String, dynamic>>> listCollection(
    String collection, {
    String? orderBy,
    bool descending = false,
    int limit = 500,
  }) async {
    final queries = <String>[Query.limit(limit)];
    if (orderBy != null) {
      queries
          .add(descending ? Query.orderDesc(orderBy) : Query.orderAsc(orderBy));
    }
    return _list(_collectionId(collection), queries);
  }

  Future<List<Map<String, dynamic>>> listWhere(
    String collection,
    String field,
    dynamic value, {
    int limit = 500,
  }) {
    return _list(_collectionId(collection), [
      Query.equal(field, value),
      Query.limit(limit),
    ]);
  }

  Future<void> upsertDocument(
    String collection,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    final collectionId = _collectionId(collection);
    final payload = _sanitize(collectionId, data);
    try {
      await _databases.updateDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: collectionId,
        documentId: documentId,
        data: payload,
      );
    } on AppwriteException catch (e) {
      if (e.code != 404) rethrow;
      await _databases.createDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: collectionId,
        documentId: documentId,
        data: payload,
      );
    }
  }

  Future<void> updateDocument(
    String collection,
    String documentId,
    Map<String, dynamic> data,
  ) {
    return _databases.updateDocument(
      databaseId: AppwriteBackendConfig.databaseId,
      collectionId: _collectionId(collection),
      documentId: documentId,
      data: _sanitize(_collectionId(collection), data),
    );
  }

  Future<void> deleteDocument(String collection, String documentId) {
    return _databases.deleteDocument(
      databaseId: AppwriteBackendConfig.databaseId,
      collectionId: _collectionId(collection),
      documentId: documentId,
    );
  }

  Future<List<Map<String, dynamic>>> _list(
    String collectionId,
    List<String> queries,
  ) async {
    final response = await _databases.listDocuments(
      databaseId: AppwriteBackendConfig.databaseId,
      collectionId: collectionId,
      queries: queries,
    );
    return response.documents
        .map((document) => {
              ...Map<String, dynamic>.from(document.data),
              'id': document.$id,
            })
        .toList();
  }

  Map<String, dynamic> _sanitize(
    String collectionId,
    Map<String, dynamic> data,
  ) {
    final payload = <String, dynamic>{};
    for (final entry in data.entries) {
      if (entry.value != null) payload[entry.key] = entry.value;
    }
    if (collectionId == AppwriteBackendConfig.podcastCategoriesCollectionId) {
      payload.remove('image_url');
    }
    return payload;
  }

  String _collectionId(String collection) {
    return switch (collection) {
      'tracts' => AppwriteBackendConfig.tractsCollectionId,
      'tract_contents' => AppwriteBackendConfig.tractContentsCollectionId,
      'tract_categories' => AppwriteBackendConfig.tractCategoriesCollectionId,
      'podcasts' => AppwriteBackendConfig.podcastsCollectionId,
      'podcast_episodes' => AppwriteBackendConfig.podcastEpisodesCollectionId,
      'podcast_categories' =>
        AppwriteBackendConfig.podcastCategoriesCollectionId,
      _ => collection,
    };
  }
}
