import 'package:appwrite/appwrite.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/appwrite_client.dart';
import 'appwrite_backend_config.dart';

/// Configuration for payment providers
class PaymentConfig {
  static const String _prefsKey = 'paystack_dynamic_public_key';
  static const String _testModePrefsKey = 'paystack_test_mode_enabled';

  static String? _cachedDynamicPublicKey;
  static bool? _cachedTestMode;

  /// Whether Paystack is currently operating in Test Sandbox mode.
  static bool get isTestMode {
    if (_cachedTestMode != null) return _cachedTestMode!;
    const envMode = bool.fromEnvironment('PAYSTACK_TEST_MODE', defaultValue: false);
    return envMode;
  }

  /// Sets the active test mode at runtime and persists it locally and in memory.
  static void setTestMode(bool value) {
    _cachedTestMode = value;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(_testModePrefsKey, value);
    }).catchError((_) {});
  }

  /// Known test public key for sandbox development
  static const String testPublicKey = String.fromEnvironment(
    'PAYSTACK_TEST_PUBLIC_KEY',
    defaultValue: 'pk_test_92de7a66b011a1f6491a53faa05b64fe9afe0976',
  );

  /// Known live public key for production
  static const String livePublicKey = String.fromEnvironment(
    'PAYSTACK_LIVE_PUBLIC_KEY',
    defaultValue: 'pk_live_4d497ec0f12f944e22598c8daa40ce716e8971cf',
  );

  /// Returns the active Paystack Public Key.
  /// Priority:
  /// 1. If Test Mode is ON: returns the test public key
  /// 2. If Test Mode is OFF: dynamic key from Appwrite app_settings (if live) or livePublicKey
  static String get paystackPublicKey {
    if (isTestMode) {
      return testPublicKey;
    }
    if (_cachedDynamicPublicKey != null &&
        _cachedDynamicPublicKey!.isNotEmpty &&
        !_cachedDynamicPublicKey!.startsWith('pk_test_')) {
      return _cachedDynamicPublicKey!;
    }
    const envKey = String.fromEnvironment(
      'PAYSTACK_PUBLIC_KEY',
      defaultValue: '',
    );
    if (envKey.isNotEmpty && !envKey.startsWith('pk_test_')) return envKey;
    return livePublicKey;
  }

  /// Sets the dynamic public key at runtime (e.g. from Appwrite function response
  /// or Appwrite `app_settings` document) and persists it locally.
  static void setDynamicPublicKey(String key) {
    final trimmed = key.trim();
    if (trimmed.isNotEmpty && trimmed.startsWith('pk_')) {
      _cachedDynamicPublicKey = trimmed;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(_prefsKey, trimmed);
      }).catchError((_) {});
    }
  }

  /// Loads the persisted public key and test mode state from device storage.
  static Future<void> loadCachedPublicKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_prefsKey);
      if (cached != null && cached.trim().isNotEmpty) {
        _cachedDynamicPublicKey = cached.trim();
      }
      final cachedMode = prefs.getBool(_testModePrefsKey);
      if (cachedMode != null) {
        _cachedTestMode = cachedMode;
      }
    } catch (_) {}
  }

  /// Queries the live Appwrite `app_settings` table for `paystack_public_key`
  /// and `paystack_test_mode` so that updating settings applies immediately.
  static Future<String> syncPublicKeyFromAppwrite() async {
    try {
      final tables = TablesDB(appwriteClient);
      final snapshot = await tables
          .listRows(
            databaseId: AppwriteBackendConfig.databaseId,
            tableId: AppwriteBackendConfig.appSettingsCollectionId,
            queries: [
              Query.limit(20),
            ],
          )
          .timeout(const Duration(seconds: 6));

      for (final rowObj in snapshot.rows) {
        final row = rowObj.data;
        final k = (row['key'] ?? row['setting_key'] ?? '').toString();
        final raw = row['value'] ?? row['setting_value'];

        if (k == 'paystack_test_mode') {
          final isEnabled = raw == true || raw.toString().toLowerCase() == 'true';
          setTestMode(isEnabled);
        } else if (k == 'paystack_public_key' && raw is String && raw.trim().startsWith('pk_')) {
          setDynamicPublicKey(raw.trim());
        }
      }
    } catch (_) {}
    return paystackPublicKey;
  }

  // Paystack Secret Keys - NEVER expose in client code
  // These are used server-side only in Appwrite Cloud Functions.

  // Paystack Callback URLs
  static const String paystackCallbackUrl = String.fromEnvironment(
    'PAYSTACK_CALLBACK_URL',
    defaultValue: 'https://app.alivenigeria.org/payment/callback',
  );

  // Webhook URLs - For server-side processing
  static const String paystackWebhookUrl = String.fromEnvironment(
    'PAYSTACK_WEBHOOK_URL',
    defaultValue: 'https://api.alivenigeria.org/webhooks/paystack',
  );

  // Payment channels to enable.
  //
  // IMPORTANT: `null` means "do not send the channels field at all", which lets
  // Paystack use every channel enabled on the merchant account. That is exactly
  // what the working web donation page (web/donation.html) does.
  static List<String>? get paystackChannels {
    const raw = String.fromEnvironment('PAYSTACK_CHANNELS', defaultValue: '');
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final parsed = trimmed
        .split(',')
        .map((channel) => channel.trim().toLowerCase())
        .where((channel) => channel.isNotEmpty)
        .toList();
    return parsed.isEmpty ? null : parsed;
  }

  // Currency code
  static const String currencyCode = 'NGN';

  // NOTE: monthly plans are created dynamically on the server for the donor's
  // chosen amount (see paystackPayments `initialize_subscription`). The old
  // static plan codes (`PAYSTACK_MONTHLY_PLAN_CODE_NGN` / `_USD`) were
  // removed — the plans they pointed at no longer exist in Paystack.
}
