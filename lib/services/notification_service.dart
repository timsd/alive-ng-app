import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';
import 'supabase_service.dart';
import 'auth_service.dart';

class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance =>
      _instance ??= NotificationService._();

  NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final SupabaseService _supabaseService = SupabaseService.instance;
  final AuthService _authService = AuthService.instance;
  final Logger _logger = Logger('NotificationService');

  bool _isInitialized = false;
  String? _fcmToken;

  // Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
      await _initializeLocalNotifications();
      await _initializeFirebaseMessaging();
      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize notifications: $e');
      }
    }
  }

  // Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }
  }

  // Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    const channels = [
      AndroidNotificationChannel(
        'prayer_requests',
        'Prayer Requests',
        description: 'Notifications for new prayer requests',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'missions',
        'Missions',
        description: 'Notifications for mission opportunities',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'daily_verse',
        'Daily Verse',
        description: 'Daily Bible verse notifications',
        importance: Importance.defaultImportance,
      ),
      AndroidNotificationChannel(
        'health_reminders',
        'Health Reminders',
        description: 'Health and wellness reminders',
        importance: Importance.defaultImportance,
      ),
      AndroidNotificationChannel(
        'study_reminders',
        'Study Reminders',
        description: 'Bible study reminders',
        importance: Importance.defaultImportance,
      ),
    ];

    for (final channel in channels) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  // Initialize Firebase Messaging
  Future<void> _initializeFirebaseMessaging() async {
    // Request permission
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get FCM token
      _fcmToken = await _firebaseMessaging.getToken();

      // Update token in database if user is authenticated
      if (_authService.isAuthenticated && _fcmToken != null) {
        await _supabaseService.updateFCMToken(
            _authService.currentUser!.id, _fcmToken!);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((token) async {
        _fcmToken = token;
        if (_authService.isAuthenticated) {
          await _supabaseService.updateFCMToken(
              _authService.currentUser!.id, token);
        }
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

      // Handle notification taps when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Handle notification tap when app is terminated
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    }
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('Received foreground message: ${message.messageId}');
    }

    // Show local notification for foreground messages
    _showLocalNotification(
      title: message.notification?.title ?? 'Alive App',
      body: message.notification?.body ?? '',
      payload: message.data,
    );
  }

  // Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    if (kDebugMode) {
      print('Notification tapped: ${message.messageId}');
    }

    // Handle navigation based on notification data
    _navigateFromNotification(message.data);
  }

  // Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      // Parse payload and navigate
      // This would typically involve parsing JSON and navigating to specific screens
      if (kDebugMode) {
        print('Local notification tapped: ${response.payload}');
      }
    }
  }

  // Navigate based on notification data
  void _navigateFromNotification(Map<String, dynamic> data) {
    final type = data['type'];
    final id = data['id'];
    
    _logger.info('Navigating from notification: type=$type, id=$id');

    switch (type) {
      case 'prayer_request':
        // Navigate to prayer request details with id: $id
        break;
      case 'mission':
        // Navigate to mission details with id: $id
        break;
      case 'daily_verse':
        // Navigate to daily verse with id: $id
        break;
      case 'health_reminder':
        // Navigate to health screen with id: $id
        break;
      case 'study_reminder':
        // Navigate to study screen
        break;
      case 'bible_memorization':
        // Navigate to Bible game screen for memorization
        break;
      default:
        // Navigate to home
        break;
    }
  }

  // Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
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

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload?.toString(),
    );
  }

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

    await _localNotifications.zonedSchedule(
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
    await _localNotifications.cancel(id);
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  // Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _localNotifications.pendingNotificationRequests();
  }

  // Update notification settings
  Future<void> updateNotificationSettings(Map<String, bool> settings) async {
    if (_authService.isAuthenticated) {
      await _supabaseService.updateNotificationSettings(
        _authService.currentUser!.id,
        settings,
      );
    }
  }

  // Fetch notification settings for a user
  Future<NotificationSettings> fetchSettings(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('notification_settings')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        return NotificationSettings.fromJson(response);
      } else {
        return await createDefaultSettings(userId);
      }
    } catch (e) {
      return NotificationSettings.defaultSettings(userId);
    }
  }

  // Create default notification settings
  Future<NotificationSettings> createDefaultSettings(String userId) async {
    try {
      final defaultSettings = NotificationSettings.defaultSettings(userId);
      final response = await Supabase.instance.client
          .from('notification_settings')
          .insert(defaultSettings.toJson())
          .select()
          .single();

      return NotificationSettings.fromJson(response);
    } catch (e) {
      return NotificationSettings.defaultSettings(userId);
    }
  }

  // Update notification settings in database
  Future<NotificationSettings> updateSettingsInDatabase(
      NotificationSettings settings) async {
    try {
      final response = await Supabase.instance.client
          .from('notification_settings')
          .upsert(settings.copyWith(updatedAt: DateTime.now()).toJson())
          .select()
          .single();

      return NotificationSettings.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update notification settings: $e');
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
      throw Exception('Failed to schedule notifications: $e');
    }
  }

  // Get FCM token
  String? get fcmToken => _fcmToken;

  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final androidImplementation =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      return await androidImplementation?.areNotificationsEnabled() ?? false;
    } else if (Platform.isIOS) {
      final iosImplementation =
          _localNotifications.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      return await iosImplementation?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  // Request notification permissions
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidImplementation =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      return await androidImplementation?.requestNotificationsPermission() ??
          false;
    } else if (Platform.isIOS) {
      final iosImplementation =
          _localNotifications.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      return await iosImplementation?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }
}

// Background message handler (must be top-level function)
Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  if (kDebugMode) {
    print('Handling background message: ${message.messageId}');
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
      healthReminderSettings: (json['health_reminder_settings'] as List?)
              ?.map((e) => HealthReminderSetting.fromJson(e))
              .toList() ??
          [],
      studyReminderSettings: (json['study_reminder_settings'] as List?)
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
