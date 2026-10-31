import '../utils/appwrite_id_utils.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../config/appwrite_backend_config.dart';
import '../main.dart';

class AppwriteAdminContentService {
  AppwriteAdminContentService._();
  static final AppwriteAdminContentService instance =
      AppwriteAdminContentService._();

  final TablesDB _tables = TablesDB(appwriteClient);

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
    await _tables.upsertRow(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: collectionId,
      rowId: AppwriteIdUtils.toValidUid(documentId),
      data: payload,
    );
  }

  Future<void> updateDocument(
    String collection,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    final collectionId = _collectionId(collection);
    await _tables.updateRow(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: collectionId,
      rowId: AppwriteIdUtils.toValidUid(documentId),
      data: _sanitize(collectionId, data),
    );
  }

  Future<void> deleteDocument(String collection, String documentId) async {
    await _tables.deleteRow(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: _collectionId(collection),
      rowId: AppwriteIdUtils.toValidUid(documentId),
    );
  }

  Future<List<Map<String, dynamic>>> _list(
    String collectionId,
    List<String> queries,
  ) async {
    final response = await _tables.listRows(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: collectionId,
      queries: queries,
    );
    return response.rows.map(_rowData).toList();
  }

  Map<String, dynamic> _rowData(models.Row row) => {
        ...Map<String, dynamic>.from(row.data),
        'id': row.$id,
      };

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
