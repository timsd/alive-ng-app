import 'dart:math';

import 'package:appwrite/appwrite.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import 'appwrite_profile_service.dart';
import 'auth_service.dart';
import 'role_access_service.dart';

enum ApprovalLinkStatus {
  approved,
  authRequired,
  forbidden,
  invalidOrExpired,
}

class ApprovalLinkResult {
  final ApprovalLinkStatus status;
  final String message;

  const ApprovalLinkResult({
    required this.status,
    required this.message,
  });

  bool get isApproved => status == ApprovalLinkStatus.approved;
}

/// Generates and validates single-use approval tokens with expiry
class ApprovalLinkService {
  static final ApprovalLinkService instance = ApprovalLinkService._();
  ApprovalLinkService._();

  final TablesDB _tables = TablesDB(appwriteClient);

  Future<String> generateToken({
    required String userId,
    Duration ttl = const Duration(hours: 24),
  }) async {
    final token = _randomToken();
    final now = DateTime.now();
    final expires = now.add(ttl);

    await _tables.createRow(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: AppwriteBackendConfig.approvalTokensCollectionId,
      rowId: token,
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

  Future<ApprovalLinkResult> consumeTokenAndApproveDetailed({
    required String userId,
    required String token,
  }) async {
    final currentUser = AuthService.instance.currentUser ??
        await AuthService.instance.getCurrentUser();
    if (currentUser == null || currentUser.uid.isEmpty) {
      return const ApprovalLinkResult(
        status: ApprovalLinkStatus.authRequired,
        message:
            'Please sign in with an Administrator account to complete this approval.',
      );
    }

    if (!RoleAccessService.instance.canAccessAdmin()) {
      try {
        final profile = await AuthService.instance.getCurrentUserProfile();
        if (profile != null) {
          RoleAccessService.instance.notifyRoleChanged(profile);
        }
      } catch (_) {}
      if (!RoleAccessService.instance.canAccessAdmin()) {
        return const ApprovalLinkResult(
          status: ApprovalLinkStatus.forbidden,
          message:
              'Administrator access is required to approve member accounts.',
        );
      }
    }

    try {
      final row = await _tables.getRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.approvalTokensCollectionId,
        rowId: token,
      );

      final data = row.data;
      if (data['used'] == true || data['userId'] != userId) {
        return const ApprovalLinkResult(
          status: ApprovalLinkStatus.invalidOrExpired,
          message: 'Approval link is invalid, expired, or already used.',
        );
      }

      final expiresAt = DateTime.tryParse('${data['expiresAt'] ?? ''}');
      if (expiresAt == null || DateTime.now().isAfter(expiresAt)) {
        return const ApprovalLinkResult(
          status: ApprovalLinkStatus.invalidOrExpired,
          message: 'This approval link has expired.',
        );
      }

      final now = DateTime.now().toIso8601String();
      await AppwriteProfileService().approveUserAndChapter(
        userId: userId,
        approverUserId: currentUser.uid,
      );

      await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.approvalTokensCollectionId,
        rowId: token,
        data: {
          'used': true,
          'usedAt': now,
        },
      );

      return const ApprovalLinkResult(
        status: ApprovalLinkStatus.approved,
        message: 'User approved successfully.',
      );
    } on AppwriteException catch (e) {
      if (e.code == 401) {
        return const ApprovalLinkResult(
          status: ApprovalLinkStatus.authRequired,
          message:
              'Please sign in with an Administrator account to complete this approval.',
        );
      }
      if (e.code == 403) {
        return const ApprovalLinkResult(
          status: ApprovalLinkStatus.forbidden,
          message:
              'Administrator access is required to approve member accounts.',
        );
      }
      return const ApprovalLinkResult(
        status: ApprovalLinkStatus.invalidOrExpired,
        message: 'Approval link is invalid, expired, or already used.',
      );
    } catch (_) {
      return const ApprovalLinkResult(
        status: ApprovalLinkStatus.invalidOrExpired,
        message: 'Approval link is invalid, expired, or already used.',
      );
    }
  }

  Future<bool> consumeTokenAndApprove({
    required String userId,
    required String token,
  }) async {
    final res = await consumeTokenAndApproveDetailed(
      userId: userId,
      token: token,
    );
    return res.isApproved;
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
