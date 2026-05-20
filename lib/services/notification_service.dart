import 'dart:convert';

import 'package:appwrite/appwrite.dart' hide Locale;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:go_router/go_router.dart';
import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../utils/logger.dart';
import '../utils/app_exception.dart';
import 'auth_service.dart';
import 'firebase_messaging_base.dart';

class NotificationService extends FirebaseMessagingBase {
  static NotificationService? _instance;
  static NotificationService get instance =>
      _instance ??= NotificationService._();

  NotificationService._();

  final AuthService _authService = AuthService.instance;
  final Logger _logger = Logger('NotificationService');
  final Databases _databases = Databases(appwriteClient);

  // Global navigator key for navigation from background contexts
  static final GlobalKey<NavigatorState> _navigatorKey =
      GlobalKey<NavigatorState>();
  static GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  bool _isInitialized = false;

  // Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();

      // Initialize Firebase
      await FirebaseMessagingBase.initializeFirebase();

      // Initialize local notifications with custom handler
      await FirebaseMessagingBase.initializeLocalNotifications(
        onNotificationTapped: _onNotificationTapped,
      );

      // Request permissions
      final hasPermission =
          await FirebaseMessagingBase.requestNotificationPermissions();
      if (!hasPermission) {
        _logger.warning('Notification permissions not granted');
        return;
      }

      // Get and save FCM token
      await FirebaseMessagingBase.getAndSaveToken();

      // Setup message handlers with custom callbacks
      FirebaseMessagingBase.setupMessageHandlers(
        onForegroundMessage: _handleForegroundMessage,
        onBackgroundMessage: _handleBackgroundMessage,
        onMessageOpenedApp: _handleMessageOpenedApp,
      );

      // Setup token refresh listener
      FirebaseMessagingBase.setupTokenRefreshListener();

