import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/tract_models.dart';

class TractDatabaseHelper {
  static final TractDatabaseHelper _instance = TractDatabaseHelper._internal();
  factory TractDatabaseHelper() => _instance;
  TractDatabaseHelper._internal();

  static Database? _database;
  static const String _databaseName = 'tracts.db';
  static const int _databaseVersion = 1;

  // Table names
  static const String _tractsTable = 'tracts';
  static const String _tractContentsTable = 'tract_contents';
  static const String _tractQuestionsTable = 'tract_questions';
  static const String _userAnswersTable = 'user_tract_answers';
  static const String _tractCategoriesTable = 'tract_categories';
  static const String _tractProgressTable = 'tract_progress';

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
    // Create tracts table
    await db.execute('''
      CREATE TABLE $_tractsTable (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        pdfUrl TEXT NOT NULL,
        localPdfPath TEXT,
        imageUrl TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isDownloaded INTEGER NOT NULL DEFAULT 0,
        orderIndex INTEGER NOT NULL DEFAULT 0,
        language TEXT NOT NULL DEFAULT 'en'
      )
    ''');

    // Create tract contents table
    await db.execute('''
      CREATE TABLE $_tractContentsTable (
        id TEXT PRIMARY KEY,
        tractId TEXT NOT NULL,
        content TEXT NOT NULL,
        metadata TEXT,
        FOREIGN KEY (tractId) REFERENCES $_tractsTable (id) ON DELETE CASCADE
      )
    ''');

    // Create tract questions table
    await db.execute('''
      CREATE TABLE $_tractQuestionsTable (
        id TEXT PRIMARY KEY,
        tractId TEXT NOT NULL,
        question TEXT NOT NULL,
        type TEXT NOT NULL,
        options TEXT,
        correctAnswer TEXT,
        orderIndex INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (tractId) REFERENCES $_tractsTable (id) ON DELETE CASCADE
      )
    ''');

    // Create user answers table
    await db.execute('''
      CREATE TABLE $_userAnswersTable (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        tractId TEXT NOT NULL,
        answers TEXT NOT NULL,
        completedAt TEXT NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        score INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (tractId) REFERENCES $_tractsTable (id) ON DELETE CASCADE
      )
    ''');

    // Create tract categories table
    await db.execute('''
      CREATE TABLE $_tractCategoriesTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        imageUrl TEXT,
        orderIndex INTEGER NOT NULL DEFAULT 0,
        isActive INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Create tract progress table
    await db.execute('''
      CREATE TABLE $_tractProgressTable (
        userId TEXT NOT NULL,
        tractId TEXT NOT NULL,
        currentQuestionIndex INTEGER NOT NULL DEFAULT 0,
        currentAnswers TEXT NOT NULL,
        lastUpdated TEXT NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        progressPercentage REAL NOT NULL DEFAULT 0.0,
        PRIMARY KEY (userId, tractId),
        FOREIGN KEY (tractId) REFERENCES $_tractsTable (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_tracts_category ON $_tractsTable (category)');
    await db.execute('CREATE INDEX idx_tracts_language ON $_tractsTable (language)');
    await db.execute('CREATE INDEX idx_user_answers_user ON $_userAnswersTable (userId)');
    await db.execute('CREATE INDEX idx_tract_questions_tract ON $_tractQuestionsTable (tractId)');
    await db.execute('CREATE INDEX idx_tract_progress_user ON $_tractProgressTable (userId)');

    // Insert default categories
    await _insertDefaultCategories(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here
    if (oldVersion < newVersion) {
      // Add upgrade logic as needed
    }
  }

  Future<void> _insertDefaultCategories(Database db) async {
    final defaultCategories = [
      {
        'id': 'bible_study',
        'name': 'Bible Study',
        'description': 'Comprehensive Bible study materials and lessons',
        'orderIndex': 1,
        'isActive': 1,
      },
      {
        'id': 'evangelism',
        'name': 'Evangelism',
        'description': 'Materials for sharing the Gospel and witnessing',
        'orderIndex': 2,
        'isActive': 1,
      },
      {
        'id': 'discipleship',
        'name': 'Discipleship',
        'description': 'Resources for growing in Christian faith',
        'orderIndex': 3,
        'isActive': 1,
      },
      {
        'id': 'doctrine',
        'name': 'Christian Doctrine',
        'description': 'Fundamental Christian beliefs and teachings',
        'orderIndex': 4,
        'isActive': 1,
      },
    ];

    for (final category in defaultCategories) {
      await db.insert(_tractCategoriesTable, category);
    }
  }

  // Tract operations
  Future<void> insertTract(Tract tract) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert(
      _tractsTable,
      {
        'id': tract.id,
        'title': tract.title,
        'description': tract.description,
        'category': tract.category,
        'pdfUrl': tract.pdfUrl ?? '',
        'localPdfPath': tract.localPdfPath,
        'imageUrl': tract.imageUrl,
        'createdAt': tract.createdAt?.toIso8601String() ?? now,
        'updatedAt': tract.updatedAt?.toIso8601String() ?? now,
        'isDownloaded': tract.isDownloaded ? 1 : 0,
        'orderIndex': tract.order,
        'language': tract.language,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Tract>> getAllTracts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tractsTable,
      orderBy: 'orderIndex ASC, title ASC',
    );

    return maps.map((map) => _tractFromMap(map)).toList();
  }

  Future<Tract?> getTractById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tractsTable,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return _tractFromMap(maps.first);
    }
    return null;
  }

  Future<List<Tract>> getTractsByCategory(String category) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tractsTable,
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'orderIndex ASC, title ASC',
    );

