import 'dart:async';
import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/appwrite_backend_config.dart';
import '../main.dart';
import 'storage_service.dart';
import 'auth_service.dart';
import '../utils/logger.dart';

class AnalyticsService {
  static AnalyticsService? _instance;
  static AnalyticsService get instance => _instance ??= AnalyticsService._();

  AnalyticsService._();

  static final Logger _logger = Logger('AnalyticsService');

  final TablesDB _tables = TablesDB(appwriteClient);
  final StorageService _storage = StorageService.instance;
  final AuthService _auth = AuthService.instance;

  bool _isInitialized = false;
  String? _sessionId;
  DateTime? _sessionStartTime;
  Timer? _sessionTimer;

  // Initialize analytics
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Start session
      await _startSession();

      // Set user properties
      await _setUserProperties();

      _isInitialized = true;

      // Track app open
      await trackEvent('app_open');
    } catch (e) {
      _logger.error('Analytics initialization error', e);
    }
  }

  // Start analytics session
  Future<void> _startSession() async {
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _sessionStartTime = DateTime.now();

    // Store session info
    await _storage.setString(StorageKeys.currentSessionId, _sessionId!);
    await _storage.setString(
        StorageKeys.sessionStartTime, _sessionStartTime!.toIso8601String());

    // Set up session timeout timer (30 minutes)
    _sessionTimer?.cancel();
    _sessionTimer = Timer(const Duration(minutes: 30), _endSession);

    // Track session start
    await trackEvent('session_start', parameters: {
      'session_id': _sessionId!,
    });
  }

  // End analytics session
  Future<void> _endSession() async {
    if (_sessionStartTime != null) {
      final sessionDuration =
          DateTime.now().difference(_sessionStartTime!).inSeconds;

      await trackEvent('session_end', parameters: {
        'session_id': _sessionId ?? 'unknown',
        'session_duration': sessionDuration,
      });

      // Store session data
      await _storeSessionData(sessionDuration);
    }

    _sessionId = null;
    _sessionStartTime = null;
    _sessionTimer?.cancel();
  }

  // Store session data locally
  Future<void> _storeSessionData(int duration) async {
    final sessions =
        await _storage.getJsonList(StorageKeys.analyticsData) ?? [];

    sessions.add({
      'session_id': _sessionId,
      'start_time': _sessionStartTime?.toIso8601String(),
      'duration': duration,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Keep only last 100 sessions
    if (sessions.length > 100) {
      sessions.removeRange(0, sessions.length - 100);
    }

    await _storage.setJsonList(
        StorageKeys.analyticsData, sessions.cast<Map<String, dynamic>>());
  }

  // Set user properties
  Future<void> _setUserProperties() async {
    try {
      final user = _auth.currentUser;
      final packageInfo = await PackageInfo.fromPlatform();
      await _storage.setJson('analytics_context', {
        'user_id': user?.uid ?? 'anonymous',
        'user_type': user == null ? 'anonymous' : 'authenticated',
        'app_version': packageInfo.version,
        'app_build': packageInfo.buildNumber,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _logger.error('Error setting user properties', e);
    }
  }

  // Track event
  Future<void> trackEvent(
    String eventName, {
    Map<String, dynamic>? parameters,
    bool storeLocally = true,
  }) async {
    try {
      // Add common parameters
      final eventParams = {
        'timestamp': DateTime.now().toIso8601String(),
        'session_id': _sessionId ?? 'no_session',
        'user_id': _auth.currentUser?.uid ?? 'anonymous',
        ...?parameters,
      };

      // Store locally if requested
      if (storeLocally) {
        await _storeEventLocally(eventName, eventParams);
      }

      // Optionally persist to Appwrite for audit/debugging.
      if (_auth.isAuthenticated) {
        try {
          await _tables.createRow(
            databaseId: AppwriteBackendConfig.databaseId,
            tableId: AppwriteBackendConfig.analyticsEventsCollectionId,
            rowId: ID.unique(),
            data: {
              'user_id': _auth.currentUser!.uid,
              'event_name': eventName,
              'parameters': jsonEncode(eventParams),
              'session_id': _sessionId,
              'created_at': DateTime.now().toUtc().toIso8601String(),
            },
          );
        } catch (e) {
          _logger.error('Failed to persist analytics event to Appwrite', e);
        }
      }
    } catch (e) {
      _logger.error('Error tracking event $eventName', e);
    }
  }

  // Store event locally
  Future<void> _storeEventLocally(
      String eventName, Map<String, dynamic> parameters) async {
    try {
      final events = await _storage.getJsonList('analytics_events') ?? [];

      events.add({
        'event_name': eventName,
        'parameters': parameters,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Keep only last 500 events
      if (events.length > 500) {
        events.removeRange(0, events.length - 500);
      }

      await _storage.setJsonList(
          'analytics_events', events.cast<Map<String, dynamic>>());
    } catch (e) {
      _logger.error('Error storing event locally', e);
    }
  }

  // Track screen view
  Future<void> trackScreenView(String screenName, {String? screenClass}) async {
    await trackEvent('screen_view', parameters: {
      'screen_name': screenName,
      'screen_class': screenClass ?? screenName,
    });

  }

  // Track user action
  Future<void> trackUserAction(
    String action, {
    String? category,
    String? label,
    int? value,
    Map<String, dynamic>? additionalParams,
  }) async {
    await trackEvent('user_action', parameters: {
      'action': action,
      'category': category,
      'label': label,
      'value': value,
      ...?additionalParams,
    });
  }

  // Track prayer request events
  Future<void> trackPrayerRequest(String action,
      {Map<String, dynamic>? metadata}) async {
    await trackEvent('prayer_request_$action', parameters: {
      'category': 'prayer',
      ...?metadata,
    });
  }

  // Track health activity events
  Future<void> trackHealthActivity(String action,
      {Map<String, dynamic>? metadata}) async {
    await trackEvent('health_activity_$action', parameters: {
      'category': 'health',
      ...?metadata,
    });
  }

  // Track study program events
  Future<void> trackStudyProgram(String action,
      {Map<String, dynamic>? metadata}) async {
    await trackEvent('study_program_$action', parameters: {
      'category': 'study',
      ...?metadata,
    });
  }

  // Track mission events
  Future<void> trackMission(String action,
      {Map<String, dynamic>? metadata}) async {
    await trackEvent('mission_$action', parameters: {
      'category': 'mission',
      ...?metadata,
    });
  }

  // Track engagement events
  Future<void> trackEngagement(String type,
      {Duration? duration, Map<String, dynamic>? metadata}) async {
    await trackEvent('engagement', parameters: {
      'engagement_type': type,
      'duration_seconds': duration?.inSeconds,
      ...?metadata,
    });
  }

  // Track error
  Future<void> trackError(
    String error, {
    String? context,
    Map<String, dynamic>? metadata,
    bool fatal = false,
  }) async {
    await trackEvent('error', parameters: {
      'error_message': error,
      'error_context': context,
      'is_fatal': fatal,
      ...?metadata,
    });

    _logger.error(
      'Tracked ${fatal ? 'fatal' : 'non-fatal'} error'
      '${context == null ? '' : ' in $context'}: $error',
    );
  }

  // Track performance
  Future<void> trackPerformance(
    String operation,
    Duration duration, {
    Map<String, dynamic>? metadata,
  }) async {
    await trackEvent('performance', parameters: {
      'operation': operation,
      'duration_ms': duration.inMilliseconds,
      ...?metadata,
    });
  }

  // Track conversion events
  Future<void> trackConversion(
    String conversionType, {
    String? source,
    double? value,
    Map<String, dynamic>? metadata,
  }) async {
    await trackEvent('conversion', parameters: {
      'conversion_type': conversionType,
      'source': source,
      'value': value,
      ...?metadata,
    });
  }

  // Set custom user property
  Future<void> setUserProperty(String name, String? value) async {
    final context = await _storage.getJson('analytics_context') ?? {};
    context[name] = value;
    context['updated_at'] = DateTime.now().toIso8601String();
    await _storage.setJson('analytics_context', context);
  }

  // Get analytics data
  Future<Map<String, dynamic>> getAnalyticsData() async {
    final sessions =
        await _storage.getJsonList(StorageKeys.analyticsData) ?? [];
    final events = await _storage.getJsonList('analytics_events') ?? [];

    return {
      'sessions': sessions,
      'events': events,
      'current_session_id': _sessionId,
      'session_start_time': _sessionStartTime?.toIso8601String(),
    };
  }

  // Clear analytics data
  Future<void> clearAnalyticsData() async {
    await _storage.remove(StorageKeys.analyticsData);
    await _storage.remove('analytics_events');
    await _storage.remove(StorageKeys.currentSessionId);
    await _storage.remove(StorageKeys.sessionStartTime);
  }

  // Reset analytics (for user logout)
  Future<void> reset() async {
    await _endSession();
    await clearAnalyticsData();
  }

  // Enable/disable analytics
  Future<void> setAnalyticsEnabled(bool enabled) async {
    await _storage.setBool('analytics_enabled', enabled);
  }

  // Check if analytics is enabled
  Future<bool> isAnalyticsEnabled() async {
    return await _storage.getBool('analytics_enabled') ?? true;
  }

  // Extend session (call when user is active)
  void extendSession() {
    if (_sessionTimer != null && _sessionStartTime != null) {
      _sessionTimer!.cancel();
      _sessionTimer = Timer(const Duration(minutes: 30), _endSession);
    }
  }

  // Dispose resources
  void dispose() {
    _sessionTimer?.cancel();
    _endSession();
  }
}

// Analytics Event Types
class AnalyticsEvents {
  // App lifecycle
  static const String appOpen = 'app_open';
  static const String appClose = 'app_close';
  static const String appBackground = 'app_background';
  static const String appForeground = 'app_foreground';

  // Authentication
  static const String signIn = 'sign_in';
  static const String signUp = 'sign_up';
  static const String signOut = 'sign_out';
  static const String passwordReset = 'password_reset';

  // Navigation
  static const String screenView = 'screen_view';
  static const String buttonTap = 'button_tap';
  static const String linkTap = 'link_tap';

  // Prayer requests
  static const String prayerRequestCreate = 'prayer_request_create';
  static const String prayerRequestUpdate = 'prayer_request_update';
  static const String prayerRequestDelete = 'prayer_request_delete';
  static const String prayerRequestPray = 'prayer_request_pray';
  static const String prayerRequestShare = 'prayer_request_share';

  // Health activities
  static const String healthActivityCreate = 'health_activity_create';
  static const String healthActivityUpdate = 'health_activity_update';
  static const String healthActivityComplete = 'health_activity_complete';

  // Study programs
  static const String studyProgramStart = 'study_program_start';
  static const String studyProgramComplete = 'study_program_complete';
  static const String studyLessonView = 'study_lesson_view';
  static const String studyLessonComplete = 'study_lesson_complete';

  // Missions
  static const String missionView = 'mission_view';
  static const String missionJoin = 'mission_join';
  static const String missionLeave = 'mission_leave';
  static const String missionDonate = 'mission_donate';

  // Social
  static const String share = 'share';
  static const String like = 'like';
  static const String comment = 'comment';
  static const String follow = 'follow';

  // Settings
  static const String settingsChange = 'settings_change';
  static const String notificationToggle = 'notification_toggle';
  static const String themeChange = 'theme_change';
  static const String languageChange = 'language_change';
}

// Riverpod providers
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService.instance;
});

final analyticsDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final analytics = ref.read(analyticsServiceProvider);
  return await analytics.getAnalyticsData();
});

final analyticsEnabledProvider = FutureProvider<bool>((ref) async {
  final analytics = ref.read(analyticsServiceProvider);
  return await analytics.isAnalyticsEnabled();
});
