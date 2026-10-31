import 'package:appwrite/appwrite.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../models/app_models.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';
import 'auth_service.dart';

class PrayerRequestsService {
  static final PrayerRequestsService _instance =
      PrayerRequestsService._internal();
  factory PrayerRequestsService() => _instance;
  PrayerRequestsService._internal();
  static PrayerRequestsService get instance => _instance;

  late final TablesDB _tables = TablesDB(appwriteClient);
  final AuthService _authService = AuthService.instance;
  final Logger _logger = Logger('PrayerRequestsService');

  Future<List<PrayerRequest>> fetchPrayerRequests({String? category}) async {
    try {
      final queries = <String>[Query.orderDesc('created_at'), Query.limit(200)];
      if (category != null && category.trim().isNotEmpty) {
        queries.add(Query.equal('category', category.trim()));
      }

      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.prayerRequestsCollectionId,
        queries: queries,
      );

      return response.rows
          .map((doc) => PrayerRequest.fromJson(_documentData(doc)))
          .where((r) => !r.isPrivate)
          .toList();
    } catch (e) {
      _logger.error('Error fetching prayer requests', e);
      throw DatabaseException(
        'Failed to fetch prayer requests',
        originalError: e,
      );
    }
  }

  Future<List<PrayerRequest>> fetchUserPrayerRequests(String userId) async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.prayerRequestsCollectionId,
        queries: [
          Query.equal('user_id', userId),
          Query.orderDesc('created_at'),
          Query.limit(200),
        ],
      );

      return response.rows
          .map((doc) => PrayerRequest.fromJson(_documentData(doc)))
          .toList();
    } catch (e) {
      _logger.error('Error fetching user prayer requests', e);
      throw DatabaseException(
        'Failed to fetch your prayer requests',
        originalError: e,
      );
    }
  }

  Future<List<PrayerRequest>> fetchSupportedPrayerRequests(
      String userId) async {
    try {
      final interactions = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.prayerInteractionsCollectionId,
        queries: [
          Query.equal('user_id', userId),
          Query.equal('type', 'pray'),
          Query.orderDesc('created_at'),
          Query.limit(100),
        ],
      );

      final requestIds = interactions.rows
          .map((doc) => doc.data['request_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      final requests = <PrayerRequest>[];
      for (final id in requestIds) {
        try {
          final doc = await _tables.getRow(
            databaseId: AppwriteBackendConfig.databaseId,
            tableId: AppwriteBackendConfig.prayerRequestsCollectionId,
            rowId: id,
          );
          requests.add(PrayerRequest.fromJson(_documentData(doc)));
        } catch (_) {
          // Ignore deleted or private requests that no longer resolve.
        }
      }
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    } catch (e) {
      _logger.error('Error fetching supported prayer requests', e);
      throw DatabaseException(
        'Failed to fetch prayers you support',
        originalError: e,
      );
    }
  }

  Future<PrayerRequest> createPrayerRequest(PrayerRequest request) async {
    try {
      final currentAppUser = _authService.currentUser;
      final String uid;
      final String? displayName;
      if (currentAppUser != null) {
        uid = currentAppUser.uid;
        displayName = currentAppUser.displayName;
      } else {
        final account = await appwriteAccount.get();
        uid = account.$id;
        displayName = account.name.isEmpty ? null : account.name;
      }
      final now = DateTime.now().toIso8601String();
      final document = await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.prayerRequestsCollectionId,
        rowId: ID.unique(),
        data: {
          'user_id': uid,
          'userId': uid,
          'requested_by': request.isAnonymous
              ? 'Anonymous'
              : (displayName?.trim().isNotEmpty == true
                  ? displayName
                  : 'ALIVE Member'),
          'requestedById': uid,
          'title': request.title,
          'description': request.description,
          'category': request.category,
          'status': 'active',
          'is_anonymous': request.isAnonymous,
          'is_answered': false,
          'is_private': request.isPrivate,
          if (request.roomId != null) 'room_id': request.roomId,
          'prayer_count': 0,
          'created_at': now,
          'updated_at': now,
        },
      );

      return PrayerRequest.fromJson(_documentData(document));
    } catch (e) {
      _logger.error('Error creating prayer request', e);
      throw DatabaseException(
        'Failed to create prayer request',
        originalError: e,
      );
    }
  }

  Future<void> prayForRequest(String requestId, String userId) async {
    try {
      final doc = await _tables.getRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.prayerRequestsCollectionId,
        rowId: requestId,
      );
      final count = (doc.data['prayer_count'] as int?) ?? 0;
      final now = DateTime.now().toIso8601String();

      await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.prayerInteractionsCollectionId,
        rowId: ID.unique(),
        data: {
          'request_id': requestId,
          'user_id': userId,
          'type': 'pray',
          'created_at': now,
        },
      );

      await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.prayerRequestsCollectionId,
        rowId: requestId,
        data: {
          'prayer_count': count + 1,
          'updated_at': now,
        },
      );
    } catch (e) {
      _logger.error('Error praying for request', e);
      throw DatabaseException('Failed to record prayer', originalError: e);
    }
  }

  Future<void> updatePrayerRequest({
    required String id,
    String? title,
    String? description,
    bool? isAnonymous,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (isAnonymous != null) updates['is_anonymous'] = isAnonymous;

      await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.prayerRequestsCollectionId,
        rowId: id,
        data: updates,
      );
    } catch (e) {
      _logger.error('Error updating prayer request', e);
      throw DatabaseException(
        'Failed to update prayer request',
        originalError: e,
      );
    }
  }

  Future<void> deletePrayerRequest(String id) async {
    try {
      await _tables.deleteRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.prayerRequestsCollectionId,
        rowId: id,
      );
    } catch (e) {
      _logger.error('Error deleting prayer request', e);
      throw DatabaseException(
        'Failed to delete prayer request',
        originalError: e,
      );
    }
  }

  // --- Private Prayer Rooms ---

  Future<List<PrivatePrayerRoom>> fetchPrivateRooms({
    required String userId,
    required String role,
  }) async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.privatePrayerRoomsCollectionId,
        queries: [
          Query.orderDesc('created_at'),
          Query.limit(100),
        ],
      );

      final allRooms = response.rows
          .map((doc) => PrivatePrayerRoom.fromJson(_documentData(doc)))
          .toList();

      return allRooms
          .where((room) => room.canUserAccess(role: role, userId: userId))
          .toList();
    } catch (e) {
      _logger.error('Error fetching private prayer rooms', e);
      // If collection doesn't exist yet or is empty, return empty list gracefully
      return <PrivatePrayerRoom>[];
    }
  }

  Future<PrivatePrayerRoom> createPrivateRoom(PrivatePrayerRoom room) async {
    try {
      final now = DateTime.now().toIso8601String();
      final document = await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.privatePrayerRoomsCollectionId,
        rowId: ID.unique(),
        data: {
          'name': room.name,
          'description': room.description,
          'allowed_roles': room.allowedRoles,
          'allowed_user_ids': room.allowedUserIds,
          'created_by': room.createdBy,
          'created_at': now,
          'updated_at': now,
          'member_count': room.memberCount,
        },
      );

      return PrivatePrayerRoom.fromJson(_documentData(document));
    } catch (e) {
      _logger.error('Error creating private prayer room', e);
      throw DatabaseException(
        'Failed to create private prayer room',
        originalError: e,
      );
    }
  }

  Future<PrivatePrayerRoom> updatePrivateRoom(PrivatePrayerRoom room) async {
    try {
      final now = DateTime.now().toIso8601String();
      final document = await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.privatePrayerRoomsCollectionId,
        rowId: room.id,
        data: {
          'name': room.name,
          'description': room.description,
          'allowed_roles': room.allowedRoles,
          'allowed_user_ids': room.allowedUserIds,
          'updated_at': now,
        },
      );

      return PrivatePrayerRoom.fromJson(_documentData(document));
    } catch (e) {
      _logger.error('Error updating private prayer room', e);
      throw DatabaseException(
        'Failed to update private prayer room',
        originalError: e,
      );
    }
  }

  Future<void> deletePrivateRoom(String roomId) async {
    try {
      await _tables.deleteRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.privatePrayerRoomsCollectionId,
        rowId: roomId,
      );
    } catch (e) {
      _logger.error('Error deleting private prayer room', e);
      throw DatabaseException(
        'Failed to delete private prayer room',
        originalError: e,
      );
    }
  }

  Future<List<PrayerRequest>> fetchRoomPrayerRequests(String roomId) async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.prayerRequestsCollectionId,
        queries: [
          Query.equal('room_id', roomId),
          Query.orderDesc('created_at'),
          Query.limit(200),
        ],
      );

      return response.rows
          .map((doc) => PrayerRequest.fromJson(_documentData(doc)))
          .toList();
    } catch (e) {
      _logger.error('Error fetching room prayer requests', e);
      return <PrayerRequest>[];
    }
  }

  // --- Answered Prayer & Testimonies ---

  Future<void> markPrayerAnswered({
    required String requestId,
    String? testimonyId,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      final updates = <String, dynamic>{
        'is_answered': true,
        'status': 'answered',
        'answered_at': now,
        'updated_at': now,
      };
      if (testimonyId != null) {
        updates['testimony_id'] = testimonyId;
      }

      await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.prayerRequestsCollectionId,
        rowId: requestId,
        data: updates,
      );
    } catch (e) {
      _logger.error('Error marking prayer as answered', e);
      throw DatabaseException(
        'Failed to mark prayer as answered',
        originalError: e,
      );
    }
  }

  Future<PrayerTestimony> addPrayerTestimony(PrayerTestimony testimony) async {
    try {
      final now = DateTime.now().toIso8601String();
      final doc = await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.prayerTestimoniesCollectionId,
        rowId: ID.unique(),
        data: {
          'prayer_request_id': testimony.prayerRequestId,
          'user_id': testimony.userId,
          'author_name': testimony.authorName,
          'title': testimony.title,
          'body': testimony.body,
          'created_at': now,
          'updated_at': now,
        },
      );

      final created = PrayerTestimony.fromJson(_documentData(doc));

      // Link testimony to prayer request and mark as answered
      await markPrayerAnswered(
        requestId: testimony.prayerRequestId,
        testimonyId: created.id,
      );

      return created;
    } catch (e) {
      _logger.error('Error adding prayer testimony', e);
      throw DatabaseException(
        'Failed to record prayer testimony',
        originalError: e,
      );
    }
  }

  Future<PrayerTestimony?> fetchPrayerTestimony(String prayerRequestId) async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.prayerTestimoniesCollectionId,
        queries: [
          Query.equal('prayer_request_id', prayerRequestId),
          Query.limit(1),
        ],
      );

      if (response.rows.isEmpty) return null;
      return PrayerTestimony.fromJson(_documentData(response.rows.first));
    } catch (e) {
      _logger.error('Error fetching prayer testimony', e);
      return null;
    }
  }

  Map<String, dynamic> _documentData(dynamic document) {
    return {
      ...Map<String, dynamic>.from(document.data as Map),
      'id': document.$id,
    };
  }
}
