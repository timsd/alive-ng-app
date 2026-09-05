import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../models/event_models.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';

class AppwriteEventsService {
  static final AppwriteEventsService instance = AppwriteEventsService._();

  AppwriteEventsService._();

  late final TablesDB _tables = TablesDB(appwriteClient);
  final Logger _logger = Logger('AppwriteEventsService');

  Future<List<Event>> listEvents() async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.eventsCollectionId,
        queries: [Query.limit(100)],
      );

      final events = response.rows.map(_rowToEvent).toList();
      events.sort((a, b) => b.sortDate.compareTo(a.sortDate));
      return events;
    } catch (e) {
      _logger.error('Failed to load events', e);
      throw DatabaseException('Failed to load events', originalError: e);
    }
  }

  Future<List<Announcement>> listAnnouncements() async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.announcementsCollectionId,
        queries: [Query.limit(100)],
      );

      final announcements = response.rows.map(_rowToAnnouncement).toList();
      announcements.sort((a, b) => b.sortDate.compareTo(a.sortDate));
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
      await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.eventsCollectionId,
        rowId: ID.unique(),
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
      await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.announcementsCollectionId,
        rowId: ID.unique(),
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

  Event _rowToEvent(models.Row row) {
    return Event.fromJson({
      ...Map<String, dynamic>.from(row.data),
      'id': row.$id,
    });
  }

  Announcement _rowToAnnouncement(models.Row row) {
    return Announcement.fromJson({
      ...Map<String, dynamic>.from(row.data),
      'id': row.$id,
    });
  }
}
