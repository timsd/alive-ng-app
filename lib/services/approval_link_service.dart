// ignore_for_file: deprecated_member_use

import 'dart:math';

import 'package:appwrite/appwrite.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import 'auth_service.dart';

/// Generates and validates single-use approval tokens with expiry
class ApprovalLinkService {
  static final ApprovalLinkService instance = ApprovalLinkService._();
  ApprovalLinkService._();

  final Databases _databases = Databases(appwriteClient);

  Future<String> generateToken({
    required String userId,
    Duration ttl = const Duration(hours: 24),
  }) async {
    final token = _randomToken();
    final now = DateTime.now();
    final expires = now.add(ttl);

    await _databases.createDocument(
      databaseId: AppwriteBackendConfig.databaseId,
      collectionId: AppwriteBackendConfig.approvalTokensCollectionId,
      documentId: token,
      data: {
        'token': token,
        'userId': userId,
        'user_id': userId,
        'expiresAt': expires.toIso8601String(),
        'expires_at': expires.toIso8601String(),
        'used': false,
        'createdAt': now.toIso8601String(),
        'created_at': now.toIso8601String(),
      },
    );
    return token;
  }

  Future<bool> consumeTokenAndApprove({
    required String userId,
    required String token,
  }) async {
    try {
      final doc = await _databases.getDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.approvalTokensCollectionId,
        documentId: token,
      );

      final data = doc.data;
      if (data['used'] == true || data['userId'] != userId) {
        return false;
      }

      final expiresAt = DateTime.tryParse('${data['expiresAt'] ?? ''}');
      if (expiresAt == null || DateTime.now().isAfter(expiresAt)) {
        return false;
      }

      final now = DateTime.now().toIso8601String();
      final approverId =
          AuthService.instance.currentUser?.uid ?? 'approval_link';

      await _databases.updateDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.usersCollectionId,
        documentId: userId,
        data: {
          'is_approved': true,
          'approval_status': 'approved',
          'approved_by': approverId,
          'approved_at': now,
          'updated_at': now,
        },
      );

      await _databases.updateDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.approvalTokensCollectionId,
        documentId: token,
        data: {
          'used': true,
          'usedAt': now,
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  String buildApprovalUrl({
    required String baseUrl,
    required String userId,
    required String token,
  }) {
    return '$baseUrl/admin-approve?userId=$userId&token=$token';
  }

  String _randomToken({int length = 32}) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)])
        .join();
  }
}
