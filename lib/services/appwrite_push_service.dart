import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../utils/logger.dart';
import 'auth_service.dart';
import 'storage_service.dart';

class AppwritePushService {
  AppwritePushService._();
  static final AppwritePushService instance = AppwritePushService._();

  late final Account _account = Account(appwriteClient);
  late final TablesDB _tables = TablesDB(appwriteClient);
  late final Messaging _messaging = Messaging(appwriteClient);
  final Logger _logger = Logger('AppwritePushService');

  Future<String?> registerToken(String token) async {
    // On a cold start the cached user is still null while the session is
    // restored, so ask the server before concluding nobody is signed in.
    final user = AuthService.instance.currentUser ??
        await AuthService.instance.getCurrentUser();
    if (user == null) {
      _logger.warning('No authenticated user to register push token for');
      return null;
    }

    // Appwrite Messaging requires a real device token issued by the delivery
    // transport (the Appwrite push provider). Without one, creating a target
    // would register a broken identifier that can never receive a push, so we
    // skip registration and fall back to in-app (Realtime) notifications.
    if (token.trim().isEmpty) {
      _logger.warning(
        'No push token available; skipping Appwrite push target registration',
      );
      return null;
    }

    final targetId = _targetIdFor(user.uid, token);
    final providerId = AppwriteBackendConfig.fcmProviderId.trim();

    try {
      await _account.createPushTarget(
        targetId: targetId,
        identifier: token,
        providerId: providerId.isEmpty ? null : providerId,
      );
    } on AppwriteException catch (e) {
      if (e.code != 409) rethrow;
      await _account.updatePushTarget(targetId: targetId, identifier: token);
    }

    await _upsertPushTokenRecord(user.uid, token, targetId);
    await StorageService.instance.setString(StorageKeys.fcmToken, token);
    await StorageService.instance.setString(StorageKeys.appwritePushTargetId, targetId);

    await subscribeCurrentTarget('all_users', targetId: targetId);
    await subscribeAdminTopicsIfEligible(targetId: targetId);
    return targetId;
  }

  /// Automatically subscribes current user device to 'admins' and 'approvals' topics
  /// if they hold an administrator or super_admin role.
  Future<void> subscribeAdminTopicsIfEligible({String? targetId}) async {
    try {
      final user = AuthService.instance.currentUser ??
          await AuthService.instance.getCurrentUser();
      if (user == null) return;

      final isSuperAdmin = AppwriteBackendConfig.isSuperAdminEmail(user.email);
      bool isAdmin = isSuperAdmin;

      if (!isAdmin) {
        final profile = await AuthService.instance.getCurrentUserProfile();
        final role = profile?.role.toLowerCase().trim() ?? '';
        if (role == 'admin' || role == 'super_admin' || role == 'superadmin') {
          isAdmin = true;
        }
      }

      if (isAdmin) {
        _logger.info('User is admin/super_admin; subscribing target to admins and approvals topics');
        await subscribeCurrentTarget('admins', targetId: targetId);
        await subscribeCurrentTarget('approvals', targetId: targetId);
      }
    } catch (e) {
      _logger.warning('Failed to subscribe admin topics: $e');
    }
  }

  Future<void> subscribeCurrentTarget(
    String topicId, {
    String? targetId,
  }) async {
    final resolvedTargetId =
        targetId ?? await StorageService.instance.getString(StorageKeys.appwritePushTargetId);
    if (resolvedTargetId == null || resolvedTargetId.isEmpty) return;

    final subscriberId = _subscriberIdFor(topicId, resolvedTargetId);
    try {
      await _messaging.createSubscriber(
        topicId: topicId,
        subscriberId: subscriberId,
        targetId: resolvedTargetId,
      );
    } on AppwriteException catch (e) {
      // 409 = already subscribed. Anything else is logged, not rethrown: the
      // push target itself is already registered and can still be addressed
      // directly, so a topic failure must not undo the whole registration.
      if (e.code != 409) {
        _logger.warning('Could not subscribe target to topic $topicId: ${e.code} ${e.message}');
      }
    } catch (e) {
      _logger.warning('Could not subscribe target to topic $topicId: $e');
    }
  }

  Future<void> unsubscribeCurrentTarget(String topicId) async {
    final targetId =
        await StorageService.instance.getString(StorageKeys.appwritePushTargetId);
    if (targetId == null || targetId.isEmpty) return;

    final subscriberId = _subscriberIdFor(topicId, targetId);
    try {
      await _messaging.deleteSubscriber(
        topicId: topicId,
        subscriberId: subscriberId,
      );
    } on AppwriteException catch (e) {
      if (e.code != 404) rethrow;
    } catch (e) {
      _logger.warning('Could not unsubscribe target from topic $topicId: $e');
    }
  }

  Future<void> deleteCurrentTarget() async {
    final targetId =
        await StorageService.instance.getString(StorageKeys.appwritePushTargetId);
    if (targetId == null || targetId.isEmpty) return;

    try {
      await _account.deletePushTarget(targetId: targetId);
    } on AppwriteException catch (e) {
      if (e.code != 404) rethrow;
    }

    await StorageService.instance.remove(StorageKeys.fcmToken);
    await StorageService.instance.remove(StorageKeys.appwritePushTargetId);
  }

  Future<void> _upsertPushTokenRecord(
    String userId,
    String token,
    String targetId,
  ) async {
    final now = DateTime.now().toIso8601String();
    final data = {
      'user_id': userId,
      'token': token,
      'provider': 'fcm',
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'updated_at': now,
    };

    try {
      await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.pushTokensCollectionId,
        rowId: targetId,
        data: data,
      );
    } on AppwriteException catch (e) {
      if (e.code != 404) rethrow;
      await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.pushTokensCollectionId,
        rowId: targetId,
        data: {
          ...data,
          'created_at': now,
        },
      );
    }
  }

  String _targetIdFor(String userId, String token) {
    final digest = sha1.convert(utf8.encode('$userId:$token')).toString();
    return 'push_${digest.substring(0, 28)}';
  }

  String _subscriberIdFor(String topicId, String targetId) {
    final digest = sha1.convert(utf8.encode('$topicId:$targetId')).toString();
    return 'sub_${digest.substring(0, 28)}';
  }
}
