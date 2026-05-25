// ignore_for_file: deprecated_member_use

import 'package:appwrite/appwrite.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';

class AppwriteContentService {
  static final AppwriteContentService instance = AppwriteContentService._();

  AppwriteContentService._();

  late final Databases _databases = Databases(appwriteClient);
  final Logger _logger = Logger('AppwriteContentService');

  Future<Map<String, dynamic>?> getContentPageBySlug(
    String slug, {
    String languageCode = 'en',
  }) async {
    try {
      final response = await _databases.listDocuments(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.contentPagesCollectionId,
        queries: [
          Query.equal('slug', slug),
          Query.equal('is_published', true),
          Query.limit(10),
        ],
      );

      if (response.documents.isEmpty) return null;

      final preferred = response.documents.firstWhere(
        (doc) => doc.data['language_code'] == languageCode,
        orElse: () => response.documents.first,
      );

      return {
        ...Map<String, dynamic>.from(preferred.data),
        'id': preferred.$id,
      };
    } catch (e) {
      _logger.error('Failed to fetch content page', e);
      throw DatabaseException('Failed to fetch content page', originalError: e);
    }
  }

  Future<String> createContentPage(Map<String, dynamic> data) async {
    try {
      final doc = await _databases.createDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.contentPagesCollectionId,
        documentId: ID.unique(),
        data: _sanitizeContentPageData(data),
      );
      return doc.$id;
    } catch (e) {
      _logger.error('Failed to create content page', e);
      throw DatabaseException('Failed to create content page',
          originalError: e);
    }
  }

  Future<void> updateContentPage(
    String documentId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _databases.updateDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.contentPagesCollectionId,
        documentId: documentId,
        data: _sanitizeContentPageData(data),
      );
    } catch (e) {
      _logger.error('Failed to update content page', e);
      throw DatabaseException('Failed to update content page',
          originalError: e);
    }
  }

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
