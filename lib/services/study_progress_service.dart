// Removed supabase_flutter import - using Firebase now
import '../models/app_models.dart';
import '../utils/toast_utils.dart';
import '../utils/logger.dart';
import '../utils/app_exception.dart';
import 'auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudyProgressService {
  static final _authService = AuthService.instance;
  static final _logger = Logger('StudyProgressService');
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<List<StudyProgress>> fetchStudyProgress() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw AuthException('User not authenticated');
      }

      // Firebase Firestore query for study_progress collection
      final snapshot = await _firestore
          .collection('study_progress')
          .where('user_id', isEqualTo: user.uid)
          .orderBy('created_at', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return StudyProgress.fromJson(data);
      }).toList();
    } catch (error) {
      _logger.error('Error fetching study progress', error);
      ToastUtils.showError('Failed to load study progress');
      if (error is AppException) rethrow;
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
      final user = _authService.currentUser;
      if (user == null) {
        ToastUtils.showError('Please log in to track your progress');
        return false;
      }

      final docId = '${user.uid}_$programId';
      final docRef = _firestore.collection('study_progress').doc(docId);
      final existing = await docRef.get();

      // Existing values
      int existingCurrentLesson = 0;
      int existingCompletedLessons = 0;
      DateTime? createdAt;
      if (existing.exists) {
        final data = existing.data() as Map<String, dynamic>;
        existingCurrentLesson = (data['current_lesson'] ?? 0) as int;
        existingCompletedLessons = (data['completed_lessons'] ?? 0) as int;
        final createdAtStr = data['created_at'] as String?;
        if (createdAtStr != null) {
          try {
            createdAt = DateTime.parse(createdAtStr);
          } catch (_) {}
        }
      }

      // Parse lesson number from lessonId
      final lessonNumber = int.tryParse(lessonId) ?? existingCurrentLesson;
      final newCurrentLesson = lessonNumber > existingCurrentLesson
          ? lessonNumber
          : existingCurrentLesson;
      final newCompletedLessons =
          existingCompletedLessons + (completed ? 1 : 0);

      // Fetch total lessons for the program to compute percentage
      int totalLessons = 0;
      try {
        final programDoc =
            await _firestore.collection('study_programs').doc(programId).get();
        if (programDoc.exists) {
          final pData = programDoc.data() as Map<String, dynamic>;
          totalLessons = (pData['total_lessons'] ?? 0) as int;
        }
      } catch (e) {
        _logger.warning(
            'Unable to fetch total lessons for program $programId: $e');
      }

      final progressPercentage =
          totalLessons > 0 ? (newCompletedLessons / totalLessons) * 100 : 0.0;

      final nowIso = DateTime.now().toIso8601String();
      final payload = {
        'id': docId,
        'user_id': user.uid,
        'program_id': programId,
        'current_lesson': newCurrentLesson,
        'completed_lessons': newCompletedLessons,
        'progress_percentage': progressPercentage,
        'last_accessed_at': nowIso,
        'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
        'updated_at': nowIso,
      };

      await docRef.set(payload, SetOptions(merge: true));

      if (completed) {
        final scoreText = score != null ? ' with a score of $score!' : '!';
        ToastUtils.showSuccess('Great job completing this lesson$scoreText');
      }

      return true;
    } catch (error) {
      _logger.error('Error updating study progress', error);
      ToastUtils.showError('Failed to update study progress');
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
    return allProgress.fold(
        0, (total, p) => total + p.progressPercentage.round());
  }

  static double getCompletionPercentage(
    List<StudyProgress> allProgress,
    String programId,
    int totalLessons,
  ) {
    final programProgress = getProgressForProgram(allProgress, programId);
    final completedLessons =
        programProgress.where((p) => p.progressPercentage >= 100).length;
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
      final user = _authService.currentUser;
      if (user == null) {
        ToastUtils.showError('Please log in to reset progress');
        return false;
      }

      // Firebase Firestore delete query for study_progress collection
      // Delete documents where user_id equals user.uid and program_id equals programId
      final query = await _firestore
          .collection('study_progress')
          .where('user_id', isEqualTo: user.uid)
          .where('program_id', isEqualTo: programId)
          .get();

      final batch = _firestore.batch();
      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      ToastUtils.showSuccess('Progress reset successfully');
      return true;
    } catch (error) {
      _logger.error('Error resetting progress', error);
      ToastUtils.showError('Failed to reset progress');
      return false;
    }
  }

  static Map<String, int> getProgressStats(List<StudyProgress> allProgress) {
    final completed =
        allProgress.where((p) => p.progressPercentage >= 100).length;
    final inProgress =
        allProgress.where((p) => p.progressPercentage < 100).length;
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
