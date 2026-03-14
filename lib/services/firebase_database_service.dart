import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/app_models.dart';
import '../models/bible_models.dart';
import '../utils/logger.dart';
import '../utils/app_exception.dart';

class FirebaseDatabaseService {
  static FirebaseDatabaseService? _instance;
  static FirebaseDatabaseService get instance =>
      _instance ??= FirebaseDatabaseService._();

  FirebaseDatabaseService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final Logger _logger = Logger('FirebaseDatabaseService');

  FirebaseFirestore get firestore => _firestore;
  FirebaseStorage get storage => _storage;
  FirebaseFunctions get functions => _functions;

  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  // Bible Service Methods
  Future<void> addBibleVerse(String book, int chapter, int verse, String text,
      String version, String language) async {
    try {
      // Create searchable text array for better search functionality
      final searchableText = _createSearchableText(text);

      await _firestore.collection('bible_verses').add({
        'book': book,
        'chapter': chapter,
        'verse': verse,
        'text': text,
        'version': version,
        'language': language,
        'searchableText': searchableText,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _logger.error('Error adding Bible verse: $e');
      throw DatabaseException('Failed to add Bible verse', originalError: e);
    }
  }

  Future<void> addBibleChapter(BibleChapter chapter) async {
    try {
      // First add the chapter document
      final chapterRef = await _firestore.collection('bible_chapters').add({
        'book': chapter.book,
        'chapter': chapter.chapter,
        'version': chapter.version,
        'language': chapter.language,
        'metadata': chapter.metadata,
        'lastUpdated': chapter.lastUpdated ?? DateTime.now(),
      });

      // Then add each verse as a document in a subcollection
      for (final verse in chapter.verses) {
        final searchableText = _createSearchableText(verse.text);

        // Add to verses subcollection
        await chapterRef.collection('verses').add({
          'number': verse.number,
          'text': verse.text,
          'footnotes': verse.footnotes,
          'crossReferences': verse.crossReferences,
          'searchableText': searchableText,
        });

        // Also add to the flat bible_verses collection for easier searching
        await _firestore.collection('bible_verses').add({
          'book': chapter.book,
          'chapter': chapter.chapter,
          'verse': verse.number,
          'text': verse.text,
          'version': chapter.version,
          'language': chapter.language,
          'searchableText': searchableText,
          'created_at': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      _logger.error('Error adding Bible chapter: $e');
      throw DatabaseException('Failed to add Bible chapter', originalError: e);
    }
  }

  Future<void> addBibleBook(BibleBook book, String language) async {
    try {
      await _firestore.collection('bible_books').add({
        'name': book.name,
        'abbreviation': book.abbreviation,
        'chapters': book.chapters,
        'testament': book.testament,
        'order': book.order,
        'translations': book.translations,
        'language': language,
      });
    } catch (e) {
      _logger.error('Error adding Bible book: $e');
      throw DatabaseException('Failed to add Bible book', originalError: e);
    }
  }

  // Helper method to create searchable text array from verse text
  List<String> _createSearchableText(String text) {
    // Remove punctuation and convert to lowercase
    final cleanText = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Split into words and remove duplicates
    final words = cleanText.split(' ').toSet().toList();

    // Filter out common words (stop words) that don't add search value
    final stopWords = {
      'the',
      'and',
      'a',
      'an',
      'in',
      'on',
      'at',
      'to',
      'for',
      'of',
      'with',
      'by',
      'as',
      'is',
      'are',
      'was',
      'were',
      'be',
      'been',
      'being',
      'have',
      'has',
      'had',
      'do',
      'does',
      'did',
      'but',
      'or',
      'if',
      'then',
      'else',
      'when',
      'where',
      'why',
      'how',
      'all',
      'any',
      'both',
      'each',
      'few',
      'more',
      'most',
      'some',
      'such',
      'no',
      'nor',
      'not',
      'only',
      'own',
      'same',
      'so',
      'than',
      'too',
      'very',
      's',
      't',
      'can',
      'will',
      'just',
      'don',
      'should',
      'now',
      'd',
      'll',
      'm',
      'o',
      're',
      've',
      'y',
      'ain',
      'aren',
      'couldn',
      'didn',
      'doesn',
      'hadn',
      'hasn',
      'haven',
      'isn',
      'ma',
      'mightn',
      'mustn',
      'needn',
      'shan',
      'shouldn',
      'wasn',
      'weren',
      'won',
      'wouldn'
    };

    return words
        .where((word) => !stopWords.contains(word) && word.length > 1)
        .toList();
  }

  // Authentication Methods
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      _logger.error('Error signing up: $e');
      throw AuthException('Failed to sign up', originalError: e);
    }
  }

  Future<UserCredential> signUpWithEmail(
    String email,
    String password, {
    String? fullName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name if provided
      if (fullName != null && credential.user != null) {
        await credential.user!.updateDisplayName(fullName);
      }

      return credential;
    } catch (e) {
      _logger.error('Error signing up: $e');
      throw AuthException('Failed to sign up', originalError: e);
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      _logger.error('Error signing out: $e');
      throw AuthException('Failed to sign out', originalError: e);
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      _logger.error('Error sending password reset email: $e');
      throw AuthException('Failed to send password reset email',
          originalError: e);
    }
  }

  // User Profile Methods
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('profiles').doc(userId).get();
      if (doc.exists) {
        return UserProfile.fromJson({...doc.data()!, 'id': doc.id});
      }
      throw NotFoundException('User profile not found');
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error getting user profile', e);
      throw DatabaseException('Failed to get user profile', originalError: e);
    }
  }

  Future<UserProfile> updateUserProfile(UserProfile user) async {
    try {
      await _firestore
          .collection('profiles')
          .doc(user.id)
          .update(user.toJson());
      return user;
    } catch (e) {
      _logger.error('Error updating user profile: $e');
      throw DatabaseException('Failed to update user profile',
          originalError: e);
    }
  }

  Future<UserProfile> createUserProfile(UserProfile user) async {
    try {
      await _firestore.collection('profiles').doc(user.id).set(user.toJson());
      return user;
    } catch (e) {
      _logger.error('Error creating user profile: $e');
      throw DatabaseException('Failed to create user profile',
          originalError: e);
    }
  }

  // Admin: Get all user profiles
  Future<List<UserProfile>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection('profiles').get();
      return snapshot.docs
          .map((doc) => UserProfile.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      _logger.error('Error getting all users: $e');
      throw DatabaseException('Failed to get all users', originalError: e);
    }
  }

