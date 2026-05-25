import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_exception.dart';
import '../models/bible_models.dart';
import 'bible_database_helper.dart';
import '../config/app_config.dart';
import '../utils/logger.dart';

class OfflineBibleService {
  static final OfflineBibleService _instance = OfflineBibleService._internal();
  factory OfflineBibleService() => _instance;
  final BibleDatabaseHelper _dbHelper;

  static final Logger _logger = Logger('OfflineBibleService');

  OfflineBibleService._internal({
    BibleDatabaseHelper? dbHelper,
  }) : _dbHelper = dbHelper ?? BibleDatabaseHelper();

  @visibleForTesting
  factory OfflineBibleService.test({
    required BibleDatabaseHelper dbHelper,
  }) {
    return OfflineBibleService._internal(
      dbHelper: dbHelper,
    );
  }

  // Default to local Yoruba as the primary offline source
  static const String _defaultVersion = 'BM';
  static const String _defaultLanguage = 'yo';

  // Supported languages and their Bible versions (fallback only)
  // Real availability is auto-discovered from assets at runtime.
  static const Map<String, List<Map<String, String>>> _supportedLanguages = {
    'en': [
      {'code': 'KJV', 'name': 'King James Version'},
      {'code': 'NIV', 'name': 'New International Version'},
      {'code': 'ESV', 'name': 'English Standard Version'},
      {'code': 'NASB', 'name': 'New American Standard Bible'},
      {'code': 'NKJV', 'name': 'New King James Version'},
      {'code': 'NLT', 'name': 'New Living Translation'},
    ],
    'yo': [
      {'code': 'BM', 'name': 'Biblica Yoruba (BM)'},
    ],
    'ha': [
      {'code': 'HAU', 'name': 'Biblica Hausa (HAU)'},
    ],
    'ig': [
      {'code': 'IGBOB', 'name': 'Biblica Igbo (IGBOB)'},
    ],
  };

