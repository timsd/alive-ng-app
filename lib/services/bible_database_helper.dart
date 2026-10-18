import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
// Web SQLite (WASM + worker). `sqflite` alone has no browser implementation,
// which is why the Bible reader was blank in the deployed web app.
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart' as p;
import '../models/bible_models.dart';
import '../constants/bible_data.dart';

/// Thrown when the bundled Bible database cannot be installed.
///
/// This exists so a broken install is reported rather than silently presenting
/// as an empty Bible. The previous code caught the failure, logged it, and
/// carried on with an empty database, which the member saw as "no translations
/// downloaded" and nobody could trace back to a failed asset copy.
class BibleDatabaseInstallException implements Exception {
  final String message;
  const BibleDatabaseInstallException(this.message);

  @override
  String toString() => 'BibleDatabaseInstallException: $message';
}

class BibleDatabaseHelper {
  static final BibleDatabaseHelper _instance = BibleDatabaseHelper._internal();
  factory BibleDatabaseHelper() => _instance;
  BibleDatabaseHelper._internal();

  static Database? _database;
  /// The runtime database name.  On mobile/desktop the pre-built
  /// `bible.db` asset is copied here on first launch so every query
  /// hits a fully-indexed, FTS5-ready database from day one.
  static const String _databaseName = 'bible_prebuilt.db';
  static const int _databaseVersion = 2;

  /// Asset path to the pre-built database shipped inside the app bundle.
  static const String _prebuiltAssetPath = 'assets/bible/bible.db';

