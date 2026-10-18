import 'dart:async';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_exception.dart';
import '../models/bible_models.dart';
import '../constants/bible_data.dart';
import '../utils/search_utils.dart';
import 'bible_database_helper.dart';
import '../utils/logger.dart';

class BibleTextHit {
  final String book;
  final int chapter;
  final int verse;
  final String reference;
  final String text;

  const BibleTextHit({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.reference,
    required this.text,
  });
}

class OfflineBibleService {
  static final OfflineBibleService _instance =
      OfflineBibleService._internal();
  factory OfflineBibleService() => _instance;
  final BibleDatabaseHelper _dbHelper;

  static final Logger _logger = Logger('OfflineBibleService');
  final Map<String, Archive> _bundleCache = {};
  final Map<String, Map<String, ArchiveFile>> _bundleFileIndex = {};
  final Map<String, Future<Archive>> _inFlightBundleLoads = {};
  static final Map<String, BibleChapter> _memoryChapterCache = {};

  static const List<BibleVerse> _genesis1KjvVerses = [
    BibleVerse(number: 1, text: "In the beginning God created the heaven and the earth."),
    BibleVerse(number: 2, text: "And the earth was without form, and void; and darkness was upon the face of the deep. And the Spirit of God moved upon the face of the waters."),
    BibleVerse(number: 3, text: "And God said, Let there be light: and there was light."),
    BibleVerse(number: 4, text: "And God saw the light, that it was good: and God divided the light from the darkness."),
    BibleVerse(number: 5, text: "And God called the light Day, and the darkness he called Night. And the evening and the morning were the first day."),
    BibleVerse(number: 6, text: "And God said, Let there be a firmament in the midst of the waters, and let it divide the waters from the waters."),
    BibleVerse(number: 7, text: "And God made the firmament, and divided the waters which were under the firmament from the waters which were above the firmament: and it was so."),
    BibleVerse(number: 8, text: "And God called the firmament Heaven. And the evening and the morning were the second day."),
    BibleVerse(number: 9, text: "And God said, Let the waters under the heaven be gathered together unto one place, and let the dry land appear: and it was so."),
    BibleVerse(number: 10, text: "And God called the dry land Earth; and the gathering together of the waters called he Seas: and God saw that it was good."),
    BibleVerse(number: 11, text: "And God said, Let the earth bring forth grass, the herb yielding seed, and the fruit tree yielding fruit after his kind, whose seed is in itself, upon the earth: and it was so."),
    BibleVerse(number: 12, text: "And the earth brought forth grass, and herb yielding seed after his kind, and the tree yielding fruit, whose seed was in itself, after his kind: and God saw that it was good."),
    BibleVerse(number: 13, text: "And the evening and the morning were the third day."),
    BibleVerse(number: 14, text: "And God said, Let there be lights in the firmament of the heaven to divide the day from the night; and let them be for signs, and for seasons, and for days, and years:"),
    BibleVerse(number: 15, text: "And let them be for lights in the firmament of the heaven to give light upon the earth: and it was so."),
    BibleVerse(number: 16, text: "And God made two great lights; the greater light to rule the day, and the lesser light to rule the night: he made the stars also."),
    BibleVerse(number: 17, text: "And God set them in the firmament of the heaven to give light upon the earth,"),
    BibleVerse(number: 18, text: "And to rule over the day and over the night, and to divide the light from the darkness: and God saw that it was good."),
    BibleVerse(number: 19, text: "And the evening and the morning were the fourth day."),
    BibleVerse(number: 20, text: "And God said, Let the waters bring forth abundantly the moving creature that hath life, and fowl that may fly above the earth in the open firmament of heaven."),
    BibleVerse(number: 21, text: "And God created great whales, and every living creature that moveth, which the waters brought forth abundantly, after their kind, and every winged fowl after his kind: and God saw that it was good."),
    BibleVerse(number: 22, text: "And God blessed them, saying, Be fruitful, and multiply, and fill the waters in the seas, and let fowl multiply in the earth."),
    BibleVerse(number: 23, text: "And the evening and the morning were the fifth day."),
    BibleVerse(number: 24, text: "And God said, Let the earth bring forth the living creature after his kind, cattle, and creeping thing, and beast of the earth after his kind: and it was so."),
    BibleVerse(number: 25, text: "And God made the beast of the earth after his kind, and cattle after their kind, and every thing that creepeth upon the earth after his kind: and God saw that it was good."),
    BibleVerse(number: 26, text: "And God said, Let us make man in our image, after our likeness: and let them have dominion over the fish of the sea, and over the fowl of the air, and over the cattle, and over all the earth, and over every creeping thing that creepeth upon the earth."),
    BibleVerse(number: 27, text: "So God created man in his own image, in the image of God created he him; male and female created he them."),
    BibleVerse(number: 28, text: "And God blessed them, and God said unto them, Be fruitful, and multiply, and replenish the earth, and subdue it: and have dominion over the fish of the sea, and over the fowl of the air, and over every living thing that moveth upon the earth."),
    BibleVerse(number: 29, text: "And God said, Behold, I have given you every herb bearing seed, which is upon the face of all the earth, and every tree, in the which is the fruit of a tree yielding seed; to you it shall be for meat."),
    BibleVerse(number: 30, text: "And to every beast of the earth, and to every fowl of the air, and to every thing that creepeth upon the earth, wherein there is life, I have given every green herb for meat: and it was so."),
    BibleVerse(number: 31, text: "And God saw every thing that he had made, and, behold, it was very good. And the evening and the morning were the sixth day."),
  ];

