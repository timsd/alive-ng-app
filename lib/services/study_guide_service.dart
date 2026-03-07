import 'package:uuid/uuid.dart';
import '../models/study_guide_models.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';
import 'firebase_database_service.dart';

class StudyGuideService {
  static final StudyGuideService _instance = StudyGuideService._internal();
  factory StudyGuideService() => _instance;
  StudyGuideService._internal();

  final FirebaseDatabaseService _firebase = FirebaseDatabaseService.instance;
  final Logger _logger = Logger('StudyGuideService');
  final Uuid _uuid = const Uuid();

  // Study Guide Management
  Future<List<StudyGuide>> getStudyGuides({
    StudyGuideType? type,
    StudyDifficulty? difficulty,
    bool? isActive,
    String? searchQuery,
  }) async {
    try {
      final studyGuides = await _firebase.getStudyGuides(
        type: type?.name,
        difficulty: difficulty?.name,
        isActive: isActive,
        searchQuery: searchQuery,
      );
      return studyGuides
          .map<StudyGuide>((json) => StudyGuide.fromJson(json))
          .toList();
    } catch (e) {
      _logger.error('Error fetching study guides', e);
      throw DatabaseException('Failed to fetch study guides', originalError: e);
    }
  }

  Future<StudyGuide?> getStudyGuideById(String studyGuideId) async {
    try {
      final response = await _firebase.getStudyGuideById(studyGuideId);
      return StudyGuide.fromJson(response);
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error fetching study guide', e);
      throw DatabaseException('Failed to fetch study guide', originalError: e);
    }
  }

  Future<List<StudyGuide>> getFeaturedStudyGuides() async {
    try {
      final response = await _firebase.getFeaturedStudyGuides();
      return response
          .map<StudyGuide>((json) => StudyGuide.fromJson(json))
          .toList();
    } catch (e) {
      _logger.error('Error fetching featured study guides', e);
      throw DatabaseException('Failed to fetch featured study guides',
          originalError: e);
    }
  }

