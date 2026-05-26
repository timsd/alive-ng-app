import 'dart:convert';

import 'package:appwrite/appwrite.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../utils/logger.dart';

class AppwriteAdminNotificationStore {
  AppwriteAdminNotificationStore._internal()
      : _tables = TablesDB(appwriteClient);

  static final AppwriteAdminNotificationStore instance =
      AppwriteAdminNotificationStore._internal();

  final TablesDB _tables;
  final Logger _logger = Logger('AppwriteAdminNotificationStore');

  Future<void> createNotificationRecord({
    required String type,
    String? title,
    String? message,
    String? userId,
    Map<String, dynamic>? details,
    Map<String, dynamic>? metadata,
    String priority = 'normal',
    bool isRead = false,
  }) async {
    try {
      await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.adminNotificationsCollectionId,
        rowId: ID.unique(),
        data: {
          'type': type,
          if (title != null) 'title': title,
          if (message != null) 'message': message,
          if (userId != null) 'user_id': userId,
          if (details != null) 'details': jsonEncode(details),
          if (metadata != null) 'metadata': jsonEncode(metadata),
          'is_read': isRead,
          'priority': priority,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
      _logger.info('Notification record stored in Appwrite');
    } catch (error) {
      _logger.error('Failed to store notification record in Appwrite', error);
    }
  }

  Future<List<Map<String, dynamic>>> listNotificationRecords({
    int limit = 50,
  }) async {
    try {
      final snapshot = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.adminNotificationsCollectionId,
        queries: [
          Query.orderDesc('created_at'),
          Query.limit(limit),
        ],
      );

      return snapshot.rows.map((row) {
        final data = Map<String, dynamic>.from(row.data);
        data['id'] = row.$id;
        data['details'] = _decodeJsonMap(data['details']);
        data['metadata'] = _decodeJsonMap(data['metadata']);
        return data;
      }).toList();
    } catch (error) {
      _logger.error('Error getting admin notifications from Appwrite', error);
      return [];
    }
  }

  Map<String, dynamic>? _decodeJsonMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is! String || value.isEmpty) return null;

    final decoded = jsonDecode(value);
    return decoded is Map<String, dynamic> ? decoded : null;
  }
}
