import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StorageService {
  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();

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

  // Initialize storage
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Ensure preferences are initialized
  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // Generic storage methods
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

  // JSON storage methods
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
      if (kDebugMode) {
        print('Error decoding JSON for key $key: $e');
      }
      return null;
    }
  }

  // List storage methods
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
      if (kDebugMode) {
        print('Error decoding JSON list for key $key: $e');
      }
      return null;
    }
  }

  // Remove methods
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

  // Secure storage methods (for sensitive data)
  Future<void> setSecureString(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (e) {
      if (kDebugMode) {
        print('Error writing secure string for key $key: $e');
      }
      rethrow;
    }
  }

  Future<String?> getSecureString(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      if (kDebugMode) {
        print('Error reading secure string for key $key: $e');
      }
      return null;
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
      if (kDebugMode) {
        print('Error decoding secure JSON for key $key: $e');
      }
      return null;
    }
  }

  Future<void> removeSecure(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      if (kDebugMode) {
        print('Error removing secure key $key: $e');
      }
    }
  }

  Future<void> clearSecure() async {
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing secure storage: $e');
      }
    }
  }

  Future<bool> containsSecureKey(String key) async {
    try {
      return await _secureStorage.containsKey(key: key);
    } catch (e) {
      if (kDebugMode) {
        print('Error checking secure key $key: $e');
      }
      return false;
    }
  }

  Future<Map<String, String>> getAllSecure() async {
    try {
      return await _secureStorage.readAll();
    } catch (e) {
      if (kDebugMode) {
        print('Error reading all secure data: $e');
      }
      return {};
    }
  }
}

// App-specific storage keys
class StorageKeys {
  // User preferences
  static const String theme = 'theme';
  static const String language = 'language';
  static const String fontSize = 'font_size';
  static const String onboardingCompleted = 'onboarding_completed';

  // Notification settings
  static const String notificationSettings = 'notification_settings';
  static const String fcmToken = 'fcm_token';

  // App settings
  static const String autoSync = 'auto_sync';
  static const String offlineMode = 'offline_mode';
  static const String dataUsage = 'data_usage';

  // Cache keys
  static const String cachedPrayerRequests = 'cached_prayer_requests';
  static const String cachedMissions = 'cached_missions';
  static const String cachedStudyPrograms = 'cached_study_programs';
  static const String cachedHealthActivities = 'cached_health_activities';
  static const String cachedDailyVerse = 'cached_daily_verse';

  // Sync keys
  static const String prayerRequests = 'prayer_requests';
  static const String healthActivities = 'health_activities';
  static const String missions = 'missions';
  static const String studyPrograms = 'study_programs';
  static const String dailyVerses = 'daily_verses';

  // User data
  static const String userProfile = 'user_profile';
  static const String userStats = 'user_stats';
  static const String userPreferences = 'user_preferences';

  // Secure keys (for sensitive data)
  static const String authToken = 'auth_token';
  static const String refreshToken = 'refresh_token';
  static const String biometricEnabled = 'biometric_enabled';
  static const String encryptionKey = 'encryption_key';

  // Sync timestamps
  static const String lastSyncTime = 'last_sync_time';
  static const String lastPrayerSync = 'last_prayer_sync';
  static const String lastMissionSync = 'last_mission_sync';
  static const String lastHealthSync = 'last_health_sync';

  // Location data
  static const String lastKnownLocation = 'last_known_location';

  // App state
  static const String currentTab = 'current_tab';
  static const String lastOpenedScreen = 'last_opened_screen';
  static const String appVersion = 'app_version';
  static const String buildNumber = 'build_number';

  // Analytics keys
  static const String analyticsData = 'analytics_data';
  static const String currentSessionId = 'current_session_id';
  static const String sessionStartTime = 'session_start_time';
}

// Storage helper methods for common operations
class StorageHelper {
  static final StorageService _storage = StorageService.instance;

  // Theme methods
  static Future<void> setTheme(String theme) async {
    await _storage.setString(StorageKeys.theme, theme);
  }

  static Future<String> getTheme() async {
    return await _storage.getString(StorageKeys.theme) ?? 'system';
  }

  // Language methods
  static Future<void> setLanguage(String language) async {
    await _storage.setString(StorageKeys.language, language);
  }

