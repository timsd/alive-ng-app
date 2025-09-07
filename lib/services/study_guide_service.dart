import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/study_guide_models.dart';
import '../utils/logger.dart';

class StudyGuideService {
  static final StudyGuideService _instance = StudyGuideService._internal();
  factory StudyGuideService() => _instance;
  StudyGuideService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
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
      dynamic query = _supabase.from('study_guides').select();

      if (type != null) {
        query = query.eq('type', type.name);
      }

      if (difficulty != null) {
        query = query.eq('difficulty', difficulty.name);
      }

      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query
            .or('title.ilike.%$searchQuery%,description.ilike.%$searchQuery%');
      }

      query = query.order('sort_order').order('title');

      final response = await query;
      return response
          .map<StudyGuide>((json) => StudyGuide.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch study guides: $e');
    }
  }

  Future<StudyGuide?> getStudyGuideById(String studyGuideId) async {
    try {
      final response = await _supabase
          .from('study_guides')
          .select()
          .eq('id', studyGuideId)
          .single();

      return StudyGuide.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<List<StudyGuide>> getFeaturedStudyGuides() async {
    try {
      final response = await _supabase
          .from('study_guides')
          .select()
          .eq('is_active', true)
          .order('sort_order')
          .limit(6);

      return response
          .map<StudyGuide>((json) => StudyGuide.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch featured study guides: $e');
    }
  }

  Future<StudyGuide> createStudyGuide(StudyGuide studyGuide) async {
    try {
      final newStudyGuide = studyGuide.copyWith(
        id: _uuid.v4(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _supabase.from('study_guides').insert(newStudyGuide.toJson());
      return newStudyGuide;
    } catch (e) {
      throw Exception('Failed to create study guide: $e');
    }
  }

  Future<StudyGuide> updateStudyGuide(StudyGuide studyGuide) async {
    try {
      final updatedStudyGuide = studyGuide.copyWith(updatedAt: DateTime.now());

      await _supabase
          .from('study_guides')
          .update(updatedStudyGuide.toJson())
          .eq('id', studyGuide.id);

      return updatedStudyGuide;
    } catch (e) {
      throw Exception('Failed to update study guide: $e');
    }
  }

  // Lesson Management
  Future<List<StudyLesson>> getLessons(String studyGuideId) async {
    try {
      final response = await _supabase
          .from('study_lessons')
          .select()
          .eq('study_guide_id', studyGuideId)
          .order('lesson_number');

      return response
          .map<StudyLesson>((json) => StudyLesson.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch lessons: $e');
    }
  }

  Future<StudyLesson?> getLessonById(String lessonId) async {
    try {
      final response = await _supabase
          .from('study_lessons')
          .select()
          .eq('id', lessonId)
          .single();

      return StudyLesson.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<StudyLesson?> getLessonByNumber(
      String studyGuideId, int lessonNumber) async {
    try {
      final response = await _supabase
          .from('study_lessons')
          .select()
          .eq('study_guide_id', studyGuideId)
          .eq('lesson_number', lessonNumber)
          .single();

      return StudyLesson.fromJson(response);
    } catch (e) {
      return null;
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

      await _supabase.from('study_lessons').insert(newLesson.toJson());
      return newLesson;
    } catch (e) {
      throw Exception('Failed to create lesson: $e');
    }
  }

  // Question Management
  Future<List<StudyQuestion>> getQuestions(String lessonId) async {
    try {
      final response = await _supabase
          .from('study_questions')
          .select()
          .eq('lesson_id', lessonId)
          .order('question_number');

      return response
          .map<StudyQuestion>((json) => StudyQuestion.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch questions: $e');
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

      await _supabase.from('study_questions').insert(newQuestion.toJson());
      return newQuestion;
    } catch (e) {
      throw Exception('Failed to create question: $e');
    }
  }

  // User Progress Management
  Future<List<UserStudyProgress>> getUserProgress(String userId) async {
    try {
      final response = await _supabase
          .from('user_study_progress')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false);

      return response
          .map<UserStudyProgress>((json) => UserStudyProgress.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch user progress: $e');
    }
  }

  Future<UserStudyProgress?> getUserStudyProgress(
      String userId, String studyGuideId) async {
    try {
      final response = await _supabase
          .from('user_study_progress')
          .select()
          .eq('user_id', userId)
          .eq('study_guide_id', studyGuideId)
          .single();

      return UserStudyProgress.fromJson(response);
    } catch (e) {
      return null;
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

      await _supabase.from('user_study_progress').insert(progress.toJson());
      return progress;
    } catch (e) {
      throw Exception('Failed to start study guide: $e');
    }
  }

  Future<UserStudyProgress> updateStudyProgress(
      UserStudyProgress progress) async {
    try {
      final updatedProgress = progress.copyWith(updatedAt: DateTime.now());

      await _supabase
          .from('user_study_progress')
          .update(updatedProgress.toJson())
          .eq('id', progress.id);

      return updatedProgress;
    } catch (e) {
      throw Exception('Failed to update study progress: $e');
    }
  }

  Future<UserStudyProgress> completeStudyGuide(
      String userId, String studyGuideId) async {
    try {
      final progress = await getUserStudyProgress(userId, studyGuideId);
      if (progress == null) {
        throw Exception('Study progress not found');
      }

      final completedProgress = progress.copyWith(
        status: StudyStatus.completed,
        completedAt: DateTime.now(),
        progressPercentage: 100.0,
        updatedAt: DateTime.now(),
      );

      await _supabase
          .from('user_study_progress')
          .update(completedProgress.toJson())
          .eq('id', progress.id);

      return completedProgress;
    } catch (e) {
      throw Exception('Failed to complete study guide: $e');
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

      final response = await _supabase
          .from('user_lesson_progress')
          .select()
          .eq('user_id', userId)
          .inFilter('lesson_id', lessonIds)
          .order('created_at');

      return response
          .map<UserLessonProgress>((json) => UserLessonProgress.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch lesson progress: $e');
    }
  }

  Future<UserLessonProgress?> getUserLessonProgressById(
      String userId, String lessonId) async {
    try {
      final response = await _supabase
          .from('user_lesson_progress')
          .select()
          .eq('user_id', userId)
          .eq('lesson_id', lessonId)
          .single();

      return UserLessonProgress.fromJson(response);
    } catch (e) {
      return null;
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

      await _supabase.from('user_lesson_progress').insert(progress.toJson());
      return progress;
    } catch (e) {
      throw Exception('Failed to start lesson: $e');
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

      await _supabase
          .from('user_lesson_progress')
          .update(updatedProgress.toJson())
          .eq('id', progress.id);

      return updatedProgress;
    } catch (e) {
      throw Exception('Failed to save answer: $e');
    }
  }

  Future<UserLessonProgress> completeLesson(String userId, String lessonId,
      {double? score}) async {
    try {
      final progress = await getUserLessonProgressById(userId, lessonId);
      if (progress == null) {
        throw Exception('Lesson progress not found');
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

      await _supabase
          .from('user_lesson_progress')
          .update(completedProgress.toJson())
          .eq('id', progress.id);

      // Update overall study guide progress
      await _updateStudyGuideProgress(userId, lessonId);

      return completedProgress;
    } catch (e) {
      throw Exception('Failed to complete lesson: $e');
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
      dynamic query = _supabase.from('study_sessions').select();

      if (facilitatorId != null) {
        query = query.eq('facilitator_id', facilitatorId);
      }

      if (participantIds != null && participantIds.isNotEmpty) {
        query = query.overlaps('participant_ids', participantIds);
      }

      if (startDate != null) {
        query = query.gte('scheduled_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('scheduled_at', endDate.toIso8601String());
      }

      if (status != null) {
        query = query.eq('status', status.name);
      }

      query = query.order('scheduled_at');

      final response = await query;
      return response
          .map<StudySession>((json) => StudySession.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch study sessions: $e');
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

      await _supabase.from('study_sessions').insert(newSession.toJson());
      return newSession;
    } catch (e) {
      throw Exception('Failed to create study session: $e');
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
      throw Exception('Failed to get study statistics: $e');
    }
  }

  // Helper Methods
  Future<void> _updateStudyGuideProgress(String userId, String lessonId) async {
    try {
      final lesson = await getLessonById(lessonId);
      if (lesson == null) return;

      final studyGuideProgress =
          await getUserStudyProgress(userId, lesson.studyGuideId);
      if (studyGuideProgress == null) return;

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
      // Log error but don't throw to avoid breaking lesson completion
      _logger.error('Error updating study guide progress', e);
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
