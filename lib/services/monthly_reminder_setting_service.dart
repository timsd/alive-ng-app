import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import 'auth_service.dart';
import '../utils/logger.dart';

/// One member who has declined the monthly giving reminder.
class MonthlyReminderOptOut {
  final String userId;
  final String? name;
  final String? email;

  const MonthlyReminderOptOut({
    required this.userId,
    this.name,
    this.email,
  });

  /// Best available label: the name, else the address, else a short id.
  String get label {
    if (name != null && name!.trim().isNotEmpty) return name!.trim();
    if (email != null && email!.trim().isNotEmpty) return email!.trim();
    return '${userId.substring(0, userId.length < 8 ? userId.length : 8)}...';
  }
}

/// Admin-configurable schedule and opt-out settings for the monthly reminder.
class MonthlyReminderConfig {
  final bool enabled;
  final int dayOfMonth;
  final int hourWat;
  final bool userToggleEnabled;

  const MonthlyReminderConfig({
    this.enabled = true,
    this.dayOfMonth = 1,
    this.hourWat = 9,
    this.userToggleEnabled = false,
  });

  MonthlyReminderConfig copyWith({
    bool? enabled,
    int? dayOfMonth,
    int? hourWat,
    bool? userToggleEnabled,
  }) {
    return MonthlyReminderConfig(
      enabled: enabled ?? this.enabled,
      dayOfMonth: (dayOfMonth ?? this.dayOfMonth).clamp(1, 31),
      hourWat: (hourWat ?? this.hourWat).clamp(0, 23),
      userToggleEnabled: userToggleEnabled ?? this.userToggleEnabled,
    );
  }

  factory MonthlyReminderConfig.fromRaw(dynamic rawValue) {
    if (rawValue == null) return const MonthlyReminderConfig();
    try {
      final Map<String, dynamic> data = rawValue is String
          ? jsonDecode(rawValue) as Map<String, dynamic>
          : Map<String, dynamic>.from(rawValue as Map);
      final rawDay = data['day_of_month'];
      final parsedDay = rawDay is num
          ? rawDay.toInt()
          : int.tryParse(rawDay?.toString() ?? '') ?? 1;
      final rawHour = data['hour_wat'];
      final parsedHour = rawHour is num
          ? rawHour.toInt()
          : int.tryParse(rawHour?.toString() ?? '') ?? 9;
      return MonthlyReminderConfig(
        enabled: data['enabled'] is bool ? data['enabled'] as bool : true,
        dayOfMonth: parsedDay.clamp(1, 31),
        hourWat: parsedHour.clamp(0, 23),
        userToggleEnabled: data['user_toggle_enabled'] == true,
      );
    } catch (e) {
      debugPrint('Invalid monthly_reminder app setting: $e');
      return const MonthlyReminderConfig();
    }
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'day_of_month': dayOfMonth.clamp(1, 31),
        'hour_wat': hourWat.clamp(0, 23),
        'user_toggle_enabled': userToggleEnabled,
      };
}

/// Controls the monthly ministry-support reminder:
/// * The admin config lives in the Appwrite `app_settings` collection
///   (document `monthly_reminder`, field `value`).
/// * By default the reminder is enabled on day `1` at `09:00 WAT`, and
///   `user_toggle_enabled` is `false` (admin-managed).
/// * When an admin enables `user_toggle_enabled`, members may opt out themselves.
class MonthlyReminderSettingService {
  static final _logger = Logger('MonthlyReminderSettingService');
  static const String _documentId = 'monthly_reminder';
  static const String _localToggleKey = 'monthly_reminder_user_opt_out';

