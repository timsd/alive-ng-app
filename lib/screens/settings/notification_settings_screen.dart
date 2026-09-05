import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/notification_settings.dart';
import '../../providers/achievement_provider.dart';
import '../../services/notification_settings_service.dart';
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
  NotificationSettings? _settings;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await NotificationSettingsService.fetchSettings();
      if (!mounted) return;
      setState(() {
        _settings = settings ?? NotificationSettings(
          userId: '',
          dailyVerseReminder: true,
          prayerReminder: true,
          healthTrackingReminder: true,
          studyReminder: true,
          missionReminder: true,
          reminderTime: '07:00',
          pushNotificationsEnabled: false,
        );
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

  Future<void> _syncReminderSchedules(NotificationSettings settings) async {
    final parts = settings.reminderTime.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 7 : 7;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final time = TimeOfDay(hour: hour, minute: minute);

    final reminders = <ReminderConfig>[
      ReminderConfig(
        type: ReminderType.dailyVerse,
        title: 'Daily Verse Reminder',
        body: 'Your daily verse is ready.',
        time: time,
        enabled:
            settings.pushNotificationsEnabled && settings.dailyVerseReminder,
      ),
      ReminderConfig(
        type: ReminderType.prayer,
        title: 'Prayer Reminder',
        body: 'Take a moment to pray.',
        time: time,
        enabled: settings.pushNotificationsEnabled && settings.prayerReminder,
      ),
      ReminderConfig(
        type: ReminderType.healthTracking,
        title: 'Health Reminder',
        body: 'Log your health activities for today.',
        time: time,
        enabled:
            settings.pushNotificationsEnabled && settings.healthTrackingReminder,
      ),
      ReminderConfig(
        type: ReminderType.study,
        title: 'Study Reminder',
        body: 'Continue your Bible study progress.',
        time: time,
        enabled: settings.pushNotificationsEnabled && settings.studyReminder,
      ),
      ReminderConfig(
        type: ReminderType.mission,
        title: 'Mission Reminder',
        body: 'Check your mission and outreach activities.',
        time: time,
        enabled: settings.pushNotificationsEnabled && settings.missionReminder,
      ),
    ];

    await ReminderService().scheduleAllReminders(reminders);
  }

  Future<void> _selectTime() async {
    if (_settings == null) return;

    final currentTime = TimeOfDay(
      hour: int.parse(_settings!.reminderTime.split(':')[0]),
      minute: int.parse(_settings!.reminderTime.split(':')[1]),
    );

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: currentTime,
    );

    if (selectedTime != null) {
      final timeString = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
      await _updateSetting(_settings!.copyWith(reminderTime: timeString));
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
          : _settings == null
              ? const Center(child: Text('Failed to load settings'))
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
                                subtitle: const Text('Receive ALIVE reminders and Appwrite messaging updates'),
                                value: _settings!.pushNotificationsEnabled,
                                onChanged: _isSaving ? null : (value) async {
                                  if (value) {
                                    final granted = await NotificationSettingsService.requestNotificationPermission();
                                    if (!granted) return;
                                    await _updateSetting(_settings!.copyWith(pushNotificationsEnabled: true));
                                  } else {
                                    await _updateSetting(_settings!.copyWith(pushNotificationsEnabled: value));
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
                              
                              // Reminder Time
                              ListTile(
                                leading: const Icon(Icons.access_time),
                                title: const Text('Reminder Time'),
                                subtitle: Text(_settings!.reminderTime),
                                trailing: const Icon(Icons.arrow_forward_ios),
                                onTap: _isSaving
                                    ? null
                                    : () async {
                                        final before = _settings?.reminderTime;
                                        await _selectTime();
                                        if (!context.mounted) return;
                                        final after = _settings?.reminderTime;
                                        if (before != after) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Reminder time updated')),
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
                                value: _settings!.dailyVerseReminder,
                                onChanged: _isSaving ? null : (value) async {
                                  await _updateSetting(_settings!.copyWith(dailyVerseReminder: value));
                                },
                              ),
                              
                              // Prayer Reminder
                              SwitchListTile(
                                secondary: const Icon(Icons.favorite),
                                title: const Text('Prayer Reminder'),
                                subtitle: const Text('Daily prayer reminders'),
                                value: _settings!.prayerReminder,
                                onChanged: _isSaving ? null : (value) async {
                                  await _updateSetting(_settings!.copyWith(prayerReminder: value));
                                },
                              ),
                              
                              // Health Tracking Reminder
                              SwitchListTile(
                                secondary: const Icon(Icons.health_and_safety),
                                title: const Text('Health Tracking'),
                                subtitle: const Text('Health and wellness reminders'),
                                value: _settings!.healthTrackingReminder,
                                onChanged: _isSaving ? null : (value) async {
                                  await _updateSetting(_settings!.copyWith(healthTrackingReminder: value));
                                },
                              ),
                              
                              // Study Reminder
                              SwitchListTile(
                                secondary: const Icon(Icons.school),
                                title: const Text('Study Reminder'),
                                subtitle: const Text('Bible study reminders'),
                                value: _settings!.studyReminder,
                                onChanged: _isSaving ? null : (value) async {
                                  await _updateSetting(_settings!.copyWith(studyReminder: value));
                                },
                              ),
                              
                              // Mission Reminder
                              SwitchListTile(
                                secondary: const Icon(Icons.volunteer_activism),
                                title: const Text('Mission Reminder'),
                                subtitle: const Text('Mission and outreach reminders'),
                                value: _settings!.missionReminder,
                                onChanged: _isSaving ? null : (value) async {
                                  await _updateSetting(_settings!.copyWith(missionReminder: value));
                                },
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
                                value: _settings!.soundEnabled,
                                onChanged: _isSaving ? null : (value) async {
                                  await _updateSetting(_settings!.copyWith(soundEnabled: value));
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
                      
                      // Test Notification Button (Hidden for standard users; debug only)
                      if (kDebugMode) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Test Notifications (Dev Mode)',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _isSaving ? null : () async {
                                      try {
                                        await ReminderService().showImmediateNotification(
                                          id: DateTime.now().millisecondsSinceEpoch,
                                          title: 'Test Notification',
                                          body: 'This is a test notification from ALIVE NG',
                                        );
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Test notification sent')),
                                        );
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error sending test notification: $e')),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.notifications_active),
                                    label: const Text('Send Test Notification'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      
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