    return maps.map((map) => _tractFromMap(map)).toList();
  }

  Future<List<Tract>> searchTracts(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tractsTable,
      where: 'title LIKE ? OR description LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'orderIndex ASC, title ASC',
    );

    return maps.map((map) => _tractFromMap(map)).toList();
  }

  Future<void> updateTractPdfPath(String tractId, String localPath) async {
    final db = await database;
    await db.update(
      _tractsTable,
      {
        'localPdfPath': localPath,
        'isDownloaded': 1,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [tractId],
    );
  }

  // Tract content operations
  Future<void> insertTractContent(TractContent content) async {
    final db = await database;
    
    // Insert tract content
    await db.insert(
      _tractContentsTable,
      {
        'id': content.id,
        'tractId': content.tractId,
        'content': content.content,
        'metadata': content.metadata != null ? json.encode(content.metadata) : null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Insert questions
    for (final question in content.questions) {
      await db.insert(
        _tractQuestionsTable,
        {
          'id': question.id,
          'tractId': content.tractId,
          'question': question.question,
          'type': question.type,
          'options': question.options != null ? json.encode(question.options) : null,
          'correctAnswer': question.correctAnswer,
          'orderIndex': question.order,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<TractContent?> getTractContent(String tractId) async {
    final db = await database;
    
    // Get content
    final List<Map<String, dynamic>> contentMaps = await db.query(
      _tractContentsTable,
      where: 'tractId = ?',
      whereArgs: [tractId],
    );

    if (contentMaps.isEmpty) return null;

    final contentMap = contentMaps.first;
    
    // Get questions
    final List<Map<String, dynamic>> questionMaps = await db.query(
      _tractQuestionsTable,
      where: 'tractId = ?',
      whereArgs: [tractId],
      orderBy: 'orderIndex ASC',
    );

    final questions = questionMaps.map((map) => TractQuestion(
      id: map['id'],
      question: map['question'],
      type: map['type'],
      options: map['options'] != null ? List<String>.from(json.decode(map['options'])) : null,
      correctAnswer: map['correctAnswer'],
      order: map['orderIndex'],
    )).toList();

    return TractContent(
      id: contentMap['id'],
      tractId: contentMap['tractId'],
      content: contentMap['content'],
      questions: questions,
      metadata: contentMap['metadata'] != null ? json.decode(contentMap['metadata']) : null,
    );
  }

  // User answer operations
  Future<void> insertUserAnswer(UserTractAnswer answer) async {
    final db = await database;
    await db.insert(
      _userAnswersTable,
      {
        'id': answer.id,
        'userId': answer.userId,
        'tractId': answer.tractId,
        'answers': json.encode(answer.answers),
        'completedAt': answer.completedAt.toIso8601String(),
        'isCompleted': answer.isCompleted ? 1 : 0,
        'score': answer.score,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UserTractAnswer?> getUserAnswer(String userId, String tractId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _userAnswersTable,
      where: 'userId = ? AND tractId = ?',
      whereArgs: [userId, tractId],
    );

    if (maps.isNotEmpty) {
      final map = maps.first;
      return UserTractAnswer(
        id: map['id'],
        userId: map['userId'],
        tractId: map['tractId'],
        answers: Map<String, String>.from(json.decode(map['answers'])),
        completedAt: DateTime.parse(map['completedAt']),
        isCompleted: map['isCompleted'] == 1,
        score: map['score'],
      );
    }
    return null;
  }

  Future<List<UserTractAnswer>> getUserProgress(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _userAnswersTable,
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'completedAt DESC',
    );

    return maps.map((map) => UserTractAnswer(
      id: map['id'],
      userId: map['userId'],
      tractId: map['tractId'],
      answers: Map<String, String>.from(json.decode(map['answers'])),
      completedAt: DateTime.parse(map['completedAt']),
      isCompleted: map['isCompleted'] == 1,
      score: map['score'],
    )).toList();
  }

  // Utility methods
  Future<int> getDatabaseSize() async {
    final db = await database;
    try {
      // Compute size using SQLite PRAGMA values to avoid filesystem access (web-safe)
      final pageCountResult = await db.rawQuery('PRAGMA page_count');
      final pageSizeResult = await db.rawQuery('PRAGMA page_size');
  
      final pageCount = (pageCountResult.first.values.first as int?) ?? 0;
      final pageSize = (pageSizeResult.first.values.first as int?) ?? 0;
      return pageCount * pageSize;
    } catch (e) {
      // Fallback for platforms where PRAGMA may not be supported; return 0
      return 0;
    }
  }

  Future<void> clearCache() async {
    final db = await database;
    await db.delete(_userAnswersTable);
    await db.delete(_tractQuestionsTable);
    await db.delete(_tractContentsTable);
    await db.delete(_tractsTable);
    await db.delete(_tractProgressTable);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  // Helper methods
  Tract _tractFromMap(Map<String, dynamic> map) {
    return Tract(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      category: map['category'] as String,
      pdfUrl: map['pdfUrl'] as String?,
      localPdfPath: map['localPdfPath'] as String?,
      imageUrl: map['imageUrl'] as String?,
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt'] as String) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt'] as String) : null,
      isDownloaded: (map['isDownloaded'] as int? ?? 0) == 1,
      order: map['orderIndex'] as int? ?? 0,
      language: map['language'] as String? ?? 'en',
    );
  }
}