  static List<BibleVerse> get instantGenesis1Verses => _genesis1KjvVerses;

  static void _seedInstantKjv() {
    final chapter = BibleChapter(
      book: 'Genesis',
      chapter: 1,
      version: 'KJV',
      language: 'en',
      verses: _genesis1KjvVerses,
    );
    _memoryChapterCache['en/KJV/genesis/1'] = chapter;
    _memoryChapterCache['en/kjv/genesis/1'] = chapter;
  }

  void _warmUpDatabaseInBackground() {
    unawaited(_dbHelper.database.then((_) {
      _logger.info('Pre-built SQLite Bible database warmed up in background');
    }).catchError((e) {
      _logger.warning('Background Bible database warmup error: $e');
    }));
  }

  /// Strips USFM/XML tags like `<pb/>`, `<pb>`, `<t>`, `</t>`, `<f>...</f>`, `<x>...</x>`, etc.
  static String cleanVerseText(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    String text = raw
        .replaceAll(RegExp(r'<f[\s\S]*?<\/f>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<x[\s\S]*?<\/x>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  OfflineBibleService._internal({
    BibleDatabaseHelper? dbHelper,
  }) : _dbHelper = dbHelper ?? BibleDatabaseHelper() {
    _seedInstantKjv();
    _warmUpDatabaseInBackground();
  }

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
      {'code': 'NLT', 'name': 'New Living Translation'},
      {'code': 'NIV', 'name': 'New International Version'},
      {'code': 'ASV', 'name': 'American Standard Version'},
      {'code': 'NASB', 'name': 'New American Standard Bible'},
      {'code': 'NKJV', 'name': 'New King James Version'},
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
    'NLT': 'New Living Translation (English)',
    'NIV': 'New International Version (English)',
    'ASV': 'American Standard Version (English)',
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

      // Prefer loading books directly from bundled assets for the requested language.
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

      // Try to get from local database (English defaults inserted on creation)
      if (kIsWeb) {
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
        return [];
      }

      try {
        final books = await _dbHelper.getAllBooks();
        if (books.isNotEmpty) {
          return books;
        }
      } on BibleDatabaseInstallException catch (e) {
        // The bundled database could not be installed. That is not a transient
        // read failure, so it must not fall through to the JSON asset path and
        // present as a Bible with no books. Report it.
        _logger.error('Bundled Bible database failed to install', e);
        rethrow;
      } catch (dbErr) {
        _logger.warning('Error fetching books from SQLite DB: $dbErr');
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

      return [];
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error getting Bible books', e);
      throw DatabaseException('Failed to get Bible books', originalError: e);
    }
  }

