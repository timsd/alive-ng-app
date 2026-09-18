import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/notification_settings.dart';
import '../../providers/achievement_provider.dart';
import '../../services/notification_settings_service.dart';
import '../../services/monthly_reminder_setting_service.dart';
import '../../services/reminder_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/loading_widget.dart';
import '../../utils/responsive_utils.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  NotificationSettings _settings = NotificationSettings(
    userId: '',
    dailyVerseReminder: true,
    prayerReminder: true,
    healthTrackingReminder: true,
    studyReminder: true,
    missionReminder: true,
    reminderTime: '07:00, 20:00',
    pushNotificationsEnabled: true,
    soundEnabled: true,
  );
  bool _isLoading = true;
  bool _isSaving = false;

  /// Admin-controlled: when false the monthly support reminder toggle is
  /// greyed out (every member receives it automatically).
  bool _monthlyToggleVisible = false;
  bool _monthlyOptedOut = false;

  @override
  void initState() {
    super.initState();
    ReminderService().initialize();
    _loadSettings();
    _loadMonthlyReminderPref();
  }

  Future<void> _loadMonthlyReminderPref() async {
    final visible =
        await MonthlyReminderSettingService.isUserToggleEnabled();
    final optedOut = await MonthlyReminderSettingService.isUserOptedOut();
    if (!mounted) return;
    setState(() {
      _monthlyToggleVisible = visible;
      _monthlyOptedOut = optedOut;
    });
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await NotificationSettingsService.fetchSettings();
      if (!mounted) return;
      setState(() {
        if (settings != null) {
          _settings = settings;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!context.mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading settings: $e')),
      );
    }
  }

  Future<void> _updateSetting(NotificationSettings newSettings) async {
    setState(() {
      _isSaving = true;
    });
    final messenger = ScaffoldMessenger.of(context);

    try {
      final success = await NotificationSettingsService.updateSettings(newSettings);
      if (success) {
        await _syncReminderSchedules(newSettings);
        setState(() {
          _settings = newSettings;
        });
        messenger.showSnackBar(
          const SnackBar(content: Text('Settings updated successfully')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error updating settings: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  TimeOfDay _parseTime(String timeStr, {required int defaultHour, required int defaultMinute}) {
    final parts = timeStr.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? defaultHour : defaultHour;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? defaultMinute : defaultMinute;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _syncReminderSchedules(NotificationSettings settings) async {
    final morningTime = _parseTime(settings.morningReminderTime, defaultHour: 7, defaultMinute: 0);
    final eveningTime = _parseTime(settings.eveningReminderTime, defaultHour: 20, defaultMinute: 0);

    final reminders = <ReminderConfig>[
      ReminderConfig(
        type: ReminderType.dailyVerse,
        title: 'Daily Verse Reminder',
        body: 'Start your day with God\'s Word. Your daily verse is ready.',
        time: morningTime,
        enabled:
            settings.pushNotificationsEnabled && settings.dailyVerseReminder,
      ),
      ReminderConfig(
        type: ReminderType.study,
        title: 'Study Reminder',
        body: 'Continue your Bible study progress today.',
        time: morningTime,
        enabled: settings.pushNotificationsEnabled && settings.studyReminder,
      ),
      ReminderConfig(
        type: ReminderType.mission,
        title: 'Mission Reminder',
        body: 'Check your mission and outreach activities.',
        time: morningTime,
        enabled: settings.pushNotificationsEnabled && settings.missionReminder,
      ),
      ReminderConfig(
        type: ReminderType.prayer,
        title: 'Prayer Reminder',
        body: 'Take a moment this evening to pray.',
        time: eveningTime,
        enabled: settings.pushNotificationsEnabled && settings.prayerReminder,
      ),
      ReminderConfig(
        type: ReminderType.healthTracking,
        title: 'Health Reminder',
        body: 'Log your daily health and wellness check-in.',
        time: eveningTime,
        enabled:
            settings.pushNotificationsEnabled && settings.healthTrackingReminder,
      ),
    ];

    await ReminderService().scheduleAllReminders(reminders);
  }

  Future<void> _selectMorningTime() async {
    final currentTime = _parseTime(_settings.morningReminderTime, defaultHour: 7, defaultMinute: 0);

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: currentTime,
      helpText: 'Select Morning Reminder Time',
    );

    if (selectedTime != null) {
      final morningStr = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
      final dualStr = NotificationSettings.formatDualReminderTime(morningStr, _settings.eveningReminderTime);
      await _updateSetting(_settings.copyWith(reminderTime: dualStr));
    }
  }

  Future<void> _selectEveningTime() async {
    final currentTime = _parseTime(_settings.eveningReminderTime, defaultHour: 20, defaultMinute: 0);

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: currentTime,
      helpText: 'Select Evening Reminder Time',
    );

    if (selectedTime != null) {
      final eveningStr = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
      final dualStr = NotificationSettings.formatDualReminderTime(_settings.morningReminderTime, eveningStr);
      await _updateSetting(_settings.copyWith(reminderTime: dualStr));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Notification Settings',
        showBackButton: true,
      ),
      body: _isLoading
          ? const LoadingWidget()
          : SingleChildScrollView(
              padding: EdgeInsets.all(
                ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 16,
                  tablet: 24,
                  desktop: 32,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Push Notifications Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Push Notifications',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text('Enable Push Notifications'),
                            subtitle: const Text('Receive reminders and ministry updates on this device'),
                            value: _settings.pushNotificationsEnabled,
                            onChanged: _isSaving ? null : (value) async {
                              final messenger = ScaffoldMessenger.of(context);
                              if (value) {
                                setState(() => _isSaving = true);
                                try {
                                  final granted = await NotificationSettingsService.requestNotificationPermission();
                                  if (!mounted) return;
                                  if (!granted) {
                                    messenger.showSnackBar(
                                      const SnackBar(content: Text('Notifications permission was not granted.')),
                                    );
                                    return;
                                  }
                                  await _updateSetting(_settings.copyWith(pushNotificationsEnabled: true));
                                } finally {
                                  if (mounted) setState(() => _isSaving = false);
                                }
                              } else {
                                await _updateSetting(_settings.copyWith(pushNotificationsEnabled: value));
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Reminder Settings Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Reminders',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Morning Reminder Time
                          ListTile(
                            leading: const Icon(Icons.wb_sunny_outlined),
                            title: const Text('Morning Reminder Time'),
                            subtitle: Text('${_settings.morningReminderTime} (Daily Verse, Study & Missions)'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: _isSaving
                                ? null
                                : () async {
                                    final before = _settings.morningReminderTime;
                                    await _selectMorningTime();
                                    if (!context.mounted) return;
                                    final after = _settings.morningReminderTime;
                                    if (before != after) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Morning reminder time updated')),
                                      );
                                    }
                                  },
                          ),

                          // Evening Reminder Time
                          ListTile(
                            leading: const Icon(Icons.nights_stay_outlined),
                            title: const Text('Evening Reminder Time'),
                            subtitle: Text('${_settings.eveningReminderTime} (Prayer & Health Check-in)'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: _isSaving
                                ? null
                                : () async {
                                    final before = _settings.eveningReminderTime;
                                    await _selectEveningTime();
                                    if (!context.mounted) return;
                                    final after = _settings.eveningReminderTime;
                                    if (before != after) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Evening reminder time updated')),
                                      );
                                    }
                                  },
                          ),
                          
                          const Divider(),
                          
                          // Daily Verse Reminder
                          SwitchListTile(
                            secondary: const Icon(Icons.book),
                            title: const Text('Daily Verse Reminder'),
                            subtitle: const Text('Get daily Bible verses'),
                            value: _settings.dailyVerseReminder,
                            onChanged: _isSaving ? null : (value) async {
                              await _updateSetting(_settings.copyWith(dailyVerseReminder: value));
                            },
                          ),
                          
                          // Prayer Reminder
                          SwitchListTile(
                            secondary: const Icon(Icons.favorite),
                            title: const Text('Prayer Reminder'),
                            subtitle: const Text('Daily prayer reminders'),
                            value: _settings.prayerReminder,
                            onChanged: _isSaving ? null : (value) async {
                              await _updateSetting(_settings.copyWith(prayerReminder: value));
                            },
                          ),
                          
                          // Health Tracking Reminder
                          SwitchListTile(
                            secondary: const Icon(Icons.health_and_safety),
                            title: const Text('Health Tracking'),
                            subtitle: const Text('Health and wellness reminders'),
                            value: _settings.healthTrackingReminder,
                            onChanged: _isSaving ? null : (value) async {
                              await _updateSetting(_settings.copyWith(healthTrackingReminder: value));
                            },
                          ),
                          
                          // Study Reminder
                          SwitchListTile(
                            secondary: const Icon(Icons.school),
                            title: const Text('Study Reminder'),
                            subtitle: const Text('Bible study reminders'),
                            value: _settings.studyReminder,
                            onChanged: _isSaving ? null : (value) async {
                              await _updateSetting(_settings.copyWith(studyReminder: value));
                            },
                          ),
                          
                          // Mission Reminder
                          SwitchListTile(
                            secondary: const Icon(Icons.public),
                            title: const Text('Mission Reminder'),
                            subtitle: const Text('Mission and outreach reminders'),
                            value: _settings.missionReminder,
                            onChanged: _isSaving ? null : (value) async {
                              await _updateSetting(_settings.copyWith(missionReminder: value));
                            },
                          ),

                          // Monthly Giving Reminder
                          // Greyed out for everyone until an admin makes the
                          // toggle available from the admin dashboard.
                          SwitchListTile(
                            secondary: Icon(
                              Icons.calendar_month,
                              color: _monthlyToggleVisible ? null : Theme.of(context).disabledColor,
                            ),
                            title: Text(
                              'Monthly Giving Reminder',
                              style: TextStyle(
                                color: _monthlyToggleVisible ? null : Theme.of(context).disabledColor,
                              ),
                            ),
                            subtitle: Text(
                              _monthlyToggleVisible
                                  ? 'Reminder on the 1st of each month — turn off to opt out'
                                  : 'This reminder is managed by the ministry admin.',
                              style: TextStyle(
                                color: _monthlyToggleVisible ? null : Theme.of(context).disabledColor,
                              ),
                            ),
                            value: _monthlyToggleVisible ? !_monthlyOptedOut : true,
                            onChanged: _monthlyToggleVisible
                                ? (value) async {
                                    final messenger =
                                        ScaffoldMessenger.of(context);
                                    final optedOut = !value;
                                    final saved = await MonthlyReminderSettingService
                                        .setUserOptedOut(optedOut);
                                    if (!mounted) return;
                                    if (saved) {
                                      setState(() {
                                        _monthlyOptedOut = optedOut;
                                      });
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            optedOut
                                                ? 'You will no longer receive the monthly giving reminder'
                                                : 'Monthly giving reminder enabled',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Sound Settings Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sound Settings',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            secondary: const Icon(Icons.volume_up),
                            title: const Text('Notification Sound'),
                            subtitle: const Text('Play sound with notifications'),
                            value: _settings.soundEnabled,
                            onChanged: _isSaving ? null : (value) async {
                              await _updateSetting(_settings.copyWith(soundEnabled: value));
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                      
                      const SizedBox(height: 16),
                      
                      // Display Settings Section
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Display Settings',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Consumer(
                                builder: (context, ref, _) {
                                  final showBadge = ref.watch(showAchievementBadgeProvider);
                                  return SwitchListTile(
                                    secondary: const Icon(Icons.emoji_events),
                                    title: const Text('Show Achievement Badge'),
                                    subtitle: const Text('Display achievement progress on Home screen'),
                                    value: showBadge,
                                    onChanged: (value) async {
                                      await ref.read(showAchievementBadgeProvider.notifier).setShowBadge(value);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(value ? 'Achievement badge enabled' : 'Achievement badge disabled')),
                                        );
                                      }
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      if (_isSaving)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ),
    );
  }
}
