import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import 'auth_service.dart';
import '../models/tract_models.dart';
import 'tract_database_helper.dart';
import 'appwrite_storage_compat_service.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';

class TractService {
  static final TractService _instance = TractService._internal();
  factory TractService() => _instance;
  TractService._internal();

  static final Logger _logger = Logger('TractService');

  final AuthService _authService = AuthService.instance;
  final TractDatabaseHelper _dbHelper = TractDatabaseHelper();
  final TablesDB _tables = TablesDB(appwriteClient);
  final AppwriteStorageCompatService _storageService =
      AppwriteStorageCompatService();

  static const String _cacheKey = 'tract_cache';
  static const String _lastUpdateKey = 'tract_last_update';

  static const String _remoteTractPath =
      AppwriteStorageCompatService.tractsPath;

  // What the Bible Says series lessons (1-11)
  static const List<String> _bibleSaysLessons = [
    'Lesson 1: What the Bible Says, Something We can Trust',
    'Lesson 2: What the Bible Says, Searching the Scriptures!',
    'Lesson 3: What the Bible Says, Making Bible Study Insightful',
    'Lesson 4: What the Bible Says, Power in The Word!',
    'Lesson 5: What the Bible Says, The Life - Giving Word!',
    'Lesson 6: What the Bible Says, The Origin of Sin!',
    'Lesson 7: What the Bible Says, God/s Moral Law!',
    'Lesson 8: What the Bible Says, God/s Eternal Rest Sign!',
    'Lesson 9: What the Bible Says, The World/s Biggest Lie!',
    'Lesson 10: What the Bible Says, He Promised to Come!',
    'Lesson 11: What the Bible Says, Beyound the Dark!',
  ];

  // Get all available tracts
  Future<List<Tract>> getAllTracts() async {
    try {
      // Try to get from local database first
      final localTracts = await _dbHelper.getAllTracts();
      if (localTracts.isNotEmpty) {
        return localTracts;
      }

      // If not in local database, fetch from Appwrite.
      final remoteTracts = await _fetchTractsFromAppwrite();
      if (remoteTracts.isNotEmpty) {
        // Cache in local database
        for (final tract in remoteTracts) {
          await _dbHelper.insertTract(tract);
        }
        return remoteTracts;
      }

      // Return default tracts if nothing found
      return _getDefaultTracts();
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error getting tracts', e);
      throw DatabaseException('Failed to fetch tracts', originalError: e);
    }
  }

  // Get tract by ID
  Future<Tract?> getTractById(String tractId) async {
    try {
      // Try local database first
      final localTract = await _dbHelper.getTractById(tractId);
      if (localTract != null) {
        return localTract;
      }

      // Fetch from Appwrite if not found locally.
      final remoteTract = await _fetchTractFromAppwrite(tractId);
      if (remoteTract != null) {
        await _dbHelper.insertTract(remoteTract);
        return remoteTract;
      }

      throw NotFoundException('Tract not found');
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error getting tract by ID', e);
      throw DatabaseException('Failed to get tract by ID', originalError: e);
    }
  }

  // Get tract content with questions and answers
  Future<TractContent?> getTractContent(String tractId) async {
    try {
      // Try local database first
      final localContent = await _dbHelper.getTractContent(tractId);
      if (localContent != null) {
        return localContent;
      }

      // Fetch from Appwrite if not found locally.
      final remoteContent = await _fetchTractContentFromAppwrite(tractId);
      if (remoteContent != null) {
        await _dbHelper.insertTractContent(remoteContent);
        return remoteContent;
      }

      throw NotFoundException('Tract content not found');
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error getting tract content', e);
      throw DatabaseException('Failed to get tract content', originalError: e);
    }
  }

  // Save user answers for a tract
  Future<bool> saveUserAnswers(
      String userId, String tractId, Map<String, String> answers) async {
    try {
      final userAnswer = UserTractAnswer(
        id: '${userId}_$tractId',
        userId: userId,
        tractId: tractId,
        answers: answers,
        completedAt: DateTime.now(),
        isCompleted: true,
        score: _calculateScore(answers),
      );

      // Save to local database
      await _dbHelper.insertUserAnswer(userAnswer);

      // Sync to Appwrite.
      await _syncUserAnswerToAppwrite(userAnswer);

      return true;
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error saving user answers', e);
      throw DatabaseException('Failed to save user answers', originalError: e);
    }
  }

