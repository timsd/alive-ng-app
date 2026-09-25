/// Abstract port interface for payment processing.
///
/// Defines contracts for one-time donation payments, recurring monthly
/// subscriptions, and reference generation without coupling callers to any
/// third-party SDK (such as `paystack_flutter_sdk`).
///
/// ```text
///   DonationService / UI  ──▶  PaymentGateway (port)  ◀──  PaystackPaymentGateway (adapter)
/// ```
library;

import '../../models/payment_models.dart';

/// Abstract payment gateway contract.
abstract class PaymentGateway {
  /// Initializes any underlying SDK resources if necessary.
  Future<void> initialize();

  /// Processes a one-off donation payment.
  Future<PaymentResponse> processDonation(PaymentRequest request);

  /// Processes a recurring monthly donation or subscription.
  Future<PaymentResponse> processMonthlyDonation(PaymentRequest request);

  /// Lists the donor's active recurring monthly donation subscriptions.
  Future<List<RecurringSubscription>> listMonthlySubscriptions({
    required String email,
  });

  /// Cancels a recurring monthly donation subscription.
  ///
  /// Pass the Paystack [subscriptionCode] when known; when omitted and the
  /// donor owns exactly one active subscription, that one is cancelled.
  Future<PaymentResponse> cancelMonthlySubscription({
    required String email,
    String? subscriptionCode,
  });

  /// Generates a standardized payment reference string:
  /// - Web: `ALIVE-WEB-APP-<timestamp>-<rand>`
  /// - Native Mobile: `ALIVE-FLUTTER-<timestamp>-<rand>`
  String generateReference();
}
