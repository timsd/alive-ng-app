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

  // Payment channels to enable
  static const List<String> paystackChannels = [
    'card',
    'bank',
    'ussd',
    'qr',
    'mobile_money',
    'bank_transfer'
  ];

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