  /// Reads the full admin-configured monthly reminder settings.
  static Future<MonthlyReminderConfig> getConfig() async {
    try {
      final tables = TablesDB(appwriteClient);
      final doc = await tables.getRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.appSettingsCollectionId,
        rowId: _documentId,
      );
      return MonthlyReminderConfig.fromRaw(
        doc.data['value'] ?? doc.data['setting_value'],
      );
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        // Never attempt admin-only app_settings writes from a read path.
        return const MonthlyReminderConfig();
      }
      _logger.info('Monthly reminder config unavailable, using defaults: $e');
      return const MonthlyReminderConfig();
    } catch (e) {
      _logger.info('Monthly reminder config unavailable, using defaults: $e');
      return const MonthlyReminderConfig();
    }
  }

  /// Saves the full admin-configured monthly reminder settings.
  static Future<bool> saveConfig(MonthlyReminderConfig config) async {
    try {
      final tables = TablesDB(appwriteClient);
      final encoded = jsonEncode(config.toJson());
      final payload = {
        'key': _documentId,
        'setting_key': _documentId,
        'value': encoded,
        'setting_value': encoded,
        'category': 'notifications',
        'is_public': true,
      };
      final permissions = <String>[
        Permission.read(Role.any()),
        Permission.read(Role.team(AppwriteBackendConfig.adminTeamId)),
        Permission.update(Role.team(AppwriteBackendConfig.adminTeamId)),
        Permission.delete(Role.team(AppwriteBackendConfig.adminTeamId)),
      ];
      try {
        await tables.updateRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.appSettingsCollectionId,
          rowId: _documentId,
          data: payload,
          permissions: permissions,
        );
      } on AppwriteException catch (e) {
        if (e.code != 404) rethrow;
        await tables.createRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.appSettingsCollectionId,
          rowId: _documentId,
          data: payload,
          permissions: permissions,
        );
      }
      return true;
    } catch (e) {
      _logger.error('Failed to save monthly reminder config: $e');
      return false;
    }
  }

  /// Reads the admin-controlled flag. Defaults to `false` (admin-managed).
  static Future<bool> isUserToggleEnabled() async {
    final config = await getConfig();
    return config.userToggleEnabled;
  }

  /// Admin-only: exposes/hides the user toggle in the app while preserving schedule fields.
  static Future<bool> setUserToggleEnabled(bool enabled) async {
    final existing = await getConfig();
    return saveConfig(existing.copyWith(userToggleEnabled: enabled));
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

  /// Members who have opted out of the monthly giving reminder.
  ///
  /// The reminder is dispatched server-side by monthlyDonationReminder, so the
  /// opt-out is a per-user column in notification_settings rather than anything
  /// held on the device. Reading it back here is the only way an admin can see
  /// who has declined, and the only way to tell a genuinely silent member from
  /// one who actively opted out.
  ///
  /// Returns an empty list when the table cannot be read, rather than throwing:
  /// this backs an informational panel and must not break the dashboard.
  static Future<List<MonthlyReminderOptOut>> listOptedOutMembers() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return const [];
      final tables = TablesDB(appwriteClient);

      // Only opted-out rows are of interest, so filter server-side rather than
      // pulling every settings row and discarding most of them.
      final snapshot = await tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.notificationSettingsCollectionId,
        queries: [
          Query.equal('monthly_reminder_opt_out', true),
          Query.limit(200),
        ],
      );

      // Row data is keyed by user_id (the row id is the user id); carry the
      // address from the users table when the row does not have one.
      final withEmail = <MonthlyReminderOptOut>[];
      for (final row in snapshot.rows) {
        final rowId = row.$id;
        String? email = row.data['email'] as String?;
        String? name = row.data['full_name'] as String?;
        if (email == null || name == null) {
          try {
            // The client SDK's Account.get() only returns the *current* account
            // and takes no id, so an admin listing other members has to read the
            // Users table directly. It is keyed by the same user id.
            final profile = await tables.getRow(
              databaseId: AppwriteBackendConfig.databaseId,
              tableId: AppwriteBackendConfig.usersCollectionId,
              rowId: rowId,
            );
            email ??= profile.data['email'] as String?;
            name ??= profile.data['full_name'] as String?;
          } catch (_) {
            // Leave whatever the settings row provided; a missing address is not
            // a reason to hide the member from the list.
          }
        }
        withEmail.add(MonthlyReminderOptOut(
          userId: rowId,
          name: name,
          email: email,
        ));
      }
      return withEmail;
    } catch (e) {
      _logger.error('Failed to list monthly reminder opt-outs: $e');
      return const [];
    }
  }

  /// Puts a member back on the reminder list.
  static Future<bool> clearOptOut(String userId) async {
    try {
      final tables = TablesDB(appwriteClient);
      await tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.notificationSettingsCollectionId,
        rowId: userId,
        data: {'monthly_reminder_opt_out': false},
      );
      return true;
    } on AppwriteException catch (e) {
      if (e.code == 404) return true;
      _logger.error('Failed to clear monthly reminder opt-out for $userId: $e');
      return false;
    } catch (e) {
      _logger.error('Failed to clear monthly reminder opt-out for $userId: $e');
      return false;
    }
  }
}
