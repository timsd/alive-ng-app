/// Configuration for payment providers
class PaymentConfig {
  // Paystack API Keys
  static String get paystackPublicKey {
    return const String.fromEnvironment('PAYSTACK_PUBLIC_KEY',
        defaultValue: 'pk_live_2c83ec0083f461344b6e11753a87ed4f7f365d4a');
  }

  // Paystack Secret Keys - NEVER expose in client code
  // These are included as comments for reference only and should be used server-side
  // static final String _paystackSecretKey = kReleaseMode
  //     ? 'sk_live_...'
  //     : 'sk_test_...';

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
  //
  // Historically this defaulted to 'card, bank, ussd, qr, mobile_money,
  // bank_transfer'. Paystack rejects the ENTIRE initialization (HTTP 502 from
  // our function, e.g. "mobile_money is not a valid channel" /
  // "channel_not_supported") when any listed channel is unavailable for the
  // account or the requested currency — which is why the APK failed for both
  // NGN and USD while the web page worked. Override only when you deliberately
  // want to restrict channels:
  //   flutter build apk --dart-define=PAYSTACK_CHANNELS="card,ussd"
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

  // Monthly plan codes per currency (configure via --dart-define)
  static const String paystackMonthlyPlanCodeNgn = String.fromEnvironment(
    'PAYSTACK_MONTHLY_PLAN_CODE_NGN',
    defaultValue: '',
  );

  static const String paystackMonthlyPlanCodeUsd = String.fromEnvironment(
    'PAYSTACK_MONTHLY_PLAN_CODE_USD',
    defaultValue: '',
  );

  static String monthlyPlanCodeForCurrency(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return paystackMonthlyPlanCodeUsd;
      case 'NGN':
      default:
        return paystackMonthlyPlanCodeNgn;
    }
  }
}
