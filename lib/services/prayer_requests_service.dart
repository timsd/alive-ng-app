import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/prayer_request.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';
import 'auth_service.dart';

class PrayerRequestsService {
  // Singleton pattern
  static final PrayerRequestsService _instance = PrayerRequestsService._internal();
  factory PrayerRequestsService() => _instance;
  PrayerRequestsService._internal();
  static PrayerRequestsService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService.instance;
  final Logger _logger = Logger('PrayerRequestsService');

  Future<List<PrayerRequest>> fetchPrayerRequests() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw AuthException('User not authenticated');
      }

      final snapshot = await _firestore
          .collection('prayer_requests')
          .where('user_id', isEqualTo: user.uid)
          .orderBy('created_at', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => PrayerRequest.fromJson(doc.data()))
          .toList();
    } catch (e) {
      _logger.error('Error fetching prayer requests', e);
      throw DatabaseException('Failed to fetch prayer requests', originalError: e);
    }
  }

  Future<void> createPrayerRequest({
    required String title,
    required String description,
    bool isAnonymous = false,
  }) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw AuthException('User not authenticated');
      }

      final docRef = _firestore.collection('prayer_requests').doc();
      final data = {
        'id': docRef.id,
        'user_id': user.uid,
        'title': title,
        'description': description,
        'is_anonymous': isAnonymous,
        'prayer_count': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await docRef.set(data);
    } catch (e) {
      _logger.error('Error creating prayer request', e);
      throw DatabaseException('Failed to create prayer request', originalError: e);
    }
  }

  Future<void> prayForRequest(String requestId) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw AuthException('User not authenticated');
      }

      await _firestore.collection('prayer_requests').doc(requestId).update({
        'prayer_count': FieldValue.increment(1),
        'updated_at': DateTime.now().toIso8601String(),
      });
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
      final user = _authService.currentUser;
      if (user == null) {
        throw AuthException('User not authenticated');
      }

      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (isAnonymous != null) updates['is_anonymous'] = isAnonymous;
      updates['updated_at'] = DateTime.now().toIso8601String();

      await _firestore.collection('prayer_requests').doc(id).update(updates);
    } catch (e) {
      _logger.error('Error updating prayer request', e);
      throw DatabaseException('Failed to update prayer request', originalError: e);
    }
  }

  Future<void> deletePrayerRequest(String id) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw AuthException('User not authenticated');
      }

      await _firestore.collection('prayer_requests').doc(id).delete();
    } catch (e) {
      _logger.error('Error deleting prayer request', e);
      throw DatabaseException('Failed to delete prayer request', originalError: e);
    }
  }
}
