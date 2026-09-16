/// Paystack adapter implementation of [PaymentGateway].
///
/// This is the ONLY file in the entire project permitted to import
/// `package:paystack_flutter_sdk`. It isolates all Paystack SDK interactions,
/// web redirect handling, access code execution, and reference formatting.
library;

import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart' as appwrite_enums;
import 'package:flutter/foundation.dart';
import 'package:paystack_flutter_sdk/paystack_flutter_sdk.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/appwrite_backend_config.dart';
import '../../config/payment_config.dart';
import '../../main.dart';
import '../../models/payment_models.dart';
import '../../utils/logger.dart';
import '../ports/payment_gateway.dart';

/// Concrete [PaymentGateway] adapter for Paystack.
class PaystackPaymentGateway implements PaymentGateway {
  final Logger _logger = Logger('PaystackPaymentGateway');
  bool _initialized = false;

  PaystackPaymentGateway();

  @override
  Future<void> initialize() async {
    if (!_initialized) {
      _initialized = true;
      _logger.info('Paystack payment gateway initialized');
    }
  }

  @override
  String generateReference() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final rand = DateTime.now().microsecondsSinceEpoch % 1000000;
    final randStr = rand.toString().padLeft(6, '0');
    return kIsWeb
        ? 'ALIVE-WEB-APP-$timestamp-$randStr'
        : 'ALIVE-FLUTTER-$timestamp-$randStr';
  }

  @override
  Future<PaymentResponse> processDonation(PaymentRequest request) async {
    try {
      if (!_initialized) {
        await initialize();
      }

      final ref = request.reference ?? generateReference();

      // In development/test, simulate a successful payment to allow end-to-end testing
      if (!kReleaseMode) {
        _logger.info(
            'Simulating payment success in development for reference: $ref');
        return PaymentResponse.success(
          reference: ref,
          message: 'Simulated payment successful (development mode)',
        );
      }

      final payload = {
        'action': 'initialize_transaction',
        'amount': request.amountMinor,
        'currency': (request.metadata != null &&
                request.metadata!['currency'] is String)
            ? request.metadata!['currency']
            : request.currency,
        'email': request.email,
        'reference': ref,
        if (request.metadata?['appwrite_user_id'] is String)
          'appwrite_user_id': request.metadata!['appwrite_user_id'],
        'callback_url': PaymentConfig.paystackCallbackUrl,
        'channels': PaymentConfig.paystackChannels,
        if (request.metadata != null) 'metadata': request.metadata,
      };

      final data = await _executePaystackFunction(payload);
      return _handlePaystackInitResponse(data: data, fallbackReference: ref);
    } catch (e) {
      _logger.error('Error processing donation: $e');
      String msg = 'Could not initialize payment. Please try again.';
      final eStr = e.toString();
      if (eStr.toLowerCase().contains('currency not supported')) {
        msg = 'USD settlement is pending merchant activation on Paystack. Please switch to NGN (Naira) — international cards are accepted for NGN payments.';
      } else if (e is Exception) {
        msg = eStr.replaceFirst('Exception: ', '');
      } else if (eStr.contains('Bad state') || eStr.contains('No element')) {
        msg = 'Payment service unavailable or returned invalid state. Please try again.';
      }
      return PaymentResponse.failed(
        message: msg,
        reference: request.reference,
      );
    }
  }

  @override
  Future<PaymentResponse> processMonthlyDonation(PaymentRequest request) async {
    try {
      if (!_initialized) {
        await initialize();
      }

      final ref = request.reference ?? generateReference();
      final planCode =
          PaymentConfig.monthlyPlanCodeForCurrency(request.currency);
      if (planCode.trim().isEmpty) {
        return PaymentResponse.failed(
          reference: ref,
          message:
              'Monthly plan code is not configured. Set PAYSTACK_MONTHLY_PLAN_CODE_${request.currency.toUpperCase()}.',
        );
      }

      if (!kReleaseMode) {
        _logger.info(
            'Simulating recurring monthly payment in development for reference: $ref');
        return PaymentResponse.success(
          reference: ref,
          message: 'Simulated monthly donation successful (development mode)',
        );
      }

      final payload = {
        'action': 'initialize_subscription',
        'currency': request.currency,
        'email': request.email,
        'reference': ref,
        if (request.metadata?['appwrite_user_id'] is String)
          'appwrite_user_id': request.metadata!['appwrite_user_id'],
        'planCode': planCode,
        'callback_url': PaymentConfig.paystackCallbackUrl,
        'channels': PaymentConfig.paystackChannels,
        if (request.metadata != null) 'metadata': request.metadata,
      };

      final data = await _executePaystackFunction(payload);
      return _handlePaystackInitResponse(data: data, fallbackReference: ref);
    } catch (e) {
      _logger.error('Error processing monthly donation: $e');
      return PaymentResponse.failed(
        message: 'Error processing monthly donation: $e',
        reference: request.reference,
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

    final bodyStr = execution.responseBody.trim();
    if (bodyStr.isEmpty) {
      throw Exception('Payment service returned an empty response. Please check your connection and retry.');
    }

    final data = jsonDecode(bodyStr) as Map<String, dynamic>;
    if (data['error'] != null) {
      final err = data['error'].toString();
      if (err.toLowerCase().contains('currency not supported')) {
        throw Exception('USD settlement is pending merchant activation on Paystack. Please switch to NGN (Naira) — international cards are accepted for NGN payments.');
      }
      throw Exception(err);
    }
    return data;
  }

  Future<PaymentResponse> _handlePaystackInitResponse({
    required Map data,
    required String fallbackReference,
  }) async {
    final authUrl = (data['authorization_url'] ??
        (data['data'] != null ? data['data']['authorization_url'] : null)) as String?;
    final accessCode = (data['access_code'] ??
        (data['data'] != null ? data['data']['access_code'] : null)) as String?;
    final returnedRef = (data['reference'] ??
        (data['data'] != null ? data['data']['reference'] : null)) as String?;
    final useRef = returnedRef ?? fallbackReference;

    // Flutter Web: ALWAYS redirect to Paystack authorization_url.
    // paystack_flutter_sdk does not support Web.
    if (kIsWeb) {
      if (authUrl != null && authUrl.isNotEmpty) {
        try {
          final uri = Uri.parse(authUrl);
          final launched = await launchUrl(uri, webOnlyWindowName: '_self');
          if (launched) {
            return PaymentResponse.redirectInitialized(
              reference: useRef,
              message: 'Redirecting to Paystack checkout...',
              authorizationUrl: authUrl,
            );
          }
        } catch (e) {
          _logger.error('Failed to launch payment URL on web: $e');
        }
      }
      _logger.error('Web payment init failed: missing authorization_url');
      return PaymentResponse.failed(
        reference: useRef,
        message: 'Unable to open Paystack checkout on web',
      );
    }

    // Native Mobile (Android / iOS): Use paystack_flutter_sdk if access_code is available
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    if (isMobile && accessCode != null && accessCode.isNotEmpty) {
      try {
        final paystack = Paystack();
        final ok =
            await paystack.initialize(PaymentConfig.paystackPublicKey, true);
        if (ok) {
          final response = await paystack.launch(accessCode);
          if (response.status == 'success') {
            return PaymentResponse.success(
              reference: response.reference,
              message: response.message,
            );
          } else if (response.status == 'cancelled') {
            return PaymentResponse.cancelled(
              reference: useRef,
              message: response.message,
            );
          }
          return PaymentResponse.failed(
            reference: useRef,
            message: response.message,
          );
        } else {
          _logger.warning('Paystack SDK init failed, falling back to authUrl');
        }
      } catch (e) {
        _logger.warning('Paystack SDK launch error ($e), falling back to authUrl');
      }
    }

    // Mobile fallback or desktop: Launch external browser with authorization_url
    if (authUrl != null && authUrl.isNotEmpty) {
      try {
        final uri = Uri.parse(authUrl);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return PaymentResponse.redirectInitialized(
          reference: useRef,
          message: 'Payment initialized, complete checkout',
          authorizationUrl: authUrl,
        );
      } catch (e) {
        _logger.error('Failed to launch payment URL: $e');
        return PaymentResponse.failed(
          reference: useRef,
          message: 'Failed to open payment page',
        );
      }
    }

    _logger.error('Missing access_code and authorization_url from backend response');
    return PaymentResponse.failed(
      reference: useRef,
      message: 'Failed to initialize payment',
    );
  }
}
