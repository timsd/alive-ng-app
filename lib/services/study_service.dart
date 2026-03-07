import 'package:cloud_firestore/cloud_firestore.dart';
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _logger = Logger('StudyService');

  // Fetch study progress for a user
  Future<List<StudyProgress>> fetchStudyProgress(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('study_progress')
          .where('user_id', isEqualTo: userId)
          .orderBy('created_at', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => StudyProgress.fromJson(doc.data()))
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
      final docRef = _firestore.collection('study_progress').doc(docId);

      final progressData = {
        'id': docId,
        'user_id': userId,
        'program_id': programId,
        'lesson_id': lessonId,
        'completed': completed,
        'score': score ?? 0,
        'completed_at': completed ? DateTime.now().toIso8601String() : null,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Ensure created_at exists if this is a new document
      final existing = await docRef.get();
      if (!existing.exists) {
        progressData['created_at'] = DateTime.now().toIso8601String();
      } else {
        // keep original created_at if present
        final data = existing.data() as Map<String, dynamic>;
        progressData['created_at'] =
            data['created_at'] ?? DateTime.now().toIso8601String();
      }

      await docRef.set(progressData, SetOptions(merge: true));

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
      final snapshot = await _firestore
          .collection('study_progress')
          .where('user_id', isEqualTo: userId)
          .where('program_id', isEqualTo: programId)
          .orderBy('created_at', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => StudyProgress.fromJson(doc.data()))
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
      await _firestore.collection('study_progress').doc(docId).delete();
    } catch (e) {
      _logger.error('Error resetting lesson progress', e);
      throw DatabaseException('Failed to reset lesson progress',
          originalError: e);
    }
  }
}
