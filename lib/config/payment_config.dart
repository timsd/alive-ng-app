import 'package:appwrite/appwrite.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import 'appwrite_backend_config.dart';

/// Configuration for payment providers
class PaymentConfig {
  static const String _prefsKey = 'paystack_dynamic_public_key';
  static String? _cachedDynamicPublicKey;

  /// Returns the active Paystack Public Key.
  /// Priority:
  /// 1. Dynamic key updated from Appwrite backend/settings at runtime or cached locally
  /// 2. Build-time `--dart-define=PAYSTACK_PUBLIC_KEY=...` from Coolify / APK build
  static String get paystackPublicKey {
    if (_cachedDynamicPublicKey != null &&
        _cachedDynamicPublicKey!.isNotEmpty) {
      return _cachedDynamicPublicKey!;
    }
    const envKey = String.fromEnvironment('PAYSTACK_PUBLIC_KEY', defaultValue: '');
    if (envKey.isNotEmpty) return envKey;
    return '';
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

  /// Loads the persisted public key from device storage.
  static Future<void> loadCachedPublicKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_prefsKey);
      if (cached != null && cached.trim().isNotEmpty) {
        _cachedDynamicPublicKey = cached.trim();
      }
    } catch (_) {}
  }

  /// Queries the live Appwrite `app_settings` table for `paystack_public_key`
  /// so that updating keys on Appwrite immediately applies to mobile apps
  /// without requiring an app rebuild or code change.
  static Future<String> syncPublicKeyFromAppwrite() async {
    try {
      final tables = TablesDB(appwriteClient);
      final snapshot = await tables
          .listRows(
            databaseId: AppwriteBackendConfig.databaseId,
            tableId: AppwriteBackendConfig.appSettingsCollectionId,
            queries: [
              Query.equal('key', 'paystack_public_key'),
              Query.limit(1),
            ],
          )
          .timeout(const Duration(seconds: 6));
      if (snapshot.rows.isNotEmpty) {
        final row = snapshot.rows.first.data;
        final raw = row['value'] ?? row['setting_value'];
        if (raw is String && raw.trim().startsWith('pk_')) {
          setDynamicPublicKey(raw.trim());
          return raw.trim();
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
    defaultValue: 'https://app.alivenigeria.org',
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
