import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/logger.dart';
import '../utils/app_exception.dart';

class StorageService {
  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();

  static final Logger _logger = Logger('StorageService');

  StorageService._();

  SharedPreferences? _prefs;
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

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
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (e) {
      _logger.error('Error writing secure string for key $key', e);
      throw StorageException('Error writing secure string for key $key', originalError: e);
    }
  }

  Future<String?> getSecureString(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      _logger.error('Error reading secure string for key $key', e);
      throw StorageException('Error reading secure string for key $key', originalError: e);
    }
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
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      _logger.error('Error removing secure key $key', e);
      throw StorageException('Error removing secure key $key', originalError: e);
    }
  }

  Future<void> clearSecure() async {
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      _logger.error('Error clearing secure storage', e);
      throw StorageException('Error clearing secure storage', originalError: e);
    }
  }

  Future<bool> containsSecureKey(String key) async {
    try {
      return await _secureStorage.containsKey(key: key);
    } catch (e) {
      _logger.error('Error checking secure key $key', e);
      throw StorageException('Error checking secure key $key', originalError: e);
    }
  }

  Future<Map<String, String>> getAllSecure() async {
    try {
      return await _secureStorage.readAll();
    } catch (e) {
      _logger.error('Error reading all secure data', e);
      throw StorageException('Error reading all secure data', originalError: e);
    }
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
