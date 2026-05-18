// ignore_for_file: deprecated_member_use

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

  late final Databases _databases = Databases(appwriteClient);
  final AuthService _authService = AuthService.instance;
  final Logger _logger = Logger('PrayerRequestsService');

  Future<List<PrayerRequest>> fetchPrayerRequests({String? category}) async {
    try {
      final queries = <String>[Query.orderDesc('created_at'), Query.limit(200)];
      if (category != null && category.trim().isNotEmpty) {
        queries.add(Query.equal('category', category.trim()));
      }

      final response = await _databases.listDocuments(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.prayerRequestsCollectionId,
        queries: queries,
      );

      return response.documents
          .map((doc) => PrayerRequest.fromJson(_documentData(doc)))
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
      final response = await _databases.listDocuments(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.prayerRequestsCollectionId,
        queries: [
          Query.equal('user_id', userId),
          Query.orderDesc('created_at'),
          Query.limit(200),
        ],
      );

      return response.documents
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

  Future<List<PrayerRequest>> fetchSupportedPrayerRequests(String userId) async {
    try {
      final interactions = await _databases.listDocuments(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.prayerInteractionsCollectionId,
        queries: [
          Query.equal('user_id', userId),
          Query.equal('type', 'pray'),
          Query.orderDesc('created_at'),
          Query.limit(100),
        ],
      );

      final requestIds = interactions.documents
          .map((doc) => doc.data['request_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      final requests = <PrayerRequest>[];
      for (final id in requestIds) {
        try {
          final doc = await _databases.getDocument(
            databaseId: AppwriteBackendConfig.databaseId,
            collectionId: AppwriteBackendConfig.prayerRequestsCollectionId,
            documentId: id,
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
      final user = _authService.currentUser ?? await appwriteAccount.get();
      final now = DateTime.now().toIso8601String();
      final document = await _databases.createDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.prayerRequestsCollectionId,
        documentId: ID.unique(),
        data: {
          'user_id': user.uid,
          'userId': user.uid,
          'requested_by': request.isAnonymous
              ? 'Anonymous'
              : (user.displayName?.trim().isNotEmpty == true
                  ? user.displayName
                  : 'ALIVE Member'),
          'requestedById': user.uid,
          'title': request.title,
          'description': request.description,
          'category': request.category,
          'status': 'active',
          'is_anonymous': request.isAnonymous,
          'is_answered': false,
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
      final doc = await _databases.getDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.prayerRequestsCollectionId,
        documentId: requestId,
      );
      final count = (doc.data['prayer_count'] as int?) ?? 0;
      final now = DateTime.now().toIso8601String();

      await _databases.createDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.prayerInteractionsCollectionId,
        documentId: ID.unique(),
        data: {
          'request_id': requestId,
          'user_id': userId,
          'type': 'pray',
          'created_at': now,
        },
      );

      await _databases.updateDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.prayerRequestsCollectionId,
        documentId: requestId,
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

      await _databases.updateDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.prayerRequestsCollectionId,
        documentId: id,
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
      await _databases.deleteDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.prayerRequestsCollectionId,
        documentId: id,
      );
    } catch (e) {
      _logger.error('Error deleting prayer request', e);
      throw DatabaseException(
        'Failed to delete prayer request',
        originalError: e,
      );
    }
  }

  Map<String, dynamic> _documentData(dynamic document) {
    return {
      ...Map<String, dynamic>.from(document.data as Map),
      'id': document.$id,
    };
  }
}
