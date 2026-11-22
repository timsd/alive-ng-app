import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../services/notification_settings_service.dart';
import '../utils/logger.dart';

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

  static final Logger _logger = Logger('ReminderService');

  /// Shares the single initialized [FlutterLocalNotificationsPlugin] from
  /// [NotificationService] so notification tap callbacks never overwrite each other.
  FlutterLocalNotificationsPlugin get _plugin =>
      NotificationService.instance.localNotificationsPlugin;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    NotificationService.configureLocalTimeZone();
    await NotificationService.instance.initialize();
    _isInitialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    return NotificationService.instance.requestPermissions();
  }

  Future<bool> scheduleReminder(ReminderConfig config) async {
    if (!config.enabled || kIsWeb) {
      return false;
    }

    await initialize();

    // Clear existing reminder if any
    await clearReminder(config.type.value);

    try {
      NotificationService.configureLocalTimeZone();
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
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

      // Schedule OS-level daily repeating notification (survives app close & reboot)
      await _scheduleLocalNotification(config, scheduledDate);
      return true;
    } catch (error) {
      _logger.error('Error scheduling reminder', error);
      return false;
    }
  }

  static const Color _aliveGreen = Color(0xFF0F9A07);

  AndroidNotificationDetails _buildAndroidDetails({
    required String channelId,
    required String channelName,
    required String channelDescription,
    Importance importance = Importance.high,
    Priority priority = Priority.high,
    bool playSound = true,
    bool showWhen = false,
    bool autoCancel = false,
    bool enableVibration = false,
    bool includeLargeIcon = true,
  }) {
    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      icon: 'ic_notification',
      largeIcon: includeLargeIcon
          ? const DrawableResourceAndroidBitmap('ic_notification_large')
          : null,
      color: _aliveGreen,
      importance: importance,
      priority: priority,
      playSound: playSound,
      showWhen: showWhen,
      autoCancel: autoCancel,
      enableVibration: enableVibration,
    );
  }

  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    await initialize();

    NotificationDetails buildDetails({required bool includeLargeIcon}) {
      final androidDetails = _buildAndroidDetails(
        channelId: 'alive_ng_notifications',
        channelName: 'ALIVE Nigeria Notifications',
        channelDescription: 'Ministry updates, broadcasts, and ALIVE Meet alerts',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        includeLargeIcon: includeLargeIcon,
      );
      const iosDetails = DarwinNotificationDetails();
      return NotificationDetails(android: androidDetails, iOS: iosDetails);
    }

    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: buildDetails(includeLargeIcon: true),
        payload: payload,
      );
    } on PlatformException catch (e) {
      if (e.code == 'invalid_large_icon') {
        await _plugin.show(
          id: id,
          title: title,
          body: body,
          notificationDetails: buildDetails(includeLargeIcon: false),
          payload: payload,
        );
      } else {
        rethrow;
      }
    }
  }

  Future<void> _scheduleLocalNotification(
    ReminderConfig config,
    tz.TZDateTime scheduledDate,
  ) async {
    final settings = await NotificationSettingsService.fetchSettings();
    final soundEnabled = settings?.soundEnabled ?? true;

    NotificationDetails buildDetails({required bool includeLargeIcon}) {
      final androidDetails = _buildAndroidDetails(
        channelId: soundEnabled ? 'reminder_channel' : 'reminder_channel_silent',
        channelName: soundEnabled ? 'Reminders' : 'Reminders (Silent)',
        channelDescription: 'Daily reminders for ALIVE Nigeria app',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        autoCancel: true,
        playSound: soundEnabled,
        enableVibration: true,
        includeLargeIcon: includeLargeIcon,
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: soundEnabled,
      );

      return NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
    }

    final payload = jsonEncode({
      'type': config.type.value,
      'route': _getRouteForType(config.type),
    });

    try {
      await _plugin.zonedSchedule(
        id: config.type.value.hashCode,
        title: config.title,
        body: config.body,
        scheduledDate: scheduledDate,
        notificationDetails: buildDetails(includeLargeIcon: true),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
    } on PlatformException catch (e) {
      if (e.code == 'invalid_large_icon') {
        await _plugin.zonedSchedule(
          id: config.type.value.hashCode,
          title: config.title,
          body: config.body,
          scheduledDate: scheduledDate,
          notificationDetails: buildDetails(includeLargeIcon: false),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: payload,
        );
      } else {
        rethrow;
      }
    }
  }

  Future<void> _showLocalNotification(ReminderConfig config) async {
    if (kIsWeb) return;
    await initialize();
    final settings = await NotificationSettingsService.fetchSettings();
    final soundEnabled = settings?.soundEnabled ?? true;

    NotificationDetails buildDetails({required bool includeLargeIcon}) {
      final androidDetails = _buildAndroidDetails(
        channelId: soundEnabled ? 'reminder_channel' : 'reminder_channel_silent',
        channelName: soundEnabled ? 'Reminders' : 'Reminders (Silent)',
        channelDescription: 'Daily reminders for ALIVE Nigeria app',
        importance: Importance.high,
        priority: Priority.high,
        autoCancel: true,
        playSound: soundEnabled,
        enableVibration: true,
        includeLargeIcon: includeLargeIcon,
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: soundEnabled,
      );

      return NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
    }

    final payload = jsonEncode({
      'type': config.type.value,
      'route': _getRouteForType(config.type),
    });

    try {
      await _plugin.show(
        id: config.type.value.hashCode,
        title: config.title,
        body: config.body,
        notificationDetails: buildDetails(includeLargeIcon: true),
        payload: payload,
      );
    } on PlatformException catch (e) {
      if (e.code == 'invalid_large_icon') {
        await _plugin.show(
          id: config.type.value.hashCode,
          title: config.title,
          body: config.body,
          notificationDetails: buildDetails(includeLargeIcon: false),
          payload: payload,
        );
      } else {
        rethrow;
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
    if (kIsWeb) return;
    await initialize();
    await _plugin.cancel(id: type.hashCode);
  }

  Future<void> clearAllReminders() async {
    if (kIsWeb) return;
    await initialize();
    for (final type in ReminderType.values) {
      await _plugin.cancel(id: type.value.hashCode);
    }
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
    if (kIsWeb) return;
    await initialize();
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
      body: 'This is a test notification from ALIVE Nigeria',
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
      _logger.error('Error loading reminders', e);
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
