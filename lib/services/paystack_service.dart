
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Mock classes to replace flutter_paystack until dependency conflicts are resolved
class PaystackPlugin {
  Future<void> initialize({required String publicKey}) async {
    // Mock implementation
  }
  
  Future<PaymentResponse> checkout(
    BuildContext context, {
    required CheckoutMethod method,
    required PaymentCharge charge,
  }) async {
    // Mock implementation - always return success for development
    return PaymentResponse(
      status: true,
      reference: charge.reference,
      message: 'Payment successful (mock)',
    );
  }
}

class PaymentCharge {
  int amount = 0;
  String reference = '';
  String email = '';
  String currency = 'NGN';
  Map<String, String> customFields = {};
  
  void putCustomField(String key, String value) {
    customFields[key] = value;
  }
}

class PaymentResponse {
  final bool status;
  final String? reference;
  final String? message;
  
  PaymentResponse({
    required this.status,
    this.reference,
    this.message,
  });
}

enum CheckoutMethod { card, bank, ussd }

class PaystackService {
  static const String _publicKey =
      'pk_test_your_paystack_public_key'; // Replace with actual key
  static final PaystackPlugin _paystack = PaystackPlugin();
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Initialize Paystack
  static Future<void> initialize() async {
    try {
      await _paystack.initialize(publicKey: _publicKey);
      debugPrint('Paystack initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Paystack: $e');
    }
  }

  // Make payment
  static Future<PaymentResult?> makePayment({
    required BuildContext context,
    required String email,
    required double amount,
    required String purpose,
    String currency = 'NGN',
    String? reference,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final charge = PaymentCharge()
        ..amount = (amount * 100).toInt() // Convert to kobo
        ..reference = reference ?? _generateReference()
        ..email = email
        ..currency = currency
        ..putCustomField('purpose', purpose);

      // Add metadata if provided
      if (metadata != null) {
        metadata.forEach((key, value) {
          charge.putCustomField(key, value.toString());
        });
      }

      final response = await _paystack.checkout(
        context,
        method: CheckoutMethod.card,
        charge: charge,
      );

      if (response.status) {
        // Payment successful, save to database
        await _saveTransaction(
          reference: charge.reference,
          amount: amount,
          email: email,
          purpose: purpose,
          status: 'success',
          paystackResponse: response.reference,
          metadata: metadata,
        );

        return PaymentResult(
          success: true,
          reference: charge.reference,
          message: response.message ?? 'Payment successful',
          transactionId: response.reference,
        );
      } else {
        // Payment failed
        await _saveTransaction(
          reference: charge.reference,
          amount: amount,
          email: email,
          purpose: purpose,
          status: 'failed',
          paystackResponse: response.reference,
          metadata: metadata,
          errorMessage: response.message,
        );

        return PaymentResult(
          success: false,
          reference: charge.reference,
          message: response.message ?? 'Payment failed',
          transactionId: response.reference,
        );
      }
    } catch (e) {
      debugPrint('Error making payment: $e');
      return PaymentResult(
        success: false,
        reference: reference ?? 'unknown',
        message: 'Payment error: $e',
      );
    }
  }

  // Make donation
  static Future<PaymentResult?> makeDonation({
    required BuildContext context,
    required String email,
    required double amount,
    String? donorName,
    String? message,
    bool isAnonymous = false,
  }) async {
    final metadata = {
      'donor_name': donorName ?? 'Anonymous',
      'message': message ?? '',
      'is_anonymous': isAnonymous.toString(),
      'donation_type': 'general',
    };

    return await makePayment(
      context: context,
      email: email,
      amount: amount,
      purpose: 'donation',
      metadata: metadata,
    );
  }

