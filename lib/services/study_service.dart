import 'package:appwrite/appwrite.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';

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
      id: json['id']?.toString() ?? '',
      programId: json['program_id']?.toString() ??
          json['study_guide_id']?.toString() ??
          '',
      lessonId: json['lesson_id']?.toString() ??
          json['current_lesson']?.toString() ??
          '',
      completed: json['completed'] == true,
      score: (json['score'] as num?)?.toInt() ?? 0,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
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
  final TablesDB _tables = TablesDB(appwriteClient);
  final _logger = Logger('StudyService');

  // Fetch study progress for a user
  Future<List<StudyProgress>> fetchStudyProgress(String userId) async {
    try {
      final snapshot = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: 'study_progress',
        queries: [
          Query.equal('user_id', userId),
          Query.orderAsc('created_at'),
          Query.limit(200),
        ],
      );

      return snapshot.rows
          .map((doc) => StudyProgress.fromJson({...doc.data, 'id': doc.$id}))
          .toList();
    } catch (e) {
      _logger.error('Error fetching study progress', e);
      throw DatabaseException('Failed to fetch study progress',
          originalError: e);
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
      final docId = '${userId}_${programId}_$lessonId';
      final now = DateTime.now().toUtc().toIso8601String();

      final progressData = {
        'id': docId,
        'user_id': userId,
        'program_id': programId,
        'study_guide_id': programId,
        'lesson_id': lessonId,
        'completed': completed,
        'score': score ?? 0,
        'completed_at': completed ? now : null,
        'updated_at': now,
        'last_accessed_at': now,
      };

      try {
        final existing = await _tables.getRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: 'study_progress',
          rowId: docId,
        );
        progressData['created_at'] = existing.data['created_at'] ?? now;
        await _tables.updateRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: 'study_progress',
          rowId: docId,
          data: progressData,
        );
      } on AppwriteException catch (e) {
        if (e.code != 404) rethrow;
        progressData['created_at'] = now;
        await _tables.createRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: 'study_progress',
          rowId: docId,
          data: progressData,
        );
      }

      return StudyProgress.fromJson(progressData);
    } catch (e) {
      _logger.error('Error updating lesson progress', e);
      throw DatabaseException('Failed to update lesson progress',
          originalError: e);
    }
  }

  // Get progress for a specific program
  Future<List<StudyProgress>> getProgramProgress(
      String userId, String programId) async {
    try {
      final snapshot = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: 'study_progress',
        queries: [
          Query.equal('user_id', userId),
          Query.equal('program_id', programId),
          Query.orderAsc('created_at'),
          Query.limit(200),
        ],
      );

      return snapshot.rows
          .map((doc) => StudyProgress.fromJson({...doc.data, 'id': doc.$id}))
          .toList();
    } catch (e) {
      _logger.error('Error fetching program progress', e);
      throw DatabaseException('Failed to fetch program progress',
          originalError: e);
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
      _logger.error('Error calculating program completion', e);
      throw DatabaseException('Failed to calculate program completion',
          originalError: e);
    }
  }

  // Get average score for a program
  Future<double> getAverageScore(String userId, String programId) async {
    try {
      final progress = await getProgramProgress(userId, programId);
      final completedLessons = progress.where((p) => p.completed).toList();

      if (completedLessons.isEmpty) return 0.0;

      final totalScore =
          completedLessons.fold<int>(0, (acc, p) => acc + p.score);
      return totalScore / completedLessons.length;
    } catch (e) {
      _logger.error('Error calculating average score', e);
      throw DatabaseException('Failed to calculate average score',
          originalError: e);
    }
  }

  // Reset progress for a lesson
  Future<void> resetLessonProgress(
      String userId, String programId, String lessonId) async {
    try {
      final docId = '${userId}_${programId}_$lessonId';
      try {
        await _tables.deleteRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: 'study_progress',
          rowId: docId,
        );
      } on AppwriteException catch (e) {
        if (e.code != 404) rethrow;
      }
    } catch (e) {
      _logger.error('Error resetting lesson progress', e);
      throw DatabaseException('Failed to reset lesson progress',
          originalError: e);
    }
  }
}
