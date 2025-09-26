import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_models.dart';
import '../utils/toast_utils.dart';
import '../utils/logger.dart';

class StudyProgressService {
  static final _supabase = Supabase.instance.client;
  static final _logger = Logger('StudyProgressService');

  static Future<List<StudyProgress>> fetchStudyProgress() async {
    try {
      final user = _supabase.auth.currentUser;
       if (user == null) {
         throw Exception('User not authenticated');
       }

      final response = await _supabase
          .from('study_progress')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => StudyProgress.fromJson(json))
          .toList();
    } catch (error) {
      _logger.error('Error fetching study progress', error);
      ToastUtils.showError('Failed to load study progress');
      return [];
    }
  }

  static Future<bool> updateLessonProgress({
    required String programId,
    required String lessonId,
    required bool completed,
    int? score,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        ToastUtils.showError('Please log in to track your progress');
        return false;
      }

      await _supabase.from('study_progress').upsert({
        'user_id': user.id,
        'program_id': programId,
        'lesson_id': lessonId,
        'completed': completed,
        'score': score ?? 0,
        'completed_at': completed ? DateTime.now().toIso8601String() : null,
      });

      if (completed) {
        final scoreText = score != null ? ' with a score of $score!' : '!';
        ToastUtils.showSuccess('Great job completing this lesson$scoreText');
      }

      return true;
    } catch (error) {
      _logger.error('Error updating study progress', error);
      ToastUtils.showError('Could not save your study progress');
      return false;
    }
  }

  static List<StudyProgress> getProgressForProgram(
    List<StudyProgress> allProgress,
    String programId,
  ) {
    return allProgress.where((p) => p.programId == programId).toList();
  }

  static int getTotalCompletedLessons(List<StudyProgress> allProgress) {
    return allProgress.where((p) => p.progressPercentage >= 100).length;
  }

  static int getTotalScore(List<StudyProgress> allProgress) {
    return allProgress.fold(0, (total, p) => total + p.progressPercentage.round());
  }

  static double getCompletionPercentage(
    List<StudyProgress> allProgress,
    String programId,
    int totalLessons,
  ) {
    final programProgress = getProgressForProgram(allProgress, programId);
    final completedLessons = programProgress.where((p) => p.progressPercentage >= 100).length;
    return totalLessons > 0 ? (completedLessons / totalLessons) * 100 : 0;
  }

  static StudyProgress? getLessonProgress(
    List<StudyProgress> allProgress,
    String programId,
    String lessonId,
  ) {
    try {
      // Convert lessonId to int and compare with currentLesson
      final lessonNumber = int.tryParse(lessonId) ?? 0;
      return allProgress.firstWhere(
        (p) => p.programId == programId && p.currentLesson == lessonNumber,
      );
    } catch (e) {
      return null;
    }
  }

  static Future<bool> resetProgress(String programId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        ToastUtils.showError('Please log in to reset progress');
        return false;
      }

      await _supabase
          .from('study_progress')
          .delete()
          .eq('user_id', user.id)
          .eq('program_id', programId);

      ToastUtils.showSuccess('Progress reset successfully');
      return true;
    } catch (error) {
      _logger.error('Error resetting progress', error);
      ToastUtils.showError('Failed to reset progress');
      return false;
    }
  }

  static Map<String, int> getProgressStats(List<StudyProgress> allProgress) {
    final completed = allProgress.where((p) => p.progressPercentage >= 100).length;
    final inProgress = allProgress.where((p) => p.progressPercentage < 100).length;
    final totalScore = getTotalScore(allProgress);
    final averageScore =
        allProgress.isNotEmpty ? (totalScore / allProgress.length).round() : 0;

    return {
      'completed': completed,
      'inProgress': inProgress,
      'totalScore': totalScore,
      'averageScore': averageScore,
    };
  }
}




