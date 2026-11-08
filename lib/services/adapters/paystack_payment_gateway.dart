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
import 'package:http/http.dart' as http;
import 'package:paystack_flutter_sdk/paystack_flutter_sdk.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/appwrite_backend_config.dart';
import '../../config/payment_config.dart';
import '../../main.dart';
import '../../models/payment_models.dart';
import '../../utils/logger.dart';
import '../../utils/error_handler.dart';
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
      await PaymentConfig.loadCachedPublicKey();
      await PaymentConfig.syncPublicKeyFromAppwrite().catchError((e) {
        _logger.warning('Failed to sync Paystack public key from Appwrite: $e');
        return PaymentConfig.paystackPublicKey;
      });
      _logger.info(
          'Paystack payment gateway initialized (active key: ${PaymentConfig.paystackPublicKey})');
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

      // Optional simulation only when explicitly enabled via --dart-define=PAYSTACK_SIMULATE_PAYMENT=true
      const simulatePayment = bool.fromEnvironment(
        'PAYSTACK_SIMULATE_PAYMENT',
        defaultValue: false,
      );
      if (simulatePayment) {
        _logger.info(
            'Simulating payment success via PAYSTACK_SIMULATE_PAYMENT for reference: $ref');
        return PaymentResponse.success(
          reference: ref,
          message: 'Simulated payment successful (development mode)',
        );
      }

      final payload = {
        'action': 'initialize_transaction',
        'amount': request.amountMinor,
        // Currency priority: explicit metadata override (e.g. Paystack-only
        // NGN billing) -> request.currency -> NGN default. Never let a null /
        // non-string currency leak into the function payload, which would make
        // the server reject the init and the APK show "not working".
        'currency': (() {
          final metaCur = request.metadata?['currency'];
          if (metaCur is String && metaCur.trim().isNotEmpty) {
            return metaCur.trim().toUpperCase();
          }
          final reqCur = request.currency;
          if (reqCur.trim().isNotEmpty) return reqCur.trim().toUpperCase();
          return 'NGN';
        })(),
        'email': request.email,
        'reference': ref,
        if (request.metadata?['appwrite_user_id'] is String)
          'appwrite_user_id': request.metadata!['appwrite_user_id'],
        'callback_url': PaymentConfig.paystackCallbackUrl,
        // Only sent when explicitly configured. Paystack rejects the whole
        // initialization if any listed channel is unavailable, and the working
        // web page omits this field entirely.
        if (PaymentConfig.paystackChannels != null)
          'channels': PaymentConfig.paystackChannels,
        if (request.metadata != null) 'metadata': request.metadata,
      };

      final data = await _executePaystackFunction(payload);
      return await _handlePaystackInitResponse(data: data, fallbackReference: ref);
    } catch (e) {
      _logger.error('Error processing donation: $e');
      final msg = ErrorHandler.getUserFriendlyMessage(
        e,
        'Could not initialize payment. Please check your internet connection and try again.',
      );
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

      const simulatePayment = bool.fromEnvironment(
        'PAYSTACK_SIMULATE_PAYMENT',
        defaultValue: false,
      );
      if (simulatePayment) {
        _logger.info(
            'Simulating recurring monthly payment via PAYSTACK_SIMULATE_PAYMENT for reference: $ref');
        return PaymentResponse.success(
          reference: ref,
          message: 'Simulated monthly donation successful (development mode)',
        );
      }

      // The server always creates a dynamic plan for the donor's chosen
      // amount — there are no pre-configured monthly plans to send.
      final payload = {
        'action': 'initialize_subscription',
        'currency': request.currency,
        'amount': request.amountMinor,
        'email': request.email,
        'reference': ref,
        if (request.metadata?['appwrite_user_id'] is String)
          'appwrite_user_id': request.metadata!['appwrite_user_id'],
        'callback_url': PaymentConfig.paystackCallbackUrl,
        // Same rule as one-time donations: omit unless explicitly configured,
        // otherwise Paystack rejects the whole initialization.
        if (PaymentConfig.paystackChannels != null)
          'channels': PaymentConfig.paystackChannels,
        if (request.metadata != null) 'metadata': request.metadata,
      };

      final data = await _executePaystackFunction(payload);
      return await _handlePaystackInitResponse(data: data, fallbackReference: ref);
    } catch (e) {
      _logger.error('Error processing monthly donation: $e');
      final msg = ErrorHandler.getUserFriendlyMessage(
        e,
        'Could not initialize monthly donation. Please check your internet connection and try again.',
      );
      return PaymentResponse.failed(
        message: msg,
        reference: request.reference,
      );
    }
  }

  @override
  Future<List<RecurringSubscription>> listMonthlySubscriptions({
    required String email,
  }) async {
    final data = await _executePaystackFunction({
      'action': 'list_subscriptions',
      'email': email,
    });
    final raw = data['subscriptions'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => RecurringSubscription.fromJson(
            Map<String, dynamic>.from(item)))
        .toList();
  }

  @override
  Future<PaymentResponse> cancelMonthlySubscription({
    required String email,
    String? subscriptionCode,
  }) async {
    try {
      if (!_initialized) {
        await initialize();
      }

      final data = await _executePaystackFunction({
        'action': 'cancel_subscription',
        'email': email,
        if (subscriptionCode != null && subscriptionCode.isNotEmpty)
          'subscription_code': subscriptionCode,
      });

      final cancelled = data['cancelled'] == true;
      final message = (data['message'] ?? 'Subscription updated.').toString();
      if (cancelled) {
        return PaymentResponse.success(
          reference: (data['subscription_code'] as String?),
          message: message,
        );
      }
      return PaymentResponse.failed(message: message);
    } catch (e) {
      _logger.error('Error cancelling monthly subscription: $e');
      final message = ErrorHandler.getUserFriendlyMessage(
        e,
        'Could not cancel monthly donation. Please try again.',
      );
      return PaymentResponse.failed(message: message);
    }
  }

  Future<Map<String, dynamic>> _executePaystackFunction(
    Map<String, dynamic> payload,
  ) async {
    final bodyJson = jsonEncode(payload);

    // 1. First attempt via Appwrite Functions SDK
    try {
      final functions = Functions(appwriteClient);
      final execution = await functions.createExecution(
        functionId: AppwriteBackendConfig.paystackPaymentsFunctionId,
        body: bodyJson,
        xasync: false,
        method: appwrite_enums.ExecutionMethod.pOST,
      );

      final bodyStr = execution.responseBody.trim();
      if (bodyStr.isNotEmpty) {
        final decoded = jsonDecode(bodyStr);
        if (decoded is Map<String, dynamic>) {
          if (decoded['error'] != null) {
            final err = decoded['error'].toString();
            if (err.toLowerCase().contains('currency not supported')) {
              throw Exception(
                'USD payment could not be processed with current settings. Please try NGN or contact support.',
              );
            }
            throw Exception(err);
          }
          return decoded;
        }
      }
    } catch (sdkErr) {
      _logger.warning(
        'Appwrite SDK createExecution note: $sdkErr. Falling back to direct HTTP execution...',
      );
      if (sdkErr is Exception &&
          sdkErr.toString().contains('currency not supported')) {
        rethrow;
      }
    }

    // 2. Direct HTTP execution fallback (works across Flutter Web and Mobile,
    // avoiding Appwrite SDK Execution.fromMap deserialization enum crashes on self-hosted instances)
    try {
      final uri = Uri.parse(
        '${appwriteClient.endPoint}/functions/${AppwriteBackendConfig.paystackPaymentsFunctionId}/executions',
      );
      final headers = <String, String>{
        'X-Appwrite-Project': AppwriteBackendConfig.projectId,
        'Content-Type': 'application/json',
      };
      try {
        final jwt = await Account(appwriteClient).createJWT();
        headers['X-Appwrite-JWT'] = jwt.jwt;
      } catch (_) {}

      final client = http.Client();
      try {
        final response = await client.post(
          uri,
          headers: headers,
          body: jsonEncode({
            'body': bodyJson,
            'async': false,
            'method': 'POST',
          }),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final execMap = jsonDecode(response.body);
          if (execMap is Map<String, dynamic>) {
            final respBody = execMap['responseBody']?.toString() ??
                execMap['response']?.toString() ??
                '';
            if (respBody.trim().isNotEmpty) {
              final decodedBody = jsonDecode(respBody);
              if (decodedBody is Map<String, dynamic>) {
                if (decodedBody['error'] != null) {
                  final err = decodedBody['error'].toString();
                  if (err.toLowerCase().contains('currency not supported')) {
                    throw Exception(
                      'USD payment could not be processed with current settings. Please try NGN or contact support.',
                    );
                  }
                  throw Exception(err);
                }
                return decodedBody;
              }
            }
          }
        } else {
          final errorMap = jsonDecode(response.body);
          if (errorMap is Map<String, dynamic> && errorMap['message'] != null) {
            throw Exception(errorMap['message']);
          }
        }
      } finally {
        client.close();
      }
    } catch (httpErr) {
      _logger.error('Direct HTTP payment function note: $httpErr');
      if (httpErr is Exception && !httpErr.toString().contains('No element')) {
        rethrow;
      }
    }

    throw Exception(
      'Payment service temporarily unavailable. Please try again or contact support.',
    );
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
    final returnedPk = (data['public_key'] ??
        (data['data'] != null ? data['data']['public_key'] : null)) as String?;
    final useRef = returnedRef ?? fallbackReference;

    if (returnedPk != null && returnedPk.trim().isNotEmpty) {
      PaymentConfig.setDynamicPublicKey(returnedPk.trim());
    }

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
        final effectivePk = (returnedPk != null && returnedPk.trim().isNotEmpty)
            ? returnedPk.trim()
            : PaymentConfig.paystackPublicKey;
        final ok =
            await paystack.initialize(effectivePk, true);
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
          _logger.warning('Paystack SDK returned non-success (${response.status}: ${response.message}), falling back to authUrl');
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
