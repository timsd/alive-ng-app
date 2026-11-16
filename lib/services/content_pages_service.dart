import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/appwrite_backend_config.dart';
import '../config/default_content_data.dart';
import '../main.dart';
import '../utils/logger.dart';

/// Single source of truth for Appwrite `content_pages` with local fallback.
class ContentPagesService {
  ContentPagesService._();
  static final ContentPagesService instance = ContentPagesService._();

  final TablesDB _tables = TablesDB(appwriteClient);
  final Logger _logger = Logger('ContentPagesService');

  List<Map<String, dynamic>>? _cachedPages;
  DateTime? _lastFetch;
  static const Duration _cacheTtl = Duration(minutes: 5);
  static const String _prefsKey = 'content_pages_cache_v1';

  void invalidateCache() {
    _cachedPages = null;
    _lastFetch = null;
  }

  Future<List<Map<String, dynamic>>> listPages({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedPages != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheTtl) {
      return _cachedPages!;
    }

    try {
      final res = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.contentPagesCollectionId,
        queries: [Query.limit(100)],
      );
      final pages = res.rows.map((row) {
        final data = Map<String, dynamic>.from(row.data);
        data['id'] = row.$id;
        return data;
      }).toList();

      if (pages.isNotEmpty) {
        _cachedPages = pages;
        _lastFetch = DateTime.now();
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefsKey, jsonEncode(pages));
        } catch (_) {}
        return pages;
      }
    } catch (e) {
      _logger.warning('Could not load content_pages from Appwrite: $e');
    }

    if (_cachedPages != null && _cachedPages!.isNotEmpty) {
      return _cachedPages!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final cached = decoded
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        if (cached.isNotEmpty) {
          _cachedPages = cached;
          return cached;
        }
      }
    } catch (_) {}

    return DefaultContentData.defaultContentPages;
  }

  Future<Map<String, dynamic>?> getPageBySlug(
    String slug, {
    bool forceRefresh = false,
  }) async {
    final pages = await listPages(forceRefresh: forceRefresh);
    final normalized = slug.trim().toLowerCase();
    for (final page in pages) {
      final pageSlug = (page['slug'] ?? '').toString().trim().toLowerCase();
      final pageId = (page['id'] ?? '').toString().trim().toLowerCase();
      if ((pageSlug == normalized || pageId == normalized) &&
          page['is_published'] != false) {
        return page;
      }
    }
    return null;
  }
}
