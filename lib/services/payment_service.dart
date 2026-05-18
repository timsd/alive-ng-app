import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart' as appwrite_enums;
import 'package:paystack_flutter_sdk/paystack_flutter_sdk.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/appwrite_backend_config.dart';
import '../config/payment_config.dart';
import '../main.dart';
import '../utils/logger.dart';

/// Unified PaymentService for all platforms (mobile and web)
/// - Simulates payments in development for end-to-end testing
/// - In release, requires server-side initialization with Paystack access codes
class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  final Logger _logger = Logger('PaymentService');
  bool _initialized = false;

  // Singleton pattern
  factory PaymentService() {
    return _instance;
  }

  PaymentService._internal();

  /// Initialize the payment service
  Future<void> initialize() async {
    if (!_initialized) {
      // If integrating a client SDK (e.g., flutter_paystack), initialize here.
      _initialized = true;
      _logger.info('Payment service initialized');
    }
  }

  /// Process a donation payment
  ///
  /// [amount] - Amount in Naira (display currency: ${PaymentConfig.currencyCode})
  /// [email] - Customer email
  /// [context] - BuildContext for showing UI components
  /// [reference] - Optional payment reference
  /// [metadata] - Optional additional data
  Future<PaymentResult> processDonation({
    required double amount,
    required String email,
    String currency = PaymentConfig.currencyCode,
    String? reference,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      if (!_initialized) {
        await initialize();
      }

      final ref = reference ?? _getReference();

      // In development/test, simulate a successful payment to allow end-to-end testing
      if (!kReleaseMode) {
        _logger.info(
            'Simulating payment success in development for reference: $ref');
        return PaymentResult(
          success: true,
          reference: ref,
          message: 'Simulated payment successful (development mode)',
        );
      }

      final amountKobo = (amount * 100).round();
      final payload = {
        'action': 'initialize_transaction',
        'amount': amountKobo,
        'currency': (metadata != null && metadata['currency'] is String)
            ? metadata['currency']
            : currency,
        'email': email,
        'reference': ref,
        'callback_url': PaymentConfig.paystackCallbackUrl,
        'channels': PaymentConfig.paystackChannels,
        if (metadata != null) 'metadata': metadata,
      };
      final data = await _executePaystackFunction(payload);
      return _handlePaystackInitResponse(data: data, fallbackReference: ref);
    } catch (e) {
      _logger.error('Error processing payment: $e');
      return PaymentResult(
        success: false,
        message: 'Error processing payment: $e',
      );
    }
  }

  Future<PaymentResult> processMonthlyDonation({
    required String email,
    required String currency,
    String? reference,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      if (!_initialized) {
        await initialize();
      }

      final ref = reference ?? _getReference();
      final planCode = PaymentConfig.monthlyPlanCodeForCurrency(currency);
      if (planCode.trim().isEmpty) {
        return PaymentResult(
          success: false,
          reference: ref,
          message:
              'Monthly plan code is not configured. Set PAYSTACK_MONTHLY_PLAN_CODE_${currency.toUpperCase()}.',
        );
      }

      if (!kReleaseMode) {
        _logger.info(
            'Simulating recurring monthly payment in development for reference: $ref');
        return PaymentResult(
          success: true,
          reference: ref,
          message: 'Simulated monthly donation successful (development mode)',
        );
      }

      final payload = {
        'action': 'initialize_subscription',
        'currency': currency,
        'email': email,
        'reference': ref,
        'planCode': planCode,
        'callback_url': PaymentConfig.paystackCallbackUrl,
        'channels': PaymentConfig.paystackChannels,
        if (metadata != null) 'metadata': metadata,
      };
      final data = await _executePaystackFunction(payload);
      return _handlePaystackInitResponse(data: data, fallbackReference: ref);
    } catch (e) {
      _logger.error('Error processing monthly donation: $e');
      return PaymentResult(
        success: false,
        message: 'Error processing monthly donation: $e',
      );
    }
  }

  Future<Map<String, dynamic>> _executePaystackFunction(
    Map<String, dynamic> payload,
  ) async {
    final functions = Functions(appwriteClient);
    final execution = await functions.createExecution(
      functionId: AppwriteBackendConfig.paystackPaymentsFunctionId,
      body: jsonEncode(payload),
      xasync: false,
      method: appwrite_enums.ExecutionMethod.pOST,
    );

    final data = jsonDecode(execution.responseBody) as Map<String, dynamic>;
    if (data['error'] != null) {
      throw Exception(data['error']);
    }
    return data;
  }

  Future<PaymentResult> _handlePaystackInitResponse({
    required Map data,
    required String fallbackReference,
  }) async {
    final authUrl = (data['authorization_url'] ??
        (data['data'] != null ? (data['data']['authorization_url']) : null)) as String?;
    final accessCode = (data['access_code'] ??
        (data['data'] != null ? (data['data']['access_code']) : null)) as String?;
    final returnedRef = (data['reference'] ??
        (data['data'] != null ? (data['data']['reference']) : null)) as String?;
    final useRef = returnedRef ?? fallbackReference;

    if (accessCode != null && accessCode.isNotEmpty) {
      try {
        final paystack = Paystack();
        final ok =
            await paystack.initialize(PaymentConfig.paystackPublicKey, true);
        if (!ok) {
          _logger.error('Paystack SDK initialization failed');
          return PaymentResult(
            success: false,
            reference: useRef,
            message: 'Failed to initialize Paystack SDK',
          );
        }
        final response = await paystack.launch(accessCode);
        if (response.status == 'success') {
          return PaymentResult(
            success: true,
            reference: response.reference,
            message: response.message,
          );
        }
        return PaymentResult(
          success: false,
          reference: useRef,
          message: response.message,
        );
      } catch (e) {
        _logger.error('Paystack SDK launch error: $e');
        return PaymentResult(
          success: false,
          reference: useRef,
          message: 'Unable to open checkout',
        );
      }
    }

    if (authUrl != null && authUrl.isNotEmpty) {
      try {
        final uri = Uri.parse(authUrl);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return PaymentResult(
          success: false,
          reference: useRef,
          message: 'Payment initialized, complete checkout',
          initialized: true,
        );
      } catch (e) {
        _logger.error('Failed to launch payment URL: $e');
        return PaymentResult(
          success: false,
          reference: useRef,
          message: 'Failed to open payment page',
        );
      }
    }

    _logger.error('Missing access_code and authorization_url from backend response');
    return PaymentResult(
      success: false,
      reference: useRef,
      message: 'Failed to initialize payment',
    );
  }

  /// Generate a unique payment reference
  String _getReference() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'ALIVE-NG-DONATION-$timestamp';
  }
}

/// Result of a payment operation
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
}
