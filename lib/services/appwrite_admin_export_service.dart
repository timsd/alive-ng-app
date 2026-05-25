import 'dart:convert';
import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';

class AppwriteAdminExportService {
  AppwriteAdminExportService._();

  static final AppwriteAdminExportService instance =
      AppwriteAdminExportService._();

  final TablesDB _tables = TablesDB(appwriteClient);
  final Storage _storage = Storage(appwriteClient);
  final Logger _logger = Logger('AppwriteAdminExportService');

  static const int _pageSize = 100;

  static const Map<String, String> _collectionIds = {
    'profiles': AppwriteBackendConfig.usersCollectionId,
    'users': AppwriteBackendConfig.usersCollectionId,
    'prayer_requests': AppwriteBackendConfig.prayerRequestsCollectionId,
    'chapters': AppwriteBackendConfig.chaptersCollectionId,
    'notification_settings':
        AppwriteBackendConfig.notificationSettingsCollectionId,
    'notification_history':
        AppwriteBackendConfig.adminNotificationsCollectionId,
  };

  Future<Map<String, dynamic>> exportDataBackup({
    List<String>? collections,
    String format = 'csv',
  }) async {
    final requestedCollections = collections?.isNotEmpty == true
        ? collections!
        : const ['profiles', 'prayer_requests', 'chapters'];
    final normalizedFormat = _normalizeFormat(format);
    final prefix = _exportPrefix('appwrite-backup');
    final files = <String, Map<String, dynamic>>{};

    try {
      for (final collectionName in requestedCollections) {
        final collectionId = _collectionIds[collectionName];
        if (collectionId == null) {
          files[collectionName] = await _uploadExport(
            prefix: prefix,
            fileName: '$collectionName.$normalizedFormat',
            contentType: _contentType(normalizedFormat),
            content: _serializeRows(
              [
                {
                  'collection': collectionName,
                  'skipped': true,
                  'reason': 'No Appwrite collection is configured',
                }
              ],
              normalizedFormat,
            ),
          );
          files[collectionName]!['count'] = 0;
          files[collectionName]!['skipped'] = true;
          continue;
        }

        final rows = await _listAllDocuments(collectionId);
        files[collectionName] = await _uploadExport(
          prefix: prefix,
          fileName: '$collectionName.$normalizedFormat',
          contentType: _contentType(normalizedFormat),
          content: _serializeRows(rows, normalizedFormat),
        );
        files[collectionName]!['count'] = rows.length;
      }

      _logger.info('Exported Appwrite backup prefix: $prefix');
      return {
        'prefix': prefix,
        'files': files,
      };
    } catch (e, stackTrace) {
      _logger.error('Error exporting Appwrite data backup', e, stackTrace);
      throw DatabaseException('Failed to export data backup',
          originalError: e, stackTrace: stackTrace);
    }
  }

  Future<Map<String, dynamic>> exportChatBackup({
    String type = 'messaging',
    Map<String, dynamic>? filter,
  }) async {
    final prefix = _exportPrefix('appwrite-chat-backup');

    try {
      final channels = await _listChatChannels(type: type, filter: filter);
      final file = await _uploadExport(
        prefix: prefix,
        fileName: 'channels.json',
        contentType: 'application/json',
        content: _prettyJson(channels),
      );

      _logger.info(
          'Exported Appwrite chat backup prefix: $prefix, count: ${channels.length}');
      return {
        'prefix': prefix,
        'count': channels.length,
        'file': file,
      };
    } catch (e, stackTrace) {
      _logger.error('Error exporting Appwrite chat backup', e, stackTrace);
      throw DatabaseException('Failed to export chat backup',
          originalError: e, stackTrace: stackTrace);
    }
  }

  Future<Map<String, dynamic>> exportChatMessages({
    String type = 'messaging',
    Map<String, dynamic>? filter,
    int limitPerChannel = 500,
  }) async {
    final prefix = _exportPrefix('appwrite-chat-messages');

    try {
      final channels = await _listChatChannels(type: type, filter: filter);
      final files = <Map<String, dynamic>>[];

      for (final channel in channels) {
        final channelId = channel['id']?.toString() ?? '';
        if (channelId.isEmpty) continue;

        final messages = await _listChannelMessages(
          channelId,
          limit: limitPerChannel,
        );
        final file = await _uploadExport(
          prefix: prefix,
          fileName: '${_safeFileName(channelId)}.json',
          contentType: 'application/json',
          content: _prettyJson(messages),
        );
        files.add({
          'cid': '${channel['type'] ?? type}:$channelId',
          'channel_id': channelId,
          'count': messages.length,
          ...file,
        });
      }

      _logger.info(
          'Exported Appwrite chat messages prefix: $prefix, files: ${files.length}');
      return {
        'prefix': prefix,
        'files': files,
      };
    } catch (e, stackTrace) {
      _logger.error('Error exporting Appwrite chat messages', e, stackTrace);
      throw DatabaseException('Failed to export chat messages',
          originalError: e, stackTrace: stackTrace);
    }
  }

