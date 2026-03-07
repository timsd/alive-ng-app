import 'package:shared_preferences/shared_preferences.dart';

class AndroidOptions {
  const AndroidOptions({bool? encryptedSharedPreferences});
}

class IOSOptions {
  final KeychainAccessibility? accessibility;
  const IOSOptions({this.accessibility});
}

class KeychainAccessibility {
  static const firstUnlockThisDevice = KeychainAccessibility._('first_unlock_this_device');
  final String value;
  const KeychainAccessibility._(this.value);
}

class FlutterSecureStorage {
  const FlutterSecureStorage({AndroidOptions? aOptions, IOSOptions? iOptions});

  Future<void> write({required String key, String? value}) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getStringList('_secure_keys') ?? <String>[];
    if (!keys.contains(key)) {
      keys.add(key);
      await prefs.setStringList('_secure_keys', keys);
    }
    if (value == null) {
      await prefs.remove('_secure_$key');
    } else {
      await prefs.setString('_secure_$key', value);
    }
  }

  Future<String?> read({required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('_secure_$key');
  }

  Future<void> delete({required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getStringList('_secure_keys') ?? <String>[];
    keys.remove(key);
    await prefs.setStringList('_secure_keys', keys);
    await prefs.remove('_secure_$key');
  }

  Future<void> deleteAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getStringList('_secure_keys') ?? <String>[];
    for (final k in keys) {
      await prefs.remove('_secure_$k');
    }
    await prefs.remove('_secure_keys');
  }

  Future<bool> containsKey({required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getStringList('_secure_keys') ?? <String>[];
    return keys.contains(key);
  }

  Future<Map<String, String>> readAll() async {
    final prefs = await SharedPreferences.getInstance();
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
