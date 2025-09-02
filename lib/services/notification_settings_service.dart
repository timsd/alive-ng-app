import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/notification_settings.dart';
import '../utils/toast_utils.dart';

class NotificationSettingsService {
  static final _supabase = Supabase.instance.client;

  static Future<NotificationSettings?> fetchSettings() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      // TODO: Uncomment when notification_settings table is available
      // final response = await _supabase
      //     .from('notification_settings')
      //     .select('*')
      //     .eq('user_id', user.id)
      //     .maybeSingle();

      // Temporary fallback - return default settings
      final response = null;

      if (response != null) {
        return NotificationSettings.fromJson(response);
      } else {
        // Create default settings
        final defaultSettings = NotificationSettings(
          userId: user.id,
          dailyVerseReminder: true,
          prayerReminder: true,
          healthTrackingReminder: true,
          studyReminder: true,
          missionReminder: true,
          reminderTime: '07:00',
          pushNotificationsEnabled: false,
        );

        // TODO: Uncomment when notification_settings table is available
        // await _supabase.from('notification_settings').insert(defaultSettings.toJson());

        return defaultSettings;
      }
    } catch (error) {
      print('Error fetching notification settings: $error');
      ToastUtils.showError('Could not load notification preferences');
      return null;
    }
  }

  static Future<bool> updateSettings(NotificationSettings settings) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        ToastUtils.showError('Please log in to update settings');
        return false;
      }

      // TODO: Uncomment when notification_settings table is available
      // await _supabase
      //     .from('notification_settings')
      //     .update(settings.toJson())
      //     .eq('user_id', user.id);

      ToastUtils.showSuccess('Your notification preferences have been saved');
      return true;
    } catch (error) {
      print('Error updating notification settings: $error');
      ToastUtils.showError('Could not save your preferences');
      return false;
    }
  }

  static Future<bool> requestNotificationPermission() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        ToastUtils.showError('Please log in to enable push notifications');
        return false;
      }

      // Request notification permission
      final status = await Permission.notification.request();

      if (status.isGranted) {
        // Update settings to enable push notifications
        final currentSettings = await fetchSettings();
        if (currentSettings != null) {
          final updatedSettings = currentSettings.copyWith(
            pushNotificationsEnabled: true,
          );
          await updateSettings(updatedSettings);
        }

        // TODO: Register for push notifications with Firebase when ready

        ToastUtils.showSuccess(
            'You\'ll receive reminders for your daily activities');
        return true;
      } else {
        ToastUtils.showError(
            'Please enable notifications in your device settings');
        return false;
      }
    } catch (error) {
      print('Error requesting notification permission: $error');
      ToastUtils.showError('Could not set up push notifications');
      return false;
    }
  }

  static Future<bool> disableNotifications() async {
    try {
      final currentSettings = await fetchSettings();
      if (currentSettings != null) {
        final updatedSettings = currentSettings.copyWith(
          pushNotificationsEnabled: false,
        );
        return await updateSettings(updatedSettings);
      }
      return false;
    } catch (error) {
      print('Error disabling notifications: $error');
      return false;
    }
  }

  static Future<bool> updateReminderTime(String time) async {
    try {
      final currentSettings = await fetchSettings();
      if (currentSettings != null) {
        final updatedSettings = currentSettings.copyWith(
          reminderTime: time,
        );
        return await updateSettings(updatedSettings);
      }
      return false;
    } catch (error) {
      print('Error updating reminder time: $error');
      return false;
    }
  }

  static Future<bool> toggleReminder(String reminderType, bool enabled) async {
    try {
      final currentSettings = await fetchSettings();
      if (currentSettings == null) return false;

      NotificationSettings updatedSettings;

      switch (reminderType) {
        case 'daily_verse':
          updatedSettings =
              currentSettings.copyWith(dailyVerseReminder: enabled);
          break;
        case 'prayer':
          updatedSettings = currentSettings.copyWith(prayerReminder: enabled);
          break;
        case 'health_tracking':
          updatedSettings =
              currentSettings.copyWith(healthTrackingReminder: enabled);
          break;
        case 'study':
          updatedSettings = currentSettings.copyWith(studyReminder: enabled);
          break;
        case 'mission':
          updatedSettings = currentSettings.copyWith(missionReminder: enabled);
          break;
        default:
          return false;
      }

      return await updateSettings(updatedSettings);
    } catch (error) {
      print('Error toggling reminder: $error');
      return false;
    }
  }

  static Future<PermissionStatus> checkNotificationPermission() async {
    return await Permission.notification.status;
  }
}
