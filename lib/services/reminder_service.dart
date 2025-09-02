import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_service.dart';

enum ReminderType {
  dailyVerse('daily_verse'),
  prayer('prayer'),
  healthTracking('health_tracking'),
  study('study'),
  mission('mission');

  const ReminderType(this.value);
  final String value;

  static ReminderType fromString(String value) {
    return ReminderType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ReminderType.dailyVerse,
    );
  }
}

class ReminderConfig {
  final ReminderType type;
  final String title;
  final String body;
  final TimeOfDay time;
  final bool enabled;

  const ReminderConfig({
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    required this.enabled,
  });

  factory ReminderConfig.fromJson(Map<String, dynamic> json) {
    final timeString = json['time'] as String;
    final timeParts = timeString.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    return ReminderConfig(
      type: ReminderType.fromString(json['type'] as String),
      title: json['title'] as String,
      body: json['body'] as String,
      time: TimeOfDay(hour: hour, minute: minute),
      enabled: json['enabled'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.value,
      'title': title,
      'body': body,
      'time':
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      'enabled': enabled,
    };
  }

  ReminderConfig copyWith({
    ReminderType? type,
    String? title,
    String? body,
    TimeOfDay? time,
    bool? enabled,
  }) {
    return ReminderConfig(
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      time: time ?? this.time,
      enabled: enabled ?? this.enabled,
    );
  }
}

class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseService _firebaseService = FirebaseService();

  bool _isInitialized = false;
  final Map<String, Timer> _scheduledReminders = {};

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone
    tz.initializeTimeZones();

    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();

    // Request Android notification permission (API 33+)
    final androidPermission = await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Request iOS notification permission
    final iosPermission = await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    // Also request Firebase FCM permission
    await _firebaseService.requestPermission();

