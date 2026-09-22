import 'package:alive_flutter_app/services/exchange_rate_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the shared USD -> NGN contract that the Flutter app, the web donation
/// page and the `paystack_payments` Appwrite Function must all agree on.
///
/// The same constant lives in three places; if this test fails after a rate
/// change, update all three:
///   lib/services/exchange_rate_service.dart -> ExchangeRateService.fallbackRate
///   web/donation.html                       -> FALLBACK_RATE
///   appwrite_functions/paystackPayments/src/main.js -> FALLBACK_USD_TO_NGN
void main() {
  group('ExchangeRateService', () {
    test('last-resort fallback matches the agreed market rate', () {
      expect(ExchangeRateService.fallbackRate, 1380.0);
    });

    test('fetched rates expire within an hour so the quote stays current', () {
      expect(ExchangeRateService.cacheTtl.inHours, lessThanOrEqualTo(1));
      expect(ExchangeRateService.cacheTtl, greaterThan(Duration.zero));
    });

    test('a session that has never fetched still quotes a usable rate', () {
      final service = ExchangeRateService.instance;
      expect(service.lastKnownRate, ExchangeRateService.fallbackRate);
      expect(service.rateSource, anyOf('fallback', 'cache'));
    });
  });
}
