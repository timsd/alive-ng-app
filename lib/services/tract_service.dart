import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import '../models/tract_models.dart';
import 'tract_database_helper.dart';
import 'firebase_storage_service.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';

class TractService {
  static final TractService _instance = TractService._internal();
  factory TractService() => _instance;
  TractService._internal();

  static final Logger _logger = Logger('TractService');

  final AuthService _authService = AuthService.instance;
  final TractDatabaseHelper _dbHelper = TractDatabaseHelper();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorageService _storageService = FirebaseStorageService();

  static const String _cacheKey = 'tract_cache';
  static const String _lastUpdateKey = 'tract_last_update';

  // Firebase Storage path for tracts
  static const String _firebaseStoragePath =
      'gs://alive-ng-flutter-app.firebasestorage.app/Tracts';

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

      // If not in local database, fetch from Firebase
      final firebaseTracts = await _fetchTractsFromFirebase();
      if (firebaseTracts.isNotEmpty) {
        // Cache in local database
        for (final tract in firebaseTracts) {
          await _dbHelper.insertTract(tract);
        }
        return firebaseTracts;
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

      // Fetch from Firebase if not found locally
      final firebaseTract = await _fetchTractFromFirebase(tractId);
      if (firebaseTract != null) {
        await _dbHelper.insertTract(firebaseTract);
        return firebaseTract;
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

      // Fetch from Firebase if not found locally
      final firebaseContent = await _fetchTractContentFromFirebase(tractId);
      if (firebaseContent != null) {
        await _dbHelper.insertTractContent(firebaseContent);
        return firebaseContent;
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

      // Sync to Firebase
      await _syncUserAnswerToFirebase(userAnswer);

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
      final doc = await _firestore
          .collection('user_tract_progress')
          .doc('${userId}_$tractId')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        data['userId'] = userId;
        data['tractId'] = tractId;
        return TractProgress.fromJson(data);
      }

      // Build from local answers if no Firestore progress doc exists
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
      throw DatabaseException('Failed to get tract progress',
          originalError: e);
    }
  }

  /// Save in-progress tract progress using [TractProgress] model.
  Future<void> saveTractProgress(TractProgress progress) async {
    try {
      await _firestore
          .collection('user_tract_progress')
          .doc('${progress.userId}_${progress.tractId}')
          .set(progress.toJson());
    } catch (e) {
      _logger.error('Error saving tract progress', e);
      throw DatabaseException('Failed to save tract progress',
          originalError: e);
    }
  }

  /// Get aggregated statistics for a tract using [TractStatistics] model.
  Future<TractStatistics> getTractStatistics(String tractId) async {
    try {
      final answersSnapshot = await _firestore
          .collection('user_tract_answers')
          .where('tractId', isEqualTo: tractId)
          .get();

      int totalCompletions = 0;
      final questionStats = <String, int>{};

      for (final doc in answersSnapshot.docs) {
        final data = doc.data();
        if (data['isCompleted'] == true) {
          totalCompletions++;
          final answers = data['answers'] as Map<String, dynamic>? ?? {};
          for (final qId in answers.keys) {
            questionStats[qId] = (questionStats[qId] ?? 0) + 1;
          }
        }
      }

      // Get download count from tract metadata
      final tractDoc =
          await _firestore.collection('tracts').doc(tractId).get();
      final totalDownloads =
          (tractDoc.data()?['downloadCount'] as int?) ?? 0;

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
          // On web, return the download URL from Firebase Storage
          final url = await _storageService.downloadTractPDF(fileName);
          if (url != null) {
            // Store the URL in the localPdfPath field for compatibility
            await _dbHelper.updateTractPdfPath(tractId, url);
          }
          return url;
        }
      }

