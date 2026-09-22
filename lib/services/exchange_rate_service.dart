import 'dart:convert';
import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../utils/logger.dart';

/// Single source of truth for the USD -> NGN rate used across the app.
///
/// The rate is always fetched live-first so the number donors see is the
/// market rate at checkout time; nothing has to be kept up to date by hand.
///
/// Priority:
/// 1. Server `paystack_payments` action `get_exchange_rate` (live market rate,
///    admin override aware). This keeps web + APK in sync with what the server
///    will actually bill.
/// 2. Live public FX API (no key required).
/// 3. Appwrite `app_settings` row with key `usd_to_ngn` (admin-published value).
/// 4. Last rate that was successfully fetched and cached on this device. This is
///    a real market rate, so it is preferred over the constant below.
/// 5. Hardcoded fallback ([fallbackRate]) — only for a first run with no
///    network, so checkout never blocks.
class ExchangeRateService {
  ExchangeRateService._internal();
  static final ExchangeRateService instance = ExchangeRateService._internal();

  /// LAST-RESORT value used only when the server function, public FX APIs, the
  /// Appwrite `app_settings` override and this device's cache are all
  /// unreachable, so checkout never blocks. Kept identical to the web page and
  /// the server fallback so app/web displays never disagree.
  static const double fallbackRate = 1380.0;
  static const String _cacheKey = 'usd_to_ngn_rate';
  static const String _cacheTimeKey = 'usd_to_ngn_rate_updated_at';

  /// How long a fetched rate is considered fresh before refetching. Short, so
  /// the displayed rate tracks the market instead of drifting for hours.
  static const Duration cacheTtl = Duration(hours: 1);

  /// Free, key-less endpoints plus the JSON path that holds the NGN rate.
  ///
  /// `api.frankfurter.app` is deliberately excluded: it serves the ECB
  /// reference set, which does not publish the Naira, so it always answered 404
  /// and only delayed the next provider.
  static const List<(String, List<String>)> _fxProviders = [
    ('https://open.er-api.com/v6/latest/USD', ['rates', 'NGN']),
    ('https://api.exchangerate-api.com/v4/latest/USD', ['rates', 'NGN']),
    (
      'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json',
      ['usd', 'ngn'],
    ),
  ];

  final Logger _logger = Logger('ExchangeRateService');
  double? _memoryRate;
  DateTime? _memoryUpdatedAt;
  String _rateSource = 'fallback';

  /// Where the current rate came from (server, live FX, app_settings, cache…).
  String get rateSource => _rateSource;

  /// Returns the current USD -> NGN rate, never throws.
  Future<double> getUsdToNgn({bool forceRefresh = false}) async {
    if (!forceRefresh && _memoryRate != null && _memoryUpdatedAt != null) {
      if (DateTime.now().difference(_memoryUpdatedAt!) < cacheTtl) {
        return _memoryRate!;
      }
    }
    if (!forceRefresh) {
      final cached = await _readCache();
      if (cached != null) {
        _memoryRate = cached.$1;
        _memoryUpdatedAt = cached.$2;
        if (DateTime.now().difference(cached.$2) < cacheTtl) {
          // Kick off a background refresh but return the cached value fast.
          _rateSource = 'cache';
          unawaited(_refreshAndCache());
          return cached.$1;
        }
      }
    }
    final live = await _refreshAndCache();
    if (live != null) return live;
    if (_memoryRate != null) return _memoryRate!;
    _rateSource = 'fallback';
    return fallbackRate;
  }

  /// Last known rate synchronously (fallback while loading).
  double get lastKnownRate => _memoryRate ?? fallbackRate;

  DateTime? get lastUpdatedAt => _memoryUpdatedAt;

