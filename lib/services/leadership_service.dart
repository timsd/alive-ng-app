import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/leadership_models.dart';
import 'package:uuid/uuid.dart';

class LeadershipService {
  static final LeadershipService _instance = LeadershipService._internal();
  factory LeadershipService() => _instance;
  LeadershipService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  // Get current user's leadership records
  Future<List<LeadershipRecord>> getCurrentUserRecords() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('leadership_records')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => LeadershipRecord.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch leadership records: $e');
    }
  }

  // Get all leadership records (admin only)
  Future<List<LeadershipRecord>> getAllRecords({
    ServiceStatus? status,
    LeadershipPosition? position,
    int? limit,
    int? offset,
  }) async {
    try {
      dynamic query = _supabase.from('leadership_records').select();

      if (status != null) {
        query = query.eq('status', status.name);
      }

      if (position != null) {
        query = query.eq('position', position.name);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      if (offset != null) {
        query = query.range(offset, offset + (limit ?? 50) - 1);
      }

      query = query.order('created_at', ascending: false);

      final response = await query;

      return (response as List)
          .map((json) => LeadershipRecord.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch all leadership records: $e');
    }
  }

  // Get leadership records by user ID
  Future<List<LeadershipRecord>> getRecordsByUserId(String userId) async {
    try {
      final response = await _supabase
          .from('leadership_records')
          .select()
          .eq('user_id', userId)
          .order('start_date', ascending: false);

      return (response as List)
          .map((json) => LeadershipRecord.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch user leadership records: $e');
    }
  }

  // Get active leadership records
  Future<List<LeadershipRecord>> getActiveRecords() async {
    try {
      final response = await _supabase
          .from('leadership_records')
          .select()
          .eq('status', ServiceStatus.active.name)
          .order('start_date', ascending: false);

      return (response as List)
          .map((json) => LeadershipRecord.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch active leadership records: $e');
    }
  }

  // Get archived leadership records (leaders/coordinators only)
  Future<List<LeadershipRecord>> getArchivedRecords() async {
    try {
      final response = await _supabase
          .from('leadership_records')
          .select()
          .eq('status', ServiceStatus.archived.name)
          .order('end_date', ascending: false);

      return (response as List)
          .map((json) => LeadershipRecord.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch archived leadership records: $e');
    }
  }

  // Create new leadership record
  Future<LeadershipRecord> createRecord({
    required String userId,
    required String userName,
    required String userEmail,
    String? userPhone,
    required LeadershipPosition position,
    required String positionTitle,
    required DateTime startDate,
    String? notes,
    Map<String, dynamic>? contactInfo,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');

      final record = LeadershipRecord(
        id: _uuid.v4(),
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        userPhone: userPhone,
        position: position,
        positionTitle: positionTitle,
        startDate: startDate,
        yearsOfService: 0,
        status: ServiceStatus.active,
        notes: notes,
        contactInfo: contactInfo,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: currentUserId,
      );

      await _supabase.from('leadership_records').insert(record.toJson());

      return record;
    } catch (e) {
      throw Exception('Failed to create leadership record: $e');
    }
  }

  // Update leadership record
  Future<LeadershipRecord> updateRecord(
    String recordId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');

      final updatedData = {
        ...updates,
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': currentUserId,
      };

      final response = await _supabase
          .from('leadership_records')
          .update(updatedData)
          .eq('id', recordId)
          .select()
          .single();

      return LeadershipRecord.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update leadership record: $e');
    }
  }

  // Complete leadership service (archive position)
  Future<LeadershipRecord> completeService(
    String recordId, {
    DateTime? endDate,
    String? achievements,
    String? notes,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');

      // Get current record to calculate years of service
      final currentRecord = await getRecordById(recordId);
      final serviceEndDate = endDate ?? DateTime.now();
      final yearsOfService =
          serviceEndDate.difference(currentRecord.startDate).inDays ~/ 365;

      final updates = {
        'end_date': serviceEndDate.toIso8601String(),
        'years_of_service': yearsOfService,
        'status': ServiceStatus.completed.name,
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': currentUserId,
      };

      if (achievements != null) updates['achievements'] = achievements;
      if (notes != null) updates['notes'] = notes;

      final response = await _supabase
          .from('leadership_records')
          .update(updates)
          .eq('id', recordId)
          .select()
          .single();

      return LeadershipRecord.fromJson(response);
    } catch (e) {
      throw Exception('Failed to complete leadership service: $e');
    }
  }

  // Archive leadership record
  Future<LeadershipRecord> archiveRecord(String recordId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');

      final updates = {
        'status': ServiceStatus.archived.name,
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': currentUserId,
      };

      final response = await _supabase
          .from('leadership_records')
          .update(updates)
          .eq('id', recordId)
          .select()
          .single();

      return LeadershipRecord.fromJson(response);
    } catch (e) {
      throw Exception('Failed to archive leadership record: $e');
    }
  }

  // Get leadership record by ID
  Future<LeadershipRecord> getRecordById(String recordId) async {
    try {
      final response = await _supabase
          .from('leadership_records')
          .select()
          .eq('id', recordId)
          .single();

      return LeadershipRecord.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch leadership record: $e');
    }
  }

  // Get leadership summary for a user
  Future<LeadershipSummary> getUserSummary(String userId) async {
    try {
      final records = await getRecordsByUserId(userId);
      final transitions = await getTransitionsByUserId(userId);

      final currentRecord = records.where((r) => r.isActive).firstOrNull;

      final totalYears = records
          .map((r) => r.yearsOfService)
          .fold(0, (sum, years) => sum + years);

      // Get user name from first record or fetch from profiles
      String userName = 'Unknown User';
      if (records.isNotEmpty) {
        userName = records.first.userName;
      } else {
        try {
          final userProfile = await _supabase
              .from('profiles')
              .select('full_name')
              .eq('id', userId)
              .single();
          userName = userProfile['full_name'] ?? 'Unknown User';
        } catch (_) {
          // Ignore error, use default name
        }
      }

      return LeadershipSummary(
        userId: userId,
        userName: userName,
        currentPosition: currentRecord?.position,
        currentPositionTitle: currentRecord?.positionTitle,
        currentPositionStartDate: currentRecord?.startDate,
        serviceHistory: records,
        totalYearsOfService: totalYears,
        totalPositionsHeld: records.length,
        transitions: transitions,
      );
    } catch (e) {
      throw Exception('Failed to fetch leadership summary: $e');
    }
  }

  // Leadership Transitions
  Future<List<LeadershipTransition>> getTransitionsByUserId(
      String userId) async {
    try {
      final response = await _supabase
          .from('leadership_transitions')
          .select()
          .eq('user_id', userId)
          .order('transition_date', ascending: false);

      return (response as List)
          .map((json) => LeadershipTransition.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch leadership transitions: $e');
    }
  }

  // Create leadership transition
  Future<LeadershipTransition> createTransition({
    required String userId,
    LeadershipPosition? fromPosition,
    required LeadershipPosition toPosition,
    String? fromPositionTitle,
    required String toPositionTitle,
    required String reason,
    String? notes,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');

      final transition = LeadershipTransition(
        id: _uuid.v4(),
        userId: userId,
        fromPosition: fromPosition,
        toPosition: toPosition,
        fromPositionTitle: fromPositionTitle,
        toPositionTitle: toPositionTitle,
        transitionDate: DateTime.now(),
        reason: reason,
        notes: notes,
        approvedBy: currentUserId,
        createdAt: DateTime.now(),
      );

      await _supabase
          .from('leadership_transitions')
          .insert(transition.toJson());

      return transition;
    } catch (e) {
      throw Exception('Failed to create leadership transition: $e');
    }
  }

  // Search leadership records
  Future<List<LeadershipRecord>> searchRecords({
    String? query,
    ServiceStatus? status,
    LeadershipPosition? position,
    DateTime? startDateFrom,
    DateTime? startDateTo,
    int? limit,
  }) async {
    try {
      dynamic supabaseQuery = _supabase.from('leadership_records').select();

      if (query != null && query.isNotEmpty) {
        supabaseQuery = supabaseQuery.or(
            'user_name.ilike.%$query%,user_email.ilike.%$query%,position_title.ilike.%$query%');
      }

      if (status != null) {
        supabaseQuery = supabaseQuery.eq('status', status.name);
      }

      if (position != null) {
        supabaseQuery = supabaseQuery.eq('position', position.name);
      }

      if (startDateFrom != null) {
        supabaseQuery =
            supabaseQuery.gte('start_date', startDateFrom.toIso8601String());
      }

      if (startDateTo != null) {
        supabaseQuery =
            supabaseQuery.lte('start_date', startDateTo.toIso8601String());
      }

      if (limit != null) {
        supabaseQuery = supabaseQuery.limit(limit);
      }

      supabaseQuery = supabaseQuery.order('created_at', ascending: false);

      final response = await supabaseQuery;

      return (response as List)
          .map((json) => LeadershipRecord.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to search leadership records: $e');
    }
  }

  // Get leadership statistics
  Future<Map<String, dynamic>> getLeadershipStatistics() async {
    try {
      // Get counts by status
      final activeCountResponse = await _supabase
          .from('leadership_records')
          .select('*')
          .eq('status', ServiceStatus.active.name)
          .count();
      final activeCount = activeCountResponse.count;

      final completedCountResponse = await _supabase
          .from('leadership_records')
          .select('*')
          .eq('status', ServiceStatus.completed.name)
          .count();
      final completedCount = completedCountResponse.count;

      final archivedCountResponse = await _supabase
          .from('leadership_records')
          .select('*')
          .eq('status', ServiceStatus.archived.name)
          .count();
      final archivedCount = archivedCountResponse.count;

      // Get counts by position
      final positionCounts = <String, int>{};
      for (final position in LeadershipPosition.values) {
        final countResponse = await _supabase
            .from('leadership_records')
            .select('*')
            .eq('position', position.name)
            .eq('status', ServiceStatus.active.name)
            .count();
        final count = countResponse.count;
        positionCounts[position.displayName] = count;
      }

      return {
        'active_leaders': activeCount,
        'completed_services': completedCount,
        'archived_records': archivedCount,
        'position_counts': positionCounts,
        'total_records': activeCount + completedCount + archivedCount,
      };
    } catch (e) {
      throw Exception('Failed to fetch leadership statistics: $e');
    }
  }
}
