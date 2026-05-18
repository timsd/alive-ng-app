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
}