    return androidPermission ?? iosPermission ?? true;
  }

  Future<bool> scheduleReminder(ReminderConfig config) async {
    if (!config.enabled) {
      return false;
    }

    await initialize();

    // Clear existing reminder if any
    await clearReminder(config.type.value);

    try {
      final now = DateTime.now();
      var scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        config.time.hour,
        config.time.minute,
      );

      // If the time has passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      // Schedule local notification
      await _scheduleLocalNotification(config, scheduledDate);

      // Schedule recurring timer for daily reminders
      _scheduleRecurringReminder(config);

      return true;
    } catch (error) {
      debugPrint('Error scheduling reminder: $error');
      return false;
    }
  }

  Future<void> _scheduleLocalNotification(
    ReminderConfig config,
    DateTime scheduledDate,
  ) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'reminder_channel',
      'Reminders',
      channelDescription: 'Daily reminders for ALIVE-NG app',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      config.type.value.hashCode,
      config.title,
      config.body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({
        'type': config.type.value,
        'route': _getRouteForType(config.type),
      }),
    );
  }

  void _scheduleRecurringReminder(ReminderConfig config) {
    final now = DateTime.now();
    var nextReminder = DateTime(
      now.year,
      now.month,
      now.day,
      config.time.hour,
      config.time.minute,
    );

    if (nextReminder.isBefore(now)) {
      nextReminder = nextReminder.add(const Duration(days: 1));
    }

    final duration = nextReminder.difference(now);

    _scheduledReminders[config.type.value] = Timer.periodic(
      const Duration(days: 1),
      (timer) {
        if (config.enabled) {
          _showLocalNotification(config);
        } else {
          timer.cancel();
          _scheduledReminders.remove(config.type.value);
        }
      },
    );

    // Schedule the first notification
    Timer(duration, () {
      if (config.enabled) {
        _showLocalNotification(config);
      }
    });
  }

  Future<void> _showLocalNotification(ReminderConfig config) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'reminder_channel',
      'Reminders',
      channelDescription: 'Daily reminders for ALIVE-NG app',
      importance: Importance.high,
      priority: Priority.high,
      autoCancel: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      config.type.value.hashCode,
      config.title,
      config.body,
      platformChannelSpecifics,
      payload: jsonEncode({
        'type': config.type.value,
        'route': _getRouteForType(config.type),
      }),
    );
  }

  void _onNotificationTapped(NotificationResponse notificationResponse) {
    final payload = notificationResponse.payload;
    if (payload != null) {
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        final route = data['route'] as String?;

        if (route != null) {
          // Navigate to the appropriate route
          // This would typically be handled by your navigation service
          debugPrint('Navigate to: $route');
        }
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }

  String _getRouteForType(ReminderType type) {
    switch (type) {
      case ReminderType.dailyVerse:
        return '/daily';
      case ReminderType.prayer:
        return '/prayer';
      case ReminderType.healthTracking:
        return '/health';
      case ReminderType.study:
        return '/study';
      case ReminderType.mission:
        return '/missions';
    }
  }

  Future<void> clearReminder(String type) async {
    // Cancel scheduled notification
    await _flutterLocalNotificationsPlugin.cancel(type.hashCode);

    // Cancel recurring timer
    final timer = _scheduledReminders[type];
    if (timer != null) {
      timer.cancel();
      _scheduledReminders.remove(type);
    }
  }

  Future<void> clearAllReminders() async {
    // Cancel all scheduled notifications
    await _flutterLocalNotificationsPlugin.cancelAll();

    // Cancel all recurring timers
    for (final timer in _scheduledReminders.values) {
      timer.cancel();
    }
    _scheduledReminders.clear();
  }

  List<ReminderConfig> getDefaultReminders() {
    return [
      const ReminderConfig(
        type: ReminderType.dailyVerse,
        title: 'Daily Verse Reminder',
        body: '📖 Start your day with God\'s Word. Your daily verse is ready!',
        time: TimeOfDay(hour: 7, minute: 0),
        enabled: true,
      ),
      const ReminderConfig(
        type: ReminderType.prayer,
        title: 'Prayer Time',
        body: '🙏 Take a moment to pray and connect with God.',
        time: TimeOfDay(hour: 18, minute: 0),
        enabled: true,
      ),
      const ReminderConfig(
        type: ReminderType.healthTracking,
        title: 'Health Check-in',
        body:
            '💚 Log your daily health activities - water, exercise, and wellness.',
        time: TimeOfDay(hour: 20, minute: 0),
        enabled: true,
      ),
      const ReminderConfig(
        type: ReminderType.study,
        title: 'Bible Study Time',
        body: '📚 Continue your Bible study journey and grow in faith.',
        time: TimeOfDay(hour: 19, minute: 0),
        enabled: true,
      ),
      const ReminderConfig(
        type: ReminderType.mission,
        title: 'Mission Reminder',
        body: '🌟 Share God\'s love today. Check your mission activities.',
        time: TimeOfDay(hour: 12, minute: 0),
        enabled: true,
      ),
    ];
  }

  Future<void> scheduleAllReminders(List<ReminderConfig> reminders) async {
    await clearAllReminders();

    for (final reminder in reminders) {
      if (reminder.enabled) {
        await scheduleReminder(reminder);
      }
    }
  }

  Future<void> scheduleTestReminder({
    required ReminderType type,
    int delaySeconds = 5,
  }) async {
    final config = ReminderConfig(
      type: type,
      title: 'Test Reminder',
      body: 'This is a test notification from ALIVE-NG',
      time: const TimeOfDay(hour: 0, minute: 0),
      enabled: true,
    );

    Timer(Duration(seconds: delaySeconds), () {
      _showLocalNotification(config);
    });
  }

  // Persistence methods
  Future<void> saveReminders(List<ReminderConfig> reminders) async {
    final prefs = await SharedPreferences.getInstance();
    final remindersJson = reminders.map((r) => r.toJson()).toList();
    await prefs.setString('reminders', jsonEncode(remindersJson));
  }

  Future<List<ReminderConfig>> loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final remindersString = prefs.getString('reminders');

    if (remindersString == null) {
      return getDefaultReminders();
    }

    try {
      final remindersJson = jsonDecode(remindersString) as List<dynamic>;
      return remindersJson
          .map((json) => ReminderConfig.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading reminders: $e');
      return getDefaultReminders();
    }
  }

  Future<void> updateReminder(ReminderConfig reminder) async {
    final reminders = await loadReminders();
    final index = reminders.indexWhere((r) => r.type == reminder.type);

    if (index != -1) {
      reminders[index] = reminder;
    } else {
      reminders.add(reminder);
    }

    await saveReminders(reminders);

    // Reschedule the reminder
    if (reminder.enabled) {
      await scheduleReminder(reminder);
    } else {
      await clearReminder(reminder.type.value);
    }
  }
}

// Global instance
final reminderService = ReminderService();
