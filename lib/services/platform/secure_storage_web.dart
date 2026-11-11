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
  static final Map<String, String> _memoryFallback = {};

  List<String> _readKeys() {
    try {
      final raw = web.window.sessionStorage.getItem(_keysIndex);
      if (raw == null || raw.isEmpty) return <String>[];
      return raw
          .split('\n')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
    } catch (_) {
      final raw = _memoryFallback[_keysIndex];
      if (raw == null || raw.isEmpty) return <String>[];
      return raw
          .split('\n')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
    }
  }

  void _writeKeys(List<String> keys) {
    if (keys.isEmpty) {
      try {
        web.window.sessionStorage.removeItem(_keysIndex);
      } catch (_) {}
      _memoryFallback.remove(_keysIndex);
      return;
    }
    final joined = keys.join('\n');
    try {
      web.window.sessionStorage.setItem(_keysIndex, joined);
    } catch (_) {}
    _memoryFallback[_keysIndex] = joined;
  }

  Future<void> write({required String key, String? value}) async {
    final keys = _readKeys();
    if (!keys.contains(key)) {
      keys.add(key);
      _writeKeys(keys);
    }
    final vk = _valueKey(key);
    if (value == null) {
      try {
        web.window.sessionStorage.removeItem(vk);
      } catch (_) {}
      _memoryFallback.remove(vk);
    } else {
      try {
        web.window.sessionStorage.setItem(vk, value);
      } catch (_) {}
      _memoryFallback[vk] = value;
    }
  }

  Future<String?> read({required String key}) async {
    final vk = _valueKey(key);
    try {
      final val = web.window.sessionStorage.getItem(vk);
      if (val != null) return val;
    } catch (_) {}
    return _memoryFallback[vk];
  }

  Future<void> delete({required String key}) async {
    final keys = _readKeys();
    keys.remove(key);
    _writeKeys(keys);
    final vk = _valueKey(key);
    try {
      web.window.sessionStorage.removeItem(vk);
    } catch (_) {}
    _memoryFallback.remove(vk);
  }

  Future<void> deleteAll() async {
    final keys = _readKeys();
    for (final k in keys) {
      final vk = _valueKey(k);
      try {
        web.window.sessionStorage.removeItem(vk);
      } catch (_) {}
      _memoryFallback.remove(vk);
    }
    try {
      web.window.sessionStorage.removeItem(_keysIndex);
    } catch (_) {}
    _memoryFallback.remove(_keysIndex);
  }

  Future<bool> containsKey({required String key}) async {
    final vk = _valueKey(key);
    try {
      if (web.window.sessionStorage.getItem(vk) != null) return true;
    } catch (_) {}
    return _memoryFallback.containsKey(vk);
  }

  Future<Map<String, String>> readAll() async {
    final keys = _readKeys();
    final Map<String, String> result = {};
    for (final k in keys) {
      final vk = _valueKey(k);
      String? v;
      try {
        v = web.window.sessionStorage.getItem(vk);
      } catch (_) {}
      v ??= _memoryFallback[vk];
      if (v != null) {
        result[k] = v;
      }
    }
    return result;
  }
}