  Future<StudyGuide> createStudyGuide(StudyGuide studyGuide) async {
    try {
      final newStudyGuide = studyGuide.copyWith(
        id: _uuid.v4(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firebase.createStudyGuide(newStudyGuide.toJson());
      return newStudyGuide;
    } catch (e) {
      _logger.error('Error creating study guide', e);
      throw DatabaseException('Failed to create study guide', originalError: e);
    }
  }

  Future<StudyGuide> updateStudyGuide(StudyGuide studyGuide) async {
    try {
      final updatedStudyGuide = studyGuide.copyWith(updatedAt: DateTime.now());

      await _firebase.updateStudyGuide(
          studyGuide.id, updatedStudyGuide.toJson());
      return updatedStudyGuide;
    } catch (e) {
      _logger.error('Error updating study guide', e);
      throw DatabaseException('Failed to update study guide', originalError: e);
    }
  }

  // Lesson Management
  Future<List<StudyLesson>> getLessons(String studyGuideId) async {
    try {
      final response = await _firebase.getStudyLessons(studyGuideId);
      return response
          .map<StudyLesson>((json) => StudyLesson.fromJson(json))
          .toList();
    } catch (e) {
      _logger.error('Error fetching lessons', e);
      throw DatabaseException('Failed to fetch lessons', originalError: e);
    }
  }

  Future<StudyLesson?> getLessonById(String lessonId) async {
    try {
      final response = await _firebase.getStudyLessonById(lessonId);
      return StudyLesson.fromJson(response);
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error fetching lesson', e);
      throw DatabaseException('Failed to fetch lesson', originalError: e);
    }
  }

  Future<StudyLesson?> getLessonByNumber(
      String studyGuideId, int lessonNumber) async {
    try {
      final response =
          await _firebase.getStudyLessonByNumber(studyGuideId, lessonNumber);
      return StudyLesson.fromJson(response);
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error fetching lesson by number', e);
      throw DatabaseException('Failed to fetch lesson by number',
          originalError: e);
    }
  }

  Future<StudyLesson> createLesson(StudyLesson lesson) async {
    try {
      final newLesson = StudyLesson(
        id: _uuid.v4(),
        studyGuideId: lesson.studyGuideId,
        title: lesson.title,
        content: lesson.content,
        keyVerses: lesson.keyVerses,
        supportingVerses: lesson.supportingVerses,
        summary: lesson.summary,
        practicalApplication: lesson.practicalApplication,
        lessonNumber: lesson.lessonNumber,
        estimatedDurationMinutes: lesson.estimatedDurationMinutes,
        resources: lesson.resources,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firebase.createStudyLesson(newLesson.toJson());
      return newLesson;
    } catch (e) {
      _logger.error('Error creating lesson', e);
      throw DatabaseException('Failed to create lesson', originalError: e);
    }
  }

  // Question Management
  Future<List<StudyQuestion>> getQuestions(String lessonId) async {
    try {
      final response = await _firebase.getStudyQuestions(lessonId);
      return response
          .map<StudyQuestion>((json) => StudyQuestion.fromJson(json))
          .toList();
    } catch (e) {
      _logger.error('Error fetching questions', e);
      throw DatabaseException('Failed to fetch questions', originalError: e);
    }
  }

  Future<StudyQuestion> createQuestion(StudyQuestion question) async {
    try {
      final newQuestion = StudyQuestion(
        id: _uuid.v4(),
        lessonId: question.lessonId,
        question: question.question,
        type: question.type,
        options: question.options,
        correctAnswer: question.correctAnswer,
        explanation: question.explanation,
        bibleReferences: question.bibleReferences,
        questionNumber: question.questionNumber,
        isRequired: question.isRequired,
        metadata: question.metadata,
        createdAt: DateTime.now(),
      );

      await _firebase.createStudyQuestion(newQuestion.toJson());
      return newQuestion;
    } catch (e) {
      _logger.error('Error creating question', e);
      throw DatabaseException('Failed to create question', originalError: e);
    }
  }

  // User Progress Management
  Future<List<UserStudyProgress>> getUserProgress(String userId) async {
    try {
      final response = await _firebase.getUserStudyProgressList(userId);

      return response
          .map<UserStudyProgress>((json) => UserStudyProgress.fromJson(json))
          .toList();
    } catch (e) {
      _logger.error('Error fetching user progress', e);
      throw DatabaseException('Failed to fetch user progress',
          originalError: e);
    }
  }

  Future<UserStudyProgress?> getUserStudyProgress(
      String userId, String studyGuideId) async {
    try {
      final response =
          await _firebase.getUserStudyProgress(userId, studyGuideId);
      return UserStudyProgress.fromJson(response);
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error fetching user study progress', e);
      throw DatabaseException('Failed to fetch user study progress',
          originalError: e);
    }
  }

  Future<UserStudyProgress> startStudyGuide(
      String userId, String studyGuideId) async {
    try {
      // Check if progress already exists
      final existingProgress = await getUserStudyProgress(userId, studyGuideId);
      if (existingProgress != null) {
        return existingProgress;
      }

      final progress = UserStudyProgress(
        id: _uuid.v4(),
        userId: userId,
        studyGuideId: studyGuideId,
        status: StudyStatus.inProgress,
        startedAt: DateTime.now(),
        currentLessonNumber: 1,
        progressPercentage: 0.0,
        totalTimeSpentMinutes: 0,
        notes: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firebase.createUserStudyProgress(progress.toJson());
      return progress;
    } catch (e) {
      _logger.error('Error starting study guide', e);
      throw DatabaseException('Failed to start study guide', originalError: e);
    }
  }

  Future<UserStudyProgress> updateStudyProgress(
      UserStudyProgress progress) async {
    try {
      final updatedProgress = progress.copyWith(updatedAt: DateTime.now());

      await _firebase.updateUserStudyProgress(
          progress.id, updatedProgress.toJson());

      return updatedProgress;
    } catch (e) {
      _logger.error('Error updating study progress', e);
      throw DatabaseException('Failed to update study progress',
          originalError: e);
    }
  }

  Future<UserStudyProgress> completeStudyGuide(
      String userId, String studyGuideId) async {
    try {
      final progress = await getUserStudyProgress(userId, studyGuideId);
      if (progress == null) {
        throw NotFoundException('Study progress not found');
      }

      final completedProgress = progress.copyWith(
        status: StudyStatus.completed,
        completedAt: DateTime.now(),
        progressPercentage: 100.0,
        updatedAt: DateTime.now(),
      );

      await _firebase.updateUserStudyProgress(
          progress.id, completedProgress.toJson());

      return completedProgress;
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error completing study guide', e);
      throw DatabaseException('Failed to complete study guide',
          originalError: e);
    }
  }

  // Lesson Progress Management
  Future<List<UserLessonProgress>> getUserLessonProgress(
      String userId, String studyGuideId) async {
    try {
      // Get all lessons for the study guide
      final lessons = await getLessons(studyGuideId);
      final lessonIds = lessons.map((l) => l.id).toList();

      if (lessonIds.isEmpty) return [];

      // Since Firebase doesn't support inFilter directly, we'll fetch each lesson progress individually
      final progressList = <UserLessonProgress>[];

      for (final lessonId in lessonIds) {
        final response =
            await _firebase.getUserLessonProgress(userId, lessonId);
        progressList.add(UserLessonProgress.fromJson(response));
      }

      // Sort by created_at to match original behavior
      progressList.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      return progressList;
    } catch (e) {
      _logger.error('Error fetching lesson progress', e);
      throw DatabaseException('Failed to fetch lesson progress',
          originalError: e);
    }
  }

  Future<UserLessonProgress?> getUserLessonProgressById(
      String userId, String lessonId) async {
    try {
      final response = await _firebase.getUserLessonProgress(userId, lessonId);
      return UserLessonProgress.fromJson(response);
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error fetching user lesson progress', e);
      throw DatabaseException('Failed to fetch user lesson progress',
          originalError: e);
    }
  }

  Future<UserLessonProgress> startLesson(String userId, String lessonId) async {
    try {
      // Check if progress already exists
      final existingProgress =
          await getUserLessonProgressById(userId, lessonId);
      if (existingProgress != null) {
        return existingProgress;
      }

      final progress = UserLessonProgress(
        id: _uuid.v4(),
        userId: userId,
        lessonId: lessonId,
        status: StudyStatus.inProgress,
        startedAt: DateTime.now(),
        timeSpentMinutes: 0,
        answers: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firebase.createUserLessonProgress(progress.toJson());
      return progress;
    } catch (e) {
      _logger.error('Error starting lesson', e);
      throw DatabaseException('Failed to start lesson', originalError: e);
    }
  }

  Future<UserLessonProgress> saveAnswer(
      String userId, String lessonId, String questionId, String answer) async {
    try {
      var progress = await getUserLessonProgressById(userId, lessonId);
      progress ??= await startLesson(userId, lessonId);

      final updatedAnswers = Map<String, String>.from(progress.answers);
      updatedAnswers[questionId] = answer;

      final updatedProgress = UserLessonProgress(
        id: progress.id,
        userId: progress.userId,
        lessonId: progress.lessonId,
        status: progress.status,
        startedAt: progress.startedAt,
        completedAt: progress.completedAt,
        timeSpentMinutes: progress.timeSpentMinutes,
        answers: updatedAnswers,
        score: progress.score,
        notes: progress.notes,
        createdAt: progress.createdAt,
        updatedAt: DateTime.now(),
      );

      await _firebase.updateUserLessonProgress(
          progress.id, updatedProgress.toJson());

      return updatedProgress;
    } catch (e) {
      _logger.error('Error saving answer', e);
      throw DatabaseException('Failed to save answer', originalError: e);
    }
  }

  Future<UserLessonProgress> completeLesson(String userId, String lessonId,
      {double? score}) async {
    try {
      final progress = await getUserLessonProgressById(userId, lessonId);
      if (progress == null) {
        throw NotFoundException('Lesson progress not found');
      }

      final completedProgress = UserLessonProgress(
        id: progress.id,
        userId: progress.userId,
        lessonId: progress.lessonId,
        status: StudyStatus.completed,
        startedAt: progress.startedAt,
        completedAt: DateTime.now(),
        timeSpentMinutes: progress.timeSpentMinutes,
        answers: progress.answers,
        score: score ?? progress.score,
        notes: progress.notes,
        createdAt: progress.createdAt,
        updatedAt: DateTime.now(),
      );

      await _firebase.updateUserLessonProgress(
          progress.id, completedProgress.toJson());

      // Update overall study guide progress
      await _updateStudyGuideProgress(userId, lessonId);

      return completedProgress;
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error completing lesson', e);
      throw DatabaseException('Failed to complete lesson', originalError: e);
    }
  }

  // Study Session Management
  Future<List<StudySession>> getStudySessions({
    String? facilitatorId,
    List<String>? participantIds,
    DateTime? startDate,
    DateTime? endDate,
    StudySessionStatus? status,
  }) async {
    try {
      final response = await _firebase.getStudySessions(
        facilitatorId: facilitatorId,
        participantIds: participantIds,
        startDate: startDate,
        endDate: endDate,
        status: status?.name,
      );
      return response
          .map<StudySession>((json) => StudySession.fromJson(json))
          .toList();
    } catch (e) {
      _logger.error('Error fetching study sessions', e);
      throw DatabaseException('Failed to fetch study sessions',
          originalError: e);
    }
  }

  Future<StudySession> createStudySession(StudySession session) async {
    try {
      final newSession = StudySession(
        id: _uuid.v4(),
        studyGuideId: session.studyGuideId,
        lessonId: session.lessonId,
        facilitatorId: session.facilitatorId,
        participantIds: session.participantIds,
        title: session.title,
        description: session.description,
        scheduledAt: session.scheduledAt,
        durationMinutes: session.durationMinutes,
        status: session.status,
        meetingLink: session.meetingLink,
        location: session.location,
        resources: session.resources,
        notes: session.notes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firebase.createStudySession(newSession.toJson());
      return newSession;
    } catch (e) {
      _logger.error('Error creating study session', e);
      throw DatabaseException('Failed to create study session',
          originalError: e);
    }
  }

  // Statistics and Analytics
  Future<Map<String, dynamic>> getStudyStatistics(String userId) async {
    try {
      final progress = await getUserProgress(userId);

      final totalStudies = progress.length;
      final completedStudies =
          progress.where((p) => p.status == StudyStatus.completed).length;
      final inProgressStudies =
          progress.where((p) => p.status == StudyStatus.inProgress).length;
      final totalTimeSpent =
          progress.fold<int>(0, (sum, p) => sum + p.totalTimeSpentMinutes);

      // Calculate average progress
      final averageProgress = progress.isEmpty
          ? 0.0
          : progress.fold<double>(0, (sum, p) => sum + p.progressPercentage) /
              progress.length;

      // Get study type distribution
      final studyGuides = await getStudyGuides();
      final typeDistribution = <StudyGuideType, int>{};

      for (final p in progress) {
        final studyGuide = studyGuides.firstWhere(
          (sg) => sg.id == p.studyGuideId,
          orElse: () => StudyGuide(
            id: '',
            title: '',
            description: '',
            type: StudyGuideType.doctrine,
            difficulty: StudyDifficulty.beginner,
            estimatedDurationMinutes: 0,
            objectives: [],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        typeDistribution[studyGuide.type] =
            (typeDistribution[studyGuide.type] ?? 0) + 1;
      }

      return {
        'totalStudies': totalStudies,
        'completedStudies': completedStudies,
        'inProgressStudies': inProgressStudies,
        'totalTimeSpentMinutes': totalTimeSpent,
        'averageProgress': averageProgress,
        'typeDistribution': typeDistribution.map((k, v) => MapEntry(k.name, v)),
        'completionRate': totalStudies > 0
            ? (completedStudies / totalStudies * 100).round()
            : 0,
      };
    } catch (e) {
      _logger.error('Error getting study statistics', e);
      throw DatabaseException('Failed to get study statistics',
          originalError: e);
    }
  }

  // Helper Methods
  Future<void> _updateStudyGuideProgress(String userId, String lessonId) async {
    try {
      final lesson = await getLessonById(lessonId);
      final studyGuideProgress =
          await getUserStudyProgress(userId, lesson!.studyGuideId);
      if (studyGuideProgress == null) {
        throw NotFoundException('Study progress not found');
      }

      final allLessons = await getLessons(lesson.studyGuideId);
      final completedLessons =
          await getUserLessonProgress(userId, lesson.studyGuideId);
      final completedCount = completedLessons
          .where((lp) => lp.status == StudyStatus.completed)
          .length;

      final progressPercentage =
          allLessons.isEmpty ? 0.0 : (completedCount / allLessons.length * 100);

      final updatedProgress = studyGuideProgress.copyWith(
        progressPercentage: progressPercentage,
        currentLessonNumber: completedCount + 1,
        status: progressPercentage >= 100
            ? StudyStatus.completed
            : StudyStatus.inProgress,
        completedAt: progressPercentage >= 100 ? DateTime.now() : null,
      );

      await updateStudyProgress(updatedProgress);
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error updating study guide progress', e);
      throw DatabaseException('Failed to update study guide progress',
          originalError: e);
    }
  }

  double calculateScore(
      List<StudyQuestion> questions, Map<String, String> answers) {
    if (questions.isEmpty) return 0.0;

    int correctAnswers = 0;
    for (final question in questions) {
      final userAnswer = answers[question.id];
      if (userAnswer != null && question.correctAnswer != null) {
        if (question.type == QuestionType.trueFalse ||
            question.type == QuestionType.multipleChoice) {
          if (userAnswer.toLowerCase() ==
              question.correctAnswer!.toLowerCase()) {
            correctAnswers++;
          }
        }
      }
    }

    return (correctAnswers / questions.length * 100);
  }

  String getTypeDescription(StudyGuideType type) {
    return StudyGuideConstants.typeDescriptions[type] ?? 'Study guide';
  }

  String getDifficultyDescription(StudyDifficulty difficulty) {
    return StudyGuideConstants.difficultyDescriptions[difficulty] ??
        'Study guide';
  }

  String getQuestionTypeDescription(QuestionType type) {
    return StudyGuideConstants.questionTypeDescriptions[type] ?? 'Question';
  }

  List<String> getBibleBooks() {
    return StudyGuideConstants.bibleBooks;
  }

  String getInspirationalQuote(String key) {
    return StudyGuideConstants.inspirationalQuotes[key] ?? '';
  }

  // Initialize default study guides
  Future<void> initializeDefaultStudyGuides() async {
    try {
      final existingGuides = await getStudyGuides();
      if (existingGuides.isNotEmpty) return; // Already initialized

      for (int i = 0; i < StudyGuideConstants.defaultStudyGuides.length; i++) {
        final guideData = StudyGuideConstants.defaultStudyGuides[i];

        final studyGuide = StudyGuide(
          id: _uuid.v4(),
          title: guideData['title'] as String,
          description: guideData['description'] as String,
          type: StudyGuideType.values.firstWhere(
            (type) => type.name == guideData['type'],
            orElse: () => StudyGuideType.doctrine,
          ),
          difficulty: StudyDifficulty.values.firstWhere(
            (difficulty) => difficulty.name == guideData['difficulty'],
            orElse: () => StudyDifficulty.beginner,
          ),
          estimatedDurationMinutes: 60,
          objectives: List<String>.from(guideData['objectives'] ?? []),
          sortOrder: i,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await createStudyGuide(studyGuide);
      }
    } catch (e) {
      _logger.error('Error initializing default study guides', e);
    }
  }
}