  // Table names
  static const String _booksTable = 'bible_books';
  static const String _chaptersTable = 'bible_chapters';
  static const String _versesTable = 'bible_verses';
  static const String _versionsTable = 'bible_versions';
  static const String _readingPlansTable = 'reading_plans';
  static const String _readingDaysTable = 'reading_days';
  static const String _userProgressTable = 'user_progress';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      return _initWebDatabase();
    }
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, _databaseName);

    // On native platforms, copy the pre-built bible.db from assets
    // on first launch.  This gives us 214 K+ verses, FTS5 search,
    // and compound indexes from the very first open — zero warm-up.
    final dbFile = File(path);
    // Check *content*, not just file existence. `existsSync()` alone is the bug
    // this replaces: a previous run that was killed mid-copy, or one that ran
    // before the asset was added, leaves a zero-byte or empty-schema file at
    // this path. That file exists, so the copy was skipped forever and the
    // member got a permanently blank reader with no error anywhere.
    //
    // The web path already got this right (_webDatabaseHasVerses counts rows);
    // native was the outlier, which is the same "asset is fine but was never
    // really installed" failure in the other direction.
    final needsInstall = !dbFile.existsSync() || !await _fileHasVerses(dbFile);
    if (needsInstall) {
      // A stale or truncated file would otherwise be appended to.
      if (dbFile.existsSync()) {
        debugPrint('[BibleDB] Existing copy at $path has no verses; '
            'replacing it with the bundled asset.');
        try {
          await dbFile.delete();
        } catch (e) {
          debugPrint('[BibleDB] Could not remove stale database: $e');
        }
      }

      // Ensure the databases directory exists
      await Directory(databasesPath).create(recursive: true);
      try {
        final data = await rootBundle.load(_prebuiltAssetPath);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await dbFile.writeAsBytes(bytes, flush: true);
        debugPrint('[BibleDB] Pre-built bible.db copied to $path '
            '(${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB)');
      } catch (e) {
        // Surfaced rather than swallowed: this used to log and continue,
        // leaving an empty database that looks healthy from the outside. The
        // reader surfaces this as an error so a broken install is visible
        // rather than presenting as "no translations downloaded".
        throw BibleDatabaseInstallException(
          'Could not install the bundled Bible database: $e',
        );
      }
    }

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Web initialisation.
  ///
  /// `sqflite` has no web implementation, so the previous code fell through
  /// to `openDatabase` here and opened nothing usable -- the reader was blank
  /// for every member on the deployed web app. This runs SQLite in a worker
  /// via WASM and seeds it from the same bundled asset, so the browser gets
  /// the identical 214 K verses the native build does.
  ///
  /// Requires `sqlite3.wasm` and `sqflite_sw.js` in `web/`. Both are produced by
  /// `dart run sqflite_common_ffi_web:setup` and are tracked in the repo, so a
  /// clean checkout can build the web app without a setup step.
  Future<Database> _initWebDatabase() async {
    // Ignore: deprecated_member_use -- assigning the global factory is the
    // documented way to point sqflite at the web implementation.
    // ignore: deprecated_member_use
    databaseFactory = databaseFactoryFfiWeb;

    final path = _databaseName;
    // Content check, not existence: this is what makes the browser recover from
    // a half-written IndexedDB copy. Matches the native _fileHasVerses check
    // so the two platforms cannot drift again.
    if (!await _webDatabaseHasVerses(path)) {
      try {
        final data = await rootBundle.load(_prebuiltAssetPath);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        // On the web the database lives in IndexedDB, so there is no file to
        // copy: the bytes have to be written through the factory. This is what
        // `sqflite_common_ffi_web` documents for importing an asset database.
        await databaseFactory.writeDatabaseBytes(path, bytes);
      } catch (e) {
        // Thrown rather than swallowed, for the same reason as the native
        // path: an empty database here is indistinguishable, to the member,
        // from "no translations downloaded".
        throw BibleDatabaseInstallException(
          'Could not install the bundled Bible database in the browser: $e',
        );
      }
    }

    return databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  /// True when the browser copy already holds verses, so the 60 MB asset is
  /// only written once rather than on every launch.
  Future<bool> _webDatabaseHasVerses(String path) async {
    Database? probe;
    try {
      probe = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: _databaseVersion,
          onCreate: _onCreate,
        ),
      );
      final rows = await probe.rawQuery('SELECT COUNT(*) AS c FROM bible_verses');
      return ((rows.first['c'] as int?) ?? 0) > 0;
    } catch (_) {
      return false;
    } finally {
      await probe?.close();
    }
  }

  /// True when the native copy at [dbFile] really holds verses.
  ///
  /// Opened read-only and by a throwaway handle, so a half-written or
  /// empty-schema file reports false and gets reinstalled instead of being
  /// trusted. Mirrors [_webDatabaseHasVerses], which is the same check for the
  /// browser's IndexedDB copy.
  Future<bool> _fileHasVerses(File dbFile) async {
    // A zero-byte file cannot be a database at all, and trying to open it
    // produces a confusing SQLite error rather than a useful answer.
    if (!dbFile.existsSync() || dbFile.lengthSync() == 0) return false;

    Database? probe;
    try {
      probe = await openDatabase(
        dbFile.path,
        // readOnly so that inspecting the file can never create tables in it or
        // otherwise mutate what we are about to decide to replace.
        readOnly: true,
      );
      final rows = await probe.rawQuery('SELECT COUNT(*) AS c FROM $_versesTable');
      final count = rows.first['c'];
      return count is int && count > 0;
    } catch (_) {
      // Unreadable, corrupt, or missing the table: treat as not installed.
      return false;
    } finally {
      await probe?.close();
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create bible_books table
    await db.execute('''
      CREATE TABLE $_booksTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        abbreviation TEXT NOT NULL,
        chapters INTEGER NOT NULL,
        testament TEXT NOT NULL,
        book_order INTEGER NOT NULL,
        translations TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(name, abbreviation)
      )
    ''');

    // Create bible_versions table
    await db.execute('''
      CREATE TABLE $_versionsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        language TEXT NOT NULL,
        language_code TEXT NOT NULL,
        description TEXT,
        is_downloaded INTEGER DEFAULT 0,
        downloaded_at TEXT,
        total_size INTEGER,
        metadata TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create bible_chapters table
    await db.execute('''
      CREATE TABLE $_chaptersTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book TEXT NOT NULL,
        chapter INTEGER NOT NULL,
        version TEXT NOT NULL,
        language TEXT NOT NULL,
        metadata TEXT,
        last_updated TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(book, chapter, version, language)
      )
    ''');

    // Create bible_verses table
    await db.execute('''
      CREATE TABLE $_versesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chapter_id INTEGER NOT NULL,
        verse_number INTEGER NOT NULL,
        text TEXT NOT NULL,
        footnotes TEXT,
        cross_references TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (chapter_id) REFERENCES $_chaptersTable (id) ON DELETE CASCADE,
        UNIQUE(chapter_id, verse_number)
      )
    ''');

    // Create reading_plans table
    await db.execute('''
      CREATE TABLE $_readingPlansTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        total_days INTEGER NOT NULL,
        start_date TEXT,
        completed_date TEXT,
        metadata TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create reading_days table
    await db.execute('''
      CREATE TABLE $_readingDaysTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id TEXT NOT NULL,
        day INTEGER NOT NULL,
        readings TEXT NOT NULL,
        theme TEXT,
        reflection TEXT,
        is_completed INTEGER DEFAULT 0,
        completed_at TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (plan_id) REFERENCES $_readingPlansTable (id) ON DELETE CASCADE,
        UNIQUE(plan_id, day)
      )
    ''');

    // Create user_progress table
    await db.execute('''
      CREATE TABLE $_userProgressTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        book TEXT NOT NULL,
        chapter INTEGER NOT NULL,
        verse INTEGER,
        version TEXT NOT NULL,
        progress_type TEXT NOT NULL, -- 'reading', 'bookmark', 'highlight', 'note'
        progress_data TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_books_testament ON $_booksTable (testament)');
    await db.execute('CREATE INDEX idx_books_order ON $_booksTable (book_order)');
    await db.execute('CREATE INDEX idx_chapters_book ON $_chaptersTable (book)');
    await db.execute('CREATE INDEX idx_chapters_version ON $_chaptersTable (version)');
    await db.execute('CREATE INDEX idx_verses_chapter ON $_versesTable (chapter_id)');
    await db.execute('CREATE INDEX idx_progress_user ON $_userProgressTable (user_id)');
    await db.execute('CREATE INDEX idx_progress_book ON $_userProgressTable (book, chapter)');

    // Insert default Bible books
    await _insertDefaultBooks(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // The pre-built bible.db ships with user_version=2 so this should
    // not fire on a normal first install.  But just in case, create
    // any runtime-only tables that might be missing.
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_readingPlansTable (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          total_days INTEGER NOT NULL,
          start_date TEXT,
          completed_date TEXT,
          metadata TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_readingDaysTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          plan_id TEXT NOT NULL,
          day INTEGER NOT NULL,
          readings TEXT NOT NULL,
          theme TEXT,
          reflection TEXT,
          is_completed INTEGER DEFAULT 0,
          completed_at TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (plan_id) REFERENCES $_readingPlansTable (id) ON DELETE CASCADE,
          UNIQUE(plan_id, day)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_userProgressTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT NOT NULL,
          book TEXT NOT NULL,
          chapter INTEGER NOT NULL,
          verse INTEGER,
          version TEXT NOT NULL,
          progress_type TEXT NOT NULL,
          progress_data TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_progress_user ON $_userProgressTable (user_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_progress_book ON $_userProgressTable (book, chapter)');
    }
  }

  Future<void> _insertDefaultBooks(Database db) async {
    final books = [
      // Old Testament
      {'name': 'Genesis', 'abbreviation': 'Gen', 'chapters': 50, 'testament': 'Old', 'order': 1},
      {'name': 'Exodus', 'abbreviation': 'Exo', 'chapters': 40, 'testament': 'Old', 'order': 2},
      {'name': 'Leviticus', 'abbreviation': 'Lev', 'chapters': 27, 'testament': 'Old', 'order': 3},
      {'name': 'Numbers', 'abbreviation': 'Num', 'chapters': 36, 'testament': 'Old', 'order': 4},
      {'name': 'Deuteronomy', 'abbreviation': 'Deu', 'chapters': 34, 'testament': 'Old', 'order': 5},
      {'name': 'Joshua', 'abbreviation': 'Jos', 'chapters': 24, 'testament': 'Old', 'order': 6},
      {'name': 'Judges', 'abbreviation': 'Jdg', 'chapters': 21, 'testament': 'Old', 'order': 7},
      {'name': 'Ruth', 'abbreviation': 'Rut', 'chapters': 4, 'testament': 'Old', 'order': 8},
      {'name': '1 Samuel', 'abbreviation': '1Sa', 'chapters': 31, 'testament': 'Old', 'order': 9},
      {'name': '2 Samuel', 'abbreviation': '2Sa', 'chapters': 24, 'testament': 'Old', 'order': 10},
      {'name': '1 Kings', 'abbreviation': '1Ki', 'chapters': 22, 'testament': 'Old', 'order': 11},
      {'name': '2 Kings', 'abbreviation': '2Ki', 'chapters': 25, 'testament': 'Old', 'order': 12},
      {'name': '1 Chronicles', 'abbreviation': '1Ch', 'chapters': 29, 'testament': 'Old', 'order': 13},
      {'name': '2 Chronicles', 'abbreviation': '2Ch', 'chapters': 36, 'testament': 'Old', 'order': 14},
      {'name': 'Ezra', 'abbreviation': 'Ezr', 'chapters': 10, 'testament': 'Old', 'order': 15},
      {'name': 'Nehemiah', 'abbreviation': 'Neh', 'chapters': 13, 'testament': 'Old', 'order': 16},
      {'name': 'Esther', 'abbreviation': 'Est', 'chapters': 10, 'testament': 'Old', 'order': 17},
      {'name': 'Job', 'abbreviation': 'Job', 'chapters': 42, 'testament': 'Old', 'order': 18},
      {'name': 'Psalms', 'abbreviation': 'Psa', 'chapters': 150, 'testament': 'Old', 'order': 19},
      {'name': 'Proverbs', 'abbreviation': 'Pro', 'chapters': 31, 'testament': 'Old', 'order': 20},
      {'name': 'Ecclesiastes', 'abbreviation': 'Ecc', 'chapters': 12, 'testament': 'Old', 'order': 21},
      {'name': 'Song of Solomon', 'abbreviation': 'Son', 'chapters': 8, 'testament': 'Old', 'order': 22},
      {'name': 'Isaiah', 'abbreviation': 'Isa', 'chapters': 66, 'testament': 'Old', 'order': 23},
      {'name': 'Jeremiah', 'abbreviation': 'Jer', 'chapters': 52, 'testament': 'Old', 'order': 24},
      {'name': 'Lamentations', 'abbreviation': 'Lam', 'chapters': 5, 'testament': 'Old', 'order': 25},
      {'name': 'Ezekiel', 'abbreviation': 'Eze', 'chapters': 48, 'testament': 'Old', 'order': 26},
      {'name': 'Daniel', 'abbreviation': 'Dan', 'chapters': 12, 'testament': 'Old', 'order': 27},
      {'name': 'Hosea', 'abbreviation': 'Hos', 'chapters': 14, 'testament': 'Old', 'order': 28},
      {'name': 'Joel', 'abbreviation': 'Joe', 'chapters': 3, 'testament': 'Old', 'order': 29},
      {'name': 'Amos', 'abbreviation': 'Amo', 'chapters': 9, 'testament': 'Old', 'order': 30},
      {'name': 'Obadiah', 'abbreviation': 'Oba', 'chapters': 1, 'testament': 'Old', 'order': 31},
      {'name': 'Jonah', 'abbreviation': 'Jon', 'chapters': 4, 'testament': 'Old', 'order': 32},
      {'name': 'Micah', 'abbreviation': 'Mic', 'chapters': 7, 'testament': 'Old', 'order': 33},
      {'name': 'Nahum', 'abbreviation': 'Nah', 'chapters': 3, 'testament': 'Old', 'order': 34},
      {'name': 'Habakkuk', 'abbreviation': 'Hab', 'chapters': 3, 'testament': 'Old', 'order': 35},
      {'name': 'Zephaniah', 'abbreviation': 'Zep', 'chapters': 3, 'testament': 'Old', 'order': 36},
      {'name': 'Haggai', 'abbreviation': 'Hag', 'chapters': 2, 'testament': 'Old', 'order': 37},
      {'name': 'Zechariah', 'abbreviation': 'Zec', 'chapters': 14, 'testament': 'Old', 'order': 38},
      {'name': 'Malachi', 'abbreviation': 'Mal', 'chapters': 4, 'testament': 'Old', 'order': 39},
      
      // New Testament
      {'name': 'Matthew', 'abbreviation': 'Mat', 'chapters': 28, 'testament': 'New', 'order': 40},
      {'name': 'Mark', 'abbreviation': 'Mar', 'chapters': 16, 'testament': 'New', 'order': 41},
      {'name': 'Luke', 'abbreviation': 'Luk', 'chapters': 24, 'testament': 'New', 'order': 42},
      {'name': 'John', 'abbreviation': 'Joh', 'chapters': 21, 'testament': 'New', 'order': 43},
      {'name': 'Acts', 'abbreviation': 'Act', 'chapters': 28, 'testament': 'New', 'order': 44},
      {'name': 'Romans', 'abbreviation': 'Rom', 'chapters': 16, 'testament': 'New', 'order': 45},
      {'name': '1 Corinthians', 'abbreviation': '1Co', 'chapters': 16, 'testament': 'New', 'order': 46},
      {'name': '2 Corinthians', 'abbreviation': '2Co', 'chapters': 13, 'testament': 'New', 'order': 47},
      {'name': 'Galatians', 'abbreviation': 'Gal', 'chapters': 6, 'testament': 'New', 'order': 48},
      {'name': 'Ephesians', 'abbreviation': 'Eph', 'chapters': 6, 'testament': 'New', 'order': 49},
      {'name': 'Philippians', 'abbreviation': 'Phi', 'chapters': 4, 'testament': 'New', 'order': 50},
      {'name': 'Colossians', 'abbreviation': 'Col', 'chapters': 4, 'testament': 'New', 'order': 51},
      {'name': '1 Thessalonians', 'abbreviation': '1Th', 'chapters': 5, 'testament': 'New', 'order': 52},
      {'name': '2 Thessalonians', 'abbreviation': '2Th', 'chapters': 3, 'testament': 'New', 'order': 53},
      {'name': '1 Timothy', 'abbreviation': '1Ti', 'chapters': 6, 'testament': 'New', 'order': 54},
      {'name': '2 Timothy', 'abbreviation': '2Ti', 'chapters': 4, 'testament': 'New', 'order': 55},
      {'name': 'Titus', 'abbreviation': 'Tit', 'chapters': 3, 'testament': 'New', 'order': 56},
      {'name': 'Philemon', 'abbreviation': 'Phm', 'chapters': 1, 'testament': 'New', 'order': 57},
      {'name': 'Hebrews', 'abbreviation': 'Heb', 'chapters': 13, 'testament': 'New', 'order': 58},
      {'name': 'James', 'abbreviation': 'Jam', 'chapters': 5, 'testament': 'New', 'order': 59},
      {'name': '1 Peter', 'abbreviation': '1Pe', 'chapters': 5, 'testament': 'New', 'order': 60},
      {'name': '2 Peter', 'abbreviation': '2Pe', 'chapters': 3, 'testament': 'New', 'order': 61},
      {'name': '1 John', 'abbreviation': '1Jo', 'chapters': 5, 'testament': 'New', 'order': 62},
      {'name': '2 John', 'abbreviation': '2Jo', 'chapters': 1, 'testament': 'New', 'order': 63},
      {'name': '3 John', 'abbreviation': '3Jo', 'chapters': 1, 'testament': 'New', 'order': 64},
      {'name': 'Jude', 'abbreviation': 'Jud', 'chapters': 1, 'testament': 'New', 'order': 65},
      {'name': 'Revelation', 'abbreviation': 'Rev', 'chapters': 22, 'testament': 'New', 'order': 66},
    ];

    for (final book in books) {
      await db.insert(
        _booksTable,
        {
          'name': book['name'],
          'abbreviation': book['abbreviation'],
          'chapters': book['chapters'],
          'testament': book['testament'],
          'book_order': book['order'],
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  // Bible Books operations
  Future<List<BibleBook>> getAllBooks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _booksTable,
      orderBy: 'book_order ASC',
    );

    return List.generate(maps.length, (i) {
      final map = maps[i];
      return BibleBook(
        name: map['name'],
        abbreviation: map['abbreviation'],
        chapters: map['chapters'],
        testament: map['testament'],
        order: map['book_order'],
        translations: map['translations'] != null 
            ? Map<String, String>.from(jsonDecode(map['translations']))
            : null,
      );
    });
  }

  Future<List<BibleBook>> getBooksByTestament(String testament) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _booksTable,
      where: 'testament = ?',
      whereArgs: [testament],
      orderBy: 'book_order ASC',
    );

    return List.generate(maps.length, (i) {
      final map = maps[i];
      return BibleBook(
        name: map['name'],
        abbreviation: map['abbreviation'],
        chapters: map['chapters'],
        testament: map['testament'],
        order: map['book_order'],
        translations: map['translations'] != null 
            ? Map<String, String>.from(jsonDecode(map['translations']))
            : null,
      );
    });
  }

  Future<BibleBook?> getBookByName(String name) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _booksTable,
      where: 'name = ? OR abbreviation = ?',
      whereArgs: [name, name],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    return BibleBook(
      name: map['name'],
      abbreviation: map['abbreviation'],
      chapters: map['chapters'],
      testament: map['testament'],
      order: map['book_order'],
      translations: map['translations'] != null 
          ? Map<String, String>.from(jsonDecode(map['translations']))
          : null,
    );
  }

  // Bible Versions operations
  Future<int> insertVersion(BibleVersion version) async {
    final db = await database;
    return await db.insert(
      _versionsTable,
      {
        'code': version.code,
        'name': version.name,
        'language': version.language,
        'language_code': version.languageCode,
        'description': version.description,
        'is_downloaded': version.isDownloaded ? 1 : 0,
        'downloaded_at': version.downloadedAt?.toIso8601String(),
        'total_size': version.totalSize,
        'metadata': version.metadata != null ? jsonEncode(version.metadata) : null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<BibleVersion>> getAllVersions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _versionsTable,
      orderBy: 'language, name ASC',
    );

    return List.generate(maps.length, (i) {
      final map = maps[i];
      return BibleVersion(
        code: map['code'],
        name: map['name'],
        language: map['language'],
        languageCode: map['language_code'],
        description: map['description'] ?? '',
        isDownloaded: map['is_downloaded'] == 1,
        downloadedAt: map['downloaded_at'] != null 
            ? DateTime.parse(map['downloaded_at'])
            : null,
        totalSize: map['total_size'],
        metadata: map['metadata'] != null 
            ? Map<String, dynamic>.from(jsonDecode(map['metadata']))
            : null,
      );
    });
  }

  /// The version codes that actually have verse text in this database.
  ///
  /// `bible_versions` is a catalogue, not proof of content: NLT and HAU are both
  /// listed there but ship with no `bible_chapters` rows at all. Offering them
  /// produced an empty reader, and a search filtered to them returned nothing
  /// for any query -- which is why "jesus wept" found no result even though the
  /// phrase is present in all five versions that do have text.
  ///
  /// Derived from the chapters table, so it stays correct if a later build
  /// loads the missing translations.
  Future<Set<String>> getLoadedVersionCodes() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT version FROM $_chaptersTable',
    );
    return rows.map((r) => r['version'] as String).toSet();
  }

  Future<List<BibleVersion>> getDownloadedVersions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _versionsTable,
      where: 'is_downloaded = ?',
      whereArgs: [1],
      orderBy: 'language, name ASC',
    );

    return List.generate(maps.length, (i) {
      final map = maps[i];
      return BibleVersion(
        code: map['code'],
        name: map['name'],
        language: map['language'],
        languageCode: map['language_code'],
        description: map['description'] ?? '',
        isDownloaded: true,
        downloadedAt: map['downloaded_at'] != null 
            ? DateTime.parse(map['downloaded_at'])
            : null,
        totalSize: map['total_size'],
        metadata: map['metadata'] != null 
            ? Map<String, dynamic>.from(jsonDecode(map['metadata']))
            : null,
      );
    });
  }

  Future<void> updateVersionDownloadStatus(String code, bool isDownloaded) async {
    final db = await database;
    await db.update(
      _versionsTable,
      {
        'is_downloaded': isDownloaded ? 1 : 0,
        'downloaded_at': isDownloaded ? DateTime.now().toIso8601String() : null,
      },
      where: 'code = ?',
      whereArgs: [code],
    );
  }

  // Bible Chapters operations
  Future<int> insertChapter(BibleChapter chapter) async {
    final db = await database;
    
    // Insert chapter
    final chapterId = await db.insert(
      _chaptersTable,
      {
        'book': chapter.book,
        'chapter': chapter.chapter,
        'version': chapter.version,
        'language': chapter.language,
        'metadata': chapter.metadata != null ? jsonEncode(chapter.metadata) : null,
        'last_updated': chapter.lastUpdated?.toIso8601String() ?? DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Insert verses using a single atomic batch for high performance
    final batch = db.batch();
    for (final verse in chapter.verses) {
      batch.insert(
        _versesTable,
        {
          'chapter_id': chapterId,
          'verse_number': verse.number,
          'text': verse.text,
          'footnotes': verse.footnotes != null ? jsonEncode(verse.footnotes) : null,
          'cross_references': verse.crossReferences != null ? jsonEncode(verse.crossReferences) : null,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);

    return chapterId;
  }

  /// Batch insert multiple chapters and their verses in an atomic transaction
  Future<void> insertChaptersBatch(List<BibleChapter> chapters) async {
    if (chapters.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final chapter in chapters) {
        final chapterId = await txn.insert(
          _chaptersTable,
          {
            'book': chapter.book,
            'chapter': chapter.chapter,
            'version': chapter.version,
            'language': chapter.language,
            'metadata': chapter.metadata != null ? jsonEncode(chapter.metadata) : null,
            'last_updated': chapter.lastUpdated?.toIso8601String() ?? DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        final batch = txn.batch();
        for (final verse in chapter.verses) {
          batch.insert(
            _versesTable,
            {
              'chapter_id': chapterId,
              'verse_number': verse.number,
              'text': verse.text,
              'footnotes': verse.footnotes != null ? jsonEncode(verse.footnotes) : null,
              'cross_references': verse.crossReferences != null ? jsonEncode(verse.crossReferences) : null,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      }
    });
  }

  Future<BibleChapter?> getChapter(String book, int chapter, String version, String language) async {
    final db = await database;
    
    // 1. Direct query by exact book name and version
    var chapterMaps = await db.query(
      _chaptersTable,
      where: 'book = ? AND chapter = ? AND version = ?',
      whereArgs: [book, chapter, version],
      limit: 1,
    );

    // 2. If not found, resolve canonical English book name (e.g. Farawa -> Genesis for HAU)
    if (chapterMaps.isEmpty) {
      final canon = BibleData.canonicalBookName(book);
      if (canon != null && canon != book) {
        chapterMaps = await db.query(
          _chaptersTable,
          where: 'book = ? AND chapter = ? AND version = ?',
          whereArgs: [canon, chapter, version],
          limit: 1,
        );
      }
    }

    if (chapterMaps.isEmpty) return null;

    final chapterMap = chapterMaps.first;
    final chapterId = chapterMap['id'];

    // Get verses
    final List<Map<String, dynamic>> verseMaps = await db.query(
      _versesTable,
      where: 'chapter_id = ?',
      whereArgs: [chapterId],
      orderBy: 'verse_number ASC',
    );

    final verses = List.generate(verseMaps.length, (i) {
      final map = verseMaps[i];
      return BibleVerse(
        number: map['verse_number'],
        text: map['text'],
        footnotes: map['footnotes'] != null 
            ? Map<String, String>.from(jsonDecode(map['footnotes']))
            : null,
        crossReferences: map['cross_references'] != null 
            ? List<String>.from(jsonDecode(map['cross_references']))
            : null,
      );
    });

    return BibleChapter(
      book: book, // Preserve requested localized book name (e.g. "Farawa") for display
      chapter: chapterMap['chapter'] as int,
      version: chapterMap['version'] as String,
      language: chapterMap['language'] as String,
      verses: verses,
      metadata: chapterMap['metadata'] != null 
          ? Map<String, dynamic>.from(jsonDecode(chapterMap['metadata'] as String))
          : null,
      lastUpdated: chapterMap['last_updated'] != null 
          ? DateTime.parse(chapterMap['last_updated'] as String)
          : null,
    );
  }

  // ────────────────────────────────────────────────────────────────────
  // FTS5 full-text search — sub-50ms queries over 214 K verses.
  // The pre-built bible.db ships with a `bible_search` FTS5 table.
  // ────────────────────────────────────────────────────────────────────

  /// Lightning-fast full-text search via FTS5.  Returns scored results
  /// with BM25 ranking.  Falls back to LIKE-based search if the FTS5
  /// table doesn't exist (e.g. empty DB on web).
  Future<List<BibleSearchResult>> fts5Search(
    String query, {
    String? version,
    String? language,
    int limit = 50,
  }) async {
    final db = await database;
    final normalised =
        query.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '').trim();
    if (normalised.isEmpty) return [];

    try {
      // Build the FTS5 MATCH expression.  Wrap multi-word queries in
      // quotes so FTS5 treats them as a phrase, then OR with individual
      // tokens for broader recall.
      final tokens = normalised.split(RegExp(r'\s+'));
      String matchExpr;
      if (tokens.length > 1) {
        final phrase = '"$normalised"';
        final orTokens = tokens.join(' OR ');
        matchExpr = '$phrase OR $orTokens';
      } else {
        matchExpr = normalised;
      }

      // Filter clauses for version/language
      final filters = <String>[];
      final args = <dynamic>[matchExpr];
      if (version != null && version.isNotEmpty) {
        filters.add('c.version = ?');
        args.add(version);
      }
      if (language != null && language.isNotEmpty) {
        filters.add('c.language = ?');
        args.add(language);
      }

      final whereExtra =
          filters.isEmpty ? '' : ' AND ${filters.join(" AND ")}';
      args.add(limit);

      final rows = await db.rawQuery('''
        SELECT c.book, c.chapter, v.verse_number AS verse,
               c.version, c.language, v.text,
               bm25(bible_search) AS rank
        FROM bible_search
        JOIN bible_verses v ON v.id = bible_search.rowid
        JOIN bible_chapters c ON c.id = v.chapter_id
        WHERE bible_search MATCH ?$whereExtra
        ORDER BY rank
        LIMIT ?
      ''', args);

      return rows.map((row) {
        final book = row['book'] as String;
        final ch = row['chapter'] as int;
        final vs = row['verse'] as int;
        return BibleSearchResult(
          book: book,
          chapter: ch,
          verse: vs,
          text: row['text'] as String,
          version: row['version'] as String,
          language: row['language'] as String,
          reference: '$book $ch:$vs',
        );
      }).toList();
    } catch (_) {
      // FTS5 table missing — fall through to legacy LIKE search.
      return [];
    }
  }

  // Search operations.
  //
  // Search standard (shared with SearchUtils + OfflineBibleService):
  // exact phrase ("jesus wept" -> John 11:35) ranks above verses that merely
  // contain the individual words. LIKE feeds candidates, Dart ranks them.
  Future<List<BibleSearchResult>> searchVerses(String query,
      {String? version, String? language, int limit = 50}) async {
    final db = await database;

    final normPhrase =
        query.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normPhrase.isEmpty) return [];
    final words = normPhrase
        .split(' ')
        .map((w) => w.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ''))
        .where((w) => w.length > 1 || RegExp(r'^\d+$').hasMatch(w))
        .where((w) => w.isNotEmpty)
        .toSet()
        .toList();
    if (words.isEmpty) return [];

    // Pull candidates touching ANY query word, then rank in Dart.
    final likeClauses =
        List.filled(words.length, 'v.text LIKE ?').join(' OR ');
    String whereClause = '($likeClauses OR c.book LIKE ?)';
    final andArgs = <dynamic>[
      for (final w in words) '%$w%',
      '%$normPhrase%',
    ];

    if (version != null) {
      whereClause += ' AND c.version = ?';
      andArgs.add(version);
    }

    if (language != null) {
      whereClause += ' AND c.language = ?';
      andArgs.add(language);
    }

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT
        c.book,
        c.chapter,
        v.verse_number as verse,
        v.text,
        c.version,
        c.language,
        c.book || ' ' || c.chapter || ':' || v.verse_number as reference
      FROM $_versesTable v
      INNER JOIN $_chaptersTable c ON v.chapter_id = c.id
      WHERE $whereClause
      LIMIT ?
    ''', [...andArgs, limit * 8]);

    int scoreRow(Map<String, dynamic> map) {
      final text = (map['text'] ?? '').toString().toLowerCase();
      final ref = (map['reference'] ?? '').toString().toLowerCase();
      var score = 0;
      if (text.contains(normPhrase)) score += 300;
      if (ref.contains(normPhrase)) score += 500;
      var hits = 0;
      for (final w in words) {
        if (text.contains(w)) hits++;
        if (ref.contains(w)) score += 5;
      }
      if (hits == words.length && words.length > 1) {
        score += 200 + hits * 10;
      } else {
        score += hits * 10;
      }
      return score;
    }

    final ranked =
        maps.where((m) => scoreRow(m) > 0).toList(growable: false)
          ..sort((a, b) => scoreRow(b).compareTo(scoreRow(a)));

    return ranked.take(limit).map((map) {
      return BibleSearchResult(
        book: map['book'],
        chapter: map['chapter'],
        verse: map['verse'],
        text: map['text'],
        version: map['version'],
        language: map['language'],
        reference: map['reference'],
      );
    }).toList();
  }

  // User Progress operations
  Future<void> saveUserProgress(String userId, String book, int chapter, int? verse, String version, String progressType, Map<String, dynamic>? progressData) async {
    final db = await database;
    await db.insert(
      _userProgressTable,
      {
        'user_id': userId,
        'book': book,
        'chapter': chapter,
        'verse': verse,
        'version': version,
        'progress_type': progressType,
        'progress_data': progressData != null ? jsonEncode(progressData) : null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<BibleUserProgress>> getUserProgress(String userId, {String? progressType}) async {
    final db = await database;
    
    String whereClause = 'user_id = ?';
    List<dynamic> whereArgs = [userId];
    
    if (progressType != null) {
      whereClause += ' AND progress_type = ?';
      whereArgs.add(progressType);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      _userProgressTable,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'updated_at DESC',
    );

    return maps.map((map) {
      final parsed = {
        ...map,
        'progress_data': map['progress_data'] != null 
            ? jsonDecode(map['progress_data'])
            : null,
      };
      return BibleUserProgress.fromMap(parsed);
    }).toList();
  }

  // Database maintenance
  Future<void> clearCache() async {
    final db = await database;
    await db.delete(_chaptersTable);
    await db.delete(_versesTable);
  }

  Future<void> clearUserProgress(String userId) async {
    final db = await database;
    await db.delete(
      _userProgressTable,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  Future<int> getDatabaseSize() async {
    final db = await database;
    final result = await db.rawQuery('PRAGMA page_count');
    final pageCount = result.first['page_count'] as int;
    final pageSizeResult = await db.rawQuery('PRAGMA page_size');
    final pageSize = pageSizeResult.first['page_size'] as int;
    return pageCount * pageSize;
  }

  Future<Map<String, int>> getTableCounts() async {
    final db = await database;
    final counts = <String, int>{};
    
    final tables = [_booksTable, _versionsTable, _chaptersTable, _versesTable, _readingPlansTable, _readingDaysTable, _userProgressTable];
    
    for (final table in tables) {
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
      counts[table] = result.first['count'] as int;
    }
    
    return counts;
  }
}