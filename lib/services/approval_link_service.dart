import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Generates and validates single-use approval tokens with expiry
class ApprovalLinkService {
  static final ApprovalLinkService instance = ApprovalLinkService._();
  ApprovalLinkService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'approval_tokens';

  Future<String> generateToken(
      {required String userId,
      Duration ttl = const Duration(hours: 24)}) async {
    final token = _randomToken();
    final now = DateTime.now();
    final expires = now.add(ttl);

    await _firestore.collection(_collection).doc(token).set({
      'userId': userId,
      'issuedAt': now.toIso8601String(),
      'expiresAt': expires.toIso8601String(),
      'used': false,
    });
    return token;
  }

  Future<bool> consumeTokenAndApprove(
      {required String userId, required String token}) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('consumeApprovalToken');
      final result = await callable.call({'userId': userId, 'token': token});
      final data = result.data;
      if (data is Map && data['ok'] == true) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  String buildApprovalUrl(
      {required String baseUrl,
      required String userId,
      required String token}) {
    return '$baseUrl/admin/approve?userId=$userId&token=$token';
  }

  String _randomToken({int length = 32}) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)])
        .join();
  }
}
