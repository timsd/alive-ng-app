// ignore_for_file: deprecated_member_use

import 'package:appwrite/appwrite.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../models/app_models.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';
import '../utils/toast_utils.dart';
import 'auth_service.dart';

class StudyProgressService {
  static final _authService = AuthService.instance;
  static final _logger = Logger('StudyProgressService');
  static final Databases _databases = Databases(appwriteClient);

  static Future<List<StudyProgress>> fetchStudyProgress() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw AuthException('User not authenticated');
      }

      final response = await _databases.listDocuments(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.studyProgressCollectionId,
        queries: [
          Query.equal('user_id', user.uid),
          Query.orderDesc('created_at'),
          Query.limit(200),
        ],
      );

      return response.documents.map((doc) {
        return StudyProgress.fromJson({
          ...doc.data,
          'id': doc.$id,
        });
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
      final existing = await _getProgressDocument(docId);

      var existingCurrentLesson = 0;
      var existingCompletedLessons = 0;
      DateTime? createdAt;
      if (existing != null) {
        existingCurrentLesson = _intValue(existing['current_lesson']);
        existingCompletedLessons = _intValue(existing['completed_lessons']);
        final createdAtStr = existing['created_at'] as String?;
        if (createdAtStr != null) {
          createdAt = DateTime.tryParse(createdAtStr);
        }
      }

      final lessonNumber = int.tryParse(lessonId) ?? existingCurrentLesson;
      final newCurrentLesson = lessonNumber > existingCurrentLesson
          ? lessonNumber
          : existingCurrentLesson;
      final newCompletedLessons =
          existingCompletedLessons + (completed ? 1 : 0);

      final totalLessons = await _getTotalLessons(programId);
      final progressPercentage =
          totalLessons > 0 ? (newCompletedLessons / totalLessons) * 100 : 0.0;

      final nowIso = DateTime.now().toUtc().toIso8601String();
      final payload = {
        'user_id': user.uid,
        'program_id': programId,
        'study_guide_id': programId,
        'current_lesson': newCurrentLesson,
        'completed_lessons': newCompletedLessons,
        'progress_percentage': progressPercentage,
        'last_accessed_at': nowIso,
        'created_at': (createdAt ?? DateTime.now().toUtc()).toIso8601String(),
        'updated_at': nowIso,
      };

      if (existing == null) {
        await _databases.createDocument(
          databaseId: AppwriteBackendConfig.databaseId,
          collectionId: AppwriteBackendConfig.studyProgressCollectionId,
          documentId: docId,
          data: payload,
        );
      } else {
        await _databases.updateDocument(
          databaseId: AppwriteBackendConfig.databaseId,
          collectionId: AppwriteBackendConfig.studyProgressCollectionId,
          documentId: docId,
          data: payload,
        );
      }

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

      final response = await _databases.listDocuments(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.studyProgressCollectionId,
        queries: [
          Query.equal('user_id', user.uid),
          Query.equal('program_id', programId),
          Query.limit(100),
        ],
      );

      for (final doc in response.documents) {
        await _databases.deleteDocument(
          databaseId: AppwriteBackendConfig.databaseId,
          collectionId: AppwriteBackendConfig.studyProgressCollectionId,
          documentId: doc.$id,
        );
      }

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

  static Future<Map<String, dynamic>?> _getProgressDocument(
    String documentId,
  ) async {
    try {
      final doc = await _databases.getDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.studyProgressCollectionId,
        documentId: documentId,
      );
      return doc.data;
    } on AppwriteException catch (error) {
      if (error.code == 404) return null;
      rethrow;
    }
  }

  static Future<int> _getTotalLessons(String programId) async {
    try {
      final doc = await _databases.getDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.studyGuidesCollectionId,
        documentId: programId,
      );
      return _intValue(doc.data['lesson_count'] ?? doc.data['total_lessons']);
    } catch (error) {
      _logger.warning(
          'Unable to fetch total lessons for program $programId: $error');
      return 0;
    }
  }

  static int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
