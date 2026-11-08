import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart' as appwrite_enums;
import 'package:http/http.dart' as http;

import '../../config/appwrite_backend_config.dart';
import '../../constants/app_constants.dart';
import '../../main.dart';
import '../../services/donation_service.dart';
import '../../utils/error_handler.dart';
import '../../widgets/custom_app_bar.dart';

class PaymentCallbackScreen extends StatefulWidget {
  final String? reference;

  const PaymentCallbackScreen({
    super.key,
    this.reference,
  });

  @override
  State<PaymentCallbackScreen> createState() => _PaymentCallbackScreenState();
}

class _PaymentCallbackScreenState extends State<PaymentCallbackScreen> {
  bool _isVerifying = true;
  bool _isSuccess = false;
  String _message = 'Verifying your payment with Paystack...';
  String? _materialTitle;
  bool _isTractDonation = false;

  @override
  void initState() {
    super.initState();
    _verifyAndRoute();
  }

  Future<void> _verifyAndRoute() async {
    final ref = widget.reference?.trim();
    if (ref == null || ref.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _isSuccess = false;
        _message = 'No payment reference received.';
      });
      return;
    }

    try {
      Map<String, dynamic>? resultPayload;

      // 1. First attempt via Appwrite Functions SDK
      try {
        final functions = Functions(appwriteClient);
        final execution = await functions.createExecution(
          functionId: AppwriteBackendConfig.paystackPaymentsFunctionId,
          body: jsonEncode({
            'action': 'verify_transaction',
            'reference': ref,
          }),
          xasync: false,
          method: appwrite_enums.ExecutionMethod.pOST,
        );

        final bodyStr = execution.responseBody.trim();
        if (bodyStr.isNotEmpty) {
          final decoded = jsonDecode(bodyStr);
          if (decoded is Map<String, dynamic>) {
            resultPayload = decoded;
          }
        }
      } catch (_) {
        // Fallback to direct HTTP
      }

      // 2. HTTP Fallback
      if (resultPayload == null) {
        try {
          final uri = Uri.parse(
            '${appwriteClient.endPoint}/functions/${AppwriteBackendConfig.paystackPaymentsFunctionId}/executions',
          );
          final client = http.Client();
          try {
            final response = await client.post(
              uri,
              headers: {
                'X-Appwrite-Project': AppwriteBackendConfig.projectId,
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'body': jsonEncode({
                  'action': 'verify_transaction',
                  'reference': ref,
                }),
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
                  resultPayload = jsonDecode(respBody) as Map<String, dynamic>?;
                }
              }
            }
          } finally {
            client.close();
          }
        } catch (_) {}
      }

      final isSuccessful = resultPayload != null &&
          (resultPayload['status'] == 'success' ||
              resultPayload['status'] == true ||
              resultPayload['success'] == true ||
              resultPayload['data']?['status'] == 'success');

      final dataMap = (resultPayload?['data'] is Map<String, dynamic>)
          ? resultPayload!['data'] as Map<String, dynamic>
          : (resultPayload?['data'] is Map
              ? Map<String, dynamic>.from(resultPayload!['data'] as Map)
              : <String, dynamic>{});

      dynamic rawMeta = resultPayload?['metadata'] ?? dataMap['metadata'];
      Map<String, dynamic> metadata = {};
      if (rawMeta is Map) {
        metadata = Map<String, dynamic>.from(rawMeta);
      } else if (rawMeta is String && rawMeta.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(rawMeta);
          if (decoded is Map) metadata = Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }

      final donationType = (metadata['donation_type'] ??
              metadata['category'] ??
              dataMap['donation_type'])
          ?.toString() ??
          '';
      String? materialId = (metadata['material_id'] ??
              metadata['materialId'] ??
              dataMap['material_id'])
          ?.toString();
      String? materialTitle = (metadata['material_title'] ??
              metadata['materialTitle'] ??
              dataMap['material_title'])
          ?.toString();

      bool isTract = donationType.toLowerCase().contains('tract') ||
          (materialId != null && materialId.isNotEmpty);

      // Robust fallback: if metadata wasn't populated in the webhook/gateway response,
      // look up the donation record by reference directly from Appwrite!
      if (ref.isNotEmpty) {
        try {
          final donation = await DonationService().getDonation(ref);
          if (donation != null) {
            if (donation.type == DonationType.tractProduction ||
                (donation.materialId != null && donation.materialId!.isNotEmpty)) {
              isTract = true;
              materialId ??= donation.materialId;
              materialTitle ??= donation.materialTitle;
            }
          }
        } catch (_) {}
      }

      if (isSuccessful && isTract && materialId != null) {
        try {
          await DonationService().recordDownload(
            materialId,
            materialTitle ?? 'Gospel Tract',
          );
        } catch (_) {}
      }

      if (!mounted) return;

      setState(() {
        _isVerifying = false;
        _isSuccess = isSuccessful;
        _isTractDonation = isTract;
        _materialTitle = materialTitle;
        if (isSuccessful) {
          _message = isTract
              ? 'Thank you! Your tract is now available in your Downloaded area.'
              : 'Thank you for your generous support! Your payment has been verified.';
        } else {
          _message = resultPayload?['message']?.toString() ??
              'Payment could not be verified automatically.';
        }
      });

      // Automatically navigate after a brief confirmation
      if (isSuccessful) {
        await Future.delayed(const Duration(milliseconds: 1400));
        if (!mounted) return;
        if (isTract) {
          context.go('/tracts?tab=downloaded');
        } else {
          context.go(AppConstants.donationRoute);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _isSuccess = false;
        _message = ErrorHandler.getUserFriendlyMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Payment Status',
        showBackButton: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isVerifying) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  _message,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ] else if (_isSuccess) ...[
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Payment Successful!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                if (_materialTitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _materialTitle!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  _message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: () {
                    if (_isTractDonation) {
                      context.go('/tracts?tab=downloaded');
                    } else {
                      context.go(AppConstants.homeRoute);
                    }
                  },
                  icon: Icon(_isTractDonation
                      ? Icons.download_done_rounded
                      : Icons.home),
                  label: Text(_isTractDonation
                      ? 'Go to Downloaded Tracts'
                      : 'Return to Home'),
                ),
              ] else ...[
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.orange,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Verification Notice',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _message,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => context.go(AppConstants.homeRoute),
                      child: const Text('Go Home'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => context.go('/tracts?tab=downloaded'),
                      child: const Text('View Saved Tracts'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

