/// Riverpod providers for the payment processing gateway.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/adapters/paystack_payment_gateway.dart';
import '../services/ports/payment_gateway.dart';

/// Provider for the abstract [PaymentGateway].
///
/// Instantiates the concrete [PaystackPaymentGateway] adapter.
final paymentGatewayProvider = Provider<PaymentGateway>((ref) {
  return PaystackPaymentGateway();
});
