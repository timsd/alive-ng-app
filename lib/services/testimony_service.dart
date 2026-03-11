import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/testimony_model.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';
import 'auth_service.dart';

class TestimonyService {
  // Singleton pattern
  static final TestimonyService _instance = TestimonyService._internal();
  factory TestimonyService() => _instance;
  TestimonyService._internal();
  static TestimonyService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService.instance;
  final Logger _logger = Logger('TestimonyService');

  // Fetch approved testimonies (public feed)
  Future<List<Testimony>> fetchTestimonies() async {
    try {
      final snapshot = await _firestore
          .collection('testimonies')
          .where('is_approved', isEqualTo: true)
          .orderBy('created_at', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Testimony.fromJson(doc.data()))
          .toList();
    } catch (e) {
      _logger.error('Error fetching testimonies', e);
      throw DatabaseException('Failed to fetch testimonies', originalError: e);
    }
  }

  // Fetch user's own testimonies (including pending)
  Future<List<Testimony>> fetchMyTestimonies() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw AuthException('User not authenticated');
      }

      final snapshot = await _firestore
          .collection('testimonies')
          .where('user_id', isEqualTo: user.uid)
          .orderBy('created_at', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Testimony.fromJson(doc.data()))
          .toList();
    } catch (e) {
      _logger.error('Error fetching my testimonies', e);
      throw DatabaseException('Failed to fetch my testimonies', originalError: e);
    }
  }

  Future<void> createTestimony({
    required String content,
    bool isAnonymous = false,
  }) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw AuthException('User not authenticated');
      }

      final String userName = user.displayName ?? 'User';
      final String? photoUrl = user.photoURL;

      final docRef = _firestore.collection('testimonies').doc();
      final data = {
        'id': docRef.id,
        'user_id': user.uid,
        'user_name': isAnonymous ? 'Anonymous' : userName,
        'user_avatar_url': isAnonymous ? null : photoUrl,
        'content': content,
        'is_anonymous': isAnonymous,
        'likes_count': 0,
        'is_approved': false, // Requires moderation by default
        'created_at': DateTime.now().toIso8601String(),
      };

      await docRef.set(data);

      // Mirror testimony into prayer strengthening pipeline; visibility follows approval.
      await _firestore.collection('prayer_strengthening_feed').doc(docRef.id).set({
        'id': docRef.id,
        'testimony_id': docRef.id,
        'user_id': user.uid,
        'author_name': isAnonymous ? 'Anonymous' : userName,
        'content': content,
        'is_anonymous': isAnonymous,
        'is_approved': false,
        'is_visible': false,
        'source': 'testimony',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      _logger.error('Error creating testimony', e);
      throw DatabaseException('Failed to create testimony', originalError: e);
    }
  }
}
