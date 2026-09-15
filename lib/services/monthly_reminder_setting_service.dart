import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../utils/logger.dart';

/// Controls the monthly ministry-support reminder:
/// * The admin flag lives in the Appwrite `app_settings` collection
///   (document `monthly_reminder`, field `value.user_toggle_enabled`).
/// * By default the flag is `false`, so every member receives the reminder
///   and the preference toggle is greyed out in the app.
/// * When an admin enables the flag, members may opt out themselves.
class MonthlyReminderSettingService {
  static final _logger = Logger('MonthlyReminderSettingService');
  static const String _documentId = 'monthly_reminder';
  static const String _localToggleKey = 'monthly_reminder_user_opt_out';

  /// Reads the admin-controlled flag. Defaults to `false` (admin-managed).
  static Future<bool> isUserToggleEnabled() async {
    try {
      final databases = Databases(appwriteClient);
      // ignore: deprecated_member_use
      final doc = await databases.getDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.appSettingsCollectionId,
        documentId: _documentId,
      );
      return _readToggleEnabled(doc.data['value']);
    } catch (e) {
      _logger.info('Monthly reminder flag unavailable, defaulting to false: $e');
      return false;
    }
  }

  /// Admin-only: exposes/hides the user toggle in the app.
  static Future<bool> setUserToggleEnabled(bool enabled) async {
    try {
      final databases = Databases(appwriteClient);
      final payload = {
        'value': jsonEncode({'user_toggle_enabled': enabled}),
      };

      try {
        // ignore: deprecated_member_use
        await databases.updateDocument(
          databaseId: AppwriteBackendConfig.databaseId,
          collectionId: AppwriteBackendConfig.appSettingsCollectionId,
          documentId: _documentId,
          data: payload,
        );
      } on AppwriteException catch (e) {
        if (e.code != 404) rethrow;
        // ignore: deprecated_member_use
        await databases.createDocument(
          databaseId: AppwriteBackendConfig.databaseId,
          collectionId: AppwriteBackendConfig.appSettingsCollectionId,
          documentId: _documentId,
          data: payload,
        );
      }
      return true;
    } catch (e) {
      _logger.error('Failed to update monthly reminder toggle flag: $e');
      return false;
    }
  }

  /// The signed-in member's own choice (only honoured when the admin flag is on).
  static Future<bool> isUserOptedOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_localToggleKey) ?? false;
    } catch (e) {
      _logger.error('Failed to read monthly reminder opt-out: $e');
      return false;
    }
  }

  static Future<bool> setUserOptedOut(bool optedOut) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_localToggleKey, optedOut);
      return true;
    } catch (e) {
      _logger.error('Failed to save monthly reminder opt-out: $e');
      return false;
    }
  }

  static bool _readToggleEnabled(dynamic rawValue) {
    if (rawValue == null) return false;
    try {
      final Map<String, dynamic> data = rawValue is String
          ? jsonDecode(rawValue) as Map<String, dynamic>
          : Map<String, dynamic>.from(rawValue as Map);
      return data['user_toggle_enabled'] == true;
    } catch (e) {
      debugPrint('Invalid monthly_reminder app setting: $e');
      return false;
    }
  }
}