  // Get Bible chapter — SQLite-first architecture.
  // The pre-built bible.db (copied on first launch) contains all 214 K+
  // verses across 9 versions.  On native platforms, the SQLite compound-
  // indexed query returns a full chapter in <1 ms.  The loose-JSON and
  // ZIP paths are kept only as web / emergency fallbacks.
  Future<BibleChapter?> getBibleChapter({
    required String book,
    required int chapter,
    String? version,
    String? language,
  }) async {
    try {
      final versionCode = version ?? _defaultVersion;
      final languageCode = language ?? _defaultLanguage;

      // 0. Super-fast in-memory cache check (0 ms response)
      final memKey = '$languageCode/$versionCode/${book.toLowerCase().trim()}/$chapter';
      final inMem = _memoryChapterCache[memKey];
      if (inMem != null && inMem.verses.isNotEmpty) {
        _prefetchChapter(book, chapter + 1, versionCode, languageCode);
        if (chapter > 1) {
          _prefetchChapter(book, chapter - 1, versionCode, languageCode);
        }
        return inMem;
      }

      // 1. PRIMARY: Pre-built SQLite database (<1 ms indexed query)
      //    The pre-built bible.db is copied from assets on first launch,
      //    so this will hit from the very first chapter open.
      try {
        final dbChapter = await _dbHelper.getChapter(
            book, chapter, versionCode, languageCode);
        if (dbChapter != null && dbChapter.verses.isNotEmpty) {
          _memoryChapterCache[memKey] = dbChapter;
          _prefetchChapter(book, chapter + 1, versionCode, languageCode);
          if (chapter > 1) {
            _prefetchChapter(book, chapter - 1, versionCode, languageCode);
          }
          return dbChapter;
        }
      } catch (dbErr) {
        _logger.warning('SQLite lookup failed: $dbErr');
      }

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

  final Map<String, _BibleSearchIndex> _searchIndexes = {};
  final Map<String, List<BibleTextHit>> _searchCache = {};
  final Map<String, Future<_BibleSearchIndex?>> _inFlightIndexBuilds = {};

  Future<_BibleSearchIndex?> _getOrBuildIndex({
    required String indexKey,
    required String versionCode,
    required String languageCode,
  }) async {
    final cached = _searchIndexes[indexKey];
    if (cached != null && cached.entries.isNotEmpty) return cached;

    final inFlight = _inFlightIndexBuilds[indexKey];
    if (inFlight != null) return inFlight;

    final future = _buildSearchIndex(
      indexKey: indexKey,
      versionCode: versionCode,
      languageCode: languageCode,
    );
    _inFlightIndexBuilds[indexKey] = future;
    try {
      final result = await future;
      return result;
    } finally {
      _inFlightIndexBuilds.remove(indexKey);
    }
  }

  // Full-text search — FTS5-first on native, in-memory fallback on web.
  // On native: FTS5 queries the pre-built `bible_search` virtual table
  // in ~35 ms across 214 K verses with BM25 ranking.  No index build needed.
  // On web: falls back to the legacy in-memory inverted-index approach.
  Future<List<BibleTextHit>> searchBibleText({
    required String query,
    String? version,
    String? language,
    int limit = 50,
  }) async {
    final versionCode = (version == null || version.isEmpty)
        ? _defaultVersion
        : version;
    final languageCode = (language == null || language.isEmpty)
        ? _defaultLanguage
        : language;
    final phrase = SearchUtils.normalize(query);
    if (phrase.isEmpty) return [];

    final indexKey = '$languageCode/$versionCode';
    final cacheKey = '$indexKey|$phrase|$limit';
    final cached = _searchCache[cacheKey];
    if (cached != null) return cached;

    // ── FTS5 fast path ────────────────────────────────────────────────
    // Runs on web as well as native. This was gated on `!kIsWeb` on the
    // assumption that FTS5 was a native-only capability, but the browser build
    // ships the stock sqflite_common_ffi_web wasm, which is compiled with
    // SQLITE_ENABLE_FTS5 (a default define in the sqlite3 package's build
    // hook). The gate therefore forced every browser search through the slow
    // in-memory fallback even though the FTS index is present in the very same
    // database the browser already loaded.
    //
    // The existing catch already falls back to the in-memory index if FTS5
    // turns out to be unavailable, so running this unconditionally is safe
    // either way.
    try {
      final ftsResults = await _dbHelper.fts5Search(
        query,
        version: versionCode,
        language: languageCode,
        limit: limit,
      );
      if (ftsResults.isNotEmpty) {
        final hits = ftsResults
            .map((r) => BibleTextHit(
                  book: r.book,
                  chapter: r.chapter,
                  verse: r.verse,
                  reference: r.reference,
                  text: r.text,
                ))
            .toList();
        if (_searchCache.length > 200) _searchCache.clear();
        _searchCache[cacheKey] = hits;
        return hits;
      }
    } catch (e) {
      _logger.warning('FTS5 search failed, falling back to in-memory: $e');
    }

    // ── Legacy in-memory index path (fallback) ───────────────────────
    final index = await _getOrBuildIndex(
      indexKey: indexKey,
      versionCode: versionCode,
      languageCode: languageCode,
    );
    if (index == null || index.entries.isEmpty) return [];

    final tokens = SearchUtils.tokensOf(query);

    // Check if query is an explicit reference (e.g. "John 3", "Psalm 23", "Genesis 1", "John 3:16")
    final refParsed = BibleData.parseReference(query);
    final Set<int> refCandidateIndices = {};
    if (refParsed['isValid'] == true) {
      final targetBook = (refParsed['book'] as String).toLowerCase();
      final targetChapter = refParsed['chapter'] as int;
      final hasChapter = refParsed['hasChapter'] as bool;
      final hasVerse = refParsed['hasVerse'] as bool;
      final targetStartVerse = refParsed['startVerse'] as int;
      final targetEndVerse = refParsed['endVerse'] as int;

      for (int i = 0; i < index.entries.length; i++) {
        final e = index.entries[i];
        if (e.book.toLowerCase() == targetBook) {
          if (!hasChapter) {
            refCandidateIndices.add(i);
          } else if (e.chapter == targetChapter) {
            if (!hasVerse || (e.verse >= targetStartVerse && e.verse <= targetEndVerse)) {
              refCandidateIndices.add(i);
            }
          }
        }
      }
    }

    // Candidate narrowing using token and stem inverted index
    final candidateIndices = index.findCandidateIndices(tokens);
    candidateIndices.addAll(refCandidateIndices);

    final pool = candidateIndices.isEmpty
        ? index.entries
        : candidateIndices.map((i) => index.entries[i]);

    final scored = <MapEntry<BibleTextHit, int>>[];
    for (final entry in pool) {
      final score = SearchUtils.scoreVerse(
        reference: entry.reference,
        text: entry.text,
        query: query,
      );
      if (score > 0) {
        scored.add(MapEntry(
          BibleTextHit(
            book: entry.book,
            chapter: entry.chapter,
            verse: entry.verse,
            reference: entry.reference,
            text: entry.text,
          ),
          score,
        ));
      }
    }

    scored.sort((a, b) {
      final comp = b.value.compareTo(a.value);
      if (comp != 0) return comp;
      if (a.key.book == b.key.book) {
        if (a.key.chapter == b.key.chapter) {
          return a.key.verse.compareTo(b.key.verse);
        }
        return a.key.chapter.compareTo(b.key.chapter);
      }
      return 0;
    });

    final result = scored.take(limit).map((e) => e.key).toList();
    if (_searchCache.length > 200) _searchCache.clear();
    _searchCache[cacheKey] = result;
    return result;
  }

  /// Returns every verse in the bundled Bible for the given language/version
  /// (~31,000 verses across all 66 books). Used by the daily-verse generator
  /// so each date maps to a unique verse from the FULL corpus instead of the
  /// small bundled static list. The result is cached after the first build.
  Future<List<BibleTextHit>> getAllVerses({
    String? version,
    String? language,
  }) async {
    final versionCode =
        (version == null || version.isEmpty) ? _defaultVersion : version;
    final languageCode =
        (language == null || language.isEmpty) ? _defaultLanguage : language;
    final indexKey = '$languageCode/$versionCode';

    final index = await _getOrBuildIndex(
      indexKey: indexKey,
      versionCode: versionCode,
      languageCode: languageCode,
    );
    if (index == null || index.entries.isEmpty) return [];

    return index.entries
        .map((e) => BibleTextHit(
              book: e.book,
              chapter: e.chapter,
              verse: e.verse,
              reference: e.reference,
              text: e.text,
            ))
        .toList();
  }

  /// Top-level isolate worker to decode ZIP bundle and construct the search index
  /// with zero UI-thread lag.
  static _BibleSearchIndex? _buildIndexFromZipBytes(Uint8List zipBytes) {
    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);
      final entries = <_IndexedVerse>[];
      final postings = <String, List<int>>{};

      final jsonFiles = archive.files
          .where((f) => f.isFile && f.name.toLowerCase().endsWith('.json'))
          .toList();

      for (final file in jsonFiles) {
        final content = file.content;
        if (content is! List<int>) continue;
        final jsonStr = utf8.decode(content);
        final data = json.decode(jsonStr) as Map<String, dynamic>;
        final meta = data['metadata'] as Map<String, dynamic>? ?? {};
        final rawBook = meta['book']?.toString() ??
            file.name.split('/').last.replaceAll('.json', '');
        final chapter = (meta['chapter'] as num?)?.toInt() ?? 1;
        final versesList = data['verses'] as List<dynamic>? ?? [];

        final bookTokens = <String>{
          ...SearchUtils.tokensOf(rawBook),
          ...BibleData.aliasesForBook(rawBook),
        };

        for (final v in versesList) {
          if (v is! Map) continue;
          final verseNum = (v['verse'] ?? v['number'] ?? 0) as int;
          final rawText = v['text']?.toString() ?? '';
          final cleanText = cleanVerseText(rawText);
          if (cleanText.isEmpty) continue;

          final ref = '$rawBook $chapter:$verseNum';
          final idx = entries.length;

          entries.add(_IndexedVerse(
            book: rawBook,
            chapter: chapter,
            verse: verseNum,
            reference: ref,
            text: cleanText,
          ));

          final verseTokens = <String>{
            ...bookTokens,
            chapter.toString(),
            verseNum.toString(),
            ...SearchUtils.tokensOf(cleanText),
          };

          final tokenSet = <String>{};
          for (final t in verseTokens) {
            tokenSet.add(t);
            final st = SearchUtils.stem(t);
            if (st != t) tokenSet.add(st);
          }

          for (final token in tokenSet) {
            (postings[token] ??= []).add(idx);
          }
        }
      }

      return _BibleSearchIndex(entries, postings);
    } catch (_) {
      return null;
    }
  }

