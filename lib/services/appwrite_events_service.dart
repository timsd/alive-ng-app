// ignore_for_file: deprecated_member_use

import 'package:appwrite/appwrite.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';

class AppwriteEventsService {
  static final AppwriteEventsService instance = AppwriteEventsService._();

  AppwriteEventsService._();

  late final Databases _databases = Databases(appwriteClient);
  final Logger _logger = Logger('AppwriteEventsService');

  Future<List<Map<String, dynamic>>> listEvents() async {
    try {
      final response = await _databases.listDocuments(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.eventsCollectionId,
        queries: [Query.limit(100)],
      );

      final events = response.documents.map(_documentToMap).toList();
      events.sort(
        (a, b) => _sortDate(b, 'created_at').compareTo(_sortDate(a, 'created_at')),
      );
      return events;
    } catch (e) {
      _logger.error('Failed to load events', e);
      throw DatabaseException('Failed to load events', originalError: e);
    }
  }

  Future<List<Map<String, dynamic>>> listAnnouncements() async {
    try {
      final response = await _databases.listDocuments(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.announcementsCollectionId,
        queries: [Query.limit(100)],
      );

      final announcements = response.documents.map(_documentToMap).toList();
      announcements.sort(
        (a, b) => _sortDate(b, 'created_at').compareTo(_sortDate(a, 'created_at')),
      );
      return announcements;
    } catch (e) {
      _logger.error('Failed to load announcements', e);
      throw DatabaseException('Failed to load announcements', originalError: e);
    }
  }

  Future<void> createEvent({
    required String title,
    required String description,
    required String location,
    required String authorId,
    DateTime? scheduledDate,
  }) async {
    final now = DateTime.now();
    final data = <String, dynamic>{
      'title': title,
      'description': description,
      'location': location,
      'status': 'published',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };
    if (scheduledDate != null) {
      data['scheduled_time'] = scheduledDate.toIso8601String();
      data['event_timestamp'] = scheduledDate.millisecondsSinceEpoch;
    }

    try {
      await _databases.createDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.eventsCollectionId,
        documentId: ID.unique(),
        data: data,
      );
    } catch (e) {
      _logger.error('Failed to create event for $authorId', e);
      throw DatabaseException('Failed to create event', originalError: e);
    }
  }

  Future<void> createAnnouncement({
    required String title,
    required String content,
    required String authorId,
    String audience = 'all',
  }) async {
    final now = DateTime.now();
    try {
      await _databases.createDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.announcementsCollectionId,
        documentId: ID.unique(),
        data: {
          'title': title,
          'content': content.trim().isEmpty ? title : content,
          'author_id': authorId,
          'audience': audience,
          'created_timestamp': now.millisecondsSinceEpoch,
          'published_at': now.toIso8601String(),
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        },
      );
    } catch (e) {
      _logger.error('Failed to create announcement', e);
      throw DatabaseException('Failed to create announcement', originalError: e);
    }
  }

  Map<String, dynamic> _documentToMap(dynamic doc) {
    return {
      ...Map<String, dynamic>.from(doc.data as Map),
      'id': doc.$id,
    };
  }

  DateTime _sortDate(Map<String, dynamic> data, String key) {
    return DateTime.tryParse(data[key]?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }
}