  Future<List<Map<String, dynamic>>> _listChatChannels({
    required String type,
    Map<String, dynamic>? filter,
  }) async {
    final queries = <String>[
      if (type.isNotEmpty) Query.equal('type', type),
    ];
    final isArchived = filter?['is_archived'];
    if (isArchived is bool) {
      queries.add(Query.equal('is_archived', isArchived));
    }
    return _listAllDocuments(
      AppwriteBackendConfig.chatChannelsCollectionId,
      baseQueries: queries,
    );
  }

  Future<List<Map<String, dynamic>>> _listChannelMessages(
    String channelId, {
    required int limit,
  }) async {
    final response = await _tables.listRows(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: AppwriteBackendConfig.chatMessagesCollectionId,
      queries: [
        Query.equal('channel_id', channelId),
        Query.orderDesc('timestamp'),
        Query.limit(limit),
      ],
    );
    return response.rows.map(_rowData).toList();
  }

  Future<List<Map<String, dynamic>>> _listAllDocuments(
    String collectionId, {
    List<String> baseQueries = const [],
  }) async {
    final documents = <Map<String, dynamic>>[];
    String? cursor;

    while (true) {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: collectionId,
        queries: [
          ...baseQueries,
          Query.limit(_pageSize),
          if (cursor != null) Query.cursorAfter(cursor),
        ],
      );
      if (response.rows.isEmpty) break;

      documents.addAll(response.rows.map(_rowData));
      if (response.rows.length < _pageSize) break;
      cursor = response.rows.last.$id;
    }

    return documents;
  }

  Map<String, dynamic> _rowData(models.Row row) {
    return {
      'id': row.$id,
      ...Map<String, dynamic>.from(row.data),
      'created_at': row.$createdAt,
      'updated_at': row.$updatedAt,
    };
  }

  Future<Map<String, dynamic>> _uploadExport({
    required String prefix,
    required String fileName,
    required String contentType,
    required String content,
  }) async {
    final storageFileName =
        '${_safeFileName(prefix)}_${_safeFileName(fileName)}';
    final file = await _storage.createFile(
      bucketId: AppwriteBackendConfig.systemExportsBucketId,
      fileId: ID.unique(),
      file: InputFile.fromBytes(
        bytes: Uint8List.fromList(utf8.encode(content)),
        filename: storageFileName,
        contentType: contentType,
      ),
    );

    final path = '${AppwriteBackendConfig.systemExportsBucketId}/'
        '$prefix/$fileName';
    return {
      'path': path,
      'file_id': file.$id,
      'url': _downloadUrl(file.$id),
    };
  }

  String _serializeRows(List<Map<String, dynamic>> rows, String format) {
    if (format == 'json') return _prettyJson(rows);
    return _toCsv(rows);
  }

  String _prettyJson(Object value) {
    return const JsonEncoder.withIndent('  ').convert(value);
  }

  String _toCsv(List<Map<String, dynamic>> rows) {
    final columns = <String>{};
    for (final row in rows) {
      columns.addAll(row.keys);
    }
    if (columns.isEmpty) return '';

    final orderedColumns = columns.toList()..sort();
    final buffer = StringBuffer()
      ..writeln(orderedColumns.map(_csvCell).join(','));

    for (final row in rows) {
      buffer.writeln(
        orderedColumns.map((key) => _csvCell(row[key])).join(','),
      );
    }
    return buffer.toString();
  }

  String _csvCell(Object? value) {
    final text = value is String ? value : jsonEncode(value);
    return '"${text.replaceAll('"', '""')}"';
  }

  String _normalizeFormat(String format) {
    final normalized = format.toLowerCase().trim();
    return normalized == 'json' ? 'json' : 'csv';
  }

  String _contentType(String format) {
    return format == 'json' ? 'application/json' : 'text/csv';
  }

  String _exportPrefix(String label) {
    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-');
    return '$label/$stamp';
  }

  String _safeFileName(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  String _downloadUrl(String fileId) {
    return '${AppwriteBackendConfig.endpoint}/storage/buckets/'
        '${AppwriteBackendConfig.systemExportsBucketId}/files/$fileId/download'
        '?project=${AppwriteBackendConfig.projectId}';
  }
}
