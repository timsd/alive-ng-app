import 'dart:convert';
import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../config/appwrite_backend_config.dart';
import '../models/donation_report_models.dart';
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
    'donations': AppwriteBackendConfig.donationRecordsCollectionId,
    'donation_records': AppwriteBackendConfig.donationRecordsCollectionId,
    'projects': AppwriteBackendConfig.projectsCollectionId,
    'payment_logs': AppwriteBackendConfig.paymentLogsCollectionId,
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

  /// Retrieve donations for in-app viewing and summary analysis
  Future<List<DonationReportEntry>> listDonationEntries({
    String? status,
    int limit = 250,
  }) async {
    final response = await _tables.listRows(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: AppwriteBackendConfig.donationRecordsCollectionId,
      queries: [
        Query.orderDesc('\$createdAt'),
        Query.limit(limit),
        if (status != null && status.isNotEmpty && status != 'all')
          Query.equal('status', status.toLowerCase()),
      ],
    );
    return response.rows
        .map((row) => DonationReportEntry.fromJson(_rowData(row)))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listDonations({
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    int limit = 100,
  }) async {
    try {
      final queries = <String>[
        Query.orderDesc('\$createdAt'),
        Query.limit(limit),
      ];

      if (status != null &&
          status.isNotEmpty &&
          status.toLowerCase() != 'all') {
        queries.add(Query.equal('status', status.toLowerCase()));
      }

      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.donationRecordsCollectionId,
        queries: queries,
      );

      return response.rows.map(_rowData).toList();
    } catch (e, stackTrace) {
      _logger.error('Error listing donations', e, stackTrace);
      return [];
    }
  }

  /// Generate a detailed donation report (CSV or JSON) and upload to Storage
  Future<Map<String, dynamic>> exportDonationsReport({
    String format = 'csv',
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) async {
    final prefix = _exportPrefix('appwrite-donations-report');
    final normalizedFormat = _normalizeFormat(format);

    try {
      final queries = <String>[
        Query.orderDesc('\$createdAt'),
      ];
      if (status != null &&
          status.isNotEmpty &&
          status.toLowerCase() != 'all') {
        queries.add(Query.equal('status', status.toLowerCase()));
      }

      final rawRows = await _listAllDocuments(
        AppwriteBackendConfig.donationRecordsCollectionId,
        baseQueries: queries,
      );

      // Pre-load project titles so we can resolve project_id → title
      final projectTitleCache = await _loadProjectTitleCache();

      // Filter by date client-side to ensure robustness across timestamp schema variations
      final rows = rawRows.where((r) {
        final dateStr = r['created_at'] ?? r['\$createdAt'];
        if (dateStr == null) return true;
        final dt = DateTime.tryParse(dateStr.toString());
        if (dt == null) return true;
        if (startDate != null && dt.isBefore(startDate)) return false;
        if (endDate != null && dt.isAfter(endDate)) return false;
        return true;
      }).toList();

      double totalAmountNgn = 0;
      double totalAmountUsd = 0;
      int successfulCount = 0;
      int pendingCount = 0;
      int failedCount = 0;
      final Map<String, int> purposeBreakdown = {};

      final formattedRows = rows.map((r) {
        final amountNum = (r['amount'] is num)
            ? (r['amount'] as num).toDouble()
            : (double.tryParse(r['amount']?.toString() ?? '0') ?? 0.0);
        final currency = (r['currency']?.toString().toUpperCase()) ?? 'NGN';
        final rowStatus =
            (r['status']?.toString().toLowerCase()) ?? 'completed';

        // --- Resolve donor name from multiple sources ---
        // Priority: explicit fields → embedded metadata payload → fallback
        final donorName = _resolveDonorName(r);

        // --- Resolve purpose / category ---
        // Priority: mission_purpose → purpose → project_title from metadata →
        //           project_id resolved via cache → fallback
        final purpose = _resolvePurpose(r, projectTitleCache);

        if (rowStatus == 'success' || rowStatus == 'completed') {
          successfulCount++;
          if (currency == 'USD') {
            totalAmountUsd += amountNum;
          } else {
            totalAmountNgn += amountNum;
          }
        } else if (rowStatus == 'failed') {
          failedCount++;
        } else {
          pendingCount++;
        }

        purposeBreakdown[purpose] = (purposeBreakdown[purpose] ?? 0) + 1;

        final isCredit = (rowStatus == 'success' || rowStatus == 'completed');
        final creditStr = isCredit ? amountNum.toStringAsFixed(2) : '0.00';
        final narration = 'DONATION: $purpose - $donorName';

        return {
          'Value Date': r['created_at'] ?? r[r'$createdAt'] ?? '',
          'Transaction Ref': r['reference'] ?? r['transaction_id'] ?? r['id'] ?? '',
          'Narration / Description': narration,
          'Payer / Donor Name': donorName,
          'Payer Email': r['donor_email'] ?? r['user_email'] ?? r['email'] ?? 'N/A',
          'Payer Phone': r['donor_phone'] ?? r['phone'] ?? 'N/A',
          'Payment Channel': r['gateway'] ?? r['channel'] ?? 'Paystack',
          'Currency': currency,
          'Inflow (Credit)': creditStr,
          'Outflow (Debit)': '0.00',
          'Net Inflow': creditStr,
          'Status': rowStatus.toUpperCase(),
          'Purpose / Category': purpose,
          'Settlement Date': r['completed_at'] ?? r['created_at'] ?? r[r'$createdAt'] ?? '',
          'Notes': r['notes'] ?? r['custom_purpose'] ?? '',
        };
      }).toList();

      final String content;
      if (normalizedFormat == 'json') {
        content = _prettyJson({
          'report_metadata': {
            'organization': 'ALIVE Nigeria',
            'account_name': 'ALIVE Nigeria Mission & Donation Ledger',
            'generated_at': DateTime.now().toUtc().toIso8601String(),
            'total_records': rows.length,
            'successful_count': successfulCount,
            'pending_count': pendingCount,
            'failed_count': failedCount,
            'total_amount_ngn': totalAmountNgn,
            'total_amount_usd': totalAmountUsd,
            'purpose_breakdown': purposeBreakdown,
          },
          'donations': formattedRows,
        });
      } else {
        content = _toBankStatementCsv(
          formattedRows,
          totalNgn: totalAmountNgn,
          totalUsd: totalAmountUsd,
          successfulCount: successfulCount,
        );
      }

      final file = await _uploadExport(
        prefix: prefix,
        fileName: 'alive_donations_report.$normalizedFormat',
        contentType: _contentType(normalizedFormat),
        content: content,
      );

      return {
        'prefix': prefix,
        'count': rows.length,
        'summary': {
          'total_ngn': totalAmountNgn,
          'total_usd': totalAmountUsd,
          'successful': successfulCount,
          'pending': pendingCount,
          'failed': failedCount,
        },
        'file': file,
        'content': content,
      };
    } catch (e, stackTrace) {
      _logger.error('Error exporting donations report', e, stackTrace);
      throw DatabaseException('Failed to export donations report',
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
      final content = _prettyJson(channels);
      final file = await _uploadExport(
        prefix: prefix,
        fileName: 'channels.json',
        contentType: 'application/json',
        content: content,
      );

      _logger.info(
          'Exported Appwrite chat backup prefix: $prefix, count: ${channels.length}');
      return {
        'prefix': prefix,
        'count': channels.length,
        'file': file,
        'content': content,
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
    try {
      final queries = <String>[
        if (type.isNotEmpty) Query.equal('type', type),
      ];
      final isArchived = filter?['is_archived'];
      if (isArchived is bool) {
        queries.add(Query.equal('is_archived', isArchived));
      }
      return await _listAllDocuments(
        AppwriteBackendConfig.chatChannelsCollectionId,
        baseQueries: queries,
      );
    } catch (e) {
      // Fallback without server-side filters in case attributes lack database indexes
      final all = await _listAllDocuments(
        AppwriteBackendConfig.chatChannelsCollectionId,
      );
      return all.where((c) {
        if (type.isNotEmpty && c['type'] != null && c['type'] != type) return false;
        if (filter != null && filter.containsKey('is_archived')) {
          if (c['is_archived'] != filter['is_archived']) return false;
        }
        return true;
      }).toList();
    }
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
    try {
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
    } catch (e) {
      _logger.warning('Storage upload unavailable; proceeding with inline export data: $e');
      return {
        'path': '$prefix/$fileName',
        'file_id': null,
        'url': null,
      };
    }
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

  /// Bank-statement-style CSV with official header and standard banking columns
  String _toBankStatementCsv(
    List<Map<String, dynamic>> rows, {
    double totalNgn = 0,
    double totalUsd = 0,
    int successfulCount = 0,
  }) {
    final buffer = StringBuffer();
    // Official Bank Statement Header Block
    buffer.writeln('"ALIVE NIGERIA - OFFICIAL FINANCIAL TRANSACTION & DONATION STATEMENT"');
    buffer.writeln('"Account Name:","ALIVE Nigeria Mission & Donation Ledger"');
    buffer.writeln('"Statement Date:","${DateTime.now().toUtc().toString().split('.').first} UTC"');
    buffer.writeln('"Total Transactions:","${rows.length}"');
    buffer.writeln('"Successful Credits:","$successfulCount"');
    buffer.writeln('"Total Inflow (NGN):","${totalNgn.toStringAsFixed(2)}"');
    if (totalUsd > 0) {
      buffer.writeln('"Total Inflow (USD):","${totalUsd.toStringAsFixed(2)}"');
    }
    buffer.writeln(''); // Empty line separator before data table

    // Standard Bank Statement Table Columns
    const bankColumns = [
      'Value Date',
      'Transaction Ref',
      'Narration / Description',
      'Payer / Donor Name',
      'Payer Email',
      'Payer Phone',
      'Payment Channel',
      'Currency',
      'Inflow (Credit)',
      'Outflow (Debit)',
      'Net Inflow',
      'Status',
      'Purpose / Category',
      'Settlement Date',
      'Notes',
    ];

    buffer.writeln(bankColumns.map(_csvCell).join(','));

    for (final row in rows) {
      buffer.writeln(
        bankColumns.map((key) => _csvCell(row[key])).join(','),
      );
    }
    return buffer.toString();
  }

  /// Resolve the real donor name from multiple data sources.
  /// Checks explicit fields, then embedded metadata/Paystack payload.
  String _resolveDonorName(Map<String, dynamic> r) {
    // 1. Explicit top-level donor fields
    for (final key in [
      'user_name',
      'donor_name',
      'name',
    ]) {
      final val = r[key]?.toString().trim();
      if (val != null && val.isNotEmpty && val != 'Anonymous Donor') {
        return val;
      }
    }

    // 2. Embedded in metadata JSON (Paystack stores donor_name here)
    final meta = _parseMetadataField(r['metadata']);
    if (meta != null) {
      for (final key in ['donor_name', 'customer_name', 'name']) {
        final val = meta[key]?.toString().trim();
        if (val != null && val.isNotEmpty && val != 'Anonymous Donor') {
          return val;
        }
      }
    }

    // 3. Derive from email if available
    final email = (r['donor_email'] ?? r['user_email'] ?? r['email'])
        ?.toString()
        .trim();
    if (email != null && email.isNotEmpty && email.contains('@')) {
      return email.split('@').first;
    }

    return 'Anonymous Donor';
  }

  /// Resolve donation purpose / category, mapping project IDs to real titles.
  String _resolvePurpose(
    Map<String, dynamic> r,
    Map<String, String> projectTitleCache,
  ) {
    // 1. Explicit purpose fields
    for (final key in [
      'mission_purpose',
      'purpose',
      'material_title',
    ]) {
      final val = r[key]?.toString().trim();
      if (val != null && val.isNotEmpty) return val;
    }

    // 2. Check metadata for project_title
    final meta = _parseMetadataField(r['metadata']);
    if (meta != null) {
      final metaTitle = meta['project_title']?.toString().trim();
      if (metaTitle != null && metaTitle.isNotEmpty) return metaTitle;

      // Resolve project_id from metadata
      final metaProjectId = meta['project_id']?.toString().trim();
      if (metaProjectId != null && metaProjectId.isNotEmpty) {
        final resolved = projectTitleCache[metaProjectId];
        if (resolved != null && resolved.isNotEmpty) return resolved;
      }
    }

    // 3. Top-level project_title / project_id
    final topTitle = r['project_title']?.toString().trim();
    if (topTitle != null && topTitle.isNotEmpty) return topTitle;

    final topProjectId = r['project_id']?.toString().trim();
    if (topProjectId != null && topProjectId.isNotEmpty) {
      final resolved = projectTitleCache[topProjectId];
      if (resolved != null && resolved.isNotEmpty) return resolved;
      return topProjectId; // Return raw ID if we can't resolve
    }

    return 'General Donation';
  }

  /// Parse metadata field that could be a JSON string or a Map.
  Map<String, dynamic>? _parseMetadataField(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Load project titles from Appwrite projects collection for ID → title resolution.
  Future<Map<String, String>> _loadProjectTitleCache() async {
    try {
      final rows = await _listAllDocuments(
        AppwriteBackendConfig.projectsCollectionId,
      );
      final cache = <String, String>{};
      for (final row in rows) {
        final id = row['id']?.toString();
        final title = row['title']?.toString();
        if (id != null && title != null && title.isNotEmpty) {
          cache[id] = title;
        }
      }
      return cache;
    } catch (e) {
      _logger.error('Failed to load project title cache', e);
      return {};
    }
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
