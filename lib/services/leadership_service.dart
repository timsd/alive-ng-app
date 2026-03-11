// Removed supabase_flutter import - using Firebase now
import '../models/leadership_models.dart';
import 'package:uuid/uuid.dart';
import 'auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';

class LeadershipService {
  static final LeadershipService _instance = LeadershipService._internal();
  factory LeadershipService() => _instance;
  LeadershipService._internal();

  static final Logger _logger = Logger('LeadershipService');
  final AuthService _authService = AuthService.instance;
  final Uuid _uuid = const Uuid();

  // Get current user's leadership records
  Future<List<LeadershipRecord>> getCurrentUserRecords() async {
    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) throw AuthException('User not authenticated');

      final querySnapshot = await FirebaseFirestore.instance
          .collection('leadership_records')
          .where('user_id', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return LeadershipRecord.fromJson(data);
      }).toList();
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Failed to fetch leadership records', e);
      throw DatabaseException('Failed to fetch leadership records',
          originalError: e);
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
      Query<Map<String, dynamic>> query =
          FirebaseFirestore.instance.collection('leadership_records');

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      if (position != null) {
        query = query.where('position', isEqualTo: position.name);
      }

      query = query.orderBy('created_at', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return LeadershipRecord.fromJson(data);
      }).toList();
    } catch (e) {
      _logger.error('Failed to fetch all leadership records', e);
      throw DatabaseException('Failed to fetch all leadership records',
          originalError: e);
    }
  }

  // Convenience: Get active leadership records
  Future<List<LeadershipRecord>> getActiveRecords({
    LeadershipPosition? position,
    int? limit,
    int? offset,
  }) async {
    return getAllRecords(
      status: ServiceStatus.active,
      position: position,
      limit: limit,
      offset: offset,
    );
  }

  // Convenience: Get archived leadership records
  Future<List<LeadershipRecord>> getArchivedRecords({
    LeadershipPosition? position,
    int? limit,
    int? offset,
  }) async {
    return getAllRecords(
      status: ServiceStatus.archived,
      position: position,
      limit: limit,
      offset: offset,
    );
  }

  // Get leadership record by ID
  Future<LeadershipRecord?> getRecordById(String recordId) async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('leadership_records')
          .doc(recordId)
          .get();

      if (!docSnapshot.exists) return null;

      final data = docSnapshot.data()!;
      data['id'] = docSnapshot.id;
      return LeadershipRecord.fromJson(data);
    } catch (e) {
      _logger.error('Failed to fetch leadership record', e);
      throw DatabaseException('Failed to fetch leadership record',
          originalError: e);
    }
  }

  // Create new leadership record
  Future<LeadershipRecord> createRecord(LeadershipRecord record) async {
    try {
      final currentUserId = _authService.currentUser?.uid;
      if (currentUserId == null) throw AuthException('User not authenticated');

      final recordData = record.toJson();
      recordData['id'] = _uuid.v4();
      recordData['user_id'] = currentUserId;
      recordData['created_at'] = DateTime.now().toIso8601String();
      recordData['updated_at'] = DateTime.now().toIso8601String();
      recordData['status'] = ServiceStatus.pending.name;

      final docRef = await FirebaseFirestore.instance
          .collection('leadership_records')
          .add(recordData);

      recordData['id'] = docRef.id;
      return LeadershipRecord.fromJson(recordData);
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Failed to create leadership record', e);
      throw DatabaseException('Failed to create leadership record',
          originalError: e);
    }
  }

  // Update leadership record
  Future<LeadershipRecord> updateRecord(
      String recordId, Map<String, dynamic> updates) async {
    try {
      final currentUserId = _authService.currentUser?.uid;
      if (currentUserId == null) throw AuthException('User not authenticated');

      updates['updated_at'] = DateTime.now().toIso8601String();
      updates['updated_by'] = currentUserId;

      await FirebaseFirestore.instance
          .collection('leadership_records')
          .doc(recordId)
          .update(updates);

      // Get updated record
      final docSnapshot = await FirebaseFirestore.instance
          .collection('leadership_records')
          .doc(recordId)
          .get();

      if (!docSnapshot.exists) {
        throw NotFoundException('Record not found after update');
      }

      final data = docSnapshot.data()!;
      data['id'] = docSnapshot.id;
      return LeadershipRecord.fromJson(data);
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Failed to update leadership record', e);
      throw DatabaseException('Failed to update leadership record',
          originalError: e);
    }
  }

  // Delete leadership record
  Future<void> deleteRecord(String recordId) async {
    try {
      await FirebaseFirestore.instance
          .collection('leadership_records')
          .doc(recordId)
          .delete();
    } catch (e) {
      _logger.error('Failed to delete leadership record', e);
      throw DatabaseException('Failed to delete leadership record',
          originalError: e);
    }
  }

  // Get records by chapter
  Future<List<LeadershipRecord>> getRecordsByChapter(String chapterId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('leadership_records')
          .where('chapter_id', isEqualTo: chapterId)
          .orderBy('created_at', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return LeadershipRecord.fromJson(data);
      }).toList();
    } catch (e) {
      throw DatabaseException('Failed to fetch chapter leadership records',
          originalError: e);
    }
  }

  // Get records by position
  Future<List<LeadershipRecord>> getRecordsByPosition(
      LeadershipPosition position) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('leadership_records')
          .where('position', isEqualTo: position.name)
          .orderBy('created_at', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return LeadershipRecord.fromJson(data);
      }).toList();
    } catch (e) {
      throw DatabaseException('Failed to fetch position leadership records',
          originalError: e);
    }
  }

  // Approve leadership record
  Future<LeadershipRecord> approveRecord(String recordId,
      {String? notes}) async {
    try {
      final currentUserId = _authService.currentUser?.uid;
      if (currentUserId == null) throw AuthException('User not authenticated');

      final updates = {
        'status': ServiceStatus.approved.name,
        'approved_by': currentUserId,
        'approved_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': currentUserId,
      };

      if (notes != null) {
        updates['approval_notes'] = notes;
      }

      await FirebaseFirestore.instance
          .collection('leadership_records')
          .doc(recordId)
          .update(updates);

      // Get updated record
      final docSnapshot = await FirebaseFirestore.instance
          .collection('leadership_records')
          .doc(recordId)
          .get();

      if (!docSnapshot.exists) {
        throw NotFoundException('Record not found after update');
      }

      final data = docSnapshot.data()!;
      data['id'] = docSnapshot.id;
      return LeadershipRecord.fromJson(data);
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('Failed to approve leadership record',
          originalError: e);
    }
  }

  // Reject leadership record
  Future<LeadershipRecord> rejectRecord(String recordId,
      {String? reason}) async {
    try {
      final currentUserId = _authService.currentUser?.uid;
      if (currentUserId == null) throw AuthException('User not authenticated');

      final updates = {
        'status': ServiceStatus.rejected.name,
        'rejected_by': currentUserId,
        'rejected_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': currentUserId,
      };

      if (reason != null) {
        updates['rejection_reason'] = reason;
      }

      await FirebaseFirestore.instance
          .collection('leadership_records')
          .doc(recordId)
          .update(updates);

      // Get updated record
      final docSnapshot = await FirebaseFirestore.instance
          .collection('leadership_records')
          .doc(recordId)
          .get();

      if (!docSnapshot.exists) {
        throw NotFoundException('Record not found after update');
      }

      final data = docSnapshot.data()!;
      data['id'] = docSnapshot.id;
      return LeadershipRecord.fromJson(data);
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('Failed to reject leadership record',
          originalError: e);
    }
  }

  // Complete leadership service
  Future<LeadershipRecord> completeService(String recordId,
      {String? completionNotes}) async {
    try {
      final currentUserId = _authService.currentUser?.uid;
      if (currentUserId == null) throw AuthException('User not authenticated');

      // Get current record before completion for transition tracking
      final currentRecord = await getRecordById(recordId);

      final updates = {
        'status': ServiceStatus.completed.name,
        'completed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': currentUserId,
      };

      if (completionNotes != null) {
        updates['completion_notes'] = completionNotes;
      }

      await FirebaseFirestore.instance
          .collection('leadership_records')
          .doc(recordId)
          .update(updates);

      // Record the leadership transition
      if (currentRecord != null) {
        await recordLeadershipTransition(LeadershipTransition(
          id: _uuid.v4(),
          userId: currentRecord.userId,
          fromPosition: currentRecord.position,
          toPosition: currentRecord.position,
          fromPositionTitle: currentRecord.positionTitle,
          toPositionTitle: currentRecord.positionTitle,
          transitionDate: DateTime.now(),
          reason: completionNotes ?? 'Service completed',
          approvedBy: currentUserId,
          createdAt: DateTime.now(),
        ));
      }

      // Get updated record
      final docSnapshot = await FirebaseFirestore.instance
          .collection('leadership_records')
          .doc(recordId)
          .get();

      if (!docSnapshot.exists) {
        throw NotFoundException('Record not found after update');
      }

      final data = docSnapshot.data()!;
      data['id'] = docSnapshot.id;
      return LeadershipRecord.fromJson(data);
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('Failed to complete leadership service',
          originalError: e);
    }
  }

  // Archive leadership record
  Future<LeadershipRecord> archiveRecord(String recordId) async {
    try {
      final currentUserId = _authService.currentUser?.uid;
      if (currentUserId == null) throw AuthException('User not authenticated');

      final updates = {
        'status': ServiceStatus.archived.name,
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': currentUserId,
      };

      await FirebaseFirestore.instance
          .collection('leadership_records')
          .doc(recordId)
          .update(updates);

      // Get updated record
      final docSnapshot = await FirebaseFirestore.instance
          .collection('leadership_records')
          .doc(recordId)
          .get();

      if (!docSnapshot.exists) {
        throw NotFoundException('Record not found after update');
      }

      final data = docSnapshot.data()!;
      data['id'] = docSnapshot.id;
      return LeadershipRecord.fromJson(data);
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('Failed to archive leadership record',
          originalError: e);
    }
  }

  // Get leadership statistics
  Future<Map<String, dynamic>> getLeadershipStatistics(
      {String? chapterId}) async {
    try {
      Query<Map<String, dynamic>> query =
          FirebaseFirestore.instance.collection('leadership_records');

      if (chapterId != null) {
        query = query.where('chapter_id', isEqualTo: chapterId);
      }

      final querySnapshot = await query.get();
      final records = querySnapshot.docs;
      int activeCount = 0;
      int completedCount = 0;
      int archivedCount = 0;
      final positionCounts = <String, int>{};

      for (final doc in records) {
        final data = doc.data();
        final status = (data['status'] as String?) ?? '';
        final position = data['position'] as String?;

        final isActiveLike = status == ServiceStatus.active.name ||
            status == ServiceStatus.approved.name;
        if (isActiveLike) {
          activeCount += 1;
          if (position != null) {
            positionCounts[position] = (positionCounts[position] ?? 0) + 1;
          }
        } else if (status == ServiceStatus.completed.name) {
          completedCount += 1;
        } else if (status == ServiceStatus.archived.name) {
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

  // Search leadership records
  Future<List<LeadershipRecord>> searchRecords(String searchTerm) async {
    try {
      // Note: Firestore doesn't support full-text search natively
      // This is a basic implementation that searches by name
      final querySnapshot = await FirebaseFirestore.instance
          .collection('leadership_records')
          .where('name', isGreaterThanOrEqualTo: searchTerm)
          .where('name', isLessThanOrEqualTo: '$searchTerm\uf8ff')
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return LeadershipRecord.fromJson(data);
      }).toList();
    } catch (e) {
      throw DatabaseException('Failed to search leadership records',
          originalError: e);
    }
  }

  // Get user's active leadership positions
  Future<List<LeadershipRecord>> getUserActivePositions(String userId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('leadership_records')
          .where('user_id', isEqualTo: userId)
          .where('status',
              whereIn: [ServiceStatus.approved.name, ServiceStatus.active.name])
          .orderBy('created_at', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return LeadershipRecord.fromJson(data);
      }).toList();
    } catch (e) {
      throw DatabaseException('Failed to fetch user active positions',
          originalError: e);
    }
  }

  /// Get a comprehensive [LeadershipSummary] for a user, including service
  /// history and transitions.
  Future<LeadershipSummary> getUserLeadershipSummary(String userId) async {
    try {
      // Fetch all records for the user
      final recordsSnapshot = await FirebaseFirestore.instance
          .collection('leadership_records')
          .where('user_id', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .get();

      final records = recordsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return LeadershipRecord.fromJson(data);
      }).toList();

      // Fetch transitions for the user
      final transitionsSnapshot = await FirebaseFirestore.instance
          .collection('leadership_transitions')
          .where('user_id', isEqualTo: userId)
          .orderBy('transition_date', descending: true)
          .get();

      final transitions = transitionsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return LeadershipTransition.fromJson(data);
      }).toList();

      // Determine current position
      final activeRecord = records.where((r) => r.isActive).firstOrNull;
      final userName = records.isNotEmpty ? records.first.userName : '';

      // Calculate total years of service
      int totalYears = 0;
      for (final record in records) {
        totalYears += record.yearsOfService;
      }

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

  /// Record a [LeadershipTransition] when a leader changes positions
  /// or completes service.
  Future<LeadershipTransition> recordLeadershipTransition(
      LeadershipTransition transition) async {
    try {
      final data = transition.toJson();
      final docRef = await FirebaseFirestore.instance
          .collection('leadership_transitions')
          .add(data);

      data['id'] = docRef.id;
      return LeadershipTransition.fromJson(data);
    } catch (e) {
      _logger.error('Failed to record leadership transition', e);
      throw DatabaseException('Failed to record leadership transition',
          originalError: e);
    }
  }

  /// Get transition history for a user.
  Future<List<LeadershipTransition>> getUserTransitions(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('leadership_transitions')
          .where('user_id', isEqualTo: userId)
          .orderBy('transition_date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return LeadershipTransition.fromJson(data);
      }).toList();
    } catch (e) {
      _logger.error('Failed to get user transitions', e);
      throw DatabaseException('Failed to get user transitions',
          originalError: e);
    }
  }
}