      _isInitialized = true;
    } catch (e) {
      _logger.error('Failed to initialize notifications', e);
    }
  }

  // Handle foreground messages with custom logic
  void _handleForegroundMessage(RemoteMessage message) {
    _logger.info('Received foreground message: ${message.messageId}');

    if (message.notification != null) {
      final title = message.notification!.title ?? 'Alive App';
      final body = message.notification!.body ?? '';

      // Show local notification for foreground messages
      FirebaseMessagingBase.showLocalNotification(
        id: message.hashCode,
        title: title,
        body: body,
        payload: message.data.toString(),
      );
    }
  }

  // Handle background messages with custom logic
  Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    _logger.info('Received background message: ${message.messageId}');

    // Process background message
    if (message.data.isNotEmpty) {
      _logger.info('Background message data: ${message.data}');

      // Process different types of background data
      final type = message.data['type'];
      switch (type) {
        case 'sync_data':
          // Trigger data synchronization
          _logger.info('Triggering data sync from background message');
          break;
        case 'cache_update':
          // Update local cache
          _logger.info('Updating cache from background message');
          break;
        case 'prayer_request_update':
          // Update prayer request data
          _logger.info('Updating prayer request data');
          break;
        case 'mission_update':
          // Update mission data
          _logger.info('Updating mission data');
          break;
        default:
          _logger.info('Processing general background message');
          break;
      }
    }
  }

  // Handle message when app is opened from background with custom logic
  void _handleMessageOpenedApp(RemoteMessage message) {
    _logger.info('Message opened app: ${message.messageId}');

    final data = message.data;
    if (data.containsKey('screen')) {
      _logger.info('Navigating to: ${data['screen']}');

      // Use the global navigator key to navigate
      final context = _navigatorKey.currentContext;
      if (context != null) {
        final screen = data['screen'] as String;
        context.go(screen.startsWith('/') ? screen : '/$screen');
      } else {
        _logger.warning(
            'Navigation context not available for direct screen navigation');
      }
    }

    // Handle navigation based on notification data
    _navigateFromNotification(message.data);
  }

  // Handle local notification tap with custom logic
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      _logger.info('Local notification tapped with payload: $payload');

      try {
        // Parse the payload as JSON if it contains structured data
        if (payload.startsWith('{')) {
          final data = Map<String, dynamic>.from(
              payload.split(',').fold<Map<String, String>>({}, (map, item) {
            final parts = item.replaceAll(RegExp(r'[{}]'), '').split(':');
            if (parts.length == 2) {
              map[parts[0].trim()] = parts[1].trim();
            }
            return map;
          }));
          _navigateFromNotification(data);
        } else {
          // Handle simple string payload
          _logger.info('Simple payload received: $payload');
        }
      } catch (e) {
        _logger.error('Error parsing notification payload: $e');
      }
    }
  }

  // Navigate based on notification data
  void _navigateFromNotification(Map<String, dynamic> data) {
    final type = data['type'];
    final id = data['id'];

    _logger.info('Navigating from notification: type=$type, id=$id');

    // Use the global navigator key to navigate from background contexts
    final context = _navigatorKey.currentContext;
    if (context == null) {
      _logger.warning('Navigation context not available');
      return;
    }

    switch (type) {
      case 'prayer_request':
        // Navigate to prayer request details with id: $id
        context.go('/prayer-requests${id != null ? '/$id' : ''}');
        _logger.info('Navigated to prayer request: $id');
        break;
      case 'mission':
        // Navigate to mission details with id: $id
        context.go('/missions${id != null ? '/$id' : ''}');
        _logger.info('Navigated to mission: $id');
        break;
      case 'daily_verse':
        // Navigate to daily verse
        context.go('/daily');
        _logger.info('Navigated to daily verse');
        break;
      case 'health_reminder':
        // Navigate to health screen
        context.go('/health');
        _logger.info('Navigated to health screen');
        break;
      case 'study_reminder':
        // Navigate to study screen
        context.go('/study');
        _logger.info('Navigated to study screen');
        break;
      case 'bible_memorization':
        // Navigate to Bible game screen for memorization
        context.go('/bible-game');
        _logger.info('Navigated to Bible memorization game');
        break;
      case 'prayer_reminder':
        // Navigate to prayer screen
        context.go('/prayer');
        _logger.info('Navigated to prayer screen');
        break;
      case 'mission_reminder':
        // Navigate to missions screen
        context.go('/missions');
        _logger.info('Navigated to missions screen');
        break;
      default:
        // Navigate to home
        context.go('/home');
        _logger.info('Navigated to home');
        break;
    }
  }

  // Show local notification using base class method
  // Schedule local notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String channelId = 'default',
    Map<String, dynamic>? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'default',
      'Default',
      channelDescription: 'Default notification channel',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await FirebaseMessagingBase.localNotifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload?.toString(),
    );
  }

  // Schedule daily verse notification
  Future<void> scheduleDailyVerseNotification({
    required DateTime time,
    bool enabled = true,
  }) async {
    if (!enabled) {
      await cancelNotification(1001);
      return;
    }

    await scheduleNotification(
      id: 1001,
      title: 'Daily Verse',
      body: 'Your daily Bible verse is ready!',
      scheduledDate: time,
      channelId: 'daily_verse',
      payload: {'type': 'daily_verse'},
    );
  }

  // Schedule health reminder
  Future<void> scheduleHealthReminder({
    required DateTime time,
    required String activity,
    bool enabled = true,
  }) async {
    final id = activity.hashCode;

    if (!enabled) {
      await cancelNotification(id);
      return;
    }

    await scheduleNotification(
      id: id,
      title: 'Health Reminder',
      body: 'Time for your $activity activity!',
      scheduledDate: time,
      channelId: 'health_reminders',
      payload: {'type': 'health_reminder', 'activity': activity},
    );
  }

  // Schedule study reminder
  Future<void> scheduleStudyReminder({
    required DateTime time,
    required String programName,
    bool enabled = true,
  }) async {
    final id = programName.hashCode;

    if (!enabled) {
      await cancelNotification(id);
      return;
    }

    await scheduleNotification(
      id: id,
      title: 'Study Reminder',
      body: 'Time to continue your $programName study!',
      scheduledDate: time,
      channelId: 'study_reminders',
      payload: {'type': 'study_reminder', 'program': programName},
    );
  }

  // Schedule Bible memorization reminder
  Future<void> scheduleBibleMemorizationReminder({
    required DateTime time,
    String? verseName,
    bool enabled = true,
  }) async {
    const id = 1006;

    if (!enabled) {
      await cancelNotification(id);
      return;
    }

    final body = verseName != null
        ? 'Time to practice $verseName!'
        : 'Time to practice your Bible verses!';

    await scheduleNotification(
      id: id,
      title: 'Bible Memorization',
      body: body,
      scheduledDate: time,
      channelId: 'study_reminders',
      payload: {'type': 'bible_memorization', 'verse': verseName},
    );
  }

  // Cancel notification
  Future<void> cancelNotification(int id) async {
    await FirebaseMessagingBase.localNotifications.cancel(id);
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await FirebaseMessagingBase.localNotifications.cancelAll();
  }

  // Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await FirebaseMessagingBase.localNotifications
        .pendingNotificationRequests();
  }

  // Update notification settings
  Future<void> updateNotificationSettings(Map<String, bool> settings) async {
    if (_authService.isAuthenticated) {
      try {
        final userId = _authService.currentUser!.uid;
        final data = {
          ...settings,
          'user_id': userId,
          'updated_at': DateTime.now().toIso8601String(),
        };
        await _upsertSettingsDocument(userId, data);
      } catch (e) {
        _logger.error('Failed to update notification settings', e);
        throw DatabaseException('Failed to update notification settings',
            originalError: e);
      }
    }
  }

  // Fetch notification settings for a user
  Future<NotificationSettings> fetchSettings(String userId) async {
    try {
      // ignore: deprecated_member_use
      final doc = await _databases.getDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.notificationSettingsCollectionId,
        documentId: userId,
      );

      return NotificationSettings.fromJson({...doc.data, 'id': doc.$id});
    } catch (e) {
      if (_isMissingDocument(e)) {
        return await createDefaultSettings(userId);
      }
      _logger.error('Failed to fetch settings, using defaults', e);
      return NotificationSettings.defaultSettings(userId);
    }
  }

  bool _isMissingDocument(Object error) {
    return error is AppwriteException && error.code == 404;
  }

  Future<void> _upsertSettingsDocument(
    String userId,
    Map<String, dynamic> data,
  ) async {
    final payload = _settingsPayload(data);
    try {
      // ignore: deprecated_member_use
      await _databases.updateDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.notificationSettingsCollectionId,
        documentId: userId,
        data: payload,
      );
    } catch (e) {
      if (!_isMissingDocument(e)) rethrow;
      // ignore: deprecated_member_use
      await _databases.createDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.notificationSettingsCollectionId,
        documentId: userId,
        data: payload,
      );
    }
  }

  Map<String, dynamic> _settingsPayload(Map<String, dynamic> data) {
    final payload = Map<String, dynamic>.from(data)..remove('id');
    final healthReminders = payload['health_reminder_settings'];
    if (healthReminders is List) {
      payload['health_reminder_settings'] = jsonEncode(healthReminders);
    }
    final studyReminders = payload['study_reminder_settings'];
    if (studyReminders is List) {
      payload['study_reminder_settings'] = jsonEncode(studyReminders);
    }
    payload.removeWhere((_, value) => value == null);
    return payload;
  }

  // Create default notification settings
  Future<NotificationSettings> createDefaultSettings(String userId) async {
    try {
      final defaultSettings = NotificationSettings.defaultSettings(userId);
      await _upsertSettingsDocument(userId, defaultSettings.toJson());
      return defaultSettings;
    } catch (e) {
      _logger.error('Failed to create default settings', e);
      return NotificationSettings.defaultSettings(userId);
    }
  }

  // Update notification settings in database
  Future<NotificationSettings> updateSettingsInDatabase(
      NotificationSettings settings) async {
    try {
      final updatedSettings = settings.copyWith(updatedAt: DateTime.now());
      await _upsertSettingsDocument(settings.userId, updatedSettings.toJson());
      return updatedSettings;
    } catch (e) {
      _logger.error('Failed to update notification settings', e);
      throw DatabaseException('Failed to update notification settings',
          originalError: e);
    }
  }

  // Schedule notifications based on settings
  Future<void> scheduleNotificationsFromSettings(
      NotificationSettings settings) async {
    try {
      await cancelAllNotifications();

      if (!settings.pushNotificationsEnabled) return;

      final timeParts = settings.reminderTime.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      final now = DateTime.now();
      var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      if (settings.dailyVerseReminder) {
        await scheduleNotification(
          id: 1001,
          title: 'Daily Bible Verse',
          body: 'Your daily verse is ready!',
          scheduledDate: scheduledDate,
          channelId: 'daily_verse',
          payload: {'type': 'daily_verse'},
        );
      }

      if (settings.prayerReminder) {
        await scheduleNotification(
          id: 1002,
          title: 'Prayer Time',
          body: 'Time for prayer and reflection',
          scheduledDate: scheduledDate.add(const Duration(minutes: 5)),
          channelId: 'prayer_requests',
          payload: {'type': 'prayer_reminder'},
        );
      }

      if (settings.healthTrackingReminder) {
        await scheduleNotification(
          id: 1003,
          title: 'Health Tracking',
          body: 'Don\'t forget to log your health data',
          scheduledDate: scheduledDate.add(const Duration(minutes: 10)),
          channelId: 'health_reminders',
          payload: {'type': 'health_reminder'},
        );
      }

      if (settings.studyReminder) {
        await scheduleNotification(
          id: 1004,
          title: 'Bible Study',
          body: 'Continue your Bible study journey',
          scheduledDate: scheduledDate.add(const Duration(minutes: 15)),
          channelId: 'study_reminders',
          payload: {'type': 'study_reminder'},
        );
      }

      if (settings.missionReminder) {
        await scheduleNotification(
          id: 1005,
          title: 'Mission Activity',
          body: 'Check out today\'s mission activities',
          scheduledDate: scheduledDate.add(const Duration(minutes: 20)),
          channelId: 'missions',
          payload: {'type': 'mission_reminder'},
        );
      }

      if (settings.bibleMemorizationReminder) {
        await scheduleNotification(
          id: 1006,
          title: 'Bible Memorization',
          body: 'Time to practice your Bible verses!',
          scheduledDate: scheduledDate.add(const Duration(minutes: 25)),
          channelId: 'study_reminders',
          payload: {'type': 'bible_memorization'},
        );
      }
    } catch (e) {
      _logger.error('Failed to schedule notifications', e);
      throw AppException('Failed to schedule notifications', originalError: e);
    }
  }

  // Get FCM token
  String? get fcmToken => FirebaseMessagingBase.fcmToken;

  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    // Try Android-specific implementation first
    final androidImplementation = FirebaseMessagingBase.localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      return await androidImplementation.areNotificationsEnabled() ?? false;
    }

    // Fallback to iOS-specific implementation
    final iosImplementation = FirebaseMessagingBase.localNotifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosImplementation != null) {
      return await iosImplementation.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    // For web or other platforms, assume notifications are enabled if plugin is available
    if (kIsWeb) {
      // Web: flutter_local_notifications has limited/no support; treat as enabled
      return true;
    }

    // Default fallback
    return false;
  }

  // Request notification permissions
  Future<bool> requestPermissions() async {
    return await FirebaseMessagingBase.requestNotificationPermissions();
  }
}

