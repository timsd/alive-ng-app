/// Configuration for payment providers
class PaymentConfig {
  // Paystack API Keys
  static String get paystackPublicKey {
    return const String.fromEnvironment('PAYSTACK_PUBLIC_KEY',
        defaultValue: '');
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
}