  Future<double?> _refreshAndCache() async {
    // 0. Ask our own server first — it resolves live market rate and honors
    // the admin override / env var, so display always matches billing.
    final server = await _fetchServerRate();
    if (server != null) {
      await _writeCache(server.$1);
      _memoryRate = server.$1;
      _memoryUpdatedAt = DateTime.now();
      _rateSource = 'server (${server.$2})';
      return server.$1;
    }
    // 1. Live FX providers (tried in order).
    final live = await _fetchLiveRate();
    if (live != null) {
      await _writeCache(live.$1);
      _memoryRate = live.$1;
      _memoryUpdatedAt = DateTime.now();
      _rateSource = 'live FX (${live.$2})';
      return live.$1;
    }
    // 2. Admin-overridable Appwrite setting.
    final remote = await _fetchAppwriteSetting();
    if (remote != null) {
      await _writeCache(remote);
      _memoryRate = remote;
      _memoryUpdatedAt = DateTime.now();
      _rateSource = 'app_settings';
      return remote;
    }
    return null;
  }

  /// Calls the deployed `paystack_payments` function action
  /// `get_exchange_rate`. Works for guests (function execute: any).
  Future<(double, String)?> _fetchServerRate() async {
    try {
      final functions = Functions(appwriteClient);
      final execution = await functions
          .createExecution(
            functionId: AppwriteBackendConfig.paystackPaymentsFunctionId,
            body: jsonEncode({'action': 'get_exchange_rate'}),
            xasync: false,
          )
          .timeout(const Duration(seconds: 10));
      final bodyStr = execution.responseBody.trim();
      if (bodyStr.isEmpty) return null;
      final decoded = jsonDecode(bodyStr);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['error'] != null) return null;
      final raw = decoded['rate'];
      final parsed =
          raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
      if (parsed != null && parsed > 100 && parsed < 100000) {
        return (parsed, decoded['source']?.toString() ?? 'server');
      }
    } catch (e) {
      _logger.error('Server exchange-rate fetch failed', e);
    }
    return null;
  }

  /// Tries the free, key-less FX providers in [\_fxProviders] and returns the
  /// first plausible USD -> NGN rate (with the provider name) or null when
  /// offline/blocked.
  Future<(double, String)?> _fetchLiveRate() async {
    for (final (url, path) in _fxProviders) {
      try {
        final res = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) continue;
        final decoded = jsonDecode(res.body);
        if (decoded is! Map<String, dynamic>) continue;
        // Walk a short JSON path, e.g. ['rates','NGN'] for open.er-api.com and
        // ['usd','ngn'] for the jsDelivr currency-api.
        dynamic cursor = decoded;
        for (final segment in path) {
          if (cursor is! Map) {
            cursor = null;
            break;
          }
          cursor = cursor[segment];
        }
        final rate = cursor is num
            ? cursor.toDouble()
            : double.tryParse(cursor?.toString() ?? '');
        if (rate != null && rate > 100 && rate < 100000) {
          return (rate, Uri.parse(url).host);
        }
      } catch (e) {
        _logger.error('Live FX fetch failed ($url)', e);
      }
    }
    return null;
  }

  /// Admin can pin an override via `app_settings` row key `usd_to_ngn`.
  Future<double?> _fetchAppwriteSetting() async {
    try {
      final tables = TablesDB(appwriteClient);
      final snapshot = await tables
          .listRows(
            databaseId: AppwriteBackendConfig.databaseId,
            tableId: AppwriteBackendConfig.appSettingsCollectionId,
            queries: [
              Query.equal('key', 'usd_to_ngn'),
              Query.limit(1),
            ],
          )
          .timeout(const Duration(seconds: 8));
      if (snapshot.rows.isEmpty) return null;
      final row = snapshot.rows.first.data;
      final raw = row['value'] ?? row['setting_value'];
      final parsed = raw is num
          ? raw.toDouble()
          : double.tryParse(raw?.toString() ?? '');
      if (parsed != null && parsed > 100 && parsed < 100000) return parsed;
    } catch (e) {
      _logger.error('Appwrite usd_to_ngn setting fetch failed', e);
    }
    return null;
  }

  Future<(double, DateTime)?> _readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rate = prefs.getDouble(_cacheKey);
      final updatedMs = prefs.getInt(_cacheTimeKey);
      if (rate == null) return null;
      final updated = updatedMs == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(updatedMs);
      return (rate, updated);
    } catch (_) {
      return _memoryRate != null && _memoryUpdatedAt != null
          ? (_memoryRate!, _memoryUpdatedAt!)
          : null;
    }
  }

  Future<void> _writeCache(double rate) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_cacheKey, rate);
      await prefs.setInt(
          _cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }
}