import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../utils/logger.dart';

class AppwriteLibraryService {
  AppwriteLibraryService._internal();
  static final AppwriteLibraryService instance =
      AppwriteLibraryService._internal();

  final TablesDB _tables = TablesDB(appwriteClient);
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
      final row = await _tables.getRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: collectionId,
        rowId: idOrTitle,
      );
      return _rowData(row);
    } on AppwriteException catch (e) {
      if (e.code != 404) {
        _logger.error('Error reading $collectionId/$idOrTitle', e);
        rethrow;
      }
    }

    try {
      final rows = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: collectionId,
        queries: [
          Query.equal('title', idOrTitle),
          Query.limit(1),
        ],
      );
      if (rows.rows.isEmpty) return null;
      return _rowData(rows.rows.first);
    } on AppwriteException catch (e) {
      if (e.code == 404) return null;
      _logger.error('Error finding $collectionId by title', e);
      rethrow;
    }
  }

  Map<String, dynamic> _rowData(models.Row row) => {
        ...Map<String, dynamic>.from(row.data),
        'id': row.$id,
      };
}
