import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/bible_models.dart';

class BibleDatabaseHelper {
  static final BibleDatabaseHelper _instance = BibleDatabaseHelper._internal();
  factory BibleDatabaseHelper() => _instance;
  BibleDatabaseHelper._internal();

  static Database? _database;
  static const String _databaseName = 'bible_offline.db';
  static const int _databaseVersion = 1;

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
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
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
    await db.execute('CREATE INDEX idx_verses_text ON $_versesTable (text)');
    await db.execute('CREATE INDEX idx_progress_user ON $_userProgressTable (user_id)');
    await db.execute('CREATE INDEX idx_progress_book ON $_userProgressTable (book, chapter)');

    // Insert default Bible books
    await _insertDefaultBooks(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here
    if (oldVersion < newVersion) {
      // Add migration logic as needed
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

    // Insert verses
    for (final verse in chapter.verses) {
      await db.insert(
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

    return chapterId;
  }

  Future<BibleChapter?> getChapter(String book, int chapter, String version, String language) async {
    final db = await database;
    
    // Get chapter info
    final List<Map<String, dynamic>> chapterMaps = await db.query(
      _chaptersTable,
      where: 'book = ? AND chapter = ? AND version = ? AND language = ?',
      whereArgs: [book, chapter, version, language],
      limit: 1,
    );

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
      book: chapterMap['book'],
      chapter: chapterMap['chapter'],
      version: chapterMap['version'],
      language: chapterMap['language'],
      verses: verses,
      metadata: chapterMap['metadata'] != null 
          ? Map<String, dynamic>.from(jsonDecode(chapterMap['metadata']))
          : null,
      lastUpdated: chapterMap['last_updated'] != null 
          ? DateTime.parse(chapterMap['last_updated'])
          : null,
    );
  }

  // Search operations
  Future<List<BibleSearchResult>> searchVerses(String query, {String? version, String? language, int limit = 50}) async {
    final db = await database;
    
    String whereClause = 'v.text LIKE ?';
    List<dynamic> whereArgs = ['%$query%'];
    
    if (version != null) {
      whereClause += ' AND c.version = ?';
      whereArgs.add(version);
    }
    
    if (language != null) {
      whereClause += ' AND c.language = ?';
      whereArgs.add(language);
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
      ORDER BY c.book, c.chapter, v.verse_number
      LIMIT ?
    ''', [...whereArgs, limit]);

    return List.generate(maps.length, (i) {
      final map = maps[i];
      return BibleSearchResult(
        book: map['book'],
        chapter: map['chapter'],
        verse: map['verse'],
        text: map['text'],
        version: map['version'],
        language: map['language'],
        reference: map['reference'],
      );
    });
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

  Future<List<Map<String, dynamic>>> getUserProgress(String userId, {String? progressType}) async {
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

    return maps.map((map) => {
      ...map,
      'progress_data': map['progress_data'] != null 
          ? jsonDecode(map['progress_data'])
          : null,
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