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
  final Databases _databases = Databases(appwriteClient);

  Future<List<Map<String, dynamic>>> listCollection(
    String collection, {
    String? orderBy,
    bool descending = false,
    int limit = 500,
  }) async {
    final collectionId = _collectionId(collection);
    try {
      final queries = <String>[Query.limit(limit)];
      if (orderBy != null) {
        queries.add(descending ? Query.orderDesc(orderBy) : Query.orderAsc(orderBy));
      }
      return await _list(collectionId, queries);
    } catch (_) {
      // Fallback: list without orderBy if index is absent, then sort in memory
      try {
        final items = await _list(collectionId, [Query.limit(limit)]);
        if (orderBy != null) {
          items.sort((a, b) {
            final valA = a[orderBy];
            final valB = b[orderBy];
            if (valA == null && valB == null) return 0;
            if (valA == null) return descending ? 1 : -1;
            if (valB == null) return descending ? -1 : 1;
            if (valA is Comparable && valB is Comparable) {
              return descending ? valB.compareTo(valA) : valA.compareTo(valB);
            }
            return 0;
          });
        }
        return items;
      } catch (e) {
        return [];
      }
    }
  }

  Future<List<Map<String, dynamic>>> listWhere(
    String collection,
    String field,
    dynamic value, {
    int limit = 500,
  }) async {
    final collectionId = _collectionId(collection);
    try {
      return await _list(collectionId, [
        Query.equal(field, value),
        Query.limit(limit),
      ]);
    } catch (_) {
      // Robust in-memory fallback if index is missing or query syntax error
      try {
        final all = await _list(collectionId, [Query.limit(limit)]);
        return all.where((item) {
          final itemVal = item[field]?.toString().toLowerCase();
          final targetVal = value?.toString().toLowerCase();
          return itemVal == targetVal;
        }).toList();
      } catch (_) {
        return [];
      }
    }
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
    final collectionId = _collectionId(collection);
    final rowId = AppwriteIdUtils.toValidUid(documentId);
    try {
      await _tables.deleteRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: collectionId,
        rowId: rowId,
      );
    } catch (_) {
      try {
        await _databases.deleteDocument(
          databaseId: AppwriteBackendConfig.databaseId,
          collectionId: collectionId,
          documentId: rowId,
        );
      } catch (_) {
        if (rowId != documentId) {
          try {
            await _tables.deleteRow(
              databaseId: AppwriteBackendConfig.databaseId,
              tableId: collectionId,
              rowId: documentId,
            );
          } catch (_) {
            await _databases.deleteDocument(
              databaseId: AppwriteBackendConfig.databaseId,
              collectionId: collectionId,
              documentId: documentId,
            );
          }
        }
      }
    }
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