// Notification settings model
class NotificationSettings {
  final String? id;
  final String userId;
  final bool prayerRequests;
  final bool missions;
  final bool dailyVerse;
  final bool healthReminders;
  final bool studyReminders;
  final DateTime? dailyVerseTime;
  final List<HealthReminderSetting> healthReminderSettings;
  final List<StudyReminderSetting> studyReminderSettings;
  final bool dailyVerseReminder;
  final bool prayerReminder;
  final bool healthTrackingReminder;
  final bool studyReminder;
  final bool missionReminder;
  final bool bibleMemorizationReminder;
  final String reminderTime;
  final bool pushNotificationsEnabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  NotificationSettings({
    this.id,
    required this.userId,
    this.prayerRequests = true,
    this.missions = true,
    this.dailyVerse = true,
    this.healthReminders = true,
    this.studyReminders = true,
    this.dailyVerseTime,
    this.healthReminderSettings = const [],
    this.studyReminderSettings = const [],
    required this.dailyVerseReminder,
    required this.prayerReminder,
    required this.healthTrackingReminder,
    required this.studyReminder,
    required this.missionReminder,
    this.bibleMemorizationReminder = true,
    required this.reminderTime,
    required this.pushNotificationsEnabled,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'prayer_requests': prayerRequests,
      'missions': missions,
      'daily_verse': dailyVerse,
      'health_reminders': healthReminders,
      'study_reminders': studyReminders,
      'daily_verse_time': dailyVerseTime?.toIso8601String(),
      'health_reminder_settings':
          healthReminderSettings.map((e) => e.toJson()).toList(),
      'study_reminder_settings':
          studyReminderSettings.map((e) => e.toJson()).toList(),
      'daily_verse_reminder': dailyVerseReminder,
      'prayer_reminder': prayerReminder,
      'health_tracking_reminder': healthTrackingReminder,
      'study_reminder': studyReminder,
      'mission_reminder': missionReminder,
      'bible_memorization_reminder': bibleMemorizationReminder,
      'reminder_time': reminderTime,
      'push_notifications_enabled': pushNotificationsEnabled,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      prayerRequests: json['prayer_requests'] ?? true,
      missions: json['missions'] ?? true,
      dailyVerse: json['daily_verse'] ?? true,
      healthReminders: json['health_reminders'] ?? true,
      studyReminders: json['study_reminders'] ?? true,
      dailyVerseTime: json['daily_verse_time'] != null
          ? DateTime.parse(json['daily_verse_time'])
          : null,
      healthReminderSettings: (_decodeJsonList(json['health_reminder_settings']))
              ?.map((e) => HealthReminderSetting.fromJson(e))
              .toList() ??
          [],
      studyReminderSettings: (_decodeJsonList(json['study_reminder_settings']))
              ?.map((e) => StudyReminderSetting.fromJson(e))
              .toList() ??
          [],
      dailyVerseReminder: json['daily_verse_reminder'] as bool? ?? true,
      prayerReminder: json['prayer_reminder'] as bool? ?? true,
      healthTrackingReminder: json['health_tracking_reminder'] as bool? ?? true,
      studyReminder: json['study_reminder'] as bool? ?? true,
      missionReminder: json['mission_reminder'] as bool? ?? true,
      bibleMemorizationReminder:
          json['bible_memorization_reminder'] as bool? ?? true,
      reminderTime: json['reminder_time'] as String? ?? '08:00',
      pushNotificationsEnabled:
          json['push_notifications_enabled'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  NotificationSettings copyWith({
    String? id,
    String? userId,
    bool? prayerRequests,
    bool? missions,
    bool? dailyVerse,
    bool? healthReminders,
    bool? studyReminders,
    DateTime? dailyVerseTime,
    List<HealthReminderSetting>? healthReminderSettings,
    List<StudyReminderSetting>? studyReminderSettings,
    bool? dailyVerseReminder,
    bool? prayerReminder,
    bool? healthTrackingReminder,
    bool? studyReminder,
    bool? missionReminder,
    bool? bibleMemorizationReminder,
    String? reminderTime,
    bool? pushNotificationsEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationSettings(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      prayerRequests: prayerRequests ?? this.prayerRequests,
      missions: missions ?? this.missions,
      dailyVerse: dailyVerse ?? this.dailyVerse,
      healthReminders: healthReminders ?? this.healthReminders,
      studyReminders: studyReminders ?? this.studyReminders,
      dailyVerseTime: dailyVerseTime ?? this.dailyVerseTime,
      healthReminderSettings:
          healthReminderSettings ?? this.healthReminderSettings,
      studyReminderSettings:
          studyReminderSettings ?? this.studyReminderSettings,
      dailyVerseReminder: dailyVerseReminder ?? this.dailyVerseReminder,
      prayerReminder: prayerReminder ?? this.prayerReminder,
      healthTrackingReminder:
          healthTrackingReminder ?? this.healthTrackingReminder,
      studyReminder: studyReminder ?? this.studyReminder,
      missionReminder: missionReminder ?? this.missionReminder,
      bibleMemorizationReminder:
          bibleMemorizationReminder ?? this.bibleMemorizationReminder,
      reminderTime: reminderTime ?? this.reminderTime,
      pushNotificationsEnabled:
          pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Create default settings
  factory NotificationSettings.defaultSettings(String userId) {
    return NotificationSettings(
      userId: userId,
      prayerRequests: true,
      missions: true,
      dailyVerse: true,
      healthReminders: true,
      studyReminders: true,
      dailyVerseReminder: true,
      prayerReminder: true,
      healthTrackingReminder: true,
      studyReminder: true,
      missionReminder: true,
      bibleMemorizationReminder: true,
      reminderTime: '08:00',
      pushNotificationsEnabled: true,
    );
  }
}

List<Map<String, dynamic>>? _decodeJsonList(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
  if (value is! String || value.isEmpty) return null;

  final decoded = jsonDecode(value);
  if (decoded is! List) return null;
  return decoded
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

class HealthReminderSetting {
  final String activity;
  final DateTime time;
  final bool enabled;

  HealthReminderSetting({
    required this.activity,
    required this.time,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'activity': activity,
      'time': time.toIso8601String(),
      'enabled': enabled,
    };
  }

  factory HealthReminderSetting.fromJson(Map<String, dynamic> json) {
    return HealthReminderSetting(
      activity: json['activity'],
      time: DateTime.parse(json['time']),
      enabled: json['enabled'] ?? true,
    );
  }
}

class StudyReminderSetting {
  final String programId;
  final String programName;
  final DateTime time;
  final bool enabled;

  StudyReminderSetting({
    required this.programId,
    required this.programName,
    required this.time,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'program_id': programId,
      'program_name': programName,
      'time': time.toIso8601String(),
      'enabled': enabled,
    };
  }

  factory StudyReminderSetting.fromJson(Map<String, dynamic> json) {
    return StudyReminderSetting(
      programId: json['program_id'],
      programName: json['program_name'],
      time: DateTime.parse(json['time']),
      enabled: json['enabled'] ?? true,
    );
  }
}

// Riverpod providers
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

final notificationSettingsProvider =
    FutureProvider<NotificationSettings>((ref) async {
  // This would typically fetch from local storage or database
  return NotificationSettings(
    userId: '',
    dailyVerseReminder: true,
    prayerReminder: true,
    healthTrackingReminder: true,
    studyReminder: true,
    missionReminder: true,
    reminderTime: '07:00',
    pushNotificationsEnabled: false,
  );
});
