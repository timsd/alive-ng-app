import 'dart:async';
import 'firebase_database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'analytics_service.dart';
import '../utils/logger.dart';
import '../utils/app_exception.dart';

class UserStatisticsService {
  static final UserStatisticsService _instance =
      UserStatisticsService._internal();
  factory UserStatisticsService() => _instance;
  UserStatisticsService._internal();

  static UserStatisticsService get instance => _instance;

  final FirebaseDatabaseService _firebase = FirebaseDatabaseService.instance;
  final Logger _logger = Logger('UserStatisticsService');
  Timer? _readingTimer;
  DateTime? _sessionStartTime;
  String? _currentUserId;
  bool _isTrackingEnabled = false;

  /// Initialize statistics tracking for a user
  Future<void> initializeTracking(String userId,
      {required bool isApproved}) async {
    _currentUserId = userId;
    _isTrackingEnabled = isApproved; // Only track for approved users

    if (_isTrackingEnabled) {
      _sessionStartTime = DateTime.now();
      await _recordSessionStart();
    }
  }

  /// Start tracking reading time
  void startReadingSession() {
    if (!_isTrackingEnabled || _currentUserId == null) return;

    _sessionStartTime = DateTime.now();
    _readingTimer?.cancel();

    // Update reading time every minute
    _readingTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateReadingTime();
    });
  }

  /// Stop tracking reading time
  void stopReadingSession() {
    if (!_isTrackingEnabled) return;

    _readingTimer?.cancel();
    _updateReadingTime();
    _sessionStartTime = null;
  }

  /// Record reading time for a user
  Future<void> recordReadingTime(Duration duration) async {
    if (!_isTrackingEnabled || _currentUserId == null) return;

    try {
      // Save to database
      await _updateUserStats({
        'total_reading_time': duration.inMinutes,
        'last_reading_date': DateTime.now().toIso8601String(),
      });

      // Create detailed reading session record
      await _firebase.firestore.collection('reading_sessions').add({
        'user_id': _currentUserId!,
        'duration_minutes': duration.inMinutes,
        'session_date': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

      _logger.debug('Reading time recorded: ${duration.inMinutes} minutes');
    } catch (e) {
      _logger.error('Error recording reading time', e);
      throw DatabaseException('Failed to record reading time',
          originalError: e);
    }
  }

  /// Record that a chapter was read
  Future<void> recordChapterRead(String book, int chapter) async {
    if (!_isTrackingEnabled || _currentUserId == null) return;

    try {
      // Save to database
      await _updateUserStats({
        'chapters_read': 1, // Increment by 1
        'last_chapter_read': '$book $chapter',
        'last_reading_date': DateTime.now().toIso8601String(),
      });

      // Create detailed chapter reading record
      await _firebase.firestore.collection('chapter_readings').add({
        'user_id': _currentUserId!,
        'book': book,
        'chapter': chapter,
        'read_date': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

      _logger.debug('Chapter read recorded: $book $chapter');
    } catch (e) {
      _logger.error('Error recording chapter read', e);
      throw DatabaseException('Failed to record chapter read',
          originalError: e);
    }
  }

  /// Record that verses were read
  Future<void> recordVersesRead(String reference, int verseCount) async {
    if (!_isTrackingEnabled || _currentUserId == null) return;

    try {
      // Save to database
      await _updateUserStats({
        'verses_read': verseCount, // Increment by verseCount
        'last_verse_read': reference,
        'last_reading_date': DateTime.now().toIso8601String(),
      });

      // Create detailed verse reading record

      await AnalyticsService.instance.trackEvent('verse_reading', parameters: {
        'user_id': _currentUserId!,
        'reference': reference,
        'verse_count': verseCount,
        'read_date': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

      // Record activity for streak calculation
      await _recordUserActivity('reading');

      _logger.debug('Verses read recorded: $reference ($verseCount verses)');
    } catch (e) {
      _logger.error('Error recording verses read', e);
      throw DatabaseException('Failed to record verses read', originalError: e);
    }
  }

  /// Record prayer offered
  Future<void> recordPrayerOffered(String prayerType) async {
    if (!_isTrackingEnabled || _currentUserId == null) return;

    try {
      // Save to database
      await _updateUserStats({
        'prayers_offered': 1, // Increment by 1
        'last_prayer_type': prayerType,
        'last_prayer_date': DateTime.now().toIso8601String(),
      });

      // Create detailed prayer record
      await AnalyticsService.instance.trackEvent('prayer_session', parameters: {
        'user_id': _currentUserId!,
        'prayer_type': prayerType,
        'prayer_date': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

      // Record activity for streak calculation
      await _recordUserActivity('prayer');

      _logger.debug('Prayer recorded: $prayerType');
    } catch (e) {
      _logger.error('Error recording prayer', e);
      throw DatabaseException('Failed to record prayer', originalError: e);
    }
  }

  /// Record study session completion
  Future<void> recordStudySessionCompleted(
      String sessionType, Duration duration) async {
    if (!_isTrackingEnabled || _currentUserId == null) return;

    try {
      // Save to database
      await _updateUserStats({
        'study_sessions_completed': 1, // Increment by 1
        'total_study_time': duration.inMinutes,
        'last_study_session_type': sessionType,
        'last_study_date': DateTime.now().toIso8601String(),
      });

      // Create detailed study session record
      await AnalyticsService.instance.trackEvent('study_session', parameters: {
        'user_id': _currentUserId!,
        'session_type': sessionType,
        'duration_minutes': duration.inMinutes,
        'session_date': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

      // Record activity for streak calculation
      await _recordUserActivity('study');

      _logger.debug(
          'Study session completed: $sessionType (${duration.inMinutes} minutes)');
    } catch (e) {
      _logger.error('Error recording study session', e);
      throw DatabaseException('Failed to record study session',
          originalError: e);
    }
  }

  /// Record app usage time
  Future<void> recordAppUsage(Duration duration) async {
    if (!_isTrackingEnabled || _currentUserId == null) return;

    try {
      // Save to database
      await _firebase.firestore
          .collection('profiles')
          .doc(_currentUserId!)
          .set({
        'total_app_time': duration.inMinutes,
        'updated_at': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      // Record activity for streak calculation if usage is significant (more than 1 minute)
      if (duration.inMinutes > 1) {
        await _recordUserActivity('app_usage');
      }

      _logger.debug('App usage recorded: ${duration.inMinutes} minutes');
    } catch (e) {
      _logger.error('Error recording app usage', e);
      throw DatabaseException('Failed to record app usage', originalError: e);
    }
  }

  /// Record engagement with content (likes, shares, comments)
  Future<void> recordContentEngagement({
    required String engagementType, // 'like', 'share', 'comment'
    required String contentType, // 'verse', 'prayer', 'study', 'chapter'
    String? contentId,
  }) async {
    if (!_isTrackingEnabled || _currentUserId == null) return;

    try {
      // Save to database - create engagement record
      await AnalyticsService.instance
          .trackEvent('user_engagement', parameters: {
        'user_id': _currentUserId!,
        'engagement_type': engagementType,
        'content_type': contentType,
        'content_id': contentId,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Also record this as a user activity for streak calculation
      await _recordUserActivity('engagement');

      _logger.debug(
          'Content engagement recorded: $engagementType on $contentType');
    } catch (e) {
      _logger.error('Error recording content engagement', e);
      throw DatabaseException('Failed to record content engagement',
          originalError: e);
    }
  }

  /// Record user activity for streak calculation
  Future<void> _recordUserActivity(String activityType) async {
    if (!_isTrackingEnabled || _currentUserId == null) return;

    try {
      final now = DateTime.now();
      final activityDate = now.toIso8601String();

      // Add to user_activities collection for streak tracking
      await _firebase.firestore.collection('user_activities').add({
        'user_id': _currentUserId!,
        'activity_type': activityType,
        'activity_date': activityDate,
        'created_at': activityDate,
      });

      _logger.debug('User activity recorded: $activityType');
    } catch (e) {
      _logger.error('Error recording user activity', e);
    }
  }

  /// Get user statistics
  Future<Map<String, dynamic>> getUserStatistics(String userId) async {
    try {
      final doc =
          await _firebase.firestore.collection('profiles').doc(userId).get();
      if (doc.exists) {
        return doc.data()!;
      }
      throw NotFoundException('User statistics not found');
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error fetching user statistics', e);
      throw DatabaseException('Failed to fetch user statistics',
          originalError: e);
    }
  }

  /// Get weekly reading goal progress with proper database queries
  Future<Map<String, dynamic>> getWeeklyProgress(String userId) async {
    try {
      final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));

      final oneWeekAgoIso = oneWeekAgo.toIso8601String();

      // Fetch weekly chapters
      final chaptersSnapshot = await _firebase.firestore
          .collection('chapter_readings')
          .where('user_id', isEqualTo: userId)
          .where('read_date', isGreaterThanOrEqualTo: oneWeekAgoIso)
          .get();
      final chaptersResponse =
          chaptersSnapshot.docs.map((doc) => doc.data()).toList();

      final chaptersReadThisWeek = chaptersResponse.length;

      // Fetch weekly verses
      final versesSnapshot = await _firebase.firestore
          .collection('analytics_events')
          .where('event_name', isEqualTo: 'verse_reading')
          .where('user_id', isEqualTo: userId)
          .where('created_at', isGreaterThanOrEqualTo: oneWeekAgoIso)
          .get();
      final versesResponse =
          versesSnapshot.docs.map((doc) => doc.data()).toList();

      final versesReadThisWeek = versesResponse.fold<int>(
        0,
        (acc, record) => acc + (record['verse_count'] as int? ?? 0),
      );

      // Fetch weekly study sessions
      final studySnapshot = await _firebase.firestore
          .collection('analytics_events')
          .where('event_name', isEqualTo: 'study_session')
          .where('user_id', isEqualTo: userId)
          .where('created_at', isGreaterThanOrEqualTo: oneWeekAgoIso)
          .get();
      final studyResponse =
          studySnapshot.docs.map((doc) => doc.data()).toList();

      final studyTimeThisWeek = studyResponse.fold<int>(
        0,
        (acc, record) => acc + (record['duration_minutes'] as int? ?? 0),
      );

      // Fetch weekly reading sessions
      final readingSnapshot = await _firebase.firestore
          .collection('reading_sessions')
          .where('user_id', isEqualTo: userId)
          .where('session_date', isGreaterThanOrEqualTo: oneWeekAgoIso)
          .get();
      final readingResponse =
          readingSnapshot.docs.map((doc) => doc.data()).toList();

      final readingTimeThisWeek = readingResponse.fold<int>(
        0,
        (acc, record) => acc + (record['duration_minutes'] as int? ?? 0),
      );

      return {
        'chaptersReadThisWeek': chaptersReadThisWeek,
        'weeklyChapterGoal': 7,
        'versesReadThisWeek': versesReadThisWeek,
        'weeklyVerseGoal': 200,
        'studyTimeThisWeek': studyTimeThisWeek,
        'weeklyStudyGoal': 120, // minutes
        'readingTimeThisWeek': readingTimeThisWeek,
        'weeklyReadingGoal': 180, // minutes
      };
    } catch (e) {
      _logger.error('Error calculating weekly progress', e);
      if (e is AppException) rethrow;
      throw DatabaseException('Failed to calculate weekly progress',
          originalError: e);
    }
  }

  /// Get monthly statistics summary
  Future<Map<String, dynamic>> getMonthlyStatistics(String userId) async {
    try {
      final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));

      final oneMonthAgoIso = oneMonthAgo.toIso8601String();

      // Fetch monthly chapters
      final chaptersSnapshot = await _firebase.firestore
          .collection('chapter_readings')
          .where('user_id', isEqualTo: userId)
          .where('read_date', isGreaterThanOrEqualTo: oneMonthAgoIso)
          .get();
      final chaptersResponse =
          chaptersSnapshot.docs.map((doc) => doc.data()).toList();

      // Fetch monthly verses
      final versesSnapshot = await _firebase.firestore
          .collection('analytics_events')
          .where('event_name', isEqualTo: 'verse_reading')
          .where('user_id', isEqualTo: userId)
          .where('created_at', isGreaterThanOrEqualTo: oneMonthAgoIso)
          .get();
      final versesResponse =
          versesSnapshot.docs.map((doc) => doc.data()).toList();

      final versesReadThisMonth = versesResponse.fold<int>(
        0,
        (acc, record) => acc + (record['verse_count'] as int? ?? 0),
      );

      // Fetch monthly study sessions
      final studySnapshot = await _firebase.firestore
          .collection('analytics_events')
          .where('event_name', isEqualTo: 'study_session')
          .where('user_id', isEqualTo: userId)
          .where('created_at', isGreaterThanOrEqualTo: oneMonthAgoIso)
          .get();
      final studyResponse =
          studySnapshot.docs.map((doc) => doc.data()).toList();

      final studyTimeThisMonth = studyResponse.fold<int>(
        0,
        (acc, record) => acc + (record['duration_minutes'] as int? ?? 0),
      );

      // Fetch monthly prayer sessions
      final prayerSnapshot = await _firebase.firestore
          .collection('analytics_events')
          .where('event_name', isEqualTo: 'prayer_session')
          .where('user_id', isEqualTo: userId)
          .where('created_at', isGreaterThanOrEqualTo: oneMonthAgoIso)
          .get();
      final prayerResponse =
          prayerSnapshot.docs.map((doc) => doc.data()).toList();

      return {
        'chaptersReadThisMonth': chaptersResponse.length,
        'versesReadThisMonth': versesReadThisMonth,
        'studyTimeThisMonth': studyTimeThisMonth,
        'prayersOfferedThisMonth': prayerResponse.length,
        'monthlyChapterGoal': 30,
        'monthlyVerseGoal': 800,
        'monthlyStudyGoal': 480, // minutes (8 hours)
        'monthlyPrayerGoal': 60,
      };
    } catch (e) {
      _logger.error('Error calculating monthly statistics', e);
      throw DatabaseException('Failed to calculate monthly statistics',
          originalError: e);
    }
  }

  /// Get reading streak for a user
  Future<int> getReadingStreak(String userId) async {
    try {
      // Get user activity records from Firebase
      final snapshot = await _firebase.firestore
          .collection('user_activities')
          .where('user_id', isEqualTo: userId)
          .where('activity_type', whereIn: ['reading', 'study', 'prayer'])
          .orderBy('activity_date', descending: true)
          .get();

      if (snapshot.docs.isEmpty) return 0;

      // Group activities by date (to handle multiple activities in one day)
      final Map<String, bool> activeDates = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final activityDate = data['activity_date'] as String?;

        if (activityDate != null) {
          // Extract just the date part (YYYY-MM-DD)
          final datePart = activityDate.split('T')[0];
          activeDates[datePart] = true;
        }
      }

      // Sort dates in descending order
      final sortedDates = activeDates.keys.toList()
        ..sort((a, b) => b.compareTo(a));

      if (sortedDates.isEmpty) return 0;

      // Calculate streak
      int streak = 0;
      final today = DateTime.now();
      final todayFormatted =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayFormatted =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      // Check if there's activity today or yesterday to start the streak
      if (activeDates.containsKey(todayFormatted) ||
          activeDates.containsKey(yesterdayFormatted)) {
        streak = 1; // Start with 1 for today/yesterday

        // Find the most recent date (today or yesterday)
        String? lastDateStr;
        if (activeDates.containsKey(todayFormatted)) {
          lastDateStr = todayFormatted;
        } else {
          lastDateStr = yesterdayFormatted;
        }

        // Convert to DateTime for calculations
        DateTime lastDate = DateTime.parse(lastDateStr);

        // Check consecutive days before today/yesterday
        for (int i = 1; i < sortedDates.length; i++) {
          final currentDateStr = sortedDates[i];
          final currentDate = DateTime.parse(currentDateStr);

          // Calculate days between this date and the last counted date
          final difference = lastDate.difference(currentDate).inDays;

          if (difference == 1) {
            // Consecutive day
            streak++;
            lastDate = currentDate;
          } else if (difference == 0) {
            // Same day (shouldn't happen with our grouping, but just in case)
            continue;
          } else {
            // Gap in streak
            break;
          }
        }
      }

      return streak;
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error calculating reading streak', e);
      throw DatabaseException('Failed to calculate reading streak',
          originalError: e);
    }
  }

  /// Private method to record session start
  Future<void> _recordSessionStart() async {
    try {
      // Save to database
      await _updateUserStats({
        'session_count': 1, // Increment by 1
        'last_session_start': DateTime.now().toIso8601String(),
      });

      _logger.debug('Session started for user: $_currentUserId');
    } catch (e) {
      _logger.error('Error recording session start', e);
      throw DatabaseException('Failed to record session start',
          originalError: e);
    }
  }

  /// Private method to update reading time
  void _updateReadingTime() {
    if (_sessionStartTime != null) {
      final duration = DateTime.now().difference(_sessionStartTime!);
      recordReadingTime(duration);
    }
  }

  /// Private method to update user statistics in database
  Future<void> _updateUserStats(Map<String, dynamic> updates) async {
    if (_currentUserId == null) return;

    try {
      // Fetch current stats from profile
      final doc = await _firebase.firestore
          .collection('profiles')
          .doc(_currentUserId!)
          .get();
      final currentStats = doc.exists ? doc.data()! : <String, dynamic>{};

      // Prepare incremental updates
      Map<String, dynamic> incrementalUpdates = {};

      if (updates.containsKey('total_reading_time')) {
        incrementalUpdates['total_reading_time'] =
            (currentStats['total_reading_time'] ?? 0) +
                updates['total_reading_time'];
      }
      if (updates.containsKey('chapters_read')) {
        incrementalUpdates['chapters_read'] =
            (currentStats['chapters_read'] ?? 0) + updates['chapters_read'];
      }
      if (updates.containsKey('verses_read')) {
        incrementalUpdates['verses_read'] =
            (currentStats['verses_read'] ?? 0) + updates['verses_read'];
      }
      if (updates.containsKey('prayers_offered')) {
        incrementalUpdates['prayers_offered'] =
            (currentStats['prayers_offered'] ?? 0) + updates['prayers_offered'];
      }
      if (updates.containsKey('study_sessions_completed')) {
        incrementalUpdates['study_sessions_completed'] =
            (currentStats['study_sessions_completed'] ?? 0) +
                updates['study_sessions_completed'];
      }

      // Add non-incremental updates
      updates.forEach((key, value) {
        if (!incrementalUpdates.containsKey(key)) {
          incrementalUpdates[key] = value;
        }
      });

      await _firebase.firestore
          .collection('profiles')
          .doc(_currentUserId!)
          .set(incrementalUpdates, SetOptions(merge: true));

      // Note: Update already handled by the set call above
      // await _firebase.updateUserStats(_currentUserId!, incrementalUpdates);
    } catch (e) {
      _logger.error('Error updating user statistics', e);
      throw DatabaseException('Failed to update user statistics',
          originalError: e);
    }
  }

  /// Enable or disable tracking
  void setTrackingEnabled(bool enabled) {
    _isTrackingEnabled = enabled;
    if (!enabled) {
      stopReadingSession();
    }
  }

  /// Clean up resources
  void dispose() {
    _readingTimer?.cancel();
    _sessionStartTime = null;
    _currentUserId = null;
    _isTrackingEnabled = false;
  }

  /// Reset statistics for a user (admin function)
  Future<void> resetUserStatistics(String userId) async {
    try {
      await _firebase.firestore.collection('profiles').doc(userId).set({
        'total_reading_time': 0,
        'chapters_read': 0,
        'verses_read': 0,
        'prayers_offered': 0,
        'study_sessions_completed': 0,
        'session_count': 0,
        'total_study_time': 0,
        'updated_at': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      _logger.info('Statistics reset for user: $userId');
    } catch (e) {
      _logger.error('Error resetting user statistics', e);
      throw DatabaseException('Failed to reset user statistics',
          originalError: e);
    }
  }

  /// Export user statistics for reporting
  Future<Map<String, dynamic>> exportUserStatistics(String userId) async {
    try {
      final stats = await getUserStatistics(userId);

      return {
        'userId': userId,
        'exportDate': DateTime.now().toIso8601String(),
        'statistics': stats,
        'weeklyProgress': await getWeeklyProgress(userId),
        'readingStreak': await getReadingStreak(userId),
      };
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error exporting user statistics', e);
      throw DatabaseException('Failed to export user statistics',
          originalError: e);
    }
  }
}
