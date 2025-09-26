import 'package:supabase_flutter/supabase_flutter.dart';

class StudyProgress {
  final String id;
  final String programId;
  final String lessonId;
  final bool completed;
  final int score;
  final DateTime? completedAt;
  final DateTime createdAt;

  const StudyProgress({
    required this.id,
    required this.programId,
    required this.lessonId,
    required this.completed,
    required this.score,
    this.completedAt,
    required this.createdAt,
  });

  factory StudyProgress.fromJson(Map<String, dynamic> json) {
    return StudyProgress(
      id: json['id'] as String,
      programId: json['program_id'] as String,
      lessonId: json['lesson_id'] as String,
      completed: json['completed'] as bool,
      score: json['score'] as int,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'program_id': programId,
      'lesson_id': lessonId,
      'completed': completed,
      'score': score,
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  StudyProgress copyWith({
    String? id,
    String? programId,
    String? lessonId,
    bool? completed,
    int? score,
    DateTime? completedAt,
    DateTime? createdAt,
  }) {
    return StudyProgress(
      id: id ?? this.id,
      programId: programId ?? this.programId,
      lessonId: lessonId ?? this.lessonId,
      completed: completed ?? this.completed,
      score: score ?? this.score,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class StudyService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Fetch study progress for a user
  Future<List<StudyProgress>> fetchStudyProgress(String userId) async {
    try {
      final response = await _supabase
          .from('study_progress')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => StudyProgress.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch study progress: $e');
    }
  }

  // Update lesson progress
  Future<StudyProgress> updateLessonProgress({
    required String userId,
    required String programId,
    required String lessonId,
    required bool completed,
    int? score,
  }) async {
    try {
      final progressData = {
        'user_id': userId,
        'program_id': programId,
        'lesson_id': lessonId,
        'completed': completed,
        'score': score ?? 0,
        'completed_at': completed ? DateTime.now().toIso8601String() : null,
      };

      final response = await _supabase
          .from('study_progress')
          .upsert(progressData)
          .select()
          .single();

      return StudyProgress.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update lesson progress: $e');
    }
  }

  // Get progress for a specific program
  Future<List<StudyProgress>> getProgramProgress(
      String userId, String programId) async {
    try {
      final response = await _supabase
          .from('study_progress')
          .select('*')
          .eq('user_id', userId)
          .eq('program_id', programId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => StudyProgress.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch program progress: $e');
    }
  }

  // Calculate completion percentage for a program
  Future<double> calculateProgramCompletion(
      String userId, String programId) async {
    try {
      final progress = await getProgramProgress(userId, programId);
      if (progress.isEmpty) return 0.0;

      final completedLessons = progress.where((p) => p.completed).length;
      return (completedLessons / progress.length) * 100;
    } catch (e) {
      throw Exception('Failed to calculate program completion: $e');
    }
  }

  // Get average score for a program
  Future<double> getAverageScore(String userId, String programId) async {
    try {
      final progress = await getProgramProgress(userId, programId);
      final completedLessons = progress.where((p) => p.completed).toList();

      if (completedLessons.isEmpty) return 0.0;

      final totalScore =
          completedLessons.fold<int>(0, (sum, p) => sum + p.score);
      return totalScore / completedLessons.length;
    } catch (e) {
      throw Exception('Failed to calculate average score: $e');
    }
  }

  // Reset progress for a lesson
  Future<void> resetLessonProgress(
      String userId, String programId, String lessonId) async {
    try {
      await _supabase
          .from('study_progress')
          .delete()
          .eq('user_id', userId)
          .eq('program_id', programId)
          .eq('lesson_id', lessonId);
    } catch (e) {
      throw Exception('Failed to reset lesson progress: $e');
    }
  }
}




