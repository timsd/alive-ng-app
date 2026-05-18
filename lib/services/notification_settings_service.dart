// ignore_for_file: deprecated_member_use

import 'package:appwrite/appwrite.dart' hide Permission;
import 'package:permission_handler/permission_handler.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../models/notification_settings.dart';
import '../utils/toast_utils.dart';
import '../utils/logger.dart';
import 'firebase_messaging_base.dart';
import 'auth_service.dart';
import 'storage_service.dart';

class NotificationSettingsService {
  static final Databases _databases = Databases(appwriteClient);
  static final _logger = Logger('NotificationSettingsService');
  static const String _databaseId = AppwriteBackendConfig.databaseId;
  static const String _collectionId =
      AppwriteBackendConfig.notificationSettingsCollectionId;

  static Future<NotificationSettings?> fetchSettings() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return null;

      try {
        final doc = await _databases.getDocument(
          databaseId: _databaseId,
          collectionId: _collectionId,
          documentId: user.uid,
        );
        final settings = NotificationSettings.fromJson(doc.data);
        await StorageHelper.setNotificationSettings(settings.toJson());
        return settings;
      } on AppwriteException catch (e) {
        if (e.code != 404) rethrow;

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

        await _databases.createDocument(
          databaseId: _databaseId,
          collectionId: _collectionId,
          documentId: user.uid,
          data: {
            ...defaultSettings.toJson(),
            ..._legacyTopicFlags(defaultSettings),
            'updated_at': DateTime.now().toIso8601String(),
          },
        );
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

      try {
        await _databases.updateDocument(
          databaseId: _databaseId,
          collectionId: _collectionId,
          documentId: user.uid,
          data: {
            ...settings.toJson(),
            ..._legacyTopicFlags(settings),
            'updated_at': DateTime.now().toIso8601String(),
          },
        );
      } on AppwriteException catch (e) {
        if (e.code != 404) rethrow;
        await _databases.createDocument(
          databaseId: _databaseId,
          collectionId: _collectionId,
          documentId: user.uid,
          data: {
            ...settings.toJson(),
            ..._legacyTopicFlags(settings),
            'updated_at': DateTime.now().toIso8601String(),
          },
        );
      }

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

  static Map<String, dynamic> _legacyTopicFlags(
    NotificationSettings settings,
  ) {
    return {
      'prayer': settings.prayerReminder,
      'study': settings.studyReminder,
      'health': settings.healthTrackingReminder,
      'events': settings.missionReminder,
      'chat': settings.pushNotificationsEnabled,
      'donations': settings.pushNotificationsEnabled,
      'kids': settings.missionReminder,
    };
  }
}