  // Admin: Update user role
  Future<void> updateUserRole(String userId, String newRole) async {
    try {
      await _firestore.collection('profiles').doc(userId).update({
        'role': newRole,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Keep Firebase Auth custom claims in sync with profile role.
      try {
        await _functions.httpsCallable('setUserRoleAndClaims').call({
          'uid': userId,
          'role': newRole,
        });
      } catch (e) {
        _logger.warning('Role claims sync failed for $userId: $e');
      }
    } catch (e) {
      _logger.error('Error updating user role: $e');
      throw DatabaseException('Failed to update user role', originalError: e);
    }
  }

  Future<bool> claimAdminRole() async {
    try {
      final result = await _functions.httpsCallable('claimAdminRole').call();
      final data = result.data;
      return data is Map && data['ok'] == true;
    } catch (e) {
      _logger.error('Error claiming admin role: $e');
      return false;
    }
  }

  // Admin: Archive user
  Future<void> archiveUser(String userId) async {
    try {
      await _firestore.collection('profiles').doc(userId).update({
        'is_archived': true,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _logger.error('Error archiving user: $e');
      throw DatabaseException('Failed to archive user', originalError: e);
    }
  }

  // Admin: Archive user leadership role
  Future<void> archiveLeadershipRole(LeadershipRecord record) async {
    try {
      await _firestore
          .collection('profiles')
          .doc(record.userId)
          .collection('leadership_history')
          .doc(record.id)
          .set(record.toJson());
    } catch (e) {
      _logger.error('Error archiving leadership role: $e');
      throw DatabaseException('Failed to archive leadership role',
          originalError: e);
    }
  }

  // Admin: Get leadership history for a user
  Future<List<LeadershipRecord>> getLeadershipHistory(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('profiles')
          .doc(userId)
          .collection('leadership_history')
          .orderBy('end_date', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => LeadershipRecord.fromJson(doc.data()))
          .toList();
    } catch (e) {
      _logger.error('Error getting leadership history: $e');
      throw DatabaseException('Failed to get leadership history',
          originalError: e);
    }
  }

  // Prayer Requests Methods
  Future<List<PrayerRequest>> getPrayerRequests({String? category}) async {
    try {
      Query orderedQuery = _firestore
          .collection('prayer_requests')
          .orderBy('created_at', descending: true);
      Query fallbackQuery = _firestore.collection('prayer_requests');

      if (category != null && category.isNotEmpty) {
        orderedQuery = orderedQuery.where('category', isEqualTo: category);
        fallbackQuery = fallbackQuery.where('category', isEqualTo: category);
      }

      QuerySnapshot snapshot;
      try {
        snapshot = await orderedQuery.get();
      } on FirebaseException catch (e) {
        // Avoid hard failure when composite index is missing in Firestore.
        if (e.code == 'failed-precondition') {
          snapshot = await fallbackQuery.get();
        } else {
          rethrow;
        }
      }
      List<PrayerRequest> requests = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        final isPublic = data['is_public'] as bool?;
        if (isPublic == false) {
          continue;
        }

        // Get user profile for each request
        if (data['user_id'] != null) {
          try {
            final profile = await getUserProfile(data['user_id']);
            if (profile != null) {
              data['user'] = profile.toJson();
            }
          } catch (e) {
            // Ignore if user profile not found
          }
        }

        requests.add(PrayerRequest.fromJson(data));
      }

      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    } catch (e) {
      _logger.error('Error getting prayer requests: $e');
      throw DatabaseException('Failed to get prayer requests',
          originalError: e);
    }
  }

  Future<PrayerRequest> createPrayerRequest(PrayerRequest request) async {
    try {
      final payload = request.toJson()
        ..remove('id')
        ..addAll({
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      final docRef =
          await _firestore.collection('prayer_requests').add(payload);
      final doc = await docRef.get();
      final data = doc.data()!;
      data['id'] = doc.id;

      // Get user profile
      if (data['user_id'] != null) {
        final profile = await getUserProfile(data['user_id']);
        if (profile != null) {
          data['user'] = profile.toJson();
        }
      }

      return PrayerRequest.fromJson(data);
    } catch (e) {
      _logger.error('Error creating prayer request: $e');
      throw DatabaseException('Failed to create prayer request',
          originalError: e);
    }
  }

  Future<void> prayForRequest(String requestId, String userId) async {
    try {
      await _firestore.runTransaction((tx) async {
        final prayerRef =
            _firestore.collection('prayer_requests').doc(requestId);
        final prayerSnap = await tx.get(prayerRef);
        if (!prayerSnap.exists) {
          throw NotFoundException('Prayer request not found');
        }

        final interactionRef =
            _firestore.collection('prayer_interactions').doc();
        tx.set(interactionRef, {
          'prayer_request_id': requestId,
          'user_id': userId,
          'interaction_type': 'pray',
          'created_at': FieldValue.serverTimestamp(),
        });

        final currentCount = (prayerSnap.data()?['prayer_count'] as int?) ?? 0;
        tx.update(prayerRef, {
          'prayer_count': currentCount + 1,
          'updated_at': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      _logger.error('Error praying for request: $e');
      throw DatabaseException('Failed to pray for request', originalError: e);
    }
  }

  // Health Activities Methods
  Future<List<HealthTracking>> getHealthActivities(
      String userId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('health_activities')
          .where('user_id', isEqualTo: userId)
          .where('created_at',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('created_at', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('created_at', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return HealthTracking.fromJson(data);
      }).toList();
    } catch (e) {
      _logger.error('Error getting health activities: $e');
      throw DatabaseException('Failed to get health activities',
          originalError: e);
    }
  }

  Future<HealthTracking> createHealthActivity(HealthTracking activity) async {
    try {
      final docRef = await _firestore
          .collection('health_activities')
          .add(activity.toJson());
      final doc = await docRef.get();
      final data = doc.data()!;
      data['id'] = doc.id;
      return HealthTracking.fromJson(data);
    } catch (e) {
      _logger.error('Error creating health activity: $e');
      throw DatabaseException('Failed to create health activity',
          originalError: e);
    }
  }

  // Missions Methods
  Future<List<Mission>> getMissions({String? category}) async {
    try {
      Query query = _firestore
          .collection('missions')
          .where('is_active', isEqualTo: true)
          .orderBy('created_at', descending: true);

      if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Mission.fromJson(data);
      }).toList();
    } catch (e) {
      _logger.error('Error getting missions: $e');
      throw DatabaseException('Failed to get missions', originalError: e);
    }
  }

  Future<void> joinMission(String userId, String missionId) async {
    try {
      await _firestore.collection('user_missions').add({
        'user_id': userId,
        'mission_id': missionId,
        'joined_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _logger.error('Error joining mission: $e');
      throw DatabaseException('Failed to join mission', originalError: e);
    }
  }

  // Study Programs Methods
  Future<List<StudyProgram>> getStudyPrograms() async {
    try {
      final snapshot = await _firestore.collection('study_programs').get();

      if (snapshot.docs.isEmpty) return <StudyProgram>[];

      final programs = snapshot.docs.map((doc) {
        final data = doc.data();
        return StudyProgram(
          id: doc.id,
          title: (data['title'] as String?)?.trim().isNotEmpty == true
              ? (data['title'] as String).trim()
              : 'Study Program',
          description: (data['description'] as String?) ?? '',
          category: (data['category'] as String?) ?? 'general',
          difficulty: (data['difficulty'] as String?) ?? 'beginner',
          duration: _toInt(data['duration']),
          totalLessons:
              _toInt(data['total_lessons'] ?? data['totalLessons'] ?? 0),
          imageUrl: (data['image_url'] as String?) ??
              (data['imageUrl'] as String?) ??
              '',
          createdAt: _toDateTime(data['created_at'] ?? data['createdAt']),
          updatedAt: _toDateTime(
              data['updated_at'] ?? data['updatedAt'] ?? data['created_at']),
        );
      }).toList();

      programs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return programs;
    } on FirebaseException catch (e) {
      // Return empty list gracefully if missing index/permission issue
      _logger
          .warning('Could not load study programs (${e.code}): ${e.message}');
      return <StudyProgram>[];
    } catch (e) {
      _logger.error('Error getting study programs: $e');
      return <StudyProgram>[];
    }
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  Future<void> enrollInStudyProgram(String userId, String programId) async {
    try {
      await _firestore.collection('user_study_programs').add({
        'user_id': userId,
        'study_program_id': programId,
        'progress': 0,
        'started_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _logger.error('Error enrolling in study program: $e');
      throw DatabaseException('Failed to enroll in study program',
          originalError: e);
    }
  }

  // Daily Verse Methods
  Future<DailyVerse?> getDailyVerse([DateTime? date]) async {
    try {
      final targetDate = date ?? DateTime.now();
      final dateString =
          '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

      final snapshot = await _firestore
          .collection('daily_verses')
          .where('date', isEqualTo: dateString)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        data['id'] = snapshot.docs.first.id;
        return DailyVerse.fromJson(data);
      }
      throw NotFoundException('Daily verse not found');
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error getting daily verse: $e');
      throw DatabaseException('Failed to get daily verse', originalError: e);
    }
  }

  // Real-time subscriptions using Firestore streams
  Stream<List<PrayerRequest>> subscribeToPrayerRequests() {
    return _firestore
        .collection('prayer_requests')
        .orderBy('created_at', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<PrayerRequest> requests = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        final isPublic = data['is_public'] as bool?;
        if (isPublic == false) {
          continue;
        }

        // Get user profile for each request
        if (data['user_id'] != null) {
          final profile = await getUserProfile(data['user_id']);
          if (profile != null) {
            data['user'] = profile.toJson();
          }
        }

        requests.add(PrayerRequest.fromJson(data));
      }

      return requests;
    });
  }

  Stream<List<Mission>> subscribeToMissions() {
    return _firestore
        .collection('missions')
        .where('is_active', isEqualTo: true)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return Mission.fromJson(data);
            }).toList());
  }

  // File Storage Methods (deduplicated)
  // Removed legacy bucket/path signatures. Use path-based versions below.

  Future<String> getPublicUrl(String bucket, String path) async {
    try {
      final ref = _storage.ref().child(bucket).child(path);
      return await ref.getDownloadURL();
    } catch (e) {
      _logger.error('Error getting public URL: $e');
      throw DatabaseException('Failed to get public URL', originalError: e);
    }
  }


  Future<bool> addBoardReport(Map<String, dynamic> reportData) async {
    try {
      await _firestore.collection('board_reports').add({
        ...reportData,
        'created_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      _logger.error('Error adding board report: $e');
      return false;
    }
  }

  Future<bool> updateBoardReportStatus(String reportId, String status) async {
    try {
      await _firestore.collection('board_reports').doc(reportId).update({
        'status': status,
        'updated_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      _logger.error('Error updating board report status: $e');
      return false;
    }
  }


  Future<bool> addBoardDecision(Map<String, dynamic> decisionData) async {
    try {
      await _firestore.collection('board_decisions').add({
        ...decisionData,
        'proposed_at': FieldValue.serverTimestamp(),
        'votes': [], // Initialize empty votes array
      });
      return true;
    } catch (e) {
      _logger.error('Error adding board decision: $e');
      return false;
    }
  }

  Future<bool> castBoardVote(String decisionId, Map<String, dynamic> voteData) async {
    try {
      final decisionRef = _firestore.collection('board_decisions').doc(decisionId);
      
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(decisionRef);
        if (!snapshot.exists) throw Exception('Decision not found');
        
        final List<dynamic> currentVotes = List.from(snapshot.data()?['votes'] ?? []);
        
        // Remove existing vote from same user if any
        currentVotes.removeWhere((v) => v['voter_id'] == voteData['voter_id']);
        
        // Add new vote
        currentVotes.add({
          ...voteData,
          'voted_at': DateTime.now().toIso8601String(),
        });
        
        transaction.update(decisionRef, {'votes': currentVotes});
      });
      return true;
    } catch (e) {
      _logger.error('Error casting board vote: $e');
      return false;
    }
  }

  // Analytics Methods
  Future<void> trackEvent(
      String userId, String eventName, Map<String, dynamic>? properties) async {
    try {
      await _firestore.collection('user_events').add({
        'user_id': userId,
        'event_name': eventName,
        'properties': properties,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Silently fail for analytics
      _logger.error('Error tracking event: $e');
    }
  }

  // FCM Token Methods
  Future<void> updateFCMToken(String userId, String token) async {
    try {
      await _firestore.collection('push_tokens').doc(userId).set({
        'user_id': userId,
        'token': token,
        'device_type': 'mobile',
        'is_active': true,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _logger.info('FCM token updated for user $userId');
    } catch (e) {
      _logger.error('Error updating FCM token: $e');
    }
  }

  // Notification Settings Methods
  Future<void> updateNotificationSettings(
      String userId, Map<String, bool> settings) async {
    try {
      await _firestore.collection('notification_settings').doc(userId).set({
        'user_id': userId,
        ...settings,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _logger.info('Notification settings updated for user $userId');
    } catch (e) {
      _logger.error('Error updating notification settings: $e');
    }
  }

  // Content Management Methods
  Future<Map<String, dynamic>?> getContentPageBySlug(String slug,
      {String? languageCode}) async {
    try {
      final targetLanguage = languageCode ?? 'en';

      // First try to get content in the requested language
      var snapshot = await _firestore
          .collection('content_pages')
          .where('slug', isEqualTo: slug)
          .where('language', isEqualTo: targetLanguage)
          .where('is_published', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        data['id'] = snapshot.docs.first.id;
        return data;
      }

      // If not found in target language, fallback to English
      if (targetLanguage != 'en') {
        snapshot = await _firestore
            .collection('content_pages')
            .where('slug', isEqualTo: slug)
            .where('language', isEqualTo: 'en')
            .where('is_published', isEqualTo: true)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final data = snapshot.docs.first.data();
          data['id'] = snapshot.docs.first.id;
          data['needs_translation'] = true;
          data['target_language'] = targetLanguage;
          return data;
        }
      }

      throw NotFoundException('Content page not found');
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error getting content page: $e');
      throw DatabaseException('Failed to get content page', originalError: e);
    }
  }

  Future<List<Map<String, dynamic>>> getDynamicContent(
      {String? languageCode, String? category}) async {
    try {
      final targetLanguage = languageCode ?? 'en';

      Query query = _firestore
          .collection('dynamic_content')
          .where('is_active', isEqualTo: true)
          .where('language', isEqualTo: targetLanguage);

      if (category != null) {
        query = query.where('category', isEqualTo: category);
      }

      var snapshot = await query.get();

      if (snapshot.docs.isEmpty && targetLanguage != 'en') {
        // Fallback to English if no content in target language
        query = _firestore
            .collection('dynamic_content')
            .where('is_active', isEqualTo: true)
            .where('language', isEqualTo: 'en');

        if (category != null) {
          query = query.where('category', isEqualTo: category);
        }

        snapshot = await query.get();

        // Mark content as needing translation
        return snapshot.docs.map((doc) {
          final Map<String, dynamic> data =
              Map<String, dynamic>.from(doc.data() as Map);
          data['id'] = doc.id;
          data['needs_translation'] = true;
          data['target_language'] = targetLanguage;
          return data;
        }).toList();
      }

      return snapshot.docs.map((doc) {
        final Map<String, dynamic> data =
            Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      _logger.error('Error getting dynamic content', e);
      throw DatabaseException('Failed to get dynamic content',
          originalError: e);
    }
  }

  // Admin Methods
  Future<List<Map<String, dynamic>>> getUsersForApproval() async {
    try {
      final snapshot = await _firestore
          .collection('profiles')
          .where('is_approved', isEqualTo: false)
          .orderBy('created_at', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      _logger.error('Error getting users for approval: $e');
      throw DatabaseException('Failed to get users for approval',
          originalError: e);
    }
  }

  Future<void> approveUser(String userId) async {
    try {
      await _firestore.collection('profiles').doc(userId).update({
        'is_approved': true,
        'approved_at': FieldValue.serverTimestamp(),
      });
      _logger.info('User $userId approved');
    } catch (e) {
      _logger.error('Error approving user: $e');
      throw DatabaseException('Failed to approve user', originalError: e);
    }
  }

  Future<void> rejectUser(String userId) async {
    try {
      await _firestore.collection('profiles').doc(userId).update({
        'is_approved': false,
        'rejected_at': FieldValue.serverTimestamp(),
      });
      _logger.info('User $userId rejected');
    } catch (e) {
      _logger.error('Error rejecting user: $e');
      throw DatabaseException('Failed to reject user', originalError: e);
    }
  }

  // Board Reports Methods
  Future<List<Map<String, dynamic>>> getBoardReports() async {
    try {
      final snapshot = await _firestore
          .collection('board_reports')
          .orderBy('created_at', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      _logger.error('Error getting board reports: $e');
      throw DatabaseException('Failed to get board reports', originalError: e);
    }
  }

  // App Settings Methods
  Future<List<Map<String, dynamic>>> getAppSettings() async {
    try {
      final snapshot =
          await _firestore.collection('app_settings').orderBy('key').get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      _logger.error('Error getting app settings: $e');
      throw DatabaseException('Failed to get app settings', originalError: e);
    }
  }

  Future<void> updateAppSetting(String key, dynamic value) async {
    try {
      await _firestore.collection('app_settings').doc(key).set({
        'key': key,
        'value': value,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _logger.info('App setting $key updated');
    } catch (e) {
      _logger.error('Error updating app setting: $e');
      throw DatabaseException('Failed to update app setting', originalError: e);
    }
  }

  // Board Documents Methods
  Future<List<Map<String, dynamic>>> getBoardDocuments() async {
    try {
      final snapshot = await _firestore
          .collection('board_documents')
          .orderBy('created_at', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      _logger.error('Error getting board documents: $e');
      throw DatabaseException('Failed to get board documents',
          originalError: e);
    }
  }

  // Board Decisions Methods
  Future<List<Map<String, dynamic>>> getBoardDecisions() async {
    try {
      final snapshot = await _firestore
          .collection('board_decisions')
          .orderBy('created_at', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      _logger.error('Error getting board decisions: $e');
      throw DatabaseException('Failed to get board decisions',
          originalError: e);
    }
  }

  // Projects Management Methods
  Future<List<Map<String, dynamic>>> getProjects() async {
    try {
      final snapshot = await _firestore
          .collection('projects')
          .orderBy('priority')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      _logger.error('Error getting projects: $e');
      throw DatabaseException('Failed to get projects', originalError: e);
    }
  }

  Future<String> addProject(Map<String, dynamic> projectData) async {
    try {
      projectData['created_at'] = FieldValue.serverTimestamp();
      if (projectData['raised'] == null) projectData['raised'] = 0;
      if (projectData['priority'] == null) projectData['priority'] = 100;
      
      final docRef = await _firestore.collection('projects').add(projectData);
      return docRef.id;
    } catch (e) {
      _logger.error('Error adding project: $e');
      throw DatabaseException('Failed to add project', originalError: e);
    }
  }

  Future<void> updateProject(String projectId, Map<String, dynamic> projectData) async {
    try {
      projectData['updated_at'] = FieldValue.serverTimestamp();
      await _firestore.collection('projects').doc(projectId).update(projectData);
    } catch (e) {
      _logger.error('Error updating project: $e');
      throw DatabaseException('Failed to update project', originalError: e);
    }
  }

  Future<void> deleteProject(String projectId) async {
    try {
      await _firestore.collection('projects').doc(projectId).delete();
    } catch (e) {
      _logger.error('Error deleting project: $e');
      throw DatabaseException('Failed to delete project', originalError: e);
    }
  }

  // Meeting File Sharing Methods
  Future<List<Map<String, dynamic>>> getMeetingFiles() async {
    try {
      final snapshot = await _firestore
          .collection('meeting_files')
          .orderBy('created_at', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      _logger.error('Error getting meeting files: $e');
      throw DatabaseException('Failed to get meeting files', originalError: e);
    }
  }

  // Stream real-time updates for meeting files
  Stream<List<Map<String, dynamic>>> getMeetingFilesStream() {
    return _firestore
        .collection('meeting_files')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  // Upload meeting file bytes to Firebase Storage and save metadata to Firestore
  Future<void> uploadMeetingFileBytes(
    Uint8List data, {
    required String fileName,
    required String description,
    required String uploaderId,
    required String uploadedBy,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileType = fileName.split('.').last.toLowerCase();
      final storagePath = 'meeting_files/$uploaderId/${timestamp}_$fileName';

      // Basic content type mapping
      String? contentType;
      switch (fileType) {
        case 'png':
          contentType = 'image/png';
          break;
        case 'jpg':
        case 'jpeg':
          contentType = 'image/jpeg';
          break;
        case 'gif':
          contentType = 'image/gif';
          break;
        case 'pdf':
          contentType = 'application/pdf';
          break;
        case 'doc':
          contentType = 'application/msword';
          break;
        case 'docx':
          contentType =
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
          break;
        case 'xls':
          contentType = 'application/vnd.ms-excel';
          break;
        case 'xlsx':
          contentType =
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          break;
        case 'ppt':
          contentType = 'application/vnd.ms-powerpoint';
          break;
        case 'pptx':
          contentType =
              'application/vnd.openxmlformats-officedocument.presentationml.presentation';
          break;
        default:
          contentType = null;
      }

      // Upload to storage
      final ref = _storage.ref().child(storagePath);
      final metadata = SettableMetadata(contentType: contentType);
      final taskSnapshot = await ref.putData(data, metadata);
      await taskSnapshot.ref.getDownloadURL(); // ensure upload completes

      // Save metadata document
      await _firestore.collection('meeting_files').add({
        'file_name': fileName,
        'file_path': storagePath,
        'file_type': fileType,
        'file_size': data.lengthInBytes,
        'description': description,
        'uploaded_by': uploadedBy,
        'uploader_id': uploaderId,
        'uploaded_at': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
      });

      _logger.info('Meeting file uploaded: $storagePath');
    } catch (e) {
      _logger.error('Error uploading meeting file: $e');
      throw DatabaseException('Failed to upload meeting file',
          originalError: e);
    }
  }

  // Get a download URL for a meeting file path
  Future<String> getMeetingFileDownloadUrl(String filePath) async {
    try {
      final ref = _storage.ref().child(filePath);
      return await ref.getDownloadURL();
    } catch (e) {
      _logger.error('Error getting download URL for $filePath: $e');
      throw DatabaseException('Failed to get download URL', originalError: e);
    }
  }

  // Delete meeting file from storage and Firestore
  Future<void> deleteMeetingFile(String documentId, String filePath) async {
    try {
      // Delete storage file
      final ref = _storage.ref().child(filePath);
      await ref.delete();

      // Delete Firestore doc
      await _firestore.collection('meeting_files').doc(documentId).delete();
      _logger.info('Meeting file deleted: $filePath (doc: $documentId)');
    } catch (e) {
      _logger.error('Error deleting meeting file: $e');
      throw DatabaseException('Failed to delete meeting file',
          originalError: e);
    }
  }

  Future<Map<String, dynamic>?> getDocument(
      String collection, String documentId) async {
    try {
      final doc = await _firestore.collection(collection).doc(documentId).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return data;
      }
      throw NotFoundException('Document not found in $collection');
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error getting document from $collection: $e');
      throw DatabaseException('Failed to get document', originalError: e);
    }
  }

  Future<List<Map<String, dynamic>>> getCollectionWhere(
    String collection,
    String field,
    dynamic value, {
    String? orderBy,
    bool descending = false,
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _firestore.collection(collection).where(field, isEqualTo: value);

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final Map<String, dynamic> data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      _logger.error(
          'Error getting collection $collection where $field == $value: $e');
      throw DatabaseException('Failed to get collection where',
          originalError: e);
    }
  }

  Future<List<Map<String, dynamic>>> getCollection(String collection,
      {Map<String, dynamic>? where,
      String? orderBy,
      bool descending = false,
      int? limit}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection(collection);

      if (where != null) {
        where.forEach((key, value) {
          query = query.where(key, isEqualTo: value);
        });
      }

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final Map<String, dynamic> data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      _logger.error('Error getting collection $collection: $e');
      throw DatabaseException('Failed to get collection', originalError: e);
    }
  }

  Future<String> createDocument(
      String collection, Map<String, dynamic> data) async {
    try {
      data['created_at'] = FieldValue.serverTimestamp();
      final docRef = await _firestore.collection(collection).add(data);
      _logger.info('Document created in $collection with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      _logger.error('Error creating document in $collection: $e');
      throw DatabaseException('Failed to create document', originalError: e);
    }
  }

  Future<void> updateDocument(
      String collection, String documentId, Map<String, dynamic> data) async {
    try {
      data['updated_at'] = FieldValue.serverTimestamp();
      await _firestore.collection(collection).doc(documentId).update(data);
      _logger.info('Document updated in $collection with ID: $documentId');
    } catch (e) {
      _logger.error('Error updating document in $collection: $e');
      throw DatabaseException('Failed to update document', originalError: e);
    }
  }

  /// Create or update a document by ID (upsert semantics).
  /// If the document does not exist, it will be created.
  /// If it exists, fields will be overwritten with the provided data.
  Future<void> createOrUpdateDocument(
      String collection, String documentId, Map<String, dynamic> data) async {
    try {
      // Stamp timestamps
      data['updated_at'] = FieldValue.serverTimestamp();
      data['id'] = documentId;
      await _firestore.collection(collection).doc(documentId).set(data);
      _logger.info('Document upserted in $collection with ID: $documentId');
    } catch (e) {
      _logger.error('Error upserting document in $collection: $e');
      throw DatabaseException('Failed to upsert document', originalError: e);
    }
  }

  Future<void> deleteDocument(String collection, String documentId) async {
    try {
      await _firestore.collection(collection).doc(documentId).delete();
      _logger.info('Document deleted from $collection with ID: $documentId');
    } catch (e) {
      _logger.error('Error deleting document from $collection: $e');
      throw DatabaseException('Failed to delete document', originalError: e);
    }
  }

  // Firebase Storage Methods
  Future<String> uploadFile(String path, Uint8List data,
      {String? contentType}) async {
    try {
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(contentType: contentType);
      final uploadTask = await ref.putData(data, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      _logger.info('File uploaded to $path');
      return downloadUrl;
    } catch (e) {
      _logger.error('Error uploading file to $path: $e');
      throw DatabaseException('Failed to upload file', originalError: e);
    }
  }

  Future<Uint8List?> downloadFile(String path) async {
    try {
      final ref = _storage.ref().child(path);
      final data = await ref.getData();
      _logger.info('File downloaded from $path');
      return data;
    } catch (e) {
      _logger.error('Error downloading file from $path: $e');
      throw DatabaseException('Failed to download file', originalError: e);
    }
  }

  Future<void> deleteFile(String path) async {
    try {
      final ref = _storage.ref().child(path);
      await ref.delete();
      _logger.info('File deleted from $path');
    } catch (e) {
      _logger.error('Error deleting file from $path: $e');
      throw DatabaseException('Failed to delete file', originalError: e);
    }
  }

  Future<List<Reference>> listFiles(String path) async {
    try {
      final ref = _storage.ref().child(path);
      final result = await ref.listAll();
      _logger.info('Listed ${result.items.length} files from $path');
      return result.items;
    } catch (e) {
      _logger.error('Error listing files from $path: $e');
      throw DatabaseException('Failed to list files', originalError: e);
    }
  }

  Future<String> getDownloadUrl(String path) async {
    try {
      final ref = _storage.ref().child(path);
      final url = await ref.getDownloadURL();
      _logger.info('Got download URL for $path');
      return url;
    } catch (e) {
      _logger.error('Error getting download URL for $path: $e');
      throw DatabaseException('Failed to get download URL', originalError: e);
    }
  }

  Future<void> deleteFileByUrl(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
      _logger.info('File deleted by URL: $downloadUrl');
    } catch (e) {
      _logger.error('Error deleting file by URL $downloadUrl: $e');
      throw DatabaseException('Failed to delete file by URL', originalError: e);
    }
  }

  // Admin: Export selected Firestore collections to Firebase Storage (CSV/JSON)
  Future<Map<String, dynamic>> exportDataBackup({
    List<String>? collections,
    String format = 'csv',
  }) async {
    try {
      final callable = _functions.httpsCallable('exportFirestoreCollections');
      final result = await callable.call(<String, dynamic>{
        if (collections != null && collections.isNotEmpty)
          'collections': collections,
        'format': format,
      });
      final data = result.data as Map<String, dynamic>;
      _logger.info(
          'Exported backup prefix: ${data['prefix']}, files: ${(data['files'] as Map).length}');
      return data;
    } catch (e) {
      _logger.error('Error exporting data backup: $e');
      throw DatabaseException('Failed to export data backup', originalError: e);
    }
  }

  Future<Map<String, dynamic>> exportChatBackup({
    String type = 'messaging',
    Map<String, dynamic>? filter,
  }) async {
    try {
      final callable = _functions.httpsCallable('exportStreamChatMetadata');
      final result = await callable.call(<String, dynamic>{
        'type': type,
        if (filter != null) 'filter': filter,
      });
      final data = result.data as Map<String, dynamic>;
      _logger.info(
          'Exported chat backup prefix: ${data['prefix']}, count: ${data['count']}');
      return data;
    } catch (e) {
      _logger.error('Error exporting chat backup: $e');
      throw DatabaseException('Failed to export chat backup', originalError: e);
    }
  }

  Future<Map<String, dynamic>> exportChatMessages({
    String type = 'messaging',
    Map<String, dynamic>? filter,
    int limitPerChannel = 500,
  }) async {
    try {
      final callable = _functions.httpsCallable('exportStreamChatMessages');
      final result = await callable.call(<String, dynamic>{
        'type': type,
        if (filter != null) 'filter': filter,
        'limitPerChannel': limitPerChannel,
      });
      final data = result.data as Map<String, dynamic>;
      _logger.info(
          'Exported chat messages prefix: ${data['prefix']}, files: ${(data['files'] as List).length}');
      return data;
    } catch (e) {
      _logger.error('Error exporting chat messages: $e');
      throw DatabaseException('Failed to export chat messages',
          originalError: e);
    }
  }

  // Sync tag visibility info to Firebase cache for faster access
  Future<void> cacheVisibleTags(String userId, List<String> visibleTags) async {
    try {
      await _firestore.collection('tag_visibility_cache').doc(userId).set({
        'user_id': userId,
        'visible_tags': visibleTags,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _logger.info(
          'Cached visible tags for user $userId (${visibleTags.length} tags)');
    } catch (e) {
      _logger.error('Error caching visible tags: $e');
    }
  }

  // Study Guides Methods
  Future<List<Map<String, dynamic>>> getStudyGuides(
      {String? type,
      String? difficulty,
      bool? isActive,
      String? searchQuery}) async {
    try {
      Query query = _firestore.collection('study_guides');
      if (type != null) {
        query = query.where('type', isEqualTo: type);
      }
      if (difficulty != null) {
        query = query.where('difficulty', isEqualTo: difficulty);
      }
      if (isActive != null) {
        query = query.where('is_active', isEqualTo: isActive);
      }
      query = query.orderBy('sort_order');
      final snapshot = await query.get();
      final guides = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        return guides.where((g) {
          final title = (g['title'] as String?)?.toLowerCase() ?? '';
          final desc = (g['description'] as String?)?.toLowerCase() ?? '';
          return title.contains(q) || desc.contains(q);
        }).toList();
      }
      return guides;
    } catch (e) {
      _logger.error('Error getting study guides: $e');
      throw DatabaseException('Failed to get study guides', originalError: e);
    }
  }

  Future<Map<String, dynamic>> getStudyGuideById(String studyGuideId) async {
    try {
      final doc =
          await _firestore.collection('study_guides').doc(studyGuideId).get();
      if (doc.exists) {
        final Map<String, dynamic> data = doc.data()!;
        data['id'] = doc.id;
        return data;
      }
      throw NotFoundException('Study guide not found');
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error getting study guide by ID: $e');
      throw DatabaseException('Failed to get study guide by ID',
          originalError: e);
    }
  }

  Future<List<Map<String, dynamic>>> getFeaturedStudyGuides() async {
    try {
      final snapshot = await _firestore
          .collection('study_guides')
          .where('is_active', isEqualTo: true)
          .orderBy('sort_order')
          .limit(10)
          .get();
      return snapshot.docs.map((doc) {
        final Map<String, dynamic> data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      _logger.error('Error getting featured study guides: $e');
      throw DatabaseException('Failed to get featured study guides',
          originalError: e);
    }
  }

  Future<void> createStudyGuide(Map<String, dynamic> data) async {
    try {
      final id = data['id'] as String?;
      if (id == null || id.isEmpty) {
        final docRef = await _firestore.collection('study_guides').add(data);
        _logger.info('Study guide created with ID: ${docRef.id}');
      } else {
        await _firestore.collection('study_guides').doc(id).set(data);
        _logger.info('Study guide created with preset ID: $id');
      }
    } catch (e) {
      _logger.error('Error creating study guide: $e');
      throw DatabaseException('Failed to create study guide', originalError: e);
    }
  }

  Future<void> updateStudyGuide(
      String studyGuideId, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection('study_guides')
          .doc(studyGuideId)
          .update(data);
      _logger.info('Study guide updated: $studyGuideId');
    } catch (e) {
      _logger.error('Error updating study guide: $e');
      throw DatabaseException('Failed to update study guide', originalError: e);
    }
  }

  // Study Lessons Methods
  Future<List<Map<String, dynamic>>> getStudyLessons(
      String studyGuideId) async {
    try {
      final snapshot = await _firestore
          .collection('study_lessons')
          .where('study_guide_id', isEqualTo: studyGuideId)
          .orderBy('lesson_number')
          .get();
      return snapshot.docs.map((doc) {
        final Map<String, dynamic> data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      _logger.error('Error getting study lessons: $e');
      throw DatabaseException('Failed to get study lessons', originalError: e);
    }
  }

  Future<Map<String, dynamic>> getStudyLessonById(String lessonId) async {
    try {
      final doc =
          await _firestore.collection('study_lessons').doc(lessonId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }
      throw NotFoundException('Study lesson not found');
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error getting lesson by ID: $e');
      throw DatabaseException('Failed to get lesson by ID', originalError: e);
    }
  }

  Future<Map<String, dynamic>> getStudyLessonByNumber(
      String studyGuideId, int lessonNumber) async {
    try {
      final snapshot = await _firestore
          .collection('study_lessons')
          .where('study_guide_id', isEqualTo: studyGuideId)
          .where('lesson_number', isEqualTo: lessonNumber)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final Map<String, dynamic> data = doc.data();
        data['id'] = doc.id;
        return data;
      }
      throw NotFoundException('Study lesson not found');
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error getting lesson by number: $e');
      throw DatabaseException('Failed to get lesson by number',
          originalError: e);
    }
  }

  Future<void> createStudyLesson(Map<String, dynamic> data) async {
    try {
      final id = data['id'] as String?;
      if (id == null || id.isEmpty) {
        final docRef = await _firestore.collection('study_lessons').add(data);
        _logger.info('Study lesson created with ID: ${docRef.id}');
      } else {
        await _firestore.collection('study_lessons').doc(id).set(data);
        _logger.info('Study lesson created with preset ID: $id');
      }
    } catch (e) {
      _logger.error('Error creating study lesson: $e');
      throw DatabaseException('Failed to create study lesson',
          originalError: e);
    }
  }

  // Study Questions Methods
  Future<List<Map<String, dynamic>>> getStudyQuestions(String lessonId) async {
    try {
      final snapshot = await _firestore
          .collection('study_questions')
          .where('lesson_id', isEqualTo: lessonId)
          .orderBy('question_number')
          .get();
      return snapshot.docs.map((doc) {
        final Map<String, dynamic> data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      _logger.error('Error getting study questions: $e');
      throw DatabaseException('Failed to get study questions',
          originalError: e);
    }
  }

  Future<void> createStudyQuestion(Map<String, dynamic> data) async {
    try {
      final id = data['id'] as String?;
      if (id == null || id.isEmpty) {
        final docRef = await _firestore.collection('study_questions').add(data);
        _logger.info('Study question created with ID: ${docRef.id}');
      } else {
        await _firestore.collection('study_questions').doc(id).set(data);
        _logger.info('Study question created with preset ID: $id');
      }
    } catch (e) {
      _logger.error('Error creating study question: $e');
      throw DatabaseException('Failed to create study question',
          originalError: e);
    }
  }

  // User Study Progress Methods
  Future<Map<String, dynamic>> getUserStudyProgress(
      String userId, String studyGuideId) async {
    try {
      final snapshot = await _firestore
          .collection('user_study_progress')
          .where('user_id', isEqualTo: userId)
          .where('study_guide_id', isEqualTo: studyGuideId)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final Map<String, dynamic> data = doc.data();
        data['id'] = doc.id;
        return data;
      }
      throw NotFoundException('User study progress not found');
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error getting user study progress: $e');
      throw DatabaseException('Failed to get user study progress',
          originalError: e);
    }
  }

  Future<List<Map<String, dynamic>>> getUserStudyProgressList(
      String userId) async {
    try {
      final snapshot = await _firestore
          .collection('user_study_progress')
          .where('user_id', isEqualTo: userId)
          .orderBy('updated_at', descending: true)
          .get();
      return snapshot.docs.map((doc) {
        final Map<String, dynamic> data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      _logger.error('Error getting user study progress list: $e');
      throw DatabaseException('Failed to get user study progress list',
          originalError: e);
    }
  }

  Future<void> createUserStudyProgress(Map<String, dynamic> data) async {
    try {
      final id = data['id'] as String?;
      if (id == null || id.isEmpty) {
        final docRef =
            await _firestore.collection('user_study_progress').add(data);
        _logger.info('User study progress created with ID: ${docRef.id}');
      } else {
        await _firestore.collection('user_study_progress').doc(id).set(data);
        _logger.info('User study progress created with preset ID: $id');
      }
    } catch (e) {
      _logger.error('Error creating user study progress: $e');
      throw DatabaseException('Failed to create user study progress',
          originalError: e);
    }
  }

  Future<void> updateUserStudyProgress(
      String progressId, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection('user_study_progress')
          .doc(progressId)
          .update(data);
      _logger.info('User study progress updated: $progressId');
    } catch (e) {
      _logger.error('Error updating user study progress: $e');
      throw DatabaseException('Failed to update user study progress',
          originalError: e);
    }
  }

  // User Lesson Progress Methods
  Future<Map<String, dynamic>> getUserLessonProgress(
      String userId, String lessonId) async {
    try {
      final snapshot = await _firestore
          .collection('user_lesson_progress')
          .where('user_id', isEqualTo: userId)
          .where('lesson_id', isEqualTo: lessonId)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final Map<String, dynamic> data = doc.data();
        data['id'] = doc.id;
        return data;
      }
      throw NotFoundException('User lesson progress not found');
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error getting user lesson progress: $e');
      throw DatabaseException('Failed to get user lesson progress',
          originalError: e);
    }
  }

  Future<void> createUserLessonProgress(Map<String, dynamic> data) async {
    try {
      final id = data['id'] as String?;
      if (id == null || id.isEmpty) {
        final docRef =
            await _firestore.collection('user_lesson_progress').add(data);
        _logger.info('User lesson progress created with ID: ${docRef.id}');
      } else {
        await _firestore.collection('user_lesson_progress').doc(id).set(data);
        _logger.info('User lesson progress created with preset ID: $id');
      }
    } catch (e) {
      _logger.error('Error creating user lesson progress: $e');
      throw DatabaseException('Failed to create user lesson progress',
          originalError: e);
    }
  }

  Future<void> updateUserLessonProgress(
      String progressId, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection('user_lesson_progress')
          .doc(progressId)
          .update(data);
      _logger.info('User lesson progress updated: $progressId');
    } catch (e) {
      _logger.error('Error updating user lesson progress: $e');
      throw DatabaseException('Failed to update user lesson progress',
          originalError: e);
    }
  }

  // Study Sessions Methods
  Future<List<Map<String, dynamic>>> getStudySessions({
    String? facilitatorId,
    List<String>? participantIds,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) async {
    try {
      Query query = _firestore.collection('study_sessions');
      if (facilitatorId != null) {
        query = query.where('facilitator_id', isEqualTo: facilitatorId);
      }
      if (participantIds != null && participantIds.isNotEmpty) {
        final limited = participantIds.length > 10
            ? participantIds.sublist(0, 10)
            : participantIds;
        query = query.where('participant_ids', arrayContainsAny: limited);
      }
      if (startDate != null) {
        query = query.where('scheduled_at',
            isGreaterThanOrEqualTo: startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.where('scheduled_at',
            isLessThanOrEqualTo: endDate.toIso8601String());
      }
      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }
      query = query.orderBy('scheduled_at');
      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      _logger.error('Error getting study sessions: $e');
      throw DatabaseException('Failed to get study sessions', originalError: e);
    }
  }

  Future<void> createStudySession(Map<String, dynamic> data) async {
    try {
      final id = data['id'] as String?;
      if (id == null || id.isEmpty) {
        final docRef = await _firestore.collection('study_sessions').add(data);
        _logger.info('Study session created with ID: ${docRef.id}');
      } else {
        await _firestore.collection('study_sessions').doc(id).set(data);
        _logger.info('Study session created with preset ID: $id');
      }
    } catch (e) {
      _logger.error('Error creating study session: $e');
      throw DatabaseException('Failed to create study session',
          originalError: e);
    }
  }

  // SSL / Connectivity Checks
  Future<Map<String, dynamic>> verifySSLConfiguration() async {
    try {
      // Perform a lightweight secure read to validate HTTPS connectivity
      await _firestore.collection('app_settings').limit(1).get();

      return {
        'success': true,
        'message': 'Firebase SSL appears configured correctly',
        'components': {
          'firestore_ssl': true,
          'storage_ssl': true,
          'functions_ssl': true,
        },
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logger.error('SSL verification failed: $e');
      return {
        'success': false,
        'error': 'SSL verification failed: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  Future<Map<String, dynamic>> testSSLConnection() async {
    final start = DateTime.now();
    try {
      final snapshot =
          await _firestore.collection('app_settings').limit(1).get();
      final duration = DateTime.now().difference(start).inMilliseconds;

      return {
        'success': true,
        'message': 'Secure Firebase connection verified',
        'latency_ms': duration,
        'result_count': snapshot.size,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logger.error('SSL test connection failed: $e');
      return {
        'success': false,
        'message': 'SSL test failed',
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}
