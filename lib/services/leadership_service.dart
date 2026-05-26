import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:uuid/uuid.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../models/leadership_models.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';
import 'auth_service.dart';

class LeadershipService {
  static final LeadershipService _instance = LeadershipService._internal();
  factory LeadershipService() => _instance;
  LeadershipService._internal();

  static final Logger _logger = Logger('LeadershipService');
  final AuthService _authService = AuthService.instance;
  final TablesDB _tables = TablesDB(appwriteClient);
  final Uuid _uuid = const Uuid();

  static const _recordsCollection =
      AppwriteBackendConfig.leadershipRecordsCollectionId;
  static const _transitionsCollection =
      AppwriteBackendConfig.leadershipTransitionsCollectionId;

  Future<List<LeadershipRecord>> getCurrentUserRecords() async {
    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) throw AuthException('User not authenticated');

      return _listRecords([
        Query.equal('user_id', userId),
        Query.orderDesc('created_at'),
      ]);
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Failed to fetch leadership records', e);
      throw DatabaseException('Failed to fetch leadership records',
          originalError: e);
    }
  }

  Future<List<LeadershipRecord>> getAllRecords({
    ServiceStatus? status,
    LeadershipPosition? position,
    int? limit,
    int? offset,
  }) async {
    try {
      final queries = <String>[Query.orderDesc('created_at')];
      if (status != null) {
        queries.add(Query.equal('status', status.name));
      }
      if (position != null) {
        queries.add(Query.equal('position', position.name));
      }
      if (limit != null) {
        queries.add(Query.limit(limit));
      }
      if (offset != null) {
        queries.add(Query.offset(offset));
      }

      return _listRecords(queries);
    } catch (e) {
      _logger.error('Failed to fetch all leadership records', e);
      throw DatabaseException('Failed to fetch all leadership records',
          originalError: e);
    }
  }

  Future<List<LeadershipRecord>> getActiveRecords({
    LeadershipPosition? position,
    int? limit,
    int? offset,
  }) {
    return getAllRecords(
      status: ServiceStatus.active,
      position: position,
      limit: limit,
      offset: offset,
    );
  }

  Future<List<LeadershipRecord>> getArchivedRecords({
    LeadershipPosition? position,
    int? limit,
    int? offset,
  }) {
    return getAllRecords(
      status: ServiceStatus.archived,
      position: position,
      limit: limit,
      offset: offset,
    );
  }

  Future<LeadershipRecord?> getRecordById(String recordId) async {
    try {
      final document = await _tables.getRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _recordsCollection,
        rowId: recordId,
      );

      return _recordFromDocument(document);
    } on AppwriteException catch (e) {
      if (e.code == 404) return null;
      _logger.error('Failed to fetch leadership record', e);
      throw DatabaseException('Failed to fetch leadership record',
          originalError: e);
    } catch (e) {
      _logger.error('Failed to fetch leadership record', e);
      throw DatabaseException('Failed to fetch leadership record',
          originalError: e);
    }
  }

  Future<LeadershipRecord> createRecord(LeadershipRecord record) async {
    try {
      final currentUserId = _authService.currentUser?.uid;
      if (currentUserId == null) throw AuthException('User not authenticated');

      final now = DateTime.now().toUtc();
      final id = _uuid.v4();
      final data = _recordToAppwriteData(record.copyWith(
        id: id,
        userId: currentUserId,
        status: ServiceStatus.pending,
        createdAt: now,
        updatedAt: now,
        createdBy: record.createdBy ?? currentUserId,
        updatedBy: currentUserId,
      ));

      final document = await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _recordsCollection,
        rowId: id,
        data: data,
      );

      return _recordFromDocument(document);
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Failed to create leadership record', e);
      throw DatabaseException('Failed to create leadership record',
          originalError: e);
    }
  }

  Future<LeadershipRecord> updateRecord(
      String recordId, Map<String, dynamic> updates) async {
    try {
      final currentUserId = _authService.currentUser?.uid;
      if (currentUserId == null) throw AuthException('User not authenticated');

      final payload = _normalizeRecordUpdates({
        ...updates,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'updated_by': currentUserId,
      });

      final document = await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _recordsCollection,
        rowId: recordId,
        data: payload,
      );

      return _recordFromDocument(document);
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Failed to update leadership record', e);
      throw DatabaseException('Failed to update leadership record',
          originalError: e);
    }
  }

  Future<void> deleteRecord(String recordId) async {
    try {
      await _tables.deleteRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _recordsCollection,
        rowId: recordId,
      );
    } catch (e) {
      _logger.error('Failed to delete leadership record', e);
      throw DatabaseException('Failed to delete leadership record',
          originalError: e);
    }
  }

  Future<List<LeadershipRecord>> getRecordsByChapter(String chapterId) {
    return _listRecords([
      Query.equal('chapter_id', chapterId),
      Query.orderDesc('created_at'),
    ]);
  }

  Future<List<LeadershipRecord>> getRecordsByPosition(
      LeadershipPosition position) {
    return _listRecords([
      Query.equal('position', position.name),
      Query.orderDesc('created_at'),
    ]);
  }

  Future<LeadershipRecord> approveRecord(String recordId,
      {String? notes}) async {
    final currentUserId = _requireCurrentUserId();
    final updates = <String, dynamic>{
      'status': ServiceStatus.approved.name,
      'approved_by': currentUserId,
      'approved_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'updated_by': currentUserId,
    };
    if (notes != null) updates['approval_notes'] = notes;
    return updateRecord(recordId, updates);
  }

  Future<LeadershipRecord> rejectRecord(String recordId,
      {String? reason}) async {
    final currentUserId = _requireCurrentUserId();
    final updates = <String, dynamic>{
      'status': ServiceStatus.rejected.name,
      'rejected_by': currentUserId,
      'rejected_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'updated_by': currentUserId,
    };
    if (reason != null) updates['rejection_reason'] = reason;
    return updateRecord(recordId, updates);
  }

  Future<LeadershipRecord> completeService(String recordId,
      {String? completionNotes}) async {
    try {
      final currentUserId = _requireCurrentUserId();
      final currentRecord = await getRecordById(recordId);
      final updates = <String, dynamic>{
        'status': ServiceStatus.completed.name,
        'completed_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'updated_by': currentUserId,
      };
      if (completionNotes != null) {
        updates['completion_notes'] = completionNotes;
      }

      final updatedRecord = await updateRecord(recordId, updates);

      if (currentRecord != null) {
        await recordLeadershipTransition(LeadershipTransition(
          id: _uuid.v4(),
          userId: currentRecord.userId,
          fromPosition: currentRecord.position,
          toPosition: currentRecord.position,
          fromPositionTitle: currentRecord.positionTitle,
          toPositionTitle: currentRecord.positionTitle,
          transitionDate: DateTime.now().toUtc(),
          reason: completionNotes ?? 'Service completed',
          approvedBy: currentUserId,
          createdAt: DateTime.now().toUtc(),
        ));
      }

      return updatedRecord;
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('Failed to complete leadership service',
          originalError: e);
    }
  }

  Future<LeadershipRecord> archiveRecord(String recordId) async {
    final currentUserId = _requireCurrentUserId();
    return updateRecord(recordId, {
      'status': ServiceStatus.archived.name,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'updated_by': currentUserId,
    });
  }

  Future<Map<String, dynamic>> getLeadershipStatistics(
      {String? chapterId}) async {
    try {
      final queries = <String>[];
      if (chapterId != null) {
        queries.add(Query.equal('chapter_id', chapterId));
      }
      queries.add(Query.limit(5000));

      final records = await _listRecords(queries);
      int activeCount = 0;
      int completedCount = 0;
      int archivedCount = 0;
      final positionCounts = <String, int>{};

      for (final record in records) {
        if (record.isActive) {
          activeCount += 1;
          positionCounts[record.position.name] =
              (positionCounts[record.position.name] ?? 0) + 1;
        } else if (record.status == ServiceStatus.completed) {
          completedCount += 1;
        } else if (record.status == ServiceStatus.archived) {
          archivedCount += 1;
        }
      }

      return <String, dynamic>{
        'total_records': records.length,
        'active_leaders': activeCount,
        'completed_services': completedCount,
        'archived_records': archivedCount,
        'position_counts': positionCounts,
      };
    } catch (e) {
      throw DatabaseException('Failed to fetch leadership statistics',
          originalError: e);
    }
  }

  Future<List<LeadershipRecord>> searchRecords(String searchTerm) async {
    try {
      final term = searchTerm.trim().toLowerCase();
      if (term.isEmpty) return getAllRecords(limit: 100);

      final records = await getAllRecords(limit: 500);
      return records.where((record) {
        return record.userName.toLowerCase().contains(term) ||
            record.userEmail.toLowerCase().contains(term) ||
            record.positionTitle.toLowerCase().contains(term);
      }).toList();
    } catch (e) {
      throw DatabaseException('Failed to search leadership records',
          originalError: e);
    }
  }

  Future<List<LeadershipRecord>> getUserActivePositions(String userId) async {
    final records = await _listRecords([
      Query.equal('user_id', userId),
      Query.orderDesc('created_at'),
    ]);
    return records.where((record) => record.isActive).toList();
  }

  Future<LeadershipSummary> getUserLeadershipSummary(String userId) async {
    try {
      final records = await _listRecords([
        Query.equal('user_id', userId),
        Query.orderDesc('created_at'),
      ]);
      final transitions = await getUserTransitions(userId);
      final activeRecord = records.where((r) => r.isActive).firstOrNull;
      final userName = records.isNotEmpty ? records.first.userName : '';
      final totalYears = records.fold<int>(
        0,
        (total, record) => total + record.yearsOfService,
      );

      return LeadershipSummary(
        userId: userId,
        userName: userName,
        currentPosition: activeRecord?.position,
        currentPositionTitle: activeRecord?.positionTitle,
        currentPositionStartDate: activeRecord?.startDate,
        serviceHistory: records,
        totalYearsOfService: totalYears,
        totalPositionsHeld: records.length,
        transitions: transitions,
      );
    } catch (e) {
      _logger.error('Failed to get user leadership summary', e);
      throw DatabaseException('Failed to get user leadership summary',
          originalError: e);
    }
  }

  Future<LeadershipTransition> recordLeadershipTransition(
      LeadershipTransition transition) async {
    try {
      final id = transition.id.isNotEmpty ? transition.id : _uuid.v4();
      final document = await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _transitionsCollection,
        rowId: id,
        data: _transitionToAppwriteData(transition),
      );

      return _transitionFromDocument(document);
    } catch (e) {
      _logger.error('Failed to record leadership transition', e);
      throw DatabaseException('Failed to record leadership transition',
          originalError: e);
    }
  }

  Future<List<LeadershipTransition>> getUserTransitions(String userId) async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _transitionsCollection,
        queries: [
          Query.equal('user_id', userId),
          Query.orderDesc('transition_date'),
        ],
      );

      return response.rows.map(_transitionFromDocument).toList();
    } catch (e) {
      _logger.error('Failed to get user transitions', e);
      throw DatabaseException('Failed to get user transitions',
          originalError: e);
    }
  }

  Future<List<LeadershipRecord>> _listRecords(List<String> queries) async {
    final response = await _tables.listRows(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: _recordsCollection,
      queries: queries,
    );
    return response.rows.map(_recordFromDocument).toList();
  }

  LeadershipRecord _recordFromDocument(dynamic document) {
    final data = Map<String, dynamic>.from(document.data as Map);
    data['id'] = document.$id;
    data['contact_info'] = _decodeJsonMap(data['contact_info']);
    return LeadershipRecord.fromJson(data);
  }

  LeadershipTransition _transitionFromDocument(dynamic document) {
    final data = Map<String, dynamic>.from(document.data as Map);
    data['id'] = document.$id;
    return LeadershipTransition.fromJson(data);
  }

  Map<String, dynamic> _recordToAppwriteData(LeadershipRecord record) {
    return _normalizeRecordUpdates(record.toJson())..remove('id');
  }

  Map<String, dynamic> _transitionToAppwriteData(
      LeadershipTransition transition) {
    return Map<String, dynamic>.from(transition.toJson())..remove('id');
  }

  Map<String, dynamic> _normalizeRecordUpdates(Map<String, dynamic> updates) {
    final normalized = <String, dynamic>{};
    for (final entry in updates.entries) {
      if (entry.key == 'id') continue;
      final value = entry.value;
      if (value == null) continue;
      if (entry.key == 'contact_info' && value is Map) {
        normalized[entry.key] = jsonEncode(value);
      } else if (value is DateTime) {
        normalized[entry.key] = value.toUtc().toIso8601String();
      } else if (value is Enum) {
        normalized[entry.key] = value.name;
      } else {
        normalized[entry.key] = value;
      }
    }
    return normalized;
  }

  Map<String, dynamic>? _decodeJsonMap(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is String && value.trim().isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    return null;
  }

  String _requireCurrentUserId() {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) throw AuthException('User not authenticated');
    return currentUserId;
  }
}