  Future<_BibleSearchIndex?> _buildSearchIndex({
    required String indexKey,
    required String versionCode,
    required String languageCode,
  }) async {
    try {
      // 1. Try loading directly from the bundled ZIP file in a background isolate
      final zipPath = 'assets/bible_bundles/$languageCode/$versionCode.zip';
      ByteData? byteData;
      try {
        byteData = await rootBundle.load(zipPath);
      } catch (_) {
        byteData = null;
      }

      if (byteData != null) {
        final bytes = byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );
        final index = await compute(_buildIndexFromZipBytes, bytes);
        if (index != null && index.entries.isNotEmpty) {
          _searchIndexes[indexKey] = index;
          return index;
        }
      }

      // 2. Fall back to the bundled database.
      //
      // The ZIP bundles are not in the repository, so on web -- where the FTS5
      // fast path is skipped -- this was the only remaining route and it did not
      // exist. Every search therefore returned zero results, whatever was
      // typed. bible.db ships with the app and already holds every loaded
      // version, so read the verses from there instead.
      final rows = await _dbHelper.database.then((db) => db.rawQuery(
            'SELECT c.book AS book, c.chapter AS chapter, '
            'v.verse_number AS verse_number, v.text AS text '
            'FROM bible_verses v '
            'JOIN bible_chapters c ON c.id = v.chapter_id '
            'WHERE c.version = ? '
            'ORDER BY c.book, c.chapter, v.verse_number',
            [versionCode],
          ));
      final index = _buildIndexFromRows(rows);
      if (index.entries.isNotEmpty) {
        _searchIndexes[indexKey] = index;
        _logger.info(
          'Built search index for $indexKey from the database '
          '(${index.entries.length} verses)',
        );
        return index;
      }
      _logger.warning(
        'No verses available for $indexKey; search will return nothing. '
        'Check that the bundled database has chapters for this version.',
      );
      return null;
    } catch (e) {
      _logger.warning('Could not build a search index for $indexKey: $e');
      return null;
    }
  }
  /// Build the search index using only bundled asset files — no network,
  /// no SQLite reads. This makes the first search fast.
  Future<void> prebuildSearchIndexes() async {
    for (final lang in ['en', 'yo', 'ha', 'ig']) {
      final versions = _supportedLanguages[lang] ?? const [];
      for (final v in versions) {
        final code = v['code'];
        if (code == null) continue;
        final key = '$lang/$code';
        if (_searchIndexes.containsKey(key)) continue;
        try {
          await _buildSearchIndex(
            indexKey: key,
            versionCode: code,
            languageCode: lang,
          );
        } catch (_) {}
      }
    }
  }


  // Search Bible verses — FTS5-first, LIKE fallback.
  Future<List<BibleSearchResult>> searchBibleVerses({
    required String query,
    String? version,
    String? language,
    int limit = 50,
  }) async {
    try {
      final versionCode = version ?? _defaultVersion;
      final languageCode = language ?? _defaultLanguage;

      if (kIsWeb) return [];

      // Try FTS5 first (~35 ms over 214 K verses)
      try {
        final ftsResults = await _dbHelper.fts5Search(
          query,
          version: versionCode,
          language: languageCode,
          limit: limit,
        );
        if (ftsResults.isNotEmpty) return ftsResults;
      } catch (_) {
        // FTS5 table unavailable — fall through to LIKE search
      }

      // Fallback: LIKE-based search
      final localResults = await _dbHelper.searchVerses(query,
          version: versionCode, language: languageCode, limit: limit);
      return localResults;
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
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('bible_downloaded_${language}_$version', true);
        return true;
      }

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
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getBool('bible_downloaded_${language}_$version') ?? false;
      }

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
      if (kIsWeb) {
        final versions = await getAvailableVersions();
        return versions.where((version) => version.isDownloaded).toList();
      }

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
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('bible_downloaded_${language}_$version', false);
        return true;
      }

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
      if (kIsWeb) return;
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
  Future<List<BibleUserProgress>> getUserReadingProgress(
      String userId) async {
    try {
      if (kIsWeb) return [];
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

    try {
      await _loadVersionBundle(language, version);
      final fileMap = _bundleFileIndex['$language/$version'] ?? const <String, ArchiveFile>{};
      for (final assetPath in candidates) {
        final fileName = assetPath.split('/').last.toLowerCase();
        final file = fileMap[fileName];
        if (file == null || !file.isFile || file.content is! List<int>) {
          continue;
        }

        final chapterJson = utf8.decode(file.content as List<int>);
        final Map<String, dynamic> chapterData = json.decode(chapterJson);
        final verses = (chapterData['verses'] as List<dynamic>)
            .map((v) => BibleVerse(
                  number: v['verse'],
                  text: cleanVerseText(v['text']?.toString()),
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
      }
    } catch (error) {
      lastError = error;
    }

    _logger.error(
      'Error loading chapter from bundle. Tried ${candidates.length} candidates',
      lastError,
    );
    throw NotFoundException(
      'Failed to load chapter from Bible bundle',
      originalError: lastError,
    );
  }

  static Archive _decodeZipArchive(Uint8List bytes) {
    return ZipDecoder().decodeBytes(bytes);
  }

  Future<Archive> _loadVersionBundle(String language, String version) async {
    final cacheKey = '$language/$version';
    final cached = _bundleCache[cacheKey];
    if (cached != null) return cached;

    final inFlight = _inFlightBundleLoads[cacheKey];
    if (inFlight != null) return inFlight;

    final future = _loadVersionBundleInternal(language, version, cacheKey);
    _inFlightBundleLoads[cacheKey] = future;
    try {
      return await future;
    } finally {
      _inFlightBundleLoads.remove(cacheKey);
    }
  }

  Future<Archive> _loadVersionBundleInternal(
      String language, String version, String cacheKey) async {
    final data = await rootBundle.load(
      'assets/bible_bundles/$language/$version.zip',
    );
    final bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    // Offload decoding from main UI isolate for zero lag
    final archive = await compute(_decodeZipArchive, bytes);
    _bundleCache[cacheKey] = archive;

    final fileMap = <String, ArchiveFile>{};
    for (final file in archive.files) {
      if (file.isFile) {
        fileMap[file.name.toLowerCase()] = file;
        final base = file.name.split('/').last.toLowerCase();
        fileMap[base] = file;
      }
    }
    _bundleFileIndex[cacheKey] = fileMap;
    return archive;
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


  void _prefetchChapter(String book, int chapter, String version, String language) {
    if (chapter < 1 || chapter > 150) return;
    final nextKey = '$language/$version/${book.toLowerCase().trim()}/$chapter';
    if (_memoryChapterCache.containsKey(nextKey)) return;
    Future.microtask(() async {
      try {
        await getBibleChapter(
          book: book,
          chapter: chapter,
          version: version,
          language: language,
        );
      } catch (_) {}
    });
  }

  /// Pre-warm a bundle in background so chapter loads are instant
  Future<void> prewarmBundle({String language = 'en', String version = 'KJV'}) async {
    try {
      await _loadVersionBundle(language, version);
    } catch (_) {}
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

  // Clear all cached Bible data
  Future<void> clearCache() async {
    try {
      if (kIsWeb) return;
      await _dbHelper.clearCache();
      _logger.info('Bible cache cleared');
    } catch (e) {
      _logger.error('Error clearing Bible cache', e);
    }
  }

  // Discover version codes from AssetManifest for a language
  Future<List<String>> getAvailableVersionCodesFromAssets(String language) =>
      _discoverAvailableVersionCodesFromAssets(language);

  Future<List<String>> _discoverAvailableVersionCodesFromAssets(
      String language) async {
    // What the app is willing to offer for this language.
    final configured = (_supportedLanguages[language] ?? const <Map<String, String>>[])
        .map((version) => version['code'])
        .whereType<String>()
        .toList();
    if (configured.isEmpty) return configured;

    // Cross-check against the bundled database.
    //
    // The configured list above is a wish list, not a record of what shipped.
    // bible.db currently carries chapters for KJV/NIV/ASV/NASB/NKJV/BM/IGBOB
    // but none for NLT or HAU, and offering those produced a blank reader
    // rather than an honest "unavailable". Filtering by what is actually
    // present keeps the picker honest and survives the data changing.
    final bundled = await _versionsPresentInDatabase();
    if (bundled.isEmpty) return configured; // Can't tell -- don't hide anything.

    final available = configured.where(bundled.contains).toList();
    if (available.length != configured.length) {
      final missing = configured.where((c) => !bundled.contains(c)).toList();
      _logger.info(
        'Hiding Bible version(s) with no bundled text: ${missing.join(', ')}',
      );
    }
    return available.isEmpty ? configured : available;
  }

  /// Version codes that actually have chapters in the bundled database.
  Future<Set<String>> _versionsPresentInDatabase() async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.rawQuery(
        'SELECT DISTINCT version FROM bible_chapters',
      );
      return rows
          .map((r) => r['version'])
          .whereType<String>()
          .where((v) => v.isNotEmpty)
          .toSet();
    } catch (_) {
      // If the database cannot be read, fall back to the configured list so
      // the reader is not emptied out by a transient failure.
      return const <String>{};
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

/// A single indexed verse used by the Bible full-text search.
class _IndexedVerse {
  final String book;
  final int chapter;
  final int verse;
  final String reference;
  final String text;

  const _IndexedVerse({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.reference,
    required this.text,
  });
}

/// Builds the search index from plain verse rows read out of the database.
///
/// This is the fallback for when the pre-built ZIP bundles are absent. They
/// were never committed (`assets/bible_bundles/` does not exist and is not
/// declared in pubspec.yaml), so _buildSearchIndex always returned null and web
/// search returned nothing for *every* query -- not just the ones reported.
_BibleSearchIndex _buildIndexFromRows(List<Map<String, dynamic>> rows) {
  final entries = <_IndexedVerse>[];
  for (final row in rows) {
    final text = (row['text'] as String?) ?? '';
    if (text.trim().isEmpty) continue;
    final book = (row['book'] as String?) ?? '';
    final chapter = (row['chapter'] as num?)?.toInt() ?? 0;
    final verse = (row['verse_number'] as num?)?.toInt() ?? 0;
    entries.add(_IndexedVerse(
      book: book,
      chapter: chapter,
      verse: verse,
      reference: '$book $chapter:$verse',
      text: text,
    ));
  }
  return _BibleSearchIndex(entries, const <String, List<int>>{});
}

/// In-memory inverted index over [_IndexedVerse] entries.
/// Supports fast token → document-id lookups for candidate narrowing.
class _BibleSearchIndex {
  final List<_IndexedVerse> entries;
  final Map<String, List<int>> _postings;

  const _BibleSearchIndex(this.entries, this._postings);

  /// Number of documents (verses) containing [token].
  int docFreq(String token) => _postings[token]?.length ?? 0;

  /// Document indices that contain [token].
  List<int> docsFor(String token) => _postings[token] ?? const <int>[];

  /// Find candidate document indices for query tokens.
  /// Aggregates matches across tokens and their stems, prioritizing
  /// verses that match multiple query words.
  Set<int> findCandidateIndices(List<String> tokens, {int maxCandidates = 3000}) {
    if (tokens.isEmpty) return entries.asMap().keys.toSet();

    final hitCounts = <int, int>{};
    for (final t in tokens) {
      final st = SearchUtils.stem(t);
      final docs = <int>{
        ...docsFor(t),
        if (st != t) ...docsFor(st),
      };
      for (final docId in docs) {
        hitCounts[docId] = (hitCounts[docId] ?? 0) + 1;
      }
    }

    if (hitCounts.isEmpty) return {};

    // Group documents by match count descending (verses matching all tokens first)
    final byHitCount = <int, List<int>>{};
    for (final entry in hitCounts.entries) {
      (byHitCount[entry.value] ??= []).add(entry.key);
    }

    final sortedCounts = byHitCount.keys.toList()..sort((a, b) => b.compareTo(a));
    final candidates = <int>{};

    for (final count in sortedCounts) {
      final list = byHitCount[count]!;
      candidates.addAll(list);
      if (candidates.length >= maxCandidates) break;
    }

    return candidates;
  }
}