  // Supported Bible versions and languages
  static const Map<String, String> supportedVersions = {
    'KJV': 'King James Version (English)',
    'NIV': 'New International Version (English)',
    'ESV': 'English Standard Version (English)',
    'NLT': 'New Living Translation (English)',
    'NASB': 'New American Standard Bible (English)',
    'NKJV': 'New King James Version (English)',
  };

  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'yo': 'Yoruba',
    'ha': 'Hausa',
    'ig': 'Igbo',
  };

  // Get all Bible books
  Future<List<BibleBook>> getBibleBooks({String? language}) async {
    try {
      final lang = language ?? _defaultLanguage;

      // If explicitly non-English or the app is configured for local-only mode,
      // prefer loading books directly from bundled assets for the requested language.
      if (lang != 'en' || AppConfig.useLocalBibleOnly) {
        final assetBooksData = await _loadBooksFromAssets(lang);
        if (assetBooksData.isNotEmpty) {
          return assetBooksData
              .map((bookData) => BibleBook(
                    name: bookData['name'],
                    abbreviation: bookData['abbreviation'],
                    chapters: bookData['chapters'],
                    testament: bookData['testament'],
                    order: bookData['order'],
                    translations: bookData['translations'],
                  ))
              .toList();
        }
        // If assets are missing, continue to fall back to DB/remote below
      }

      // Try to get from local database (English defaults inserted on creation)
      final books = await _dbHelper.getAllBooks();
      if (books.isNotEmpty) {
        return books;
      }

      // If not in database, try to get from assets (default language)
      final assetBooksDefault = await _loadBooksFromAssets(_defaultLanguage);
      if (assetBooksDefault.isNotEmpty) {
        return assetBooksDefault
            .map((bookData) => BibleBook(
                  name: bookData['name'],
                  abbreviation: bookData['abbreviation'],
                  chapters: bookData['chapters'],
                  testament: bookData['testament'],
                  order: bookData['order'],
                  translations: bookData['translations'],
                ))
            .toList();
      }

      // Return books from database (default books are inserted during creation)
      return await _dbHelper.getAllBooks();
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error getting Bible books', e);
      throw DatabaseException('Failed to get Bible books', originalError: e);
    }
  }

  // Get Bible chapter
  Future<BibleChapter?> getBibleChapter({
    required String book,
    required int chapter,
    String? version,
    String? language,
  }) async {
    try {
      final versionCode = version ?? _defaultVersion;
      final languageCode = language ?? _defaultLanguage;

      // Try to get from local database first
      final cachedChapter =
          await _dbHelper.getChapter(book, chapter, versionCode, languageCode);
      if (cachedChapter != null && cachedChapter.verses.isNotEmpty) {
        return cachedChapter;
      }

      // If not cached, try to get from assets
      final assetChapter = await _loadChapterFromAssets(
          book, chapter, versionCode, languageCode);
      if (assetChapter != null) {
        await _dbHelper.insertChapter(assetChapter);
        return assetChapter;
      }

      // Local-only mode: do not call external providers.
      throw NotFoundException('Bible chapter not found');
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error getting Bible chapter', e);
      throw DatabaseException('Failed to get Bible chapter', originalError: e);
    }
  }

  // Get full Bible book
  Future<List<BibleChapter>> getBibleBookFull({
    required String book,
    required int totalChapters,
    String? version,
    String? language,
  }) async {
    try {
      final List<BibleChapter> allChapters = [];
      for (int i = 1; i <= totalChapters; i++) {
        final chapter = await getBibleChapter(
          book: book,
          chapter: i,
          version: version,
          language: language,
        );
        if (chapter != null) {
          allChapters.add(chapter);
        }
      }
      return allChapters;
    } catch (e) {
      _logger.error('Error getting full Bible book', e);
      // Return what we have so far if some chapters fail, or rethrow
      return [];
    }
  }

  // Search Bible verses
  Future<List<BibleSearchResult>> searchBibleVerses({
    required String query,
    String? version,
    String? language,
    int limit = 50,
  }) async {
    try {
      final versionCode = version ?? _defaultVersion;
      final languageCode = language ?? _defaultLanguage;

      // Search in local database first
      final localResults = await _dbHelper.searchVerses(query,
          version: versionCode, language: languageCode, limit: limit);
      if (localResults.isNotEmpty) {
        for (final r in localResults) {
          await _saveSearchResultToDatabase(r);
        }
        return localResults;
      }

      // Local-only mode: do not search remote providers.
      return [];
    } catch (e) {
      _logger.error('Error searching Bible verses', e);
      throw DatabaseException('Failed to search Bible verses',
          originalError: e);
    }
  }

  // Download Bible version for offline use
  Future<bool> downloadBibleVersion(String version, String language) async {
    try {
      // Check if already downloaded
      final versions = await _dbHelper.getAllVersions();
      final existingVersion = versions
          .where((v) => v.code == version && v.languageCode == language)
          .firstOrNull;

      if (existingVersion?.isDownloaded == true) {
        return true; // Already downloaded
      }

      // Create or update version record
      final bibleVersion = BibleVersion(
        code: version,
        name: _getVersionName(version, language),
        language: _getLanguageName(language),
        languageCode: language,
        description: 'Downloaded Bible version',
        isDownloaded: false,
      );
      await _dbHelper.insertVersion(bibleVersion);

      // Download all books and chapters for this version
      final books = await getBibleBooks(language: language);
      int totalChapters = 0;
      int downloadedChapters = 0;

      // Calculate total chapters
      for (final book in books) {
        totalChapters += book.chapters;
      }

      // Download each chapter
      for (final book in books) {
        for (int chapter = 1; chapter <= book.chapters; chapter++) {
          final chapterData = await _loadChapterFromAssets(
            book.name,
            chapter,
            version,
            language,
          );
          if (chapterData != null) {
            await _dbHelper.insertChapter(chapterData);
          }
          downloadedChapters++;

          // Optional: Report progress
          _logger
              .info('Downloaded $downloadedChapters/$totalChapters chapters');
        }
      }

      // Mark version as downloaded
      await _dbHelper.updateVersionDownloadStatus(version, true);

      return true;
    } catch (e) {
      _logger.error('Error downloading Bible version', e);
      throw DatabaseException('Failed to download Bible version',
          originalError: e);
    }
  }

  // Check if Bible version is downloaded
  Future<bool> isBibleVersionDownloaded(String version, String language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('bible_downloaded_${language}_$version') ?? false;
    } catch (e) {
      _logger.error('Error checking if Bible version is downloaded', e);
      throw DatabaseException('Failed to check if Bible version is downloaded',
          originalError: e);
    }
  }

  // Get available Bible versions
  Future<List<BibleVersion>> getAvailableVersions({String? language}) async {
    try {
      final versions = <BibleVersion>[];

      // Try dynamic discovery from assets via AssetManifest
      Future<List<String>> discoverLangVersions(String lang) async {
        final discovered = await _discoverAvailableVersionCodesFromAssets(lang);
        if (discovered.isNotEmpty) return discovered;
        // Fallback to configured list
        return (_supportedLanguages[lang] ?? [])
            .map((v) => v['code']!)
            .toList();
      }

      if (language != null) {
        final languageVersions = await discoverLangVersions(language);
        for (final code in languageVersions) {
          final isDownloaded = await _isVersionDownloaded(code, language);
          versions.add(BibleVersion(
            code: code,
            name: _getVersionName(code, language),
            language: _getLanguageName(language),
            languageCode: language,
            description: 'Bible version in ${_getLanguageName(language)}',
            isDownloaded: isDownloaded,
          ));
        }
      } else {
        // Return all versions for all languages
        for (final entry in _supportedLanguages.entries) {
          final lang = entry.key;
          final langCodes = await discoverLangVersions(lang);
          for (final code in langCodes) {
            final isDownloaded = await _isVersionDownloaded(code, lang);
            versions.add(BibleVersion(
              code: code,
              name: _getVersionName(code, lang),
              language: _getLanguageName(lang),
              languageCode: lang,
              description: 'Bible version in ${_getLanguageName(lang)}',
              isDownloaded: isDownloaded,
            ));
          }
        }
      }

      return versions;
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error getting available versions', e);
      throw DatabaseException('Failed to get available versions',
          originalError: e);
    }
  }

  // Check if a version is downloaded
  Future<bool> _isVersionDownloaded(String version, String language) async {
    try {
      final versions = await _dbHelper.getDownloadedVersions();
      return versions
          .any((v) => v.code == version && v.languageCode == language);
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error checking if version is downloaded', e);
      throw DatabaseException('Failed to check if version is downloaded',
          originalError: e);
    }
  }

  // Get downloaded Bible versions
  Future<List<BibleVersion>> getDownloadedVersions() async {
    try {
      return await _dbHelper.getDownloadedVersions();
    } catch (e) {
      _logger.error('Error getting downloaded versions', e);
      throw DatabaseException('Failed to get downloaded versions',
          originalError: e);
    }
  }

  // Delete downloaded version
  Future<bool> deleteDownloadedVersion(String version, String language) async {
    try {
      await _dbHelper.updateVersionDownloadStatus(version, false);
      // Note: This doesn't actually delete the chapters, just marks as not downloaded
      // You might want to implement actual deletion of chapter data
      return true;
    } catch (e) {
      _logger.error('Error deleting downloaded version', e);
      throw DatabaseException('Failed to delete downloaded version',
          originalError: e);
    }
  }

  // Get cache size
  Future<int> getCacheSize() async {
    try {
      return await _dbHelper.getDatabaseSize();
    } catch (e) {
      return 0;
    }
  }

  // Save user reading progress
  Future<void> saveReadingProgress(String userId, String book, int chapter,
      int? verse, String version) async {
    try {
      await _dbHelper.saveUserProgress(
          userId, book, chapter, verse, version, 'reading', null);
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error saving reading progress', e);
      throw DatabaseException('Failed to save reading progress',
          originalError: e);
    }
  }

  // Get user reading progress
  Future<List<Map<String, dynamic>>> getUserReadingProgress(
      String userId) async {
    try {
      return await _dbHelper.getUserProgress(userId, progressType: 'reading');
    } catch (e) {
      _logger.error('Error getting reading progress', e);
      throw DatabaseException('Failed to get reading progress',
          originalError: e);
    }
  }

  // Get supported languages
  Future<List<Map<String, String>>> getSupportedLanguages() async {
    return _supportedLanguages.entries
        .map((entry) => {
              'code': entry.key,
              'name': _getLanguageName(entry.key),
              'versions': entry.value.length.toString(),
            })
        .toList();
  }

  // Private helper methods

  Future<List<Map<String, dynamic>>> _loadBooksFromAssets(
      String language) async {
    try {
      final String booksJson =
          await rootBundle.loadString('assets/bible/books_$language.json');
      final List<dynamic> booksList = json.decode(booksJson);
      return booksList.cast<Map<String, dynamic>>();
    } catch (e) {
      // If asset doesn't exist, return empty list
      return [];
    }
  }

  Future<BibleChapter?> _loadChapterFromAssets(
      String book, int chapter, String version, String language) async {
    final candidates =
        _buildChapterAssetCandidates(book, chapter, version, language);
    Object? lastError;
    for (final assetPath in candidates) {
      try {
        final String chapterJson = await rootBundle.loadString(assetPath);
        final Map<String, dynamic> chapterData = json.decode(chapterJson);

        final verses = (chapterData['verses'] as List<dynamic>)
            .map((v) => BibleVerse(
                  number: v['verse'],
                  text: v['text'],
                  footnotes: v['footnotes']?.cast<String, String>(),
                  crossReferences: v['crossReferences']?.cast<String>(),
                ))
            .toList();

        return BibleChapter(
          book: book,
          chapter: chapter,
          version: version,
          language: language,
          verses: verses,
          metadata: chapterData['metadata'],
          lastUpdated: DateTime.now(),
        );
      } catch (e) {
        lastError = e;
      }
    }
    _logger.error(
      'Error loading chapter from assets. Tried ${candidates.length} candidates',
      lastError,
    );
    throw NotFoundException('Failed to load chapter from assets',
        originalError: lastError);
  }

  List<String> _buildChapterAssetCandidates(
      String book, int chapter, String version, String language) {
    final raw = book.trim();
    final lower = raw.toLowerCase();
    final collapsed = lower.replaceAll(RegExp(r'\s+'), ' ').trim();
    final underscore = collapsed.replaceAll(' ', '_');
    final dash = collapsed.replaceAll(' ', '-');
    final noPunct = collapsed
        .replaceAll("'", '')
        .replaceAll('’', '')
        .replaceAll('.', '')
        .replaceAll(',', '')
        .replaceAll(':', '')
        .replaceAll(';', '');
    final noPunctUnderscore = noPunct.replaceAll(' ', '_');
    final leadingNumberSeparated =
        collapsed.replaceFirstMapped(RegExp(r'^([1-3])\s+'), (match) {
      return '${match.group(1)}_';
    });
    final leadingNumberDashed =
        collapsed.replaceFirstMapped(RegExp(r'^([1-3])\s+'), (match) {
      return '${match.group(1)}-';
    });
    final compactNumberName =
        collapsed.replaceFirstMapped(RegExp(r'^([1-3])\s+'), (match) {
      return match.group(1)!;
    });
    String ordinalPrefix = '';
    if (collapsed.startsWith('1 ')) {
      ordinalPrefix = collapsed.replaceFirst('1 ', 'first ');
    } else if (collapsed.startsWith('2 ')) {
      ordinalPrefix = collapsed.replaceFirst('2 ', 'second ');
    } else if (collapsed.startsWith('3 ')) {
      ordinalPrefix = collapsed.replaceFirst('3 ', 'third ');
    }

    final names = <String>{
      raw,
      lower,
      collapsed,
      underscore,
      dash,
      noPunct,
      noPunctUnderscore,
      leadingNumberSeparated,
      leadingNumberDashed,
      compactNumberName,
      ordinalPrefix,
    }.where((n) => n.isNotEmpty);

    return names
        .map((name) => 'assets/bible/$language/$version/${name}_$chapter.json')
        .toList();
  }

  // Remote Bible integrations intentionally removed for offline/local assets.

  // Verify required versions/languages availability in local storage
  Future<Map<String, dynamic>> verifyRequiredImports() async {
    final requiredVersions = ['BM', 'HAU', 'IGBOB'];
    final requiredLanguages = ['en', 'yo', 'ha', 'ig'];
    final result = <String, dynamic>{};

    for (final lang in requiredLanguages) {
      final entries = <String, bool>{};
      for (final version in requiredVersions) {
        entries[version] = await _isVersionDownloaded(version, lang);
      }
      result[lang] = entries;
    }
    return result;
  }

  String _getVersionName(String code, String language) {
    // Prefer configured friendly names
    final versions = _supportedLanguages[language];
    if (versions != null) {
      final version = versions.where((v) => v['code'] == code).firstOrNull;
      if (version != null) return version['name'] ?? code;
    }
    // Fall back to global English mapping if available
    final friendly = supportedVersions[code];
    if (friendly != null) return friendly;
    return code;
  }

  String _getLanguageName(String code) {
    const languageNames = {
      'en': 'English',
      'yo': 'Yoruba',
      'ha': 'Hausa',
      'ig': 'Igbo',
    };
    return languageNames[code] ?? code;
  }

  // Save search result to local database
  Future<void> _saveSearchResultToDatabase(BibleSearchResult result) async {
    try {
      // First check if we already have this chapter
      final existingChapter = await _dbHelper.getChapter(
          result.book, result.chapter, result.version, result.language);

      if (existingChapter == null) {
        // If we don't have the chapter, fetch it and save it
        await _loadChapterFromAssets(
            result.book, result.chapter, result.version, result.language);
      }
    } catch (e) {
      _logger.error('Error saving search result to database', e);
    }
  }

  // Clear all cached Bible data
  Future<void> clearCache() async {
    try {
      await _dbHelper.clearCache();
      _logger.info('Bible cache cleared');
    } catch (e) {
      _logger.error('Error clearing Bible cache', e);
    }
  }

  // Discover version codes from AssetManifest for a language
  Future<List<String>> _discoverAvailableVersionCodesFromAssets(
      String language) async {
    try {
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifest = json.decode(manifestJson);
      final Set<String> codes = {};
      final prefix = 'assets/bible/$language/';

      for (final key in manifest.keys) {
        if (key.startsWith(prefix)) {
          final remainder = key.substring(prefix.length);
          final slashIndex = remainder.indexOf('/');
          if (slashIndex > 0) {
            final code = remainder.substring(0, slashIndex);
            // Basic sanity: ensure it looks like a folder name (no dot)
            if (!code.contains('.')) {
              codes.add(code);
            }
          }
        }
      }

      return codes.toList()..sort();
    } catch (e) {
      // If manifest unavailable, return empty to fall back to defaults
      return [];
    }
  }

  // ---- BibleReadingPlan / BibleReadingDay integration ----

  /// Create a new [BibleReadingPlan] for a user.
  Future<BibleReadingPlan> createReadingPlan({
    required String userId,
    required String name,
    required String description,
    required List<BibleReadingDay> days,
    String version = 'KJV',
  }) async {
    try {
      final plan = BibleReadingPlan(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        description: description,
        days: days,
        totalDays: days.length,
        startDate: DateTime.now(),
        metadata: {'version': version},
      );

      final prefs = await SharedPreferences.getInstance();
      final plans = prefs.getStringList('reading_plans_$userId') ?? [];
      plans.add(json.encode(plan.toJson()));
      await prefs.setStringList('reading_plans_$userId', plans);

      return plan;
    } catch (e) {
      _logger.error('Error creating reading plan', e);
      throw DatabaseException('Failed to create reading plan',
          originalError: e);
    }
  }

  /// Get all [BibleReadingPlan]s for a user.
  Future<List<BibleReadingPlan>> getUserReadingPlans(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final plans = prefs.getStringList('reading_plans_$userId') ?? [];
      return plans.map((planJson) {
        return BibleReadingPlan.fromJson(
            json.decode(planJson) as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      _logger.error('Error getting reading plans', e);
      return [];
    }
  }

  /// Mark a [BibleReadingDay] as completed within a plan.
  Future<void> completeReadingDay({
    required String userId,
    required String planId,
    required int dayNumber,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'reading_plan_progress_${userId}_$planId';
      final completedDays = prefs.getStringList(key) ?? [];
      if (!completedDays.contains(dayNumber.toString())) {
        completedDays.add(dayNumber.toString());
        await prefs.setStringList(key, completedDays);
      }
    } catch (e) {
      _logger.error('Error completing reading day', e);
    }
  }

  /// Get completed day numbers for a reading plan.
  Future<List<int>> getCompletedReadingDays(
      String userId, String planId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'reading_plan_progress_${userId}_$planId';
      final completedDays = prefs.getStringList(key) ?? [];
      return completedDays.map((d) => int.tryParse(d) ?? 0).toList();
    } catch (e) {
      return [];
    }
  }
}
