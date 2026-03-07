class NotificationSettings {
  final String userId;
  final bool dailyVerseReminder;
  final bool prayerReminder;
  final bool healthTrackingReminder;
  final bool studyReminder;
  final bool missionReminder;
  final String reminderTime;
  final bool pushNotificationsEnabled;
  final bool soundEnabled;

  NotificationSettings({
    required this.userId,
    required this.dailyVerseReminder,
    required this.prayerReminder,
    required this.healthTrackingReminder,
    required this.studyReminder,
    required this.missionReminder,
    required this.reminderTime,
    required this.pushNotificationsEnabled,
    this.soundEnabled = true,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      userId: json['user_id'] ?? '',
      dailyVerseReminder: json['daily_verse_reminder'] ?? true,
      prayerReminder: json['prayer_reminder'] ?? true,
      healthTrackingReminder: json['health_tracking_reminder'] ?? true,
      studyReminder: json['study_reminder'] ?? true,
      missionReminder: json['mission_reminder'] ?? true,
      reminderTime: json['reminder_time'] ?? '07:00',
      pushNotificationsEnabled: json['push_notifications_enabled'] ?? false,
      soundEnabled: json['sound_enabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'daily_verse_reminder': dailyVerseReminder,
      'prayer_reminder': prayerReminder,
      'health_tracking_reminder': healthTrackingReminder,
      'study_reminder': studyReminder,
      'mission_reminder': missionReminder,
      'reminder_time': reminderTime,
      'push_notifications_enabled': pushNotificationsEnabled,
      'sound_enabled': soundEnabled,
    };
  }

  NotificationSettings copyWith({
    String? userId,
    bool? dailyVerseReminder,
    bool? prayerReminder,
    bool? healthTrackingReminder,
    bool? studyReminder,
    bool? missionReminder,
    String? reminderTime,
    bool? pushNotificationsEnabled,
    bool? soundEnabled,
  }) {
    return NotificationSettings(
      userId: userId ?? this.userId,
      dailyVerseReminder: dailyVerseReminder ?? this.dailyVerseReminder,
      prayerReminder: prayerReminder ?? this.prayerReminder,
      healthTrackingReminder: healthTrackingReminder ?? this.healthTrackingReminder,
      studyReminder: studyReminder ?? this.studyReminder,
      missionReminder: missionReminder ?? this.missionReminder,
      reminderTime: reminderTime ?? this.reminderTime,
      pushNotificationsEnabled: pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
    );
  }
}



