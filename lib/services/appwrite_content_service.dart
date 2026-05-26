import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';

class AppwriteContentService {
  static final AppwriteContentService instance = AppwriteContentService._();

  AppwriteContentService._();

  late final TablesDB _tables = TablesDB(appwriteClient);
  final Logger _logger = Logger('AppwriteContentService');

  Future<Map<String, dynamic>?> getContentPageBySlug(
    String slug, {
    String languageCode = 'en',
  }) async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.contentPagesCollectionId,
        queries: [
          Query.equal('slug', slug),
          Query.equal('is_published', true),
          Query.limit(10),
        ],
      );

      if (response.rows.isEmpty) return null;

      final preferred = response.rows.firstWhere(
        (row) => row.data['language_code'] == languageCode,
        orElse: () => response.rows.first,
      );

      return _rowToMap(preferred);
    } catch (e) {
      _logger.error('Failed to fetch content page', e);
      throw DatabaseException('Failed to fetch content page', originalError: e);
    }
  }

  Future<String> createContentPage(Map<String, dynamic> data) async {
    try {
      final row = await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.contentPagesCollectionId,
        rowId: ID.unique(),
        data: _sanitizeContentPageData(data),
      );
      return row.$id;
    } catch (e) {
      _logger.error('Failed to create content page', e);
      throw DatabaseException(
        'Failed to create content page',
        originalError: e,
      );
    }
  }

  Future<void> updateContentPage(
    String documentId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.contentPagesCollectionId,
        rowId: documentId,
        data: _sanitizeContentPageData(data),
      );
    } catch (e) {
      _logger.error('Failed to update content page', e);
      throw DatabaseException(
        'Failed to update content page',
        originalError: e,
      );
    }
  }

  Map<String, dynamic> _rowToMap(models.Row row) => {
        ...Map<String, dynamic>.from(row.data),
        'id': row.$id,
      };

  Map<String, dynamic> _sanitizeContentPageData(Map<String, dynamic> data) {
    final sanitized = Map<String, dynamic>.from(data)
      ..remove('id')
      ..removeWhere((key, value) => key.startsWith(r'$') || value == null);

    sanitized.putIfAbsent('language', () => 'en');
    sanitized.putIfAbsent('language_code', () => 'en');
    sanitized.putIfAbsent('category', () => sanitized['page_type'] ?? 'page');

    return sanitized;
  }
}
