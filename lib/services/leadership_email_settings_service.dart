import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/appwrite_backend_config.dart';
import 'appwrite_client.dart';
import '../utils/appwrite_id_utils.dart';
import '../utils/appwrite_upsert_helper.dart';

/// Service managing the list of recipient email addresses for ALIVE Leadership,
/// Council, Board of Directors, and Leaders' Meeting rooms.
///
/// Supports board members, council leaders, and department heads who need to
/// receive synthesized meeting minutes, resolutions, and session summaries.
class LeadershipEmailSettingsService extends ChangeNotifier {
  LeadershipEmailSettingsService._internal() {
    _loadFromCache();
  }

  static final LeadershipEmailSettingsService _instance =
      LeadershipEmailSettingsService._internal();
  factory LeadershipEmailSettingsService() => _instance;
  static LeadershipEmailSettingsService get instance => _instance;

  static const String settingKey = 'leadership_meeting_recipients';
  // Legacy key for backwards-compatibility with previous data
  static const String legacySettingKey = 'board_meeting_recipients';
  static const String defaultEmail = 'aliveng.bod@alivenigeria.org';
  static const String _prefKey = 'cached_leadership_meeting_recipients';
  static const String _legacyPrefKey = 'cached_board_meeting_recipients';

  final TablesDB _tables = TablesDB(appwriteClient);
  List<String> _recipients = [defaultEmail];
  bool _isLoaded = false;

  List<String> get recipients => List.unmodifiable(_recipients);
  String get recipientsSummary => _recipients.join(', ');

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var cached = prefs.getStringList(_prefKey);
      if (cached == null || cached.isEmpty) {
        cached = prefs.getStringList(_legacyPrefKey);
      }
      if (cached != null && cached.isNotEmpty) {
        _recipients = _cleanEmails(cached);
      }
      _isLoaded = true;
      notifyListeners();
    } catch (_) {}
    // Sync latest from Appwrite in background
    fetchFromRemote();
  }

  /// Parses and cleans a list or string of emails
  static List<String> _cleanEmails(Iterable<String> inputs) {
    final result = <String>{};
    for (final raw in inputs) {
      final parts = raw.split(RegExp(r'[,;\n\r\s]+'));
      for (final p in parts) {
        final email = p.trim().toLowerCase();
        if (email.contains('@') && email.contains('.') && email.length >= 6) {
          result.add(email);
        }
      }
    }
    if (result.isEmpty) {
      result.add(defaultEmail);
    }
    return result.toList();
  }

  /// Returns the current active list of recipients
  Future<List<String>> getLeadershipRecipients() async {
    if (!_isLoaded) {
      final prefs = await SharedPreferences.getInstance();
      var cached = prefs.getStringList(_prefKey);
      if (cached == null || cached.isEmpty) {
        cached = prefs.getStringList(_legacyPrefKey);
      }
      if (cached != null && cached.isNotEmpty) {
        _recipients = _cleanEmails(cached);
        _isLoaded = true;
      }
    }
    return List.unmodifiable(_recipients);
  }

  /// Alias for backward compatibility
  Future<List<String>> getBoardMeetingRecipients() => getLeadershipRecipients();

  /// Syncs the setting from Appwrite app_settings table
  Future<List<String>> fetchFromRemote() async {
    try {
      // 1. Try modern setting key
      var response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.appSettingsCollectionId,
        queries: [
          Query.equal('setting_key', settingKey),
          Query.limit(1),
        ],
      );

      // 2. Fallback to legacy board key if modern key not yet saved
      if (response.rows.isEmpty) {
        response = await _tables.listRows(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.appSettingsCollectionId,
          queries: [
            Query.equal('setting_key', legacySettingKey),
            Query.limit(1),
          ],
        );
      }

      String? rawVal;
      if (response.rows.isNotEmpty) {
        final data = response.rows.first.data;
        rawVal = (data['setting_value'] ?? data['value'])?.toString();
      } else {
        // Fallback check by key attribute
        final keyRes = await _tables.listRows(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.appSettingsCollectionId,
          queries: [
            Query.equal('key', settingKey),
            Query.limit(1),
          ],
        );
        if (keyRes.rows.isNotEmpty) {
          final data = keyRes.rows.first.data;
          rawVal = (data['setting_value'] ?? data['value'])?.toString();
        }
      }

      if (rawVal != null && rawVal.trim().isNotEmpty) {
        final parsed = _cleanEmails(rawVal.split(RegExp(r'[,;\n\r]+')));
        _recipients = parsed;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_prefKey, _recipients);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[LeadershipEmailSettingsService] Fetch note: $e');
    }
    return List.unmodifiable(_recipients);
  }

  /// Updates the list of recipients both locally and in Appwrite
  Future<void> saveRecipients(List<String> emails) async {
    final cleaned = _cleanEmails(emails);
    _recipients = cleaned;

    // Cache locally
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefKey, _recipients);
    } catch (_) {}
    notifyListeners();

    // Persist to Appwrite app_settings
    try {
      final serialized = cleaned.join(', ');
      final docId = AppwriteIdUtils.toValidUid(settingKey, prefix: 'st');
      final payload = {
        'setting_key': settingKey,
        'key': settingKey,
        'setting_value': serialized,
        'value': serialized,
        'category': 'leadership',
        'description':
            'Comma-separated email addresses for ALIVE Board members, Leadership room leaders, and Council who receive meeting minutes & resolutions.',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await AppwriteUpsertHelper.updateOrCreateRow(
        _tables,
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.appSettingsCollectionId,
        rowId: docId,
        data: payload,
        createData: {
          ...payload,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
      debugPrint(
          '[LeadershipEmailSettingsService] Saved recipients to Appwrite: $serialized');
    } catch (e) {
      debugPrint('[LeadershipEmailSettingsService] Save to remote note: $e');
    }
  }

  /// Adds a single email to the recipient list
  Future<void> addRecipient(String email) async {
    final cleaned = email.trim().toLowerCase();
    if (!cleaned.contains('@') || !cleaned.contains('.')) return;
    if (!_recipients.contains(cleaned)) {
      final updated = List<String>.from(_recipients)..add(cleaned);
      await saveRecipients(updated);
    }
  }

  /// Removes an email from the recipient list
  Future<void> removeRecipient(String email) async {
    final cleaned = email.trim().toLowerCase();
    final updated = List<String>.from(_recipients)..remove(cleaned);
    await saveRecipients(updated);
  }
}
