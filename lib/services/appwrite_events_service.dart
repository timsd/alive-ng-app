import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _eventsCacheKey = 'appwrite_events_cache_v1';
  static const String _announcementsCacheKey = 'appwrite_announcements_cache_v1';

  Future<List<Event>> listEvents() async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.eventsCollectionId,
        queries: [Query.limit(200)],
      );

      final rawMaps = response.rows
          .where((row) {
            final status = (row.data['status'] ?? '').toString().toLowerCase();
            return status != 'draft' && status != 'archived';
          })
          .map((row) => {
                ...Map<String, dynamic>.from(row.data),
                'id': row.$id,
              })
          .toList();

      await _saveCache(_eventsCacheKey, rawMaps);
      final events = rawMaps.map(Event.fromJson).toList();
      events.sort((a, b) => b.sortDate.compareTo(a.sortDate));
      return events;
    } catch (e) {
      final cached = await _loadCache(_eventsCacheKey);
      if (cached != null) {
        final events = cached.map(Event.fromJson).toList();
        events.sort((a, b) => b.sortDate.compareTo(a.sortDate));
        return events;
      }
      _logger.error('Failed to load events', e);
      throw DatabaseException('Failed to load events', originalError: e);
    }
  }

  Future<List<Announcement>> listAnnouncements() async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.announcementsCollectionId,
        queries: [Query.limit(200)],
      );

      final now = DateTime.now();
      final rawMaps = response.rows
          .where((row) {
            if (row.data['is_active'] == false) return false;
            final expiresRaw = row.data['expires_at']?.toString();
            if (expiresRaw != null && expiresRaw.isNotEmpty) {
              final expiresAt = DateTime.tryParse(expiresRaw);
              if (expiresAt != null && expiresAt.isBefore(now)) return false;
            }
            return true;
          })
          .map((row) => {
                ...Map<String, dynamic>.from(row.data),
                'id': row.$id,
              })
          .toList();

      await _saveCache(_announcementsCacheKey, rawMaps);
      final announcements = rawMaps.map(Announcement.fromJson).toList();
      announcements.sort((a, b) => b.sortDate.compareTo(a.sortDate));
      return announcements;
    } catch (e) {
      final cached = await _loadCache(_announcementsCacheKey);
      if (cached != null) {
        final announcements = cached.map(Announcement.fromJson).toList();
        announcements.sort((a, b) => b.sortDate.compareTo(a.sortDate));
        return announcements;
      }
      _logger.error('Failed to load announcements', e);
      throw DatabaseException('Failed to load announcements', originalError: e);
    }
  }

  Future<void> _saveCache(String key, List<Map<String, dynamic>> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(items));
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>?> _loadCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } catch (_) {
      return null;
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
}
