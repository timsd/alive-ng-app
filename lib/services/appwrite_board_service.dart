import '../utils/appwrite_id_utils.dart';
import 'dart:convert';

import 'package:appwrite/appwrite.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../utils/app_exception.dart';
import '../utils/docx_report_generator.dart';
import '../utils/logger.dart';

class AppwriteBoardService {
  static final AppwriteBoardService instance = AppwriteBoardService._();

  AppwriteBoardService._();

  final TablesDB _tables = TablesDB(appwriteClient);
  final Logger _logger = Logger('AppwriteBoardService');

  Future<List<Map<String, dynamic>>> getBoardReports() async {
    return _list(AppwriteBackendConfig.boardReportsCollectionId);
  }

  Future<bool> addBoardReport(Map<String, dynamic> reportData) async {
    await _create(AppwriteBackendConfig.boardReportsCollectionId, reportData);
    return true;
  }

  Future<String> createBoardReport(Map<String, dynamic> reportData) async {
    return _create(AppwriteBackendConfig.boardReportsCollectionId, reportData);
  }

  Future<bool> deleteBoardReport(String reportId) async {
    try {
      await _tables.deleteRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.boardReportsCollectionId,
        rowId: AppwriteIdUtils.toValidUid(reportId),
      );
      return true;
    } catch (e) {
      _logger.error('Failed to delete board report', e);
      throw DatabaseException('Failed to delete board report',
          originalError: e);
    }
  }

  Future<bool> updateBoardReportStatus(String reportId, String status) async {
    await _tables.updateRow(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: AppwriteBackendConfig.boardReportsCollectionId,
      rowId: AppwriteIdUtils.toValidUid(reportId),
      data: {
        'status': status,
        'updated_at': _now(),
        if (status == 'reviewed') 'reviewed_at': _now(),
      },
    );
    return true;
  }

  Future<bool> updateBoardReportReview({
    required String reportId,
    required String status,
    String? feedback,
    String? reviewerName,
    Map<String, dynamic>? updatedMetadata,
  }) async {
    final updateData = <String, dynamic>{
      'status': status,
      'updated_at': _now(),
      'reviewed_at': _now(),
    };
    if (updatedMetadata != null) {
      updateData['metadata'] = jsonEncode(updatedMetadata);
    }
    await _tables.updateRow(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: AppwriteBackendConfig.boardReportsCollectionId,
      rowId: AppwriteIdUtils.toValidUid(reportId),
      data: updateData,
    );
    return true;
  }

  Future<List<Map<String, dynamic>>> getBoardDecisions() async {
    return _list(AppwriteBackendConfig.boardDecisionsCollectionId);
  }

  Future<List<Map<String, dynamic>>> getBoardDocuments() async {
    return _list(AppwriteBackendConfig.boardDocumentsCollectionId);
  }

  Future<bool> addBoardDocument(Map<String, dynamic> documentData) async {
    await _create(
        AppwriteBackendConfig.boardDocumentsCollectionId, documentData);
    return true;
  }

  Future<bool> addBoardDecision(Map<String, dynamic> decisionData) async {
    await _create(AppwriteBackendConfig.boardDecisionsCollectionId, {
      ...decisionData,
      'status': decisionData['status'] ?? 'proposed',
    });
    return true;
  }

  Future<bool> updateBoardDecisionStatus(
    String decisionId,
    String status, {
    String? resolution,
  }) async {
    try {
      await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.boardDecisionsCollectionId,
        rowId: AppwriteIdUtils.toValidUid(decisionId),
        data: {
          'status': status,
          if (resolution != null) 'resolution': resolution,
          if (status == 'approved' || status == 'rejected')
            'resolved_at': _now(),
          'updated_at': _now(),
        },
      );
      return true;
    } catch (e) {
      _logger.error('Failed to update board decision status', e);
      throw DatabaseException('Failed to update board decision status',
          originalError: e);
    }
  }

  Future<bool> deleteBoardDecision(String decisionId) async {
    try {
      await _tables.deleteRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.boardDecisionsCollectionId,
        rowId: AppwriteIdUtils.toValidUid(decisionId),
      );
      return true;
    } catch (e) {
      _logger.error('Failed to delete board decision', e);
      throw DatabaseException('Failed to delete board decision',
          originalError: e);
    }
  }

  Future<bool> castBoardVote(
    String decisionId,
    Map<String, dynamic> voteData,
  ) async {
    try {
      final current = await _tables.getRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.boardDecisionsCollectionId,
        rowId: AppwriteIdUtils.toValidUid(decisionId),
      );
      final data = _documentData(current);
      final rawVotes = data['votes'];
      List<dynamic> parsedList = const [];
      if (rawVotes is List) {
        parsedList = rawVotes;
      } else if (rawVotes is String && rawVotes.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(rawVotes);
          if (decoded is List) parsedList = decoded;
        } catch (_) {}
      }
      final votes = List<Map<String, dynamic>>.from(
        parsedList.whereType<Map>().map(
          (vote) => Map<String, dynamic>.from(vote),
        ),
      );

      final voterId = voteData['voter_id']?.toString();
      final nextVote = {
        ...voteData,
        'id': voteData['id'] ?? ID.unique(),
        'decision_id': decisionId,
        'voted_at': voteData['voted_at'] ?? _now(),
      };

      final existingIndex = votes.indexWhere(
        (vote) => vote['voter_id']?.toString() == voterId,
      );
      if (existingIndex >= 0) {
        votes[existingIndex] = nextVote;
      } else {
        votes.add(nextVote);
      }

      await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.boardDecisionsCollectionId,
        rowId: AppwriteIdUtils.toValidUid(decisionId),
        data: {
          'votes': jsonEncode(votes),
          if (data['status'] == 'proposed') 'status': 'voting',
          'updated_at': _now(),
        },
      );
      return true;
    } catch (e) {
      _logger.error('Failed to cast board vote', e);
      throw DatabaseException('Failed to cast board vote', originalError: e);
    }
  }

  Future<List<Map<String, dynamic>>> _list(String collectionId) async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: collectionId,
        queries: [Query.orderDesc('created_at'), Query.limit(200)],
      );
      return response.rows.map(_documentData).toList();
    } catch (e) {
      _logger.error('Failed to fetch board collection', e);
      throw DatabaseException('Failed to fetch board data', originalError: e);
    }
  }

  Future<String> _create(String collectionId, Map<String, dynamic> data) async {
    try {
      final doc = await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: collectionId,
        rowId: AppwriteIdUtils.toValidUid(data['id']?.toString() ?? ID.unique()),
        data: _writeData(data),
      );
      return doc.$id;
    } catch (e) {
      _logger.error('Failed to create board document', e);
      throw DatabaseException('Failed to create board document',
          originalError: e);
    }
  }

  static const Set<String> _jsonFieldKeys = {
    'votes',
    'metadata',
    'attachments',
    'tags',
    'agenda_items',
    'attendees',
    'action_items',
    'resolutions',
    'participants',
    'permissions',
    'settings',
    'metrics',
    'data',
    'decisions',
  };

  Map<String, dynamic> _documentData(dynamic document) {
    final data = Map<String, dynamic>.from(document.data as Map);
    return {
      ...data.map((key, value) => MapEntry(key, _readValue(key, value))),
      'id': document.$id,
    };
  }

  Map<String, dynamic> _writeData(Map<String, dynamic> data) {
    final payload = <String, dynamic>{};
    for (final entry in data.entries) {
      final key = switch (entry.key) {
        'authorId' => 'author_id',
        'authorName' => 'author_name',
        'createdAt' => 'created_at',
        'updatedAt' => 'updated_at',
        _ => entry.key,
      };
      payload[key] = entry.value;
    }

    payload
      ..remove('id')
      ..removeWhere((key, value) => key.startsWith(r'$') || value == null);

    payload.putIfAbsent('created_at', _now);
    payload['updated_at'] = _now();

    for (final entry in payload.entries.toList()) {
      final value = entry.value;
      if (value is Map || value is List) {
        payload[entry.key] = jsonEncode(value);
      }
    }
    return payload;
  }

  dynamic _readValue(String key, dynamic value) {
    if (value is! String) return value;
    if (!_jsonFieldKeys.contains(key)) return value;
    final trimmed = value.trim();
    if ((!trimmed.startsWith('{') || !trimmed.endsWith('}')) &&
        (!trimmed.startsWith('[') || !trimmed.endsWith(']'))) {
      return value;
    }
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return value;
    }
  }

  String _now() => DateTime.now().toUtc().toIso8601String();

  /// Resolves member/chapter/location/mission-field details for `.docx` reports.
  Future<Map<String, DocxSenderDetails>> fetchDocxSenderDetails(
    Set<String> userIds,
  ) async {
    final cleanIds = userIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    if (cleanIds.isEmpty) return const {};

    final results = <String, DocxSenderDetails>{};

    DocxSenderDetails mapRow(Map<String, dynamic> data) {
      String pick(List<String> keys) {
        for (final key in keys) {
          final v = data[key]?.toString().trim() ?? '';
          if (v.isNotEmpty) return v;
        }
        return '';
      }

      final city = pick(['city']);
      final state = pick(['state']);
      final fallbackLoc = [city, state].where((s) => s.isNotEmpty).join(', ');

      return DocxSenderDetails(
        name: pick(['full_name', 'fullName', 'display_name', 'displayName', 'name']),
        chapter: pick(['chapter', 'chapter_name', 'chapterName']),
        location: pick(['location', 'address']).isNotEmpty
            ? pick(['location', 'address'])
            : fallbackLoc,
        missionField: pick(['mission_field', 'missionField', 'zone']),
        email: pick(['email']),
        phone: pick(['phone', 'phone_number', 'phoneNumber']),
      );
    }

    try {
      for (var i = 0; i < cleanIds.length; i += 50) {
        final chunk = cleanIds.sublist(i, i + 50 > cleanIds.length ? cleanIds.length : i + 50);
        final res = await _tables.listRows(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.usersCollectionId,
          queries: [
            Query.equal('\$id', chunk),
            Query.limit(chunk.length),
          ],
        );
        for (final row in res.rows) {
          results[row.$id] = mapRow(row.data);
        }
      }
    } catch (e) {
      _logger.warning('Batch sender lookup failed, falling back to per-user fetch: $e');
      for (final id in cleanIds) {
        try {
          final row = await _tables.getRow(
            databaseId: AppwriteBackendConfig.databaseId,
            tableId: AppwriteBackendConfig.usersCollectionId,
            rowId: id,
          );
          results[id] = mapRow(row.data);
        } catch (_) {}
      }
    }

    return results;
  }
}
