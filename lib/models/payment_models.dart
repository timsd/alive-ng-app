/// Domain models for the payment processing layer.
///
/// These models are SDK-agnostic: they MUST NOT import `package:paystack_flutter_sdk`
/// or any other third-party payment gateway SDK.
/// They form the innermost core of our Hexagonal Architecture for payments.
library;

/// Represents the status of a payment transaction.
enum PaymentStatus {
  /// Payment was authorized and confirmed successful.
  success,

  /// Payment failed or was rejected.
  failed,

  /// Payment was cancelled by the user.
  cancelled,

  /// Payment checkout was initialized and awaiting completion (e.g. via redirect or external checkout).
  processing,
}

/// Request parameters for initiating a donation or payment transaction.
class PaymentRequest {
  /// Payment amount in standard currency units (e.g. Naira, USD).
  final double amount;

  /// Customer / donor email address.
  final String email;

  /// ISO currency code (default: 'NGN').
  final String currency;

  /// Optional specific payment reference. If omitted, the gateway will generate one.
  final String? reference;

  /// Whether this is a recurring monthly subscription/donation.
  final bool isRecurringMonthly;

  /// Optional additional metadata attached to the transaction.
  final Map<String, dynamic>? metadata;

  const PaymentRequest({
    required this.amount,
    required this.email,
    this.currency = 'NGN',
    this.reference,
    this.isRecurringMonthly = false,
    this.metadata,
  });

  /// Amount in minor currency units (e.g. kobo or cents, amount * 100).
  int get amountMinor => (amount * 100).round();

  PaymentRequest copyWith({
    double? amount,
    String? email,
    String? currency,
    String? reference,
    bool? isRecurringMonthly,
    Map<String, dynamic>? metadata,
  }) {
    return PaymentRequest(
      amount: amount ?? this.amount,
      email: email ?? this.email,
      currency: currency ?? this.currency,
      reference: reference ?? this.reference,
      isRecurringMonthly: isRecurringMonthly ?? this.isRecurringMonthly,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() =>
      'PaymentRequest(amount: $amount, currency: $currency, email: $email, '
      'reference: $reference, recurring: $isRecurringMonthly)';
}

/// Represents a recurring monthly donation subscription on Paystack.
class RecurringSubscription {
  /// Paystack subscription identifier.
  final String subscriptionCode;

  /// Subscription status as reported by Paystack (e.g. `active`).
  final String status;

  /// Amount in minor units (kobo/cents).
  final int amountMinor;

  /// ISO currency code of the underlying plan.
  final String? currency;

  /// Human-readable plan name.
  final String? planName;

  /// Next scheduled charge date, when known.
  final DateTime? nextPaymentDate;

  const RecurringSubscription({
    required this.subscriptionCode,
    required this.status,
    required this.amountMinor,
    this.currency,
    this.planName,
    this.nextPaymentDate,
  });

  /// Amount in display units.
  double get amount => amountMinor / 100;

  factory RecurringSubscription.fromJson(Map<String, dynamic> json) {
    DateTime? next;
    final rawNext = json['next_payment_date'];
    if (rawNext is String && rawNext.isNotEmpty) {
      next = DateTime.tryParse(rawNext);
    }
    return RecurringSubscription(
      subscriptionCode: (json['subscription_code'] ?? '').toString(),
      status: (json['status'] ?? 'active').toString(),
      amountMinor: (json['amount'] as num?)?.round() ?? 0,
      currency: json['currency'] as String?,
      planName: json['plan'] as String?,
      nextPaymentDate: next,
    );
  }
}

/// Response returned by the payment gateway following processing or initialization.
class PaymentResponse {
  /// Status of the payment operation.
  final PaymentStatus status;

  /// Human-readable message describing the outcome.
  final String message;

  /// Unique payment reference for the transaction.
  final String? reference;

  /// Whether external redirect or checkout was launched (e.g. for web or external browser).
  final bool isRedirectInitialized;

  /// The payment authorization URL, if checkout was opened via URL.
  final String? authorizationUrl;

  const PaymentResponse({
    required this.status,
    required this.message,
    this.reference,
    this.isRedirectInitialized = false,
    this.authorizationUrl,
  });

  /// Convenience shorthand: returns true if [status] == [PaymentStatus.success].
  bool get isSuccess => status == PaymentStatus.success;

  /// Convenience shorthand: returns true if [status] == [PaymentStatus.processing]
  /// or [isRedirectInitialized] is true.
  bool get isProcessing =>
      status == PaymentStatus.processing || isRedirectInitialized;

  /// Convenience factory for a successful payment response.
  factory PaymentResponse.success({
    required String message,
    String? reference,
  }) {
    return PaymentResponse(
      status: PaymentStatus.success,
      message: message,
      reference: reference,
    );
  }

  /// Convenience factory for an initialized external redirect checkout.
  factory PaymentResponse.redirectInitialized({
    required String message,
    required String reference,
    String? authorizationUrl,
  }) {
    return PaymentResponse(
      status: PaymentStatus.processing,
      message: message,
      reference: reference,
      isRedirectInitialized: true,
      authorizationUrl: authorizationUrl,
    );
  }

  /// Convenience factory for a failed payment.
  factory PaymentResponse.failed({
    required String message,
    String? reference,
  }) {
    return PaymentResponse(
      status: PaymentStatus.failed,
      message: message,
      reference: reference,
    );
  }

  /// Convenience factory for a cancelled payment.
  factory PaymentResponse.cancelled({
    required String message,
    String? reference,
  }) {
    return PaymentResponse(
      status: PaymentStatus.cancelled,
      message: message,
      reference: reference,
    );
  }

  @override
  String toString() =>
      'PaymentResponse(status: $status, reference: $reference, '
      'isRedirectInitialized: $isRedirectInitialized, message: $message)';
}