  static Future<String> getLanguage() async {
    return await _storage.getString(StorageKeys.language) ?? 'en';
  }

  // Onboarding methods
  static Future<void> setOnboardingCompleted(bool completed) async {
    await _storage.setBool(StorageKeys.onboardingCompleted, completed);
  }

  static Future<bool> isOnboardingCompleted() async {
    return await _storage.getBool(StorageKeys.onboardingCompleted) ?? false;
  }

  // Notification settings methods
  static Future<void> setNotificationSettings(
      Map<String, dynamic> settings) async {
    await _storage.setJson(StorageKeys.notificationSettings, settings);
  }

  static Future<Map<String, dynamic>?> getNotificationSettings() async {
    return await _storage.getJson(StorageKeys.notificationSettings);
  }

  // Cache methods
  static Future<void> setCachedData(
      String key, List<Map<String, dynamic>> data) async {
    await _storage.setJsonList(key, data);
    await _storage.setString(
        '${key}_timestamp', DateTime.now().toIso8601String());
  }

  static Future<List<Map<String, dynamic>>?> getCachedData(String key,
      {Duration? maxAge}) async {
    if (maxAge != null) {
      final timestampString = await _storage.getString('${key}_timestamp');
      if (timestampString != null) {
        final timestamp = DateTime.parse(timestampString);
        if (DateTime.now().difference(timestamp) > maxAge) {
          // Cache is too old, remove it
          await _storage.remove(key);
          await _storage.remove('${key}_timestamp');
          return null;
        }
      }
    }

    return await _storage.getJsonList(key);
  }

  static Future<bool> isCacheValid(String key, Duration maxAge) async {
    final timestampString = await _storage.getString('${key}_timestamp');
    if (timestampString == null) return false;

    final timestamp = DateTime.parse(timestampString);
    return DateTime.now().difference(timestamp) <= maxAge;
  }

  // Sync timestamp methods
  static Future<void> setLastSyncTime(String key, DateTime time) async {
    await _storage.setString(key, time.toIso8601String());
  }

  static Future<DateTime?> getLastSyncTime(String key) async {
    final timeString = await _storage.getString(key);
    return timeString != null ? DateTime.parse(timeString) : null;
  }

  // User preferences methods
  static Future<void> setUserPreference(String key, dynamic value) async {
    final preferences =
        await _storage.getJson(StorageKeys.userPreferences) ?? {};
    preferences[key] = value;
    await _storage.setJson(StorageKeys.userPreferences, preferences);
  }

  static Future<T?> getUserPreference<T>(String key) async {
    final preferences = await _storage.getJson(StorageKeys.userPreferences);
    return preferences?[key] as T?;
  }

  // App version methods
  static Future<void> setAppVersion(String version, int buildNumber) async {
    await _storage.setString(StorageKeys.appVersion, version);
    await _storage.setInt(StorageKeys.buildNumber, buildNumber);
  }

  static Future<Map<String, dynamic>> getAppVersion() async {
    final version = await _storage.getString(StorageKeys.appVersion);
    final buildNumber = await _storage.getInt(StorageKeys.buildNumber);
    return {
      'version': version,
      'buildNumber': buildNumber,
    };
  }

  // Clear all app data (for logout or reset)
  static Future<void> clearAppData() async {
    await _storage.clear();
    // Keep some essential data
    await setOnboardingCompleted(true);
  }

  // Clear only user-specific data (for logout)
  static Future<void> clearUserData() async {
    final keysToKeep = {
      StorageKeys.theme,
      StorageKeys.language,
      StorageKeys.fontSize,
      StorageKeys.onboardingCompleted,
      StorageKeys.appVersion,
      StorageKeys.buildNumber,
    };

    final allKeys = await _storage.getKeys();
    for (final key in allKeys) {
      if (!keysToKeep.contains(key)) {
        await _storage.remove(key);
      }
    }

    // Clear secure storage
    await _storage.clearSecure();
  }
}

// Riverpod providers
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService.instance;
});

final themeProvider = FutureProvider<String>((ref) async {
  return await StorageHelper.getTheme();
});

final languageProvider = FutureProvider<String>((ref) async {
  return await StorageHelper.getLanguage();
});

final onboardingCompletedProvider = FutureProvider<bool>((ref) async {
  return await StorageHelper.isOnboardingCompleted();
});




