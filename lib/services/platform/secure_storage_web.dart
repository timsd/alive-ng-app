import 'package:web/web.dart' as web;

class AndroidOptions {
  const AndroidOptions({bool? encryptedSharedPreferences});
}

class IOSOptions {
  final KeychainAccessibility? accessibility;
  const IOSOptions({this.accessibility});
}

class KeychainAccessibility {
  static const firstUnlockThisDevice =
      KeychainAccessibility._('first_unlock_this_device');
  final String value;
  const KeychainAccessibility._(this.value);
}

class FlutterSecureStorage {
  const FlutterSecureStorage({AndroidOptions? aOptions, IOSOptions? iOptions});

  static const String _keysIndex = '_secure_keys';
  static String _valueKey(String key) => '_secure_$key';

  List<String> _readKeys() {
    final raw = web.window.sessionStorage.getItem(_keysIndex);
    if (raw == null || raw.isEmpty) return <String>[];
    return raw
        .split('\n')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  void _writeKeys(List<String> keys) {
    if (keys.isEmpty) {
      web.window.sessionStorage.removeItem(_keysIndex);
      return;
    }
    web.window.sessionStorage.setItem(_keysIndex, keys.join('\n'));
  }

  Future<void> write({required String key, String? value}) async {
    final keys = _readKeys();
    if (!keys.contains(key)) {
      keys.add(key);
      _writeKeys(keys);
    }
    if (value == null) {
      web.window.sessionStorage.removeItem(_valueKey(key));
    } else {
      web.window.sessionStorage.setItem(_valueKey(key), value);
    }
  }

  Future<String?> read({required String key}) async {
    return web.window.sessionStorage.getItem(_valueKey(key));
  }

  Future<void> delete({required String key}) async {
    final keys = _readKeys();
    keys.remove(key);
    _writeKeys(keys);
    web.window.sessionStorage.removeItem(_valueKey(key));
  }

  Future<void> deleteAll() async {
    final keys = _readKeys();
    for (final k in keys) {
      web.window.sessionStorage.removeItem(_valueKey(k));
    }
    web.window.sessionStorage.removeItem(_keysIndex);
  }

  Future<bool> containsKey({required String key}) async {
    return web.window.sessionStorage.getItem(_valueKey(key)) != null;
  }

  Future<Map<String, String>> readAll() async {
    final keys = _readKeys();
    final Map<String, String> result = {};
    for (final k in keys) {
      final v = web.window.sessionStorage.getItem(_valueKey(k));
      if (v != null) {
        result[k] = v;
      }
    }
    return result;
  }
}
