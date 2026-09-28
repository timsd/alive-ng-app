import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import 'auth_service.dart';
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

  /// The signed-in member's own choice.
  ///
  /// Mirrored to the server so the monthly reminder function can honour it.
  /// It used to be local-only, which meant a member who turned the reminder
  /// off was still sent the push: the function runs server-side and had no way
  /// to see a SharedPreferences value on one handset.
  ///
  /// The local copy is still written first so the toggle reflects the choice
  /// immediately, and so the UI still works if the server write fails.
  static Future<bool> isUserOptedOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final local = prefs.getBool(_localToggleKey) ?? false;
      // Prefer the server value when it is known, so a member who opted out on
      // one device is opted out on all of them.
      final remote = await _readServerOptOut();
      if (remote != null) return remote;
      return local;
    } catch (e) {
      _logger.error('Failed to read monthly reminder opt-out: $e');
      return false;
    }
  }

  static Future<bool> setUserOptedOut(bool optedOut) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_localToggleKey, optedOut);
    } catch (e) {
      _logger.error('Failed to save monthly reminder opt-out locally: $e');
    }

    // The server write is what actually stops the push, so its failure is
    // reported rather than swallowed: returning true here while the server
    // still says false would show the member "you will no longer receive..."
    // and then send them the reminder anyway.
    final saved = await _writeServerOptOut(optedOut);
    return saved;
  }

  /// Reads the per-user opt-out from notification_settings, or null when the
  /// row or column is not there yet.
  static Future<bool?> _readServerOptOut() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return null;
      final tables = TablesDB(appwriteClient);
      final row = await tables.getRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.notificationSettingsCollectionId,
        rowId: user.uid,
      );
      final v = row.data['monthly_reminder_opt_out'];
      return v is bool ? v : null;
    } catch (e) {
      // A missing row (404) simply means no stored choice yet.
      _logger.info('No server-side monthly reminder opt-out yet: $e');
      return null;
    }
  }

  static Future<bool> _writeServerOptOut(bool optedOut) async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return false;
      final tables = TablesDB(appwriteClient);

      try {
        await tables.updateRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.notificationSettingsCollectionId,
          rowId: user.uid,
          data: { 'monthly_reminder_opt_out': optedOut },
        );
      } on AppwriteException catch (e) {
        // 404 means the member has no settings row yet. Creating one here would
        // need every other required column, which is the job of
        // NotificationSettingsService.fetchSettings, so leave it to that rather
        // than writing a half-populated row.
        if (e.code != 404) rethrow;
        // No row to update. fetchSettings() creates one on the member's next
        // settings load, and that row defaults to opted-in, so there is nothing
        // lost by not writing here. Report success only when turning the
        // reminder back on, so the member is not told they are opted out.
        _logger.info('No notification_settings row to update yet; the member '
            'gets one on their next settings load.');
        return !optedOut;
      }
      return true;
    } catch (e) {
      _logger.error('Failed to save monthly reminder opt-out to the server: $e');
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
