// ignore_for_file: deprecated_member_use

import 'package:appwrite/appwrite.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../models/testimony_model.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';
import 'auth_service.dart';

class TestimonyService {
  static final TestimonyService _instance = TestimonyService._internal();
  factory TestimonyService() => _instance;
  TestimonyService._internal() : _databases = Databases(appwriteClient);
  static TestimonyService get instance => _instance;

  final Databases _databases;
  final AuthService _authService = AuthService.instance;
  final Logger _logger = Logger('TestimonyService');

  static const String databaseId = AppwriteBackendConfig.databaseId;
  static const String testimoniesCollectionId =
      AppwriteBackendConfig.testimoniesCollectionId;
  static const String prayerFeedCollectionId =
      AppwriteBackendConfig.prayerStrengtheningFeedCollectionId;

  Future<List<Testimony>> fetchTestimonies() async {
    try {
      final response = await _databases.listDocuments(
        databaseId: databaseId,
        collectionId: testimoniesCollectionId,
        queries: [
          Query.equal('is_approved', true),
          Query.orderDesc('created_at'),
          Query.limit(100),
        ],
      );

      return response.documents
          .map((document) => _testimonyFromData(document.$id, document.data))
          .toList();
    } catch (e) {
      _logger.error('Error fetching testimonies from Appwrite', e);
      throw DatabaseException('Failed to fetch testimonies', originalError: e);
    }
  }

  Future<List<Testimony>> fetchMyTestimonies() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return <Testimony>[];

      final response = await _databases.listDocuments(
        databaseId: databaseId,
        collectionId: testimoniesCollectionId,
        queries: [
          Query.equal('user_id', user.uid),
          Query.orderDesc('created_at'),
          Query.limit(100),
        ],
      );

      return response.documents
          .map((document) => _testimonyFromData(document.$id, document.data))
          .toList();
    } catch (e) {
      _logger.error('Error fetching my testimonies from Appwrite', e);
      throw DatabaseException('Failed to fetch my testimonies',
          originalError: e);
    }
  }

  Future<void> createTestimony({
    required String content,
    bool isAnonymous = false,
  }) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw AuthException(
            'Please sign in to share your testimony. Tap "Sign In" from the menu.');
      }

      final now = DateTime.now().toIso8601String();
      final documentId = ID.unique();
      final userName = user.displayName ?? 'User';
      final visibleUserName = isAnonymous ? 'Anonymous' : userName;
      final avatarUrl = isAnonymous ? null : user.photoURL;

      await _databases.createDocument(
        databaseId: databaseId,
        collectionId: testimoniesCollectionId,
        documentId: documentId,
        data: {
          'user_id': user.uid,
          'userId': user.uid,
          'user_name': visibleUserName,
          'user_avatar_url': avatarUrl,
          'content': content,
          'is_anonymous': isAnonymous,
          'likes_count': 0,
          'is_approved': false,
          'is_shared_publicly': true,
          'created_at': now,
          'updated_at': now,
        },
      );

      await _databases.createDocument(
        databaseId: databaseId,
        collectionId: prayerFeedCollectionId,
        documentId: documentId,
        data: {
          'source_id': documentId,
          'testimony_id': documentId,
          'user_id': user.uid,
          'title': 'Testimony',
          'author_name': visibleUserName,
          'content': content,
          'source': 'testimony',
          'is_anonymous': isAnonymous,
          'is_approved': false,
          'is_visible': false,
          'created_at': now,
          'updated_at': now,
        },
      );
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error creating testimony in Appwrite', e);
      throw DatabaseException('Failed to create testimony', originalError: e);
    }
  }

  Testimony _testimonyFromData(String documentId, Map<String, dynamic> data) {
    return Testimony.fromJson({
      ...data,
      'id': data['id'] ?? documentId,
    });
  }
}
