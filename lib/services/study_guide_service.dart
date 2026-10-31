import '../utils/appwrite_id_utils.dart';
import 'dart:convert';

import 'package:appwrite/appwrite.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../models/study_guide_models.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';

class StudyGuideService {
  static final StudyGuideService _instance = StudyGuideService._internal();
  factory StudyGuideService() => _instance;
  StudyGuideService._internal();

  late final TablesDB _tables = TablesDB(appwriteClient);
  final Logger _logger = Logger('StudyGuideService');

  Future<List<StudyGuide>> getStudyGuides({
    StudyGuideType? type,
    StudyDifficulty? difficulty,
    bool? isActive,
    String? searchQuery,
  }) async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.studyGuidesCollectionId,
        queries: [
          Query.limit(200),
          Query.orderAsc('title'),
        ],
      );

      var guides = response.rows
          .map((doc) => _studyGuideFromData(
              doc.$id, doc.data, doc.$createdAt, doc.$updatedAt))
          .toList();

      if (type != null) {
        guides = guides.where((guide) => guide.type == type).toList();
      }
      if (difficulty != null) {
        guides =
            guides.where((guide) => guide.difficulty == difficulty).toList();
      }
      if (isActive != null) {
        guides = guides.where((guide) => guide.isActive == isActive).toList();
      }
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final query = searchQuery.toLowerCase().trim();
        guides = guides
            .where((guide) =>
                guide.title.toLowerCase().contains(query) ||
                guide.description.toLowerCase().contains(query))
            .toList();
      }

      return guides;
    } catch (e) {
      _logger.error('Error fetching study guides', e);
      throw DatabaseException('Failed to fetch study guides', originalError: e);
    }
  }

  Future<StudyGuide?> getStudyGuideById(String studyGuideId) async {
    try {
      final doc = await _tables.getRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.studyGuidesCollectionId,
        rowId: AppwriteIdUtils.toValidUid(studyGuideId),
      );
      return _studyGuideFromData(
          doc.$id, doc.data, doc.$createdAt, doc.$updatedAt);
    } on AppwriteException catch (e) {
      if (e.code == 404) return null;
      _logger.error('Error fetching study guide', e);
      throw DatabaseException('Failed to fetch study guide', originalError: e);
    } catch (e) {
      _logger.error('Error fetching study guide', e);
      throw DatabaseException('Failed to fetch study guide', originalError: e);
    }
  }

  Future<List<StudyGuide>> getFeaturedStudyGuides() async {
    try {
      final guides = await getStudyGuides(isActive: true);
      return guides
          .where((guide) => _bool(guide.metadata['is_featured']))
          .take(10)
          .toList();
    } catch (e) {
      _logger.error('Error fetching featured study guides', e);
      throw DatabaseException('Failed to fetch featured study guides',
          originalError: e);
    }
  }

  Future<StudyGuide> createStudyGuide(StudyGuide studyGuide) async {
    try {
      final now = DateTime.now();
      final newStudyGuide = studyGuide.copyWith(
        id: AppwriteIdUtils.uniqueId(),
        createdAt: now,
        updatedAt: now,
      );

      await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.studyGuidesCollectionId,
        rowId: AppwriteIdUtils.toValidUid(newStudyGuide.id),
        data: _studyGuideToData(newStudyGuide),
      );
      return newStudyGuide;
    } catch (e) {
      _logger.error('Error creating study guide', e);
      throw DatabaseException('Failed to create study guide', originalError: e);
    }
  }

  Future<StudyGuide> updateStudyGuide(StudyGuide studyGuide) async {
    try {
      final updatedStudyGuide = studyGuide.copyWith(updatedAt: DateTime.now());
      await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.studyGuidesCollectionId,
        rowId: AppwriteIdUtils.toValidUid(studyGuide.id),
        data: _studyGuideToData(updatedStudyGuide),
      );
      return updatedStudyGuide;
    } catch (e) {
      _logger.error('Error updating study guide', e);
      throw DatabaseException('Failed to update study guide', originalError: e);
    }
  }

  Future<List<StudyLesson>> getLessons(String studyGuideId) async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.studyLessonsCollectionId,
        queries: [
          Query.equal('study_guide_id', studyGuideId),
          Query.orderAsc('lesson_number'),
          Query.limit(200),
        ],
      );
      return response.rows
          .map((doc) => _lessonFromData(
              doc.$id, doc.data, doc.$createdAt, doc.$updatedAt))
          .toList();
    } catch (e) {
      _logger.error('Error fetching lessons', e);
      throw DatabaseException('Failed to fetch lessons', originalError: e);
    }
  }

  Future<StudyLesson?> getLessonById(String lessonId) async {
    try {
      final doc = await _tables.getRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.studyLessonsCollectionId,
        rowId: AppwriteIdUtils.toValidUid(lessonId),
      );
      return _lessonFromData(doc.$id, doc.data, doc.$createdAt, doc.$updatedAt);
    } on AppwriteException catch (e) {
      if (e.code == 404) return null;
      _logger.error('Error fetching lesson', e);
      throw DatabaseException('Failed to fetch lesson', originalError: e);
    } catch (e) {
      _logger.error('Error fetching lesson', e);
      throw DatabaseException('Failed to fetch lesson', originalError: e);
    }
  }

  Future<StudyLesson?> getLessonByNumber(
      String studyGuideId, int lessonNumber) async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.studyLessonsCollectionId,
        queries: [
          Query.equal('study_guide_id', studyGuideId),
          Query.equal('lesson_number', lessonNumber),
          Query.limit(1),
        ],
      );
      if (response.rows.isEmpty) return null;
      final doc = response.rows.first;
      return _lessonFromData(doc.$id, doc.data, doc.$createdAt, doc.$updatedAt);
    } catch (e) {
      _logger.error('Error fetching lesson by number', e);
      throw DatabaseException('Failed to fetch lesson by number',
          originalError: e);
    }
  }

  Future<StudyLesson> createLesson(StudyLesson lesson) async {
    try {
      final now = DateTime.now();
      final newLesson = StudyLesson(
        id: AppwriteIdUtils.uniqueId(),
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
        createdAt: now,
        updatedAt: now,
      );

      await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.studyLessonsCollectionId,
        rowId: AppwriteIdUtils.toValidUid(newLesson.id),
        data: _lessonToData(newLesson),
      );
      return newLesson;
    } catch (e) {
      _logger.error('Error creating lesson', e);
      throw DatabaseException('Failed to create lesson', originalError: e);
    }
  }

  Future<List<StudyQuestion>> getQuestions(String lessonId) async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.studyQuestionsCollectionId,
        queries: [
          Query.equal('lesson_id', lessonId),
          Query.orderAsc('order'),
          Query.limit(200),
        ],
      );
      return response.rows
          .map((doc) => _questionFromData(doc.$id, doc.data, doc.$createdAt))
          .toList();
    } catch (e) {
      _logger.error('Error fetching questions', e);
      throw DatabaseException('Failed to fetch questions', originalError: e);
    }
  }

  Future<StudyQuestion> createQuestion(StudyQuestion question) async {
    try {
      final newQuestion = StudyQuestion(
        id: AppwriteIdUtils.uniqueId(),
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

      await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.studyQuestionsCollectionId,
        rowId: AppwriteIdUtils.toValidUid(newQuestion.id),
        data: _questionToData(newQuestion),
      );
      return newQuestion;
    } catch (e) {
      _logger.error('Error creating question', e);
      throw DatabaseException('Failed to create question', originalError: e);
    }
  }

  Future<List<UserStudyProgress>> getUserProgress(String userId) async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.studyProgressCollectionId,
        queries: [
          Query.equal('user_id', userId),
          Query.limit(200),
        ],
      );
      return response.rows
          .where((doc) => _string(doc.data['study_guide_id']).isNotEmpty)
          .where((doc) => _string(doc.data['lesson_id']).isEmpty)
          .map((doc) => _studyProgressFromData(
              doc.$id, doc.data, doc.$createdAt, doc.$updatedAt))
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
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.studyProgressCollectionId,
        queries: [
          Query.equal('user_id', userId),
          Query.equal('study_guide_id', studyGuideId),
          Query.limit(50),
        ],
      );
      final docs = response.rows
          .where((doc) => _string(doc.data['lesson_id']).isEmpty)
          .toList();
      if (docs.isEmpty) return null;
      final doc = docs.first;
      return _studyProgressFromData(
          doc.$id, doc.data, doc.$createdAt, doc.$updatedAt);
    } catch (e) {
      _logger.error('Error fetching user study progress', e);
      throw DatabaseException('Failed to fetch user study progress',
          originalError: e);
    }
  }

  Future<UserStudyProgress> startStudyGuide(
      String userId, String studyGuideId) async {
    try {
      final existingProgress = await getUserStudyProgress(userId, studyGuideId);
      if (existingProgress != null) return existingProgress;

      final now = DateTime.now();
      final progress = UserStudyProgress(
        id: '${userId}_$studyGuideId',
        userId: userId,
        studyGuideId: studyGuideId,
        status: StudyStatus.inProgress,
        startedAt: now,
        currentLessonNumber: 1,
        progressPercentage: 0.0,
        totalTimeSpentMinutes: 0,
        notes: {},
        createdAt: now,
        updatedAt: now,
      );

      await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.studyProgressCollectionId,
        rowId: AppwriteIdUtils.toValidUid(progress.id),
        data: _studyProgressToData(progress),
      );
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
      await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.studyProgressCollectionId,
        rowId: AppwriteIdUtils.toValidUid(progress.id),
        data: _studyProgressToData(updatedProgress),
      );
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
      await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.studyProgressCollectionId,
        rowId: AppwriteIdUtils.toValidUid(progress.id),
        data: _studyProgressToData(completedProgress),
      );
      return completedProgress;
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error completing study guide', e);
      throw DatabaseException('Failed to complete study guide',
          originalError: e);
    }
  }

  Future<List<UserLessonProgress>> getUserLessonProgress(
      String userId, String studyGuideId) async {
    try {
      final lessons = await getLessons(studyGuideId);
      final lessonIds = lessons.map((lesson) => lesson.id).toSet();
      if (lessonIds.isEmpty) return [];

      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.studyProgressCollectionId,
        queries: [
          Query.equal('user_id', userId),
          Query.equal('study_guide_id', studyGuideId),
          Query.limit(200),
        ],
      );

      final progressList = response.rows
          .where((doc) => lessonIds.contains(_string(doc.data['lesson_id'])))
          .map((doc) => _lessonProgressFromData(
              doc.$id, doc.data, doc.$createdAt, doc.$updatedAt))
          .toList();
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
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.studyProgressCollectionId,
        queries: [
          Query.equal('user_id', userId),
          Query.equal('lesson_id', lessonId),
          Query.limit(1),
        ],
      );
      if (response.rows.isEmpty) return null;
      final doc = response.rows.first;
      return _lessonProgressFromData(
          doc.$id, doc.data, doc.$createdAt, doc.$updatedAt);
    } catch (e) {
      _logger.error('Error fetching user lesson progress', e);
      throw DatabaseException('Failed to fetch user lesson progress',
          originalError: e);
    }
  }

  Future<UserLessonProgress> startLesson(String userId, String lessonId) async {
    try {
      final existingProgress =
          await getUserLessonProgressById(userId, lessonId);
      if (existingProgress != null) return existingProgress;

      final lesson = await getLessonById(lessonId);
      final now = DateTime.now();
      final progress = UserLessonProgress(
        id: '${userId}_lesson_$lessonId',
        userId: userId,
        lessonId: lessonId,
        status: StudyStatus.inProgress,
        startedAt: now,
        timeSpentMinutes: 0,
        answers: {},
        createdAt: now,
        updatedAt: now,
      );

      await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.studyProgressCollectionId,
        rowId: AppwriteIdUtils.toValidUid(progress.id),
        data: _lessonProgressToData(progress, lesson?.studyGuideId ?? ''),
      );
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

      final lesson = await getLessonById(lessonId);
      await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.studyProgressCollectionId,
        rowId: AppwriteIdUtils.toValidUid(progress.id),
        data: _lessonProgressToData(
          updatedProgress,
          lesson?.studyGuideId ?? '',
        ),
      );
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

      final lesson = await getLessonById(lessonId);
      await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.studyProgressCollectionId,
        rowId: AppwriteIdUtils.toValidUid(progress.id),
        data: _lessonProgressToData(
          completedProgress,
          lesson?.studyGuideId ?? '',
        ),
      );
      await _updateStudyGuideProgress(userId, lessonId);
      return completedProgress;
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error completing lesson', e);
      throw DatabaseException('Failed to complete lesson', originalError: e);
    }
  }

  Future<List<StudySession>> getStudySessions({
    String? facilitatorId,
    List<String>? participantIds,
    DateTime? startDate,
    DateTime? endDate,
    StudySessionStatus? status,
  }) async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.studySessionsCollectionId,
        queries: [
          if (facilitatorId != null)
            Query.equal('facilitator_id', facilitatorId),
          if (status != null) Query.equal('status', status.name),
          Query.orderDesc('scheduled_at'),
          Query.limit(200),
        ],
      );
      var sessions = response.rows
          .map((doc) => _sessionFromData(
              doc.$id, doc.data, doc.$createdAt, doc.$updatedAt))
          .toList();
      if (participantIds != null && participantIds.isNotEmpty) {
        sessions = sessions
            .where((session) =>
                participantIds.any((id) => session.participantIds.contains(id)))
            .toList();
      }
      if (startDate != null) {
        sessions = sessions
            .where((session) => !session.scheduledAt.isBefore(startDate))
            .toList();
      }
      if (endDate != null) {
        sessions = sessions
            .where((session) => !session.scheduledAt.isAfter(endDate))
            .toList();
      }
      return sessions;
    } catch (e) {
      _logger.error('Error fetching study sessions', e);
      throw DatabaseException('Failed to fetch study sessions',
          originalError: e);
    }
  }

  Future<StudySession> createStudySession(StudySession session) async {
    try {
      final now = DateTime.now();
      final newSession = StudySession(
        id: AppwriteIdUtils.uniqueId(),
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
        createdAt: now,
        updatedAt: now,
      );

      await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.studySessionsCollectionId,
        rowId: AppwriteIdUtils.toValidUid(newSession.id),
        data: _sessionToData(newSession),
      );
      return newSession;
    } catch (e) {
      _logger.error('Error creating study session', e);
      throw DatabaseException('Failed to create study session',
          originalError: e);
    }
  }

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
      final averageProgress = progress.isEmpty
          ? 0.0
          : progress.fold<double>(0, (sum, p) => sum + p.progressPercentage) /
              progress.length;

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

  Future<void> _updateStudyGuideProgress(String userId, String lessonId) async {
    try {
      final lesson = await getLessonById(lessonId);
      if (lesson == null) throw NotFoundException('Lesson not found');
      final studyGuideProgress =
          await getUserStudyProgress(userId, lesson.studyGuideId);
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

    var correctAnswers = 0;
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

    return correctAnswers / questions.length * 100;
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

  List<String> getBibleBooks() => StudyGuideConstants.bibleBooks;

  String getInspirationalQuote(String key) {
    return StudyGuideConstants.inspirationalQuotes[key] ?? '';
  }

  Future<void> initializeDefaultStudyGuides() async {
    try {
      final existingGuides = await getStudyGuides();
      if (existingGuides.isNotEmpty) return;

      for (var i = 0; i < StudyGuideConstants.defaultStudyGuides.length; i++) {
        final guideData = StudyGuideConstants.defaultStudyGuides[i];
        final studyGuide = StudyGuide(
          id: AppwriteIdUtils.uniqueId(),
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

  StudyGuide _studyGuideFromData(String id, Map<String, dynamic> data,
      String createdAt, String updatedAt) {
    final metadata = _map(data['metadata']);
    metadata['is_featured'] = _bool(data['is_featured']);
    return StudyGuide(
      id: id,
      title: _string(data['title'], fallback: 'Study Guide'),
      description: _string(data['description']),
      type: _enumByName(
        StudyGuideType.values,
        _string(data['type'], fallback: StudyGuideType.doctrine.name),
        StudyGuideType.doctrine,
      ),
      difficulty: _enumByName(
        StudyDifficulty.values,
        _string(data['difficulty'], fallback: StudyDifficulty.beginner.name),
        StudyDifficulty.beginner,
      ),
      estimatedDurationMinutes: _int(data['estimated_duration_minutes'],
          fallback: _int(data['duration'], fallback: 60)),
      objectives: _list(data['objectives']),
      prerequisites: _list(data['prerequisites']),
      imageUrl: _string(data['image_url'] ?? data['cover_image_url']),
      isActive:
          _bool(data['is_active'] ?? data['is_published'], fallback: true),
      sortOrder: _int(data['sort_order']),
      metadata: metadata,
      createdAt: _date(data['created_at'], fallback: createdAt),
      updatedAt: _date(data['updated_at'], fallback: updatedAt),
    );
  }

  Map<String, dynamic> _studyGuideToData(StudyGuide guide) {
    return {
      'title': guide.title,
      'description': guide.description,
      'type': guide.type.name,
      'difficulty': guide.difficulty.name,
      'cover_image_url': guide.imageUrl ?? '',
      'lesson_count': _int(guide.metadata['lesson_count']),
      'is_featured': _bool(guide.metadata['is_featured']),
      'is_published': guide.isActive,
      'created_at': guide.createdAt.toIso8601String(),
      'updated_at': guide.updatedAt.toIso8601String(),
    };
  }

  StudyLesson _lessonFromData(String id, Map<String, dynamic> data,
      String createdAt, String updatedAt) {
    final resources = _map(data['resources']);
    return StudyLesson(
      id: id,
      studyGuideId: _string(data['study_guide_id']),
      title: _string(data['title'], fallback: 'Lesson'),
      content: _string(data['content']),
      keyVerses: _list(resources['key_verses']),
      supportingVerses: _list(resources['supporting_verses']),
      summary: _string(resources['summary']),
      practicalApplication: _string(resources['practical_application']),
      lessonNumber: _int(data['lesson_number']),
      estimatedDurationMinutes:
          _int(resources['estimated_duration_minutes'], fallback: 30),
      resources: resources,
      createdAt: _date(data['created_at'], fallback: createdAt),
      updatedAt: _date(data['updated_at'], fallback: updatedAt),
    );
  }

  Map<String, dynamic> _lessonToData(StudyLesson lesson) {
    final resources = Map<String, dynamic>.from(lesson.resources);
    resources.addAll({
      'key_verses': lesson.keyVerses,
      'supporting_verses': lesson.supportingVerses,
      'summary': lesson.summary,
      'practical_application': lesson.practicalApplication,
      'estimated_duration_minutes': lesson.estimatedDurationMinutes,
    });
    return {
      'study_guide_id': lesson.studyGuideId,
      'lesson_number': lesson.lessonNumber,
      'title': lesson.title,
      'content': lesson.content,
      'resources': jsonEncode(resources),
      'created_at': lesson.createdAt.toIso8601String(),
      'updated_at': lesson.updatedAt.toIso8601String(),
    };
  }

  StudyQuestion _questionFromData(
      String id, Map<String, dynamic> data, String createdAt) {
    return StudyQuestion(
      id: id,
      lessonId: _string(data['lesson_id']),
      question: _string(data['question']),
      type: _enumByName(
        QuestionType.values,
        _string(data['type'], fallback: QuestionType.shortAnswer.name),
        QuestionType.shortAnswer,
      ),
      options: _list(data['options']),
      correctAnswer: _string(data['correct_answer']),
      explanation: _string(data['explanation']),
      bibleReferences: _list(data['bible_references']),
      questionNumber: _int(data['question_number'],
          fallback: _int(data['order'], fallback: 1)),
      isRequired: _bool(data['is_required'], fallback: true),
      metadata: _map(data['metadata']),
      createdAt: _date(data['created_at'], fallback: createdAt),
    );
  }

  Map<String, dynamic> _questionToData(StudyQuestion question) {
    return {
      'lesson_id': question.lessonId,
      'question': question.question,
      'type': question.type.name,
      'options': jsonEncode(question.options),
      'correct_answer': question.correctAnswer ?? '',
      'order': question.questionNumber,
    };
  }

  UserStudyProgress _studyProgressFromData(String id, Map<String, dynamic> data,
      String createdAt, String updatedAt) {
    final completed = _bool(data['completed']);
    return UserStudyProgress(
      id: id,
      userId: _string(data['user_id']),
      studyGuideId: _string(data['study_guide_id'] ?? data['program_id']),
      status: _statusFromData(data['status'], completed),
      startedAt: _date(data['started_at'], fallback: createdAt),
      completedAt: _nullableDate(data['completed_at']),
      currentLessonNumber: _int(data['current_lesson'], fallback: 1),
      progressPercentage: _double(data['progress_percentage']),
      totalTimeSpentMinutes: _int(data['total_time_spent_minutes']),
      notes: _map(data['notes']),
      createdAt: _date(data['created_at'], fallback: createdAt),
      updatedAt: _date(data['updated_at'], fallback: updatedAt),
    );
  }

  Map<String, dynamic> _studyProgressToData(UserStudyProgress progress) {
    return {
      'user_id': progress.userId,
      'program_id': progress.studyGuideId,
      'study_guide_id': progress.studyGuideId,
      'lesson_id': '',
      'status': progress.status.name,
      'completed': progress.status == StudyStatus.completed,
      'score': 0,
      'current_lesson': progress.currentLessonNumber,
      'completed_lessons': 0,
      'progress_percentage': progress.progressPercentage,
      'started_at': progress.startedAt.toIso8601String(),
      'completed_at': progress.completedAt?.toIso8601String(),
      'time_spent_minutes': 0,
      'total_time_spent_minutes': progress.totalTimeSpentMinutes,
      'answers': jsonEncode({}),
      'notes': jsonEncode(progress.notes),
      'last_accessed_at': progress.updatedAt.toIso8601String(),
      'created_at': progress.createdAt.toIso8601String(),
      'updated_at': progress.updatedAt.toIso8601String(),
    };
  }

  UserLessonProgress _lessonProgressFromData(String id,
      Map<String, dynamic> data, String createdAt, String updatedAt) {
    final completed = _bool(data['completed']);
    final notes = _map(data['notes']);
    return UserLessonProgress(
      id: id,
      userId: _string(data['user_id']),
      lessonId: _string(data['lesson_id']),
      status: _statusFromData(data['status'], completed),
      startedAt: _date(data['started_at'], fallback: createdAt),
      completedAt: _nullableDate(data['completed_at']),
      timeSpentMinutes: _int(data['time_spent_minutes']),
      answers: Map<String, String>.from(_map(data['answers'])),
      score: _nullableDouble(data['score']),
      notes: _string(notes['notes']),
      createdAt: _date(data['created_at'], fallback: createdAt),
      updatedAt: _date(data['updated_at'], fallback: updatedAt),
    );
  }

  Map<String, dynamic> _lessonProgressToData(
      UserLessonProgress progress, String studyGuideId) {
    return {
      'user_id': progress.userId,
      'program_id': studyGuideId,
      'study_guide_id': studyGuideId,
      'lesson_id': progress.lessonId,
      'status': progress.status.name,
      'completed': progress.status == StudyStatus.completed,
      'score': (progress.score ?? 0).round(),
      'current_lesson': 0,
      'completed_lessons': progress.status == StudyStatus.completed ? 1 : 0,
      'progress_percentage':
          progress.status == StudyStatus.completed ? 100.0 : 0.0,
      'started_at': progress.startedAt.toIso8601String(),
      'completed_at': progress.completedAt?.toIso8601String(),
      'time_spent_minutes': progress.timeSpentMinutes,
      'total_time_spent_minutes': 0,
      'answers': jsonEncode(progress.answers),
      'notes': jsonEncode({'notes': progress.notes}),
      'last_accessed_at': progress.updatedAt.toIso8601String(),
      'created_at': progress.createdAt.toIso8601String(),
      'updated_at': progress.updatedAt.toIso8601String(),
    };
  }

  StudySession _sessionFromData(String id, Map<String, dynamic> data,
      String createdAt, String updatedAt) {
    return StudySession(
      id: id,
      studyGuideId: _string(data['study_guide_id']),
      lessonId: _string(data['lesson_id']),
      facilitatorId: _string(data['facilitator_id']),
      participantIds: _list(data['participant_ids']),
      title: _string(data['title'], fallback: 'Study Session'),
      description: _string(data['description']),
      scheduledAt: _date(data['scheduled_at'], fallback: createdAt),
      durationMinutes: _int(data['duration_minutes'], fallback: 60),
      status: _enumByName(
        StudySessionStatus.values,
        _string(data['status'], fallback: StudySessionStatus.scheduled.name),
        StudySessionStatus.scheduled,
      ),
      meetingLink: _string(data['meeting_link']),
      location: _string(data['location']),
      resources: _map(data['resources']),
      notes: _string(data['notes']),
      createdAt: _date(data['created_at'], fallback: createdAt),
      updatedAt: _date(data['updated_at'], fallback: updatedAt),
    );
  }

  Map<String, dynamic> _sessionToData(StudySession session) {
    return {
      'study_guide_id': session.studyGuideId,
      'lesson_id': session.lessonId ?? '',
      'facilitator_id': session.facilitatorId,
      'participant_ids': session.participantIds,
      'title': session.title,
      'description': session.description ?? '',
      'scheduled_at': session.scheduledAt.toIso8601String(),
      'duration_minutes': session.durationMinutes,
      'status': session.status.name,
      'meeting_link': session.meetingLink ?? '',
      'location': session.location ?? '',
      'resources': jsonEncode(session.resources),
      'notes': session.notes ?? '',
      'created_at': session.createdAt.toIso8601String(),
      'updated_at': session.updatedAt.toIso8601String(),
    };
  }

  T _enumByName<T extends Enum>(List<T> values, String name, T fallback) {
    return values.firstWhere(
      (value) => value.name == name,
      orElse: () => fallback,
    );
  }

  StudyStatus _statusFromData(dynamic value, bool completed) {
    if (completed) return StudyStatus.completed;
    return _enumByName(
      StudyStatus.values,
      _string(value, fallback: StudyStatus.inProgress.name),
      StudyStatus.inProgress,
    );
  }

  String _string(dynamic value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return fallback;
  }

  int _int(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  double _double(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  double? _nullableDouble(dynamic value) {
    if (value == null) return null;
    return _double(value);
  }

  bool _bool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true'
          ? true
          : value.toLowerCase() == 'false'
              ? false
              : fallback;
    }
    return fallback;
  }

  DateTime _date(dynamic value, {required String fallback}) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.parse(fallback);
    }
    return DateTime.parse(fallback);
  }

  DateTime? _nullableDate(dynamic value) {
    if (value == null) return null;
    if (value is String && value.trim().isEmpty) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  List<String> _list(dynamic value) {
    if (value is List) return value.map((item) => item.toString()).toList();
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((item) => item.toString()).toList();
        }
      } catch (_) {
        return value
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
    }
    return const [];
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return decoded.map((key, item) => MapEntry(key.toString(), item));
        }
      } catch (_) {
        return const {};
      }
    }
    return const {};
  }
}