  // Get user answers for a tract
  Future<UserTractAnswer?> getUserAnswers(String userId, String tractId) async {
    try {
      return await _dbHelper.getUserAnswer(userId, tractId);
    } catch (e) {
      _logger.error('Error getting user answers', e);
      throw DatabaseException('Failed to get user answers', originalError: e);
    }
  }

  // Get user progress for all tracts
  Future<List<UserTractAnswer>> getUserProgress(String userId) async {
    try {
      return await _dbHelper.getUserProgress(userId);
    } catch (e) {
      _logger.error('Error getting user progress', e);
      throw DatabaseException('Failed to get user progress', originalError: e);
    }
  }

  /// Get detailed progress for a specific tract using [TractProgress] model.
  Future<TractProgress?> getTractProgress(String userId, String tractId) async {
    try {
      final row = await _tables.getRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: 'tract_progress',
        rowId: '${userId}_$tractId',
      );
      return TractProgress.fromJson({
        'id': row.$id,
        'userId': row.data['user_id'] ?? userId,
        'tractId': row.data['tract_id'] ?? tractId,
        'currentPage': row.data['current_page'] ?? 0,
        'isCompleted': row.data['is_completed'] ?? false,
        'lastUpdated':
            row.data['last_updated'] ?? DateTime.now().toIso8601String(),
      });
    } on AppwriteException catch (e) {
      if (e.code != 404) {
        _logger.error('Error getting tract progress', e);
        throw DatabaseException('Failed to get tract progress',
            originalError: e);
      }

      // Build from local answers if no Appwrite progress doc exists.
      final answer = await _dbHelper.getUserAnswer(userId, tractId);
      if (answer != null) {
        return TractProgress(
          id: '${userId}_$tractId',
          userId: userId,
          tractId: tractId,
          currentPage: 0,
          lastUpdated: answer.completedAt,
          isCompleted: answer.isCompleted,
        );
      }
      return null;
    } catch (e) {
      _logger.error('Error getting tract progress', e);
      throw DatabaseException('Failed to get tract progress', originalError: e);
    }
  }

  /// Save in-progress tract progress using [TractProgress] model.
  Future<void> saveTractProgress(TractProgress progress) async {
    try {
      final payload = {
        'user_id': progress.userId,
        'tract_id': progress.tractId,
        'current_page': progress.currentPage,
        'is_completed': progress.isCompleted,
        'last_updated': progress.lastUpdated.toUtc().toIso8601String(),
      };
      final docId = '${progress.userId}_${progress.tractId}';
      try {
        await _tables.updateRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: 'tract_progress',
          rowId: docId,
          data: payload,
        );
      } on AppwriteException catch (e) {
        if (e.code != 404) rethrow;
        await _tables.createRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: 'tract_progress',
          rowId: docId,
          data: payload,
        );
      }
    } catch (e) {
      _logger.error('Error saving tract progress', e);
      throw DatabaseException('Failed to save tract progress',
          originalError: e);
    }
  }

  /// Get aggregated statistics for a tract using [TractStatistics] model.
  Future<TractStatistics> getTractStatistics(String tractId) async {
    try {
      final answersSnapshot = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: 'user_tract_answers',
        queries: [
          Query.equal('tract_id', tractId),
          Query.limit(200),
        ],
      );

      int totalCompletions = 0;
      final questionStats = <String, int>{};

      for (final row in answersSnapshot.rows) {
        final data = row.data;
        if (data['is_completed'] == true) {
          totalCompletions++;
          final answers = _decodeMap(data['answers']) ?? {};
          for (final qId in answers.keys) {
            questionStats[qId] = (questionStats[qId] ?? 0) + 1;
          }
        }
      }

      // Get download count from tract metadata
      var totalDownloads = 0;
      try {
        final tractRow = await _tables.getRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: 'tracts',
          rowId: tractId,
        );
        totalDownloads = _intValue(
            tractRow.data['downloadCount'] ?? tractRow.data['downloads']);
      } catch (_) {}

      return TractStatistics(
        totalTracts: totalCompletions,
        activeReaders: 0,
        totalDownloads: totalDownloads,
        categoryDistribution: {},
      );
    } catch (e) {
      _logger.error('Error getting tract statistics', e);
      throw DatabaseException('Failed to get tract statistics',
          originalError: e);
    }
  }

  // Download tract PDF for offline use
  Future<String?> downloadTractPDF(String tractId, String pdfUrl) async {
    try {
      final tract = await getTractById(tractId);
      // getTractById throws NotFoundException if null

      // For "What the Bible Says" series, use the lesson number to get the PDF
      if (tract!.category == 'Bible Study') {
        final lessonMatch = RegExp(r'Lesson (\d+)').firstMatch(tract.title);
        if (lessonMatch != null) {
          final lessonNumber = int.parse(lessonMatch.group(1)!);
          final fileName = 'lesson_$lessonNumber.pdf';
          // On web, return the Appwrite Storage download URL.
          final url = await _storageService.downloadTractPDF(fileName);
          if (url != null) {
            await _dbHelper.updateTractPdfPath(tractId, url);
          }
          return url;
        }
      }

      // For other tracts, use the PDF URL directly (store URL instead of downloading to local filesystem)
      if (pdfUrl.isNotEmpty) {
        await _dbHelper.updateTractPdfPath(tractId, pdfUrl);
        return pdfUrl;
      }

      return null;
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error downloading tract PDF', e);
      throw DatabaseException('Failed to download tract PDF', originalError: e);
    }
  }

  // Search tracts by title or content
  Future<List<Tract>> searchTracts(String query) async {
    try {
      return await _dbHelper.searchTracts(query);
    } catch (e) {
      _logger.error('Error searching tracts', e);
      throw DatabaseException('Failed to search tracts', originalError: e);
    }
  }

  // Get tracts by category
  Future<List<Tract>> getTractsByCategory(String category) async {
    try {
      return await _dbHelper.getTractsByCategory(category);
    } catch (e) {
      _logger.error('Error getting tracts by category', e);
      throw DatabaseException('Failed to get tracts by category',
          originalError: e);
    }
  }

  Future<void> syncWithAppwrite() async {
    try {
      // Load What the Bible Says tracts from Appwrite Storage.
      await _loadWhatTheBibleSaysTracts();

      // Fetch latest tracts from Appwrite.
      final remoteTracts = await _fetchTractsFromAppwrite();

      // Update local database
      for (final tract in remoteTracts) {
        await _dbHelper.insertTract(tract);
      }

      // Sync user answers to Appwrite.
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        final userAnswers = await _dbHelper.getUserProgress(currentUser.uid);
        for (final answer in userAnswers) {
          await _syncUserAnswerToAppwrite(answer);
        }
      }

      // Update last sync time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error syncing with Appwrite', e);
      throw DatabaseException('Failed to sync with Appwrite', originalError: e);
    }
  }

  // Private helper methods

  Future<List<Tract>> _fetchTractsFromAppwrite() async {
    try {
      final querySnapshot = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: 'tracts',
        queries: [
          Query.orderAsc('order'),
          Query.limit(200),
        ],
      );
      return querySnapshot.rows.map((row) {
        return Tract.fromDocument(row.data, row.$id);
      }).toList();
    } catch (e) {
      _logger.error('Error fetching tracts from Appwrite', e);
      return [];
    }
  }

  Future<Tract?> _fetchTractFromAppwrite(String tractId) async {
    try {
      final row = await _tables.getRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: 'tracts',
        rowId: tractId,
      );
      return Tract.fromDocument(row.data, row.$id);
    } on AppwriteException catch (e) {
      if (e.code == 404) return null;
      _logger.error('Error fetching tract from Appwrite', e);
      return null;
    } catch (e) {
      _logger.error('Error fetching tract from Appwrite', e);
      return null;
    }
  }

  Future<TractContent?> _fetchTractContentFromAppwrite(String tractId) async {
    try {
      final row = await _tables.getRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: 'tract_contents',
        rowId: tractId,
      );
      final data = row.data;
      return TractContent(
        id: row.$id,
        tractId: tractId,
        content: data['content']?.toString() ?? '',
        questions: _decodeQuestions(data['questions']),
        metadata: _decodeMap(data['metadata']),
      );
    } on AppwriteException catch (e) {
      if (e.code == 404) return null;
      _logger.error('Error fetching tract content from Appwrite', e);
      return null;
    } catch (e) {
      _logger.error('Error fetching tract content from Appwrite', e);
      return null;
    }
  }

  Future<void> _syncUserAnswerToAppwrite(UserTractAnswer answer) async {
    try {
      final payload = {
        'user_id': answer.userId,
        'tract_id': answer.tractId,
        'answers': jsonEncode(answer.answers),
        'completed_at': answer.completedAt.toUtc().toIso8601String(),
        'is_completed': answer.isCompleted,
        'score': answer.score,
      };
      try {
        await _tables.updateRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: 'user_tract_answers',
          rowId: answer.id,
          data: payload,
        );
      } on AppwriteException catch (e) {
        if (e.code != 404) rethrow;
        await _tables.createRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: 'user_tract_answers',
          rowId: answer.id,
          data: payload,
        );
      }
    } catch (e) {
      _logger.error('Error syncing user answer to Appwrite', e);
    }
  }

  List<TractQuestion> _decodeQuestions(dynamic value) {
    if (value == null) return [];
    final rawQuestions = value is String ? jsonDecode(value) : value;
    if (rawQuestions is! List) return [];
    return rawQuestions.map((raw) {
      final question = raw is Map<String, dynamic>
          ? raw
          : Map<String, dynamic>.from(raw as Map);
      return TractQuestion(
        id: question['id']?.toString() ?? '',
        question: question['question']?.toString() ?? '',
        type: question['type']?.toString() ?? 'text',
        options: question['options'] is List
            ? List<String>.from(question['options'] as List)
            : null,
        correctAnswer: question['correctAnswer']?.toString() ??
            question['correct_answer']?.toString(),
        order: _intValue(question['order']),
      );
    }).toList();
  }

  Map<String, dynamic>? _decodeMap(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.trim().isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    return null;
  }

  int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _calculateScore(Map<String, String> answers) {
    // Simple scoring logic - can be enhanced based on correct answers
    return answers.length * 10; // 10 points per answered question
  }

  List<Tract> _getDefaultTracts() {
    return _bibleSaysLessons.asMap().entries.map((entry) {
      final index = entry.key;
      final title = entry.value;
      return Tract(
        id: 'bible_says_${index + 1}',
        title: title,
        description:
            'Bible study lesson ${index + 1} from the "What the Bible Says" series',
        category: 'Bible Study',
        pdfUrl: '$_remoteTractPath/bible_says_lesson_${index + 1}.pdf',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isDownloaded: false,
        order: index + 1,
        language: 'en',
      );
    }).toList();
  }

  // Load "What the Bible Says" tracts from Appwrite Storage.
  Future<void> _loadWhatTheBibleSaysTracts() async {
    try {
      final lessons = await _storageService.getWhatTheBibleSaysLessons();

      for (final entry in lessons.entries) {
        final lessonNumber = entry.key;
        final downloadUrl = entry.value;
        final tractId = 'bible_says_$lessonNumber';

        // Update the tract with the PDF URL
        final existingTract = await _dbHelper.getTractById(tractId);
        if (existingTract != null) {
          final updatedTract = Tract(
            id: existingTract.id,
            title: existingTract.title,
            description: existingTract.description,
            category: existingTract.category,
            pdfUrl: downloadUrl,
            localPdfPath: existingTract.localPdfPath,
            imageUrl: existingTract.imageUrl,
            createdAt: existingTract.createdAt,
            updatedAt: DateTime.now(),
            isDownloaded: existingTract.isDownloaded,
            order: existingTract.order,
            language: existingTract.language,
          );

          await _dbHelper.insertTract(updatedTract);
        }
      }
    } catch (e) {
      _logger.error('Error loading What the Bible Says tracts', e);
    }
  }

  // Clear all cached tract data
  Future<void> clearCache() async {
    try {
      await _dbHelper.clearCache();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_lastUpdateKey);
      _logger.info('Tract cache cleared');
    } catch (e) {
      _logger.error('Error clearing tract cache', e);
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
}
