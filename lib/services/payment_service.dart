import 'dart:async';

import '../config/payment_config.dart';
import '../models/payment_models.dart';
import 'adapters/paystack_payment_gateway.dart';
import 'ports/payment_gateway.dart';

/// Unified PaymentService delegating to [PaymentGateway].
///
/// This service acts as an application-level facade. It NO LONGER imports
/// `package:paystack_flutter_sdk`. All third-party SDK dependencies are
/// strictly confined to `lib/services/adapters/paystack_payment_gateway.dart`.
class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  final PaymentGateway _gateway;

  factory PaymentService([PaymentGateway? gateway]) {
    if (gateway != null) {
      return PaymentService._withGateway(gateway);
    }
    return _instance;
  }

  PaymentService._internal() : _gateway = PaystackPaymentGateway();

  PaymentService._withGateway(this._gateway);

  /// Underlying payment gateway port.
  PaymentGateway get gateway => _gateway;

  /// Initialize the payment service
  Future<void> initialize() => _gateway.initialize();

  /// Process a donation payment
  ///
  /// [amount] - Amount in display currency units
  /// [email] - Customer email
  /// [currency] - ISO currency code
  /// [reference] - Optional payment reference
  /// [metadata] - Optional additional data
  Future<PaymentResult> processDonation({
    required double amount,
    required String email,
    String currency = PaymentConfig.currencyCode,
    String? reference,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await _gateway.processDonation(
      PaymentRequest(
        amount: amount,
        email: email,
        currency: currency,
        reference: reference,
        metadata: metadata,
      ),
    );
    return PaymentResult.fromResponse(response);
  }

  /// Process recurring monthly donation
  Future<PaymentResult> processMonthlyDonation({
    required double amount,
    required String email,
    required String currency,
    String? reference,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await _gateway.processMonthlyDonation(
      PaymentRequest(
        amount: amount,
        email: email,
        currency: currency,
        reference: reference,
        isRecurringMonthly: true,
        metadata: metadata,
      ),
    );
    return PaymentResult.fromResponse(response);
  }

  /// Lists the signed-in donor's active recurring monthly subscriptions.
  Future<List<RecurringSubscription>> listMonthlySubscriptions({
    required String email,
  }) =>
      _gateway.listMonthlySubscriptions(email: email);

  /// Cancels a recurring monthly donation subscription.
  Future<PaymentResponse> cancelMonthlySubscription({
    required String email,
    String? subscriptionCode,
  }) =>
      _gateway.cancelMonthlySubscription(
        email: email,
        subscriptionCode: subscriptionCode,
      );
}

/// Result of a payment operation (legacy compatibility model).
class PaymentResult {
  final bool success;
  final String? reference;
  final String message;
  final bool initialized;

  PaymentResult({
    required this.success,
    this.reference,
    required this.message,
    this.initialized = false,
  });

  /// Translates domain [PaymentResponse] to [PaymentResult].
  factory PaymentResult.fromResponse(PaymentResponse response) {
    return PaymentResult(
      success: response.isSuccess,
      reference: response.reference,
      message: response.message,
      initialized: response.isRedirectInitialized,
    );
  }
}
