import sys

content_part3 = """

  /// Process a donation payment - web optimized using URL redirect
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

      // In development/test, simulate a successful payment
      if (!kReleaseMode) {
        _logger.info('Simulating payment success for reference: \$ref');
        return PaymentResult(
          success: true,
          reference: ref,
          message: 'Simulated payment successful (development mode)',
        );
      }

      // Convert to kobo/cents
      final amountInSmallestUnit = (amount * 100).round();

      final payload = {
        'action': 'initialize_transaction',
        'amount': amountInSmallestUnit,
        'currency': currency,
        'email': email,
        'reference': ref,
        if (metadata?['appwrite_user_id'] is String)
          'appwrite_user_id': metadata!['appwrite_user_id'],
        'callback_url': PaymentConfig.paystackCallbackUrl,
        'channels': PaymentConfig.paystackChannels,
        if (metadata != null) 'metadata': metadata,
      };

      final data = await _executePaystackFunction(payload);
      return _handlePaystackInitResponse(data: data, fallbackReference: ref);
    } catch (e) {
      _logger.error('Error processing payment: \$e');
      return PaymentResult(
        success: false,
        message: 'Error processing payment: \$e',
      );
    }
  }
"""

with open('lib/services/payment_service.dart', 'a', encoding='utf-8') as f:
    f.write(content_part3)

print("Part 3 written")