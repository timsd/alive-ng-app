import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../utils/appwrite_id_utils.dart';
import '../utils/logger.dart';

class AppwriteLibraryService {
  AppwriteLibraryService._internal();
  static final AppwriteLibraryService instance =
      AppwriteLibraryService._internal();

  final TablesDB _tables = TablesDB(appwriteClient);
  final Logger _logger = Logger('AppwriteLibraryService');

  Future<List<Map<String, dynamic>>> listBooks() async {
    return _listCollection(AppwriteBackendConfig.booksCollectionId);
  }

  Future<List<Map<String, dynamic>>> listArticles() async {
    return _listCollection(AppwriteBackendConfig.articlesCollectionId);
  }

  Future<List<Map<String, dynamic>>> listAudio() async {
    final episodes = await _listCollection(
      AppwriteBackendConfig.podcastEpisodesCollectionId,
    );
    final podcasts = await _listCollection(
      AppwriteBackendConfig.podcastsCollectionId,
    );
    final combined = <Map<String, dynamic>>[
      ...episodes.map((e) => {
            ...e,
            'author': e['podcast_title'] ?? e['author'] ?? 'ALIVE Audio',
            'category': e['category'] ?? 'Podcast',
            'language': e['language'] ?? 'en',
          }),
      ...podcasts
          .where((p) =>
              (p['audio_url'] ?? p['audioUrl'] ?? '').toString().isNotEmpty)
          .map((p) => {
                ...p,
                'author': p['host'] ?? p['author'] ?? 'ALIVE Audio',
                'category': p['category'] ?? 'Podcast',
                'language': p['language'] ?? 'en',
              }),
    ];
    return combined;
  }

  Future<List<Map<String, dynamic>>> listVideos() async {
    return _listCollection(AppwriteBackendConfig.videosCollectionId);
  }

  Future<List<Map<String, dynamic>>> _listCollection(
    String collectionId,
  ) async {
    try {
      final rows = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: collectionId,
        queries: [Query.limit(100)],
      );
      return rows.rows.map(_rowData).toList();
    } catch (e) {
      _logger.warning('Could not list $collectionId: $e');
      return const [];
    }
  }

  Future<Map<String, dynamic>?> getBook(String idOrTitle) {
    return _getByIdOrTitle(AppwriteBackendConfig.booksCollectionId, idOrTitle);
  }

  Future<Map<String, dynamic>?> getArticle(String idOrTitle) {
    return _getByIdOrTitle(
      AppwriteBackendConfig.articlesCollectionId,
      idOrTitle,
    );
  }

  Future<Map<String, dynamic>?> getPodcastEpisode(String idOrTitle) async {
    final ep = await _getByIdOrTitle(
      AppwriteBackendConfig.podcastEpisodesCollectionId,
      idOrTitle,
    );
    if (ep != null) return ep;
    return _getByIdOrTitle(
      AppwriteBackendConfig.podcastsCollectionId,
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
    final trimmed = idOrTitle.trim();
    if (trimmed.isEmpty) return null;

    if (AppwriteIdUtils.isValidUid(trimmed)) {
      try {
        final row = await _tables.getRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: collectionId,
          rowId: trimmed,
        );
        return _rowData(row);
      } on AppwriteException catch (e) {
        if (e.code != 404 && e.code != 400) {
          _logger.error('Error reading $collectionId/$trimmed', e);
          rethrow;
        }
      }
    }

    try {
      final rows = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: collectionId,
        queries: [
          Query.equal('title', trimmed),
          Query.limit(1),
        ],
      );
      if (rows.rows.isEmpty) return null;
      return _rowData(rows.rows.first);
    } on AppwriteException catch (e) {
      if (e.code == 404 || e.code == 400) return null;
      _logger.error('Error finding $collectionId by title', e);
      return null;
    }
  }

  Map<String, dynamic> _rowData(models.Row row) => {
        ...Map<String, dynamic>.from(row.data),
        'id': row.$id,
      };
}