      // For other tracts, use the PDF URL directly (store URL instead of downloading to local filesystem)
      if (pdfUrl.isNotEmpty) {
        // Store the URL in the localPdfPath field for compatibility
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

  // Sync all tract data with Firebase
  Future<void> syncWithFirebase() async {
    try {
      // Load What the Bible Says tracts from Firebase Storage
      await _loadWhatTheBibleSaysTracts();

      // Fetch latest tracts from Firebase
      final firebaseTracts = await _fetchTractsFromFirebase();

      // Update local database
      for (final tract in firebaseTracts) {
        await _dbHelper.insertTract(tract);
      }

      // Sync user answers to Firebase
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        final userAnswers = await _dbHelper.getUserProgress(currentUser.uid);
        for (final answer in userAnswers) {
          await _syncUserAnswerToFirebase(answer);
        }
      }

      // Update last sync time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error syncing with Firebase', e);
      throw DatabaseException('Failed to sync with Firebase', originalError: e);
    }
  }

  // Private helper methods

  Future<List<Tract>> _fetchTractsFromFirebase() async {
    try {
      final querySnapshot = await _firestore.collection('tracts').get();
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Tract(
          id: doc.id,
          title: data['title'] ?? '',
          description: data['description'] ?? '',
          category: data['category'] ?? '',
          pdfUrl: data['pdfUrl'] ?? '',
          localPdfPath: data['localPdfPath'],
          imageUrl: data['imageUrl'],
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          updatedAt:
              (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          isDownloaded: data['isDownloaded'] ?? false,
          order: data['order'] ?? 0,
          language: data['language'] ?? 'en',
        );
      }).toList();
    } catch (e) {
      _logger.error('Error fetching tracts from Firebase', e);
      return [];
    }
  }

  Future<Tract?> _fetchTractFromFirebase(String tractId) async {
    try {
      final doc = await _firestore.collection('tracts').doc(tractId).get();
      if (doc.exists) {
        final data = doc.data()!;
        return Tract(
          id: doc.id,
          title: data['title'] ?? '',
          description: data['description'] ?? '',
          category: data['category'] ?? '',
          pdfUrl: data['pdfUrl'] ?? '',
          localPdfPath: data['localPdfPath'],
          imageUrl: data['imageUrl'],
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          updatedAt:
              (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          isDownloaded: data['isDownloaded'] ?? false,
          order: data['order'] ?? 0,
          language: data['language'] ?? 'en',
        );
      }
      return null;
    } catch (e) {
      _logger.error('Error fetching tract from Firebase', e);
      return null;
    }
  }

  Future<TractContent?> _fetchTractContentFromFirebase(String tractId) async {
    try {
      final doc =
          await _firestore.collection('tract_contents').doc(tractId).get();
      if (doc.exists) {
        final data = doc.data()!;
        return TractContent(
          id: doc.id,
          tractId: tractId,
          content: data['content'] ?? '',
          questions: (data['questions'] as List<dynamic>?)
                  ?.map((q) => TractQuestion(
                        id: q['id'] ?? '',
                        question: q['question'] ?? '',
                        type: q['type'] ?? 'text',
                        options: q['options']?.cast<String>(),
                        correctAnswer: q['correctAnswer'],
                        order: q['order'] ?? 0,
                      ))
                  .toList() ??
              [],
          metadata: data['metadata'],
        );
      }
      return null;
    } catch (e) {
      _logger.error('Error fetching tract content from Firebase', e);
      return null;
    }
  }

  Future<void> _syncUserAnswerToFirebase(UserTractAnswer answer) async {
    try {
      await _firestore.collection('user_tract_answers').doc(answer.id).set({
        'userId': answer.userId,
        'tractId': answer.tractId,
        'answers': answer.answers,
        'completedAt': Timestamp.fromDate(answer.completedAt),
        'isCompleted': answer.isCompleted,
        'score': answer.score,
      });
    } catch (e) {
      _logger.error('Error syncing user answer to Firebase', e);
    }
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
        pdfUrl: '$_firebaseStoragePath/bible_says_lesson_${index + 1}.pdf',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isDownloaded: false,
        order: index + 1,
        language: 'en',
      );
    }).toList();
  }

  // Load "What the Bible Says" tracts from Firebase Storage
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