  // Verify payment
  static Future<bool> verifyPayment(String reference) async {
    try {
      // This would typically be done server-side
      // Call Supabase Edge Function to verify payment
      final response = await _supabase.functions.invoke(
        'verify-payment',
        body: {'reference': reference},
      );

      final data = response.data;
      if (data != null && data['status'] == 'success') {
        // Update transaction status in database
        await _updateTransactionStatus(reference, 'verified');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error verifying payment: $e');
      return false;
    }
  }

  // Get transaction history
  static Future<List<Transaction>> getTransactionHistory(String userId) async {
    try {
      final response = await _supabase
          .from('transactions')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Transaction.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching transaction history: $e');
      return [];
    }
  }

  // Get donation statistics
  static Future<DonationStats> getDonationStats(String userId) async {
    try {
      final response = await _supabase
          .from('transactions')
          .select('amount, purpose, created_at')
          .eq('user_id', userId)
          .eq('status', 'success');

      final transactions = response as List;

      double totalDonations = 0;
      int transactionCount = transactions.length;

      for (final transaction in transactions) {
        final amount = (transaction['amount'] as num).toDouble();
        final purpose = transaction['purpose'] as String;

        switch (purpose) {
          case 'donation':
            totalDonations += amount;
            break;
        }
      }

      return DonationStats(
        totalDonations: totalDonations,
        totalAmount: totalDonations,
        transactionCount: transactionCount,
      );
    } catch (e) {
      debugPrint('Error fetching donation stats: $e');
      return DonationStats(
        totalDonations: 0,
        totalAmount: 0,
        transactionCount: 0,
      );
    }
  }

  // Generate unique reference
  static String _generateReference() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999).toString().padLeft(6, '0');
    return 'ALIVE_${timestamp}_$random';
  }

  // Save transaction to database
  static Future<void> _saveTransaction({
    required String reference,
    required double amount,
    required String email,
    required String purpose,
    required String status,
    String? paystackResponse,
    Map<String, dynamic>? metadata,
    String? errorMessage,
  }) async {
    try {
      final user = _supabase.auth.currentUser;

      await _supabase.from('transactions').insert({
        'reference': reference,
        'user_id': user?.id,
        'email': email,
        'amount': amount,
        'purpose': purpose,
        'status': status,
        'paystack_response': paystackResponse,
        'metadata': metadata,
        'error_message': errorMessage,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving transaction: $e');
    }
  }

  // Update transaction status
  static Future<void> _updateTransactionStatus(
      String reference, String status) async {
    try {
      await _supabase.from('transactions').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('reference', reference);
    } catch (e) {
      debugPrint('Error updating transaction status: $e');
    }
  }
}

// Payment result model
class PaymentResult {
  final bool success;
  final String reference;
  final String message;
  final String? transactionId;

  PaymentResult({
    required this.success,
    required this.reference,
    required this.message,
    this.transactionId,
  });
}

// Transaction model
class Transaction {
  final String id;
  final String reference;
  final String? userId;
  final String email;
  final double amount;
  final String purpose;
  final String status;
  final String? paystackResponse;
  final Map<String, dynamic>? metadata;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Transaction({
    required this.id,
    required this.reference,
    this.userId,
    required this.email,
    required this.amount,
    required this.purpose,
    required this.status,
    this.paystackResponse,
    this.metadata,
    this.errorMessage,
    required this.createdAt,
    this.updatedAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      reference: json['reference'] as String,
      userId: json['user_id'] as String?,
      email: json['email'] as String,
      amount: (json['amount'] as num).toDouble(),
      purpose: json['purpose'] as String,
      status: json['status'] as String,
      paystackResponse: json['paystack_response'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      errorMessage: json['error_message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reference': reference,
      'user_id': userId,
      'email': email,
      'amount': amount,
      'purpose': purpose,
      'status': status,
      'paystack_response': paystackResponse,
      'metadata': metadata,
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

// Donation statistics model
class DonationStats {
  final double totalDonations;
  final double totalAmount;
  final int transactionCount;

  DonationStats({
    required this.totalDonations,
    required this.totalAmount,
    required this.transactionCount,
  });
}
