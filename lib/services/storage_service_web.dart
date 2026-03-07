import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import '../utils/app_exception.dart';

class StorageService {
  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();

  static final Logger _logger = Logger('StorageService');

  StorageService._();

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> setString(String key, String value) async {
    final prefs = await _preferences;
    await prefs.setString(key, value);
  }

  Future<String?> getString(String key) async {
    final prefs = await _preferences;
    return prefs.getString(key);
  }

  Future<void> setInt(String key, int value) async {
    final prefs = await _preferences;
    await prefs.setInt(key, value);
  }

  Future<int?> getInt(String key) async {
    final prefs = await _preferences;
    return prefs.getInt(key);
  }

  Future<void> setBool(String key, bool value) async {
    final prefs = await _preferences;
    await prefs.setBool(key, value);
  }

  Future<bool?> getBool(String key) async {
    final prefs = await _preferences;
    return prefs.getBool(key);
  }

  Future<void> setDouble(String key, double value) async {
    final prefs = await _preferences;
    await prefs.setDouble(key, value);
  }

  Future<double?> getDouble(String key) async {
    final prefs = await _preferences;
    return prefs.getDouble(key);
  }

  Future<void> setStringList(String key, List<String> value) async {
    final prefs = await _preferences;
    await prefs.setStringList(key, value);
  }

  Future<List<String>?> getStringList(String key) async {
    final prefs = await _preferences;
    return prefs.getStringList(key);
  }

  Future<void> setJson(String key, Map<String, dynamic> value) async {
    final jsonString = jsonEncode(value);
    await setString(key, jsonString);
  }

  Future<Map<String, dynamic>?> getJson(String key) async {
    final jsonString = await getString(key);
    if (jsonString == null) return null;
    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      _logger.error('Error decoding JSON for key $key', e);
      throw StorageException('Error decoding JSON for key $key', originalError: e);
    }
  }

  Future<void> setJsonList(String key, List<Map<String, dynamic>> value) async {
    final jsonString = jsonEncode(value);
    await setString(key, jsonString);
  }

  Future<List<Map<String, dynamic>>?> getJsonList(String key) async {
    final jsonString = await getString(key);
    if (jsonString == null) return null;
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return null;
    } catch (e) {
      _logger.error('Error decoding JSON list for key $key', e);
      throw StorageException('Error decoding JSON list for key $key', originalError: e);
    }
  }

  Future<void> remove(String key) async {
    final prefs = await _preferences;
    await prefs.remove(key);
  }

  Future<void> clear() async {
    final prefs = await _preferences;
    await prefs.clear();
  }

  Future<bool> containsKey(String key) async {
    final prefs = await _preferences;
    return prefs.containsKey(key);
  }

  Future<Set<String>> getKeys() async {
    final prefs = await _preferences;
    return prefs.getKeys();
  }

  Future<void> setSecureString(String key, String value) async {
    final prefs = await _preferences;
    final keys = prefs.getStringList('_secure_keys') ?? <String>[];
    if (!keys.contains(key)) {
      keys.add(key);
      await prefs.setStringList('_secure_keys', keys);
    }
    await prefs.setString('_secure_$key', value);
  }

  Future<String?> getSecureString(String key) async {
    final prefs = await _preferences;
    return prefs.getString('_secure_$key');
  }

  Future<void> setSecureJson(String key, Map<String, dynamic> value) async {
    final jsonString = jsonEncode(value);
    await setSecureString(key, jsonString);
  }

  Future<Map<String, dynamic>?> getSecureJson(String key) async {
    final jsonString = await getSecureString(key);
    if (jsonString == null) return null;
    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      _logger.error('Error decoding secure JSON for key $key', e);
      throw StorageException('Error decoding secure JSON for key $key', originalError: e);
    }
  }

  Future<void> removeSecure(String key) async {
    final prefs = await _preferences;
    final keys = prefs.getStringList('_secure_keys') ?? <String>[];
    keys.remove(key);
    await prefs.setStringList('_secure_keys', keys);
    await prefs.remove('_secure_$key');
  }

  Future<void> clearSecure() async {
    final prefs = await _preferences;
    final keys = prefs.getStringList('_secure_keys') ?? <String>[];
    for (final k in keys) {
      await prefs.remove('_secure_$k');
    }
    await prefs.remove('_secure_keys');
  }

  Future<bool> containsSecureKey(String key) async {
    final prefs = await _preferences;
    final keys = prefs.getStringList('_secure_keys') ?? <String>[];
    return keys.contains(key);
  }

  Future<Map<String, String>> getAllSecure() async {
    final prefs = await _preferences;
    final keys = prefs.getStringList('_secure_keys') ?? <String>[];
    final Map<String, String> result = {};
    for (final k in keys) {
      final v = prefs.getString('_secure_$k');
      if (v != null) {
        result[k] = v;
      }
    }
    return result;
  }
}

class StorageKeys {
  static const String theme = 'theme';
  static const String language = 'language';
  static const String fontSize = 'font_size';
  static const String onboardingCompleted = 'onboarding_completed';
  static const String notificationSettings = 'notification_settings';
  static const String fcmToken = 'fcm_token';
  static const String autoSync = 'auto_sync';
  static const String offlineMode = 'offline_mode';
  static const String dataUsage = 'data_usage';
  static const String cachedPrayerRequests = 'cached_prayer_requests';
  static const String cachedMissions = 'cached_missions';
  static const String cachedStudyPrograms = 'cached_study_programs';
  static const String cachedHealthActivities = 'cached_health_activities';
}
