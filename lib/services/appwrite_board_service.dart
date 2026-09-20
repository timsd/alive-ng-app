import 'dart:convert';

import 'package:appwrite/appwrite.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../utils/app_exception.dart';
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

  Future<bool> updateBoardReportStatus(String reportId, String status) async {
    await _tables.updateRow(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: AppwriteBackendConfig.boardReportsCollectionId,
      rowId: reportId,
      data: {
        'status': status,
        'updated_at': _now(),
        if (status == 'reviewed') 'reviewed_at': _now(),
      },
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

  Future<bool> deleteBoardDecision(String decisionId) async {
    try {
      await _tables.deleteRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.boardDecisionsCollectionId,
        rowId: decisionId,
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
        rowId: decisionId,
      );
      final data = _documentData(current);
      final votes = List<Map<String, dynamic>>.from(
        (data['votes'] as List? ?? const []).map(
          (vote) => Map<String, dynamic>.from(vote as Map),
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
        rowId: decisionId,
        data: {
          'votes': jsonEncode(votes),
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
        rowId: data['id']?.toString() ?? ID.unique(),
        data: _writeData(data),
      );
      return doc.$id;
    } catch (e) {
      _logger.error('Failed to create board document', e);
      throw DatabaseException('Failed to create board document',
          originalError: e);
    }
  }

  Map<String, dynamic> _documentData(dynamic document) {
    final data = Map<String, dynamic>.from(document.data as Map);
    return {
      ...data.map((key, value) => MapEntry(key, _readValue(value))),
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

  dynamic _readValue(dynamic value) {
    if (value is! String) return value;
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
}
