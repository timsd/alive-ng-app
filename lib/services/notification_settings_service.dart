// Removed supabase_flutter import - using Firebase now
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_settings.dart';
import '../utils/toast_utils.dart';
import '../utils/logger.dart';
import 'firebase_messaging_base.dart';
import 'firebase_database_service.dart';
import 'auth_service.dart';
import 'storage_service.dart';

class NotificationSettingsService {
  static final _firebase = FirebaseDatabaseService.instance;
  static final _logger = Logger('NotificationSettingsService');

  static Future<NotificationSettings?> fetchSettings() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return null;

      // Fetch notification settings from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('notification_settings')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final settings = NotificationSettings.fromJson(doc.data()!);
        // Cache locally
        await StorageHelper.setNotificationSettings(settings.toJson());
        return settings;
      } else {
        // Create default settings
        final defaultSettings = NotificationSettings(
          userId: user.uid,
          dailyVerseReminder: true,
          prayerReminder: true,
          healthTrackingReminder: true,
          studyReminder: true,
          missionReminder: true,
          reminderTime: '07:00',
          pushNotificationsEnabled: false,
        );

        // Persist default settings to Firestore
        await FirebaseFirestore.instance
            .collection('notification_settings')
            .doc(user.uid)
            .set({
          ...defaultSettings.toJson(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        // Cache locally
        await StorageHelper.setNotificationSettings(defaultSettings.toJson());

        return defaultSettings;
      }
    } catch (error) {
      _logger.error('Error fetching notification settings: $error');
      ToastUtils.showError('Could not load notification preferences');
      return null;
    }
  }

  static Future<bool> updateSettings(NotificationSettings settings) async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) {
        ToastUtils.showError('Please log in to update settings');
        return false;
      }

      // Update notification settings in Firestore
      await FirebaseFirestore.instance
          .collection('notification_settings')
          .doc(user.uid)
          .set({
        ...settings.toJson(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Optionally update limited boolean settings via FirebaseDatabaseService for analytics/backward compat
      try {
        await _firebase.updateNotificationSettings(user.uid, {
          'daily_verse_reminder': settings.dailyVerseReminder,
          'prayer_reminder': settings.prayerReminder,
          'health_tracking_reminder': settings.healthTrackingReminder,
          'study_reminder': settings.studyReminder,
          'mission_reminder': settings.missionReminder,
          'push_notifications_enabled': settings.pushNotificationsEnabled,
          'sound_enabled': settings.soundEnabled,
        });
      } catch (e) {
        // Do not fail overall on this secondary write
        _logger.warning('Secondary notification settings write failed: $e');
      }

      // Cache locally
      await StorageHelper.setNotificationSettings(settings.toJson());

      ToastUtils.showSuccess('Your notification preferences have been saved');
      return true;
    } catch (error) {
      _logger.error('Error updating notification settings: $error');
      ToastUtils.showError('Could not save your preferences');
      return false;
    }
  }

  static Future<bool> requestNotificationPermission() async {
    try {
      final user = AuthService.instance.currentUser;
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

        // Register for push notifications with Firebase
        try {
          await FirebaseMessagingBase.getAndSaveToken();
          _logger.info('Successfully registered for push notifications with Firebase');
        } catch (e) {
          _logger.error('Failed to register for push notifications with Firebase', e);
          // Don't fail the entire operation if Firebase registration fails
        }

        ToastUtils.showSuccess(
            'You\'ll receive reminders for your daily activities');
        return true;
      } else {
        ToastUtils.showError(
            'Please enable notifications in your device settings');
        return false;
      }
    } catch (error) {
      _logger.error('Error requesting notification permission: $error');
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
      _logger.error('Error disabling notifications: $error');
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
      _logger.error('Error updating reminder time: $error');
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
      _logger.error('Error toggling reminder: $error');
      return false;
    }
  }

  static Future<PermissionStatus> checkNotificationPermission() async {
    return await Permission.notification.status;
  }
}




