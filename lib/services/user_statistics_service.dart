import 'dart:async';
import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';
import 'analytics_service.dart';

class UserStatisticsService {
  static final UserStatisticsService _instance =
      UserStatisticsService._internal();
  factory UserStatisticsService() => _instance;
  UserStatisticsService._internal();

  static UserStatisticsService get instance => _instance;

  final TablesDB _tables = TablesDB(appwriteClient);
  final Logger _logger = Logger('UserStatisticsService');
  Timer? _readingTimer;
  DateTime? _sessionStartTime;
  String? _currentUserId;
  bool _isTrackingEnabled = false;

  /// Initialize statistics tracking for a user.
  Future<void> initializeTracking(
    String userId, {
    required bool isApproved,
  }) async {
    _currentUserId = userId;
    _isTrackingEnabled = isApproved;

    if (_isTrackingEnabled) {
      _sessionStartTime = DateTime.now();
      await _recordSessionStart();
    }
  }

  /// Start tracking reading time.
  void startReadingSession() {
    if (!_isTrackingEnabled || _currentUserId == null) return;

    _sessionStartTime = DateTime.now();
    _readingTimer?.cancel();

    _readingTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateReadingTime();
    });
  }

  /// Stop tracking reading time.
  void stopReadingSession() {
    if (!_isTrackingEnabled) return;

    _readingTimer?.cancel();
    _updateReadingTime();
    _sessionStartTime = null;
  }

  /// Record reading time for a user.
  Future<void> recordReadingTime(Duration duration) async {
    if (!_isTrackingEnabled || _currentUserId == null) return;

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _updateUserStats({
        'total_reading_time': duration.inMinutes,
        'last_reading_date': now,
      });

      await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.readingSessionsCollectionId,
        rowId: ID.unique(),
        data: {
          'user_id': _currentUserId!,
          'duration_minutes': duration.inMinutes,
          'session_date': now,
          'created_at': now,
        },
      );

      _logger.debug('Reading time recorded: ${duration.inMinutes} minutes');
    } catch (e) {
      _logger.error('Error recording reading time', e);
      throw DatabaseException('Failed to record reading time',
          originalError: e);
    }
  }

  /// Record that a chapter was read.
  Future<void> recordChapterRead(String book, int chapter) async {
    if (!_isTrackingEnabled || _currentUserId == null) return;

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _updateUserStats({
        'chapters_read': 1,
        'last_chapter_read': '$book $chapter',
        'last_reading_date': now,
      });

      await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.chapterReadingsCollectionId,
        rowId: ID.unique(),
        data: {
          'user_id': _currentUserId!,
          'book': book,
          'chapter': chapter,
          'read_date': now,
          'created_at': now,
        },
      );

      await _recordUserActivity('reading');
      _logger.debug('Chapter read recorded: $book $chapter');
    } catch (e) {
      _logger.error('Error recording chapter read', e);
      throw DatabaseException('Failed to record chapter read',
          originalError: e);
    }
  }

  /// Record that verses were read.
  Future<void> recordVersesRead(String reference, int verseCount) async {
    if (!_isTrackingEnabled || _currentUserId == null) return;

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _updateUserStats({
        'verses_read': verseCount,
        'last_verse_read': reference,
        'last_reading_date': now,
      });

      await AnalyticsService.instance.trackEvent('verse_reading', parameters: {
        'user_id': _currentUserId!,
        'reference': reference,
        'verse_count': verseCount,
        'read_date': now,
        'created_at': now,
      });

      await _recordUserActivity('reading');
      _logger.debug('Verses read recorded: $reference ($verseCount verses)');
    } catch (e) {
      _logger.error('Error recording verses read', e);
      throw DatabaseException('Failed to record verses read', originalError: e);
    }
  }

  /// Record prayer offered.
  Future<void> recordPrayerOffered(String prayerType) async {
    if (!_isTrackingEnabled || _currentUserId == null) return;

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _updateUserStats({
        'prayers_offered': 1,
        'last_prayer_type': prayerType,
        'last_prayer_date': now,
      });

      await AnalyticsService.instance.trackEvent('prayer_session', parameters: {
        'user_id': _currentUserId!,
        'prayer_type': prayerType,
        'prayer_date': now,
        'created_at': now,
      });

      await _recordUserActivity('prayer');
      _logger.debug('Prayer recorded: $prayerType');
    } catch (e) {
      _logger.error('Error recording prayer', e);
      throw DatabaseException('Failed to record prayer', originalError: e);
    }
  }

  /// Record study session completion.
  Future<void> recordStudySessionCompleted(
    String sessionType,
    Duration duration,
  ) async {
    if (!_isTrackingEnabled || _currentUserId == null) return;

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _updateUserStats({
        'study_sessions_completed': 1,
        'total_study_time': duration.inMinutes,
        'last_study_session_type': sessionType,
        'last_study_date': now,
      });

      await AnalyticsService.instance.trackEvent('study_session', parameters: {
        'user_id': _currentUserId!,
        'session_type': sessionType,
        'duration_minutes': duration.inMinutes,
        'session_date': now,
        'created_at': now,
      });

      await _recordUserActivity('study');
      _logger.debug(
          'Study session completed: $sessionType (${duration.inMinutes} minutes)');
    } catch (e) {
      _logger.error('Error recording study session', e);
      throw DatabaseException('Failed to record study session',
          originalError: e);
    }
  }

  /// Record app usage time.
  Future<void> recordAppUsage(Duration duration) async {
    if (!_isTrackingEnabled || _currentUserId == null) return;

    try {
      await _updateUserStats({
        'total_app_time': duration.inMinutes,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (duration.inMinutes > 1) {
        await _recordUserActivity('app_usage');
      }

      _logger.debug('App usage recorded: ${duration.inMinutes} minutes');
    } catch (e) {
      _logger.error('Error recording app usage', e);
      throw DatabaseException('Failed to record app usage', originalError: e);
    }
  }

  /// Record engagement with content.
  Future<void> recordContentEngagement({
    required String engagementType,
    required String contentType,
    String? contentId,
  }) async {
    if (!_isTrackingEnabled || _currentUserId == null) return;

    try {
      await AnalyticsService.instance.trackEvent(
        'user_engagement',
        parameters: {
          'user_id': _currentUserId!,
          'engagement_type': engagementType,
          'content_type': contentType,
          'content_id': contentId,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
      );

      await _recordUserActivity('engagement');
      _logger.debug(
          'Content engagement recorded: $engagementType on $contentType');
    } catch (e) {
      _logger.error('Error recording content engagement', e);
      throw DatabaseException('Failed to record content engagement',
          originalError: e);
    }
  }

  /// Get user statistics from the Appwrite users table.
  Future<Map<String, dynamic>> getUserStatistics(String userId) async {
    try {
      final row = await _tables.getRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.usersCollectionId,
        rowId: userId,
      );
      return row.data;
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        throw NotFoundException('User statistics not found');
      }
      _logger.error('Error fetching user statistics', e);
      throw DatabaseException('Failed to fetch user statistics',
          originalError: e);
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error fetching user statistics', e);
      throw DatabaseException('Failed to fetch user statistics',
          originalError: e);
    }
  }

  /// Get weekly reading goal progress with Appwrite queries.
  Future<Map<String, dynamic>> getWeeklyProgress(String userId) async {
    try {
      final oneWeekAgo =
          DateTime.now().toUtc().subtract(const Duration(days: 7));
      final oneWeekAgoIso = oneWeekAgo.toIso8601String();

      final chaptersResponse = await _listDocuments(
        AppwriteBackendConfig.chapterReadingsCollectionId,
        [
          Query.equal('user_id', userId),
          Query.greaterThanEqual('read_date', oneWeekAgoIso),
          Query.limit(100),
        ],
      );

      final versesResponse = await _listAnalyticsEvents(
        userId: userId,
        eventName: 'verse_reading',
        sinceIso: oneWeekAgoIso,
      );

      final studyResponse = await _listAnalyticsEvents(
        userId: userId,
        eventName: 'study_session',
        sinceIso: oneWeekAgoIso,
      );

      final readingResponse = await _listDocuments(
        AppwriteBackendConfig.readingSessionsCollectionId,
        [
          Query.equal('user_id', userId),
          Query.greaterThanEqual('session_date', oneWeekAgoIso),
          Query.limit(100),
        ],
      );

      return {
        'chaptersReadThisWeek': chaptersResponse.length,
        'weeklyChapterGoal': 7,
        'versesReadThisWeek': _sumInt(versesResponse, 'verse_count'),
        'weeklyVerseGoal': 200,
        'studyTimeThisWeek': _sumInt(studyResponse, 'duration_minutes'),
        'weeklyStudyGoal': 120,
        'readingTimeThisWeek': _sumInt(readingResponse, 'duration_minutes'),
        'weeklyReadingGoal': 180,
      };
    } catch (e) {
      _logger.error('Error calculating weekly progress', e);
      if (e is AppException) rethrow;
      throw DatabaseException('Failed to calculate weekly progress',
          originalError: e);
    }
  }

  /// Get monthly statistics summary.
  Future<Map<String, dynamic>> getMonthlyStatistics(String userId) async {
    try {
      final oneMonthAgo =
          DateTime.now().toUtc().subtract(const Duration(days: 30));
      final oneMonthAgoIso = oneMonthAgo.toIso8601String();

      final chaptersResponse = await _listDocuments(
        AppwriteBackendConfig.chapterReadingsCollectionId,
        [
          Query.equal('user_id', userId),
          Query.greaterThanEqual('read_date', oneMonthAgoIso),
          Query.limit(100),
        ],
      );

      final versesResponse = await _listAnalyticsEvents(
        userId: userId,
        eventName: 'verse_reading',
        sinceIso: oneMonthAgoIso,
      );
      final studyResponse = await _listAnalyticsEvents(
        userId: userId,
        eventName: 'study_session',
        sinceIso: oneMonthAgoIso,
      );
      final prayerResponse = await _listAnalyticsEvents(
        userId: userId,
        eventName: 'prayer_session',
        sinceIso: oneMonthAgoIso,
      );

      return {
        'chaptersReadThisMonth': chaptersResponse.length,
        'versesReadThisMonth': _sumInt(versesResponse, 'verse_count'),
        'studyTimeThisMonth': _sumInt(studyResponse, 'duration_minutes'),
        'prayersOfferedThisMonth': prayerResponse.length,
        'monthlyChapterGoal': 30,
        'monthlyVerseGoal': 800,
        'monthlyStudyGoal': 480,
        'monthlyPrayerGoal': 60,
      };
    } catch (e) {
      _logger.error('Error calculating monthly statistics', e);
      throw DatabaseException('Failed to calculate monthly statistics',
          originalError: e);
    }
  }

  /// Get reading streak for a user.
  Future<int> getReadingStreak(String userId) async {
    try {
      final activities = await _listDocuments(
        AppwriteBackendConfig.userActivitiesCollectionId,
        [
          Query.equal('user_id', userId),
          Query.orderDesc('activity_date'),
          Query.limit(100),
        ],
      );

      final activeDates = <String, bool>{};
      for (final activity in activities) {
        final type = activity['activity_type'] as String?;
        if (!['reading', 'study', 'prayer'].contains(type)) continue;

        final activityDate = activity['activity_date'] as String?;
        if (activityDate != null) {
          activeDates[activityDate.split('T')[0]] = true;
        }
      }

      final sortedDates = activeDates.keys.toList()
        ..sort((a, b) => b.compareTo(a));
      if (sortedDates.isEmpty) return 0;

      int streak = 0;
      final today = DateTime.now();
      final todayFormatted = _dateKey(today);
      final yesterdayFormatted =
          _dateKey(today.subtract(const Duration(days: 1)));

      if (activeDates.containsKey(todayFormatted) ||
          activeDates.containsKey(yesterdayFormatted)) {
        streak = 1;

        final lastDateStr = activeDates.containsKey(todayFormatted)
            ? todayFormatted
            : yesterdayFormatted;
        var lastDate = DateTime.parse(lastDateStr);

        for (var i = 1; i < sortedDates.length; i++) {
          final currentDate = DateTime.parse(sortedDates[i]);
          final difference = lastDate.difference(currentDate).inDays;

          if (difference == 1) {
            streak++;
            lastDate = currentDate;
          } else if (difference != 0) {
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

  /// Enable or disable tracking.
  void setTrackingEnabled(bool enabled) {
    _isTrackingEnabled = enabled;
    if (!enabled) {
      stopReadingSession();
    }
  }

  /// Clean up resources.
  void dispose() {
    _readingTimer?.cancel();
    _sessionStartTime = null;
    _currentUserId = null;
    _isTrackingEnabled = false;
  }

  /// Reset statistics for a user.
  Future<void> resetUserStatistics(String userId) async {
    try {
      await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.usersCollectionId,
        rowId: userId,
        data: {
          'total_reading_time': 0,
          'chapters_read': 0,
          'verses_read': 0,
          'prayers_offered': 0,
          'study_sessions_completed': 0,
          'session_count': 0,
          'total_study_time': 0,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      );

      _logger.info('Statistics reset for user: $userId');
    } catch (e) {
      _logger.error('Error resetting user statistics', e);
      throw DatabaseException('Failed to reset user statistics',
          originalError: e);
    }
  }

  /// Export user statistics for reporting.
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

  Future<void> _recordUserActivity(String activityType) async {
    if (!_isTrackingEnabled || _currentUserId == null) return;

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.userActivitiesCollectionId,
        rowId: ID.unique(),
        data: {
          'user_id': _currentUserId!,
          'activity_type': activityType,
          'activity_date': now,
          'created_at': now,
        },
      );

      _logger.debug('User activity recorded: $activityType');
    } catch (e) {
      _logger.error('Error recording user activity', e);
    }
  }

  Future<void> _recordSessionStart() async {
    try {
      await _updateUserStats({
        'session_count': 1,
        'last_session_start': DateTime.now().toUtc().toIso8601String(),
      });

      _logger.debug('Session started for user: $_currentUserId');
    } catch (e) {
      _logger.error('Error recording session start', e);
      throw DatabaseException('Failed to record session start',
          originalError: e);
    }
  }

  void _updateReadingTime() {
    if (_sessionStartTime != null) {
      final duration = DateTime.now().difference(_sessionStartTime!);
      recordReadingTime(duration);
    }
  }

  Future<void> _updateUserStats(Map<String, dynamic> updates) async {
    if (_currentUserId == null) return;

    try {
      final currentStats = await getUserStatistics(_currentUserId!);
      final incrementalUpdates = <String, dynamic>{};

      for (final key in [
        'total_reading_time',
        'chapters_read',
        'verses_read',
        'prayers_offered',
        'study_sessions_completed',
        'session_count',
        'total_study_time',
        'total_app_time',
      ]) {
        if (updates.containsKey(key)) {
          incrementalUpdates[key] =
              _intValue(currentStats[key]) + _intValue(updates[key]);
        }
      }

      updates.forEach((key, value) {
        incrementalUpdates.putIfAbsent(key, () => value);
      });
      incrementalUpdates['updated_at'] =
          DateTime.now().toUtc().toIso8601String();

      await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.usersCollectionId,
        rowId: _currentUserId!,
        data: incrementalUpdates,
      );
    } catch (e) {
      _logger.error('Error updating user statistics', e);
      throw DatabaseException('Failed to update user statistics',
          originalError: e);
    }
  }

  Future<List<Map<String, dynamic>>> _listDocuments(
    String collectionId,
    List<String> queries,
  ) async {
    final response = await _tables.listRows(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: collectionId,
      queries: queries,
    );
    return response.rows.map(_rowData).toList();
  }

  Map<String, dynamic> _rowData(models.Row row) {
    return Map<String, dynamic>.from(row.data);
  }

  Future<List<Map<String, dynamic>>> _listAnalyticsEvents({
    required String userId,
    required String eventName,
    required String sinceIso,
  }) async {
    final events = await _listDocuments(
      AppwriteBackendConfig.analyticsEventsCollectionId,
      [
        Query.equal('user_id', userId),
        Query.equal('event_name', eventName),
        Query.greaterThanEqual('created_at', sinceIso),
        Query.limit(100),
      ],
    );

    return events.map((event) {
      final parameters = event['parameters'];
      if (parameters is String) {
        final decoded = jsonDecode(parameters);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      }
      return event;
    }).toList();
  }

  int _sumInt(List<Map<String, dynamic>> records, String key) {
    return records.fold<int>(
      0,
      (acc, record) => acc + _intValue(record[key]),
    );
  }

  int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
