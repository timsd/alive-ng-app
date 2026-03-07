import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'firebase_database_service.dart';
import 'storage_service.dart';
import 'auth_service.dart';
import '../utils/logger.dart';

class AnalyticsService {
  static AnalyticsService? _instance;
  static AnalyticsService get instance => _instance ??= AnalyticsService._();

  AnalyticsService._();

  static final Logger _logger = Logger('AnalyticsService');

  final FirebaseDatabaseService _firebase = FirebaseDatabaseService.instance;
  final StorageService _storage = StorageService.instance;
  final AuthService _auth = AuthService.instance;

  // Supabase removed

  FirebaseAnalytics? _analytics;
  FirebaseCrashlytics? _crashlytics;

  bool _isInitialized = false;
  String? _sessionId;
  DateTime? _sessionStartTime;
  Timer? _sessionTimer;

  // Initialize analytics
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Firebase Analytics
      _analytics = FirebaseAnalytics.instance;
      _crashlytics = FirebaseCrashlytics.instance;

      // Set up crash reporting
      if (!kDebugMode) {
        FlutterError.onError = _crashlytics!.recordFlutterFatalError;
        PlatformDispatcher.instance.onError = (error, stack) {
          _crashlytics!.recordError(error, stack, fatal: true);
          return true;
        };
      }

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
      if (user != null) {
        await _analytics?.setUserId(id: user.uid);
        await _crashlytics?.setUserIdentifier(user.uid);

        // Set user properties
        await _analytics?.setUserProperty(
            name: 'user_type', value: 'authenticated');

        // Get user profile for additional properties
        final profile = await _storage.getJson(StorageKeys.userProfile);
        if (profile != null) {
          await _analytics?.setUserProperty(
            name: 'user_role',
            value: profile['role'] ?? 'member',
          );
          await _analytics?.setUserProperty(
            name: 'church_id',
            value: profile['church_id']?.toString(),
          );
        }
      } else {
        await _analytics?.setUserProperty(
            name: 'user_type', value: 'anonymous');
      }

      // Set app properties
      final packageInfo = await PackageInfo.fromPlatform();
      await _analytics?.setUserProperty(
          name: 'app_version', value: packageInfo.version);
      await _analytics?.setUserProperty(
          name: 'app_build', value: packageInfo.buildNumber);

      // Set device properties
      final deviceInfo = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        await _analytics?.setUserProperty(
            name: 'device_model', value: androidInfo.model);
        await _analytics?.setUserProperty(
            name: 'os_version', value: androidInfo.version.release);
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        await _analytics?.setUserProperty(
            name: 'device_model', value: iosInfo.model);
        await _analytics?.setUserProperty(
            name: 'os_version', value: iosInfo.systemVersion);
      }
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

      // Track with Firebase Analytics
      if (_analytics != null) {
        // Convert parameters to Firebase Analytics format
        final firebaseParams = <String, Object>{};
        eventParams.forEach((key, value) {
          if (value != null) {
            firebaseParams[key] = value.toString();
          }
        });

        await _analytics!.logEvent(
          name: eventName.replaceAll(' ', '_').toLowerCase(),
          parameters: firebaseParams,
        );
      }

      // Store locally if requested
      if (storeLocally) {
        await _storeEventLocally(eventName, eventParams);
      }

      // Optionally persist to Firestore for audit/debugging
      if (_auth.isAuthenticated) {
        try {
          await _firebase.firestore.collection('analytics_events').add({
            'user_id': _auth.currentUser!.uid,
            'event_name': eventName,
            'parameters': eventParams,
            'session_id': _sessionId,
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          _logger.error('Failed to persist analytics event to Firestore', e);
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

    // Also track with Firebase Analytics
    await _analytics?.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
    );
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

    // Also report to Crashlytics
    if (_crashlytics != null) {
      await _crashlytics!.recordError(
        error,
        null,
        fatal: fatal,
        information: [
          if (context != null) 'Context: $context',
          if (metadata != null) 'Metadata: ${jsonEncode(metadata)}',
        ],
      );
    }
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
    await _analytics?.setUserProperty(name: name, value: value);
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
    await _analytics?.resetAnalyticsData();
    await clearAnalyticsData();

    // Clear user identification
    await _crashlytics?.setUserIdentifier('');
  }

  // Enable/disable analytics
  Future<void> setAnalyticsEnabled(bool enabled) async {
    await _analytics?.setAnalyticsCollectionEnabled(enabled);
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
