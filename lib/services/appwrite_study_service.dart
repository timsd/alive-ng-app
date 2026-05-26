import 'dart:convert';

import 'package:appwrite/appwrite.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../models/app_models.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';

class AppwriteStudyService {
  static final AppwriteStudyService instance = AppwriteStudyService._();

  AppwriteStudyService._();

  late final TablesDB _tables = TablesDB(appwriteClient);
  final Logger _logger = Logger('AppwriteStudyService');

  Future<List<StudyProgram>> getStudyPrograms() async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.studyGuidesCollectionId,
        queries: [
          Query.equal('is_published', true),
          Query.orderDesc('created_at'),
          Query.limit(200),
        ],
      );

      return response.rows.map((row) {
        final data = row.data;
        return StudyProgram(
          id: row.$id,
          title: _string(data['title'], fallback: 'Study Program'),
          description: _string(data['description']),
          category: _string(data['type'], fallback: 'general'),
          difficulty: _string(data['difficulty'], fallback: 'beginner'),
          duration: _int(data['duration']),
          totalLessons: _int(data['lesson_count']),
          imageUrl: _string(data['cover_image_url']),
          createdAt: _date(data['created_at'], fallback: row.$createdAt),
          updatedAt: _date(data['updated_at'], fallback: row.$updatedAt),
        );
      }).toList();
    } catch (e) {
      _logger.error('Failed to fetch study programs', e);
      throw DatabaseException('Failed to fetch study programs',
          originalError: e);
    }
  }

  Future<List<StudyProgress>> getUserStudyProgress(String userId) async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.studyProgressCollectionId,
        queries: [
          Query.equal('user_id', userId),
          Query.orderDesc('last_accessed_at'),
          Query.limit(200),
        ],
      );

      return response.rows.map((row) {
        final data = row.data;
        return StudyProgress(
          id: row.$id,
          userId: _string(data['user_id']),
          programId: _string(
            data['program_id'] ?? data['study_guide_id'],
          ),
          currentLesson: _int(data['current_lesson']),
          completedLessons: _int(data['completed_lessons']),
          progressPercentage: _double(data['progress_percentage']),
          lastAccessedAt:
              _date(data['last_accessed_at'], fallback: row.$updatedAt),
          createdAt: _date(data['created_at'], fallback: row.$createdAt),
          updatedAt: _date(data['updated_at'], fallback: row.$updatedAt),
        );
      }).toList();
    } catch (e) {
      _logger.error('Failed to fetch study progress', e);
      throw DatabaseException('Failed to fetch study progress',
          originalError: e);
    }
  }

  Future<String> createStudyGuide(Map<String, dynamic> data) async {
    try {
      final row = await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.studyGuidesCollectionId,
        rowId: data['id']?.toString() ?? ID.unique(),
        data: _sanitizeWriteData(data),
      );
      return row.$id;
    } catch (e) {
      _logger.error('Failed to create study guide', e);
      throw DatabaseException('Failed to create study guide', originalError: e);
    }
  }

  Future<String> createStudyLesson(Map<String, dynamic> data) async {
    try {
      final row = await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.studyLessonsCollectionId,
        rowId: data['id']?.toString() ?? ID.unique(),
        data: _sanitizeWriteData(data),
      );
      return row.$id;
    } catch (e) {
      _logger.error('Failed to create study lesson', e);
      throw DatabaseException('Failed to create study lesson',
          originalError: e);
    }
  }

  Map<String, dynamic> _sanitizeWriteData(Map<String, dynamic> data) {
    final sanitized = Map<String, dynamic>.from(data)
      ..remove('id')
      ..removeWhere((key, value) => key.startsWith(r'$') || value == null);

    for (final entry in sanitized.entries.toList()) {
      final value = entry.value;
      if (value is Map || value is List) {
        sanitized[entry.key] = jsonEncode(value);
      }
    }

    return sanitized;
  }

  String _string(dynamic value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return fallback;
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _double(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  DateTime _date(dynamic value, {required String fallback}) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.parse(fallback);
    }
    return DateTime.parse(fallback);
  }
}
