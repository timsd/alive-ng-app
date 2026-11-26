import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../config/appwrite_backend_config.dart';
import 'appwrite_client.dart';
import '../utils/logger.dart';
import 'auth_service.dart';
import 'storage_service.dart';

class AppwritePushService {
  AppwritePushService._();
  static final AppwritePushService instance = AppwritePushService._();

  late final Account _account = Account(appwriteClient);
  late final TablesDB _tables = TablesDB(appwriteClient);
  late final Messaging _messaging = Messaging(appwriteClient);
  late final Functions _functions = Functions(appwriteClient);
  final Logger _logger = Logger('AppwritePushService');

  // Hybrid Push fallback: native Appwrite Push (MQTT) for non-GMS / Huawei devices
  // where Firebase Cloud Messaging (FCM) is unavailable.
  Push? _nativePush;
  final List<PushSubscription> _nativePushSubs = <PushSubscription>[];
  void Function()? _stopNativeOpenedListener;
  String? _activeNativePushUserId;
  bool _initialNativePushChecked = false;

  bool get isNativeAppwritePushActive => _nativePushSubs.isNotEmpty;

  /// Checks whether the app was launched from a terminated state by tapping
  /// a native Appwrite Push background notification (non-GMS fallback).
  Future<void> checkInitialNativePushNotification(
    void Function(Map<String, dynamic> data) onOpened,
  ) async {
    if (kIsWeb || _initialNativePushChecked) return;
    _initialNativePushChecked = true;
    try {
      final push = _nativePush ??= Push(appwriteClient);
      final initial = await push.getInitialNotification();
      if (initial != null) {
        _logger.info(
          'Launched from native Appwrite Push notification on topic: ${initial.topic}',
        );
        onOpened(Map<String, dynamic>.from(initial.data));
      }
    } catch (e) {
      _logger.warning('Could not read initial native Appwrite Push notification: $e');
    }
  }

  /// Activates built-in Appwrite Push (MQTT over TLS) as an automatic fallback
  /// when FCM is unavailable (e.g. non-GMS Android / Huawei devices).
  Future<bool> activateNativeAppwritePushFallback({
    String? userId,
    String? userEmail,
    required void Function(Map<String, dynamic> data) onNotificationOpened,
    required Future<void> Function(
      String title,
      String body,
      Map<String, dynamic> data,
    ) onForegroundMessage,
  }) async {
    if (kIsWeb) return false;

    String? resolvedUserId =
        userId?.trim().isNotEmpty == true ? userId!.trim() : null;
    String? resolvedEmail =
        userEmail?.trim().isNotEmpty == true ? userEmail!.trim() : null;

    if (resolvedUserId == null || resolvedEmail == null) {
      try {
        final sdkUser = await _account.get();
        resolvedUserId ??= sdkUser.$id;
        resolvedEmail ??= sdkUser.email;
      } catch (_) {
        final cached = AuthService.instance.currentUser;
        resolvedUserId ??= cached?.uid;
        resolvedEmail ??= cached?.email;
      }
    }

    // Native Appwrite Push authenticates via the user's Appwrite session.
    if (resolvedUserId == null || resolvedUserId.isEmpty) {
      _logger.info(
        'FCM unavailable and user is not signed in yet; native Appwrite Push fallback will activate after sign-in.',
      );
      return false;
    }

    if (_activeNativePushUserId == resolvedUserId && _nativePushSubs.isNotEmpty) {
      return true;
    }

    closeNativeAppwritePushFallback();

    try {
      final clientId =
          'alive_${sha1.convert(utf8.encode('$resolvedUserId:${defaultTargetPlatform.name}')).toString().substring(0, 20)}';
      appwriteClient.setPushClientId(clientId);

      final push = _nativePush ??= Push(appwriteClient);
      push
        ..onOpen(() => _logger.info('Native Appwrite Push (MQTT) connected'))
        ..onClose(() => _logger.info('Native Appwrite Push (MQTT) disconnected'))
        ..onError((err) => _logger.warning('Native Appwrite Push notice: $err'));

      _stopNativeOpenedListener = push.onNotificationOpened((opened) {
        _logger.info('Native Appwrite Push tapped: topic=${opened.topic}');
        onNotificationOpened(Map<String, dynamic>.from(opened.data));
      });

      void handleIncoming(PushMessage message) {
        try {
          final raw = message.data.trim();
          String title = 'ALIVE Nigeria';
          String body = raw;
          Map<String, dynamic> data = <String, dynamic>{};
          if (raw.startsWith('{')) {
            final decoded = jsonDecode(raw);
            if (decoded is Map) {
              final map = Map<String, dynamic>.from(decoded);
              title = (map['title'] ?? title).toString();
              body = (map['body'] ?? '').toString();
              final nested = map['data'];
              if (nested is Map) {
                data = Map<String, dynamic>.from(nested);
              } else {
                data = map;
              }
            }
          }
          onForegroundMessage(title, body, data);
        } catch (e) {
          _logger.warning('Failed to parse native Appwrite Push payload: $e');
        }
      }

      // 1. Subscribe to signed-in user's reserved `users/<userId>` topic
      //    (delivers prayer support, monthly reminders, direct user pushes).
      final userSub = await push.subscribe(
        null,
        handleIncoming,
        background: true,
        title: 'ALIVE Nigeria',
        retry: true,
      );
      _nativePushSubs.add(userSub);

      // 2. Subscribe to ministry-wide `all_users` broadcast topic (plus admin topics if eligible).
      final extraTopics = <String>['all_users'];
      bool isAdmin = AppwriteBackendConfig.isSuperAdminEmail(resolvedEmail ?? '');
      if (!isAdmin) {
        try {
          final profile = await AuthService.instance.getCurrentUserProfile();
          final role = profile?.role.toLowerCase().trim() ?? '';
          if (role == 'admin' || role == 'super_admin') {
            isAdmin = true;
          }
        } catch (_) {}
      }
      if (isAdmin) {
        extraTopics.addAll(const ['admins', 'approvals']);
      }

      try {
        final topicSub = await push.subscribe(
          extraTopics,
          handleIncoming,
          background: true,
          title: 'ALIVE Nigeria',
          retry: true,
        );
        _nativePushSubs.add(topicSub);
      } catch (e) {
        _logger.warning('Native Appwrite Push topic subscription notice: $e');
      }

      _activeNativePushUserId = resolvedUserId;
      _logger.info(
        'Hybrid Push fallback active via native Appwrite Push for user $resolvedUserId (topics: users/$resolvedUserId, ${extraTopics.join(", ")})',
      );

      // Best-effort observability log in push_tokens
      try {
        await _upsertPushTokenRecord(
          resolvedUserId,
          'mqtt:$clientId',
          'mqtt_${sha1.convert(utf8.encode(resolvedUserId)).toString().substring(0, 26)}',
          provider: 'appwrite_push',
        );
      } catch (_) {}

      return true;
    } catch (e) {
      _logger.warning('Native Appwrite Push fallback could not connect: $e');
      closeNativeAppwritePushFallback();
      return false;
    }
  }

  /// Tears down any active native Appwrite Push (MQTT) session and stops
  /// Android background delivery (called on sign-out or when FCM succeeds).
  void closeNativeAppwritePushFallback() {
    try {
      _stopNativeOpenedListener?.call();
    } catch (_) {}
    _stopNativeOpenedListener = null;

    for (final sub in _nativePushSubs) {
      try {
        sub.unsubscribe();
      } catch (_) {}
    }
    _nativePushSubs.clear();

    try {
      _nativePush?.close();
    } catch (_) {}
    _nativePush = null;
    _activeNativePushUserId = null;
  }

  Future<String?> registerToken(
    String token, {
    String? userId,
    String? userEmail,
  }) async {
    // Appwrite Messaging requires a real device token issued by the delivery
    // transport (the Appwrite push provider). Without one, creating a target
    // would register a broken identifier that can never receive a push.
    final trimmedToken = token.trim();
    if (trimmedToken.isEmpty) {
      _logger.warning(
        'No push token available; skipping Appwrite push target registration',
      );
      return null;
    }

    // Resolve the currently signed-in Appwrite session directly via Account
    // first so sessions established by AppwriteAuthGateway (which does not go
    // through AuthService.instance) are always recognized immediately.
    String? resolvedUserId = userId?.trim().isNotEmpty == true ? userId!.trim() : null;
    String? resolvedEmail = userEmail?.trim().isNotEmpty == true ? userEmail!.trim() : null;

    if (resolvedUserId == null || resolvedEmail == null) {
      try {
        final sdkUser = await _account.get();
        resolvedUserId ??= sdkUser.$id;
        resolvedEmail ??= sdkUser.email;
      } catch (_) {
        final cached = AuthService.instance.currentUser;
        resolvedUserId ??= cached?.uid;
        resolvedEmail ??= cached?.email;
      }
    }

    // Fresh mobile installs / Guest users (before login) still auto-register
    // via the server-managed guest_push_devices bucket so every device receives
    // `all_users` broadcasts immediately after downloading and installing.
    if (resolvedUserId == null || resolvedUserId.isEmpty) {
      _logger.info(
        'No signed-in user yet; registering mobile device token as guest push target',
      );
      return registerGuestDeviceToken(trimmedToken);
    }

    final targetId = _targetIdFor(resolvedUserId, trimmedToken);
    final providerId = AppwriteBackendConfig.fcmProviderId.trim();

    try {
      await _account.createPushTarget(
        targetId: targetId,
        identifier: trimmedToken,
        providerId: providerId.isEmpty ? null : providerId,
      );
    } on AppwriteException catch (e) {
      if (e.code != 409) rethrow;
      await _account.updatePushTarget(
        targetId: targetId,
        identifier: trimmedToken,
      );
    }

    await StorageService.instance.setString(StorageKeys.fcmToken, trimmedToken);
    await StorageService.instance.setString(StorageKeys.appwritePushTargetId, targetId);

    // Subscribe to `all_users` FIRST so a transient DB write failure on
    // `push_tokens` can never prevent the device from receiving broadcasts.
    await subscribeCurrentTarget('all_users', targetId: targetId);
    await subscribeAdminTopicsIfEligible(
      targetId: targetId,
      userId: resolvedUserId,
      userEmail: resolvedEmail,
    );

    try {
      await _upsertPushTokenRecord(resolvedUserId, trimmedToken, targetId);
    } catch (e) {
      _logger.warning('Could not record push token row (target still subscribed): $e');
    }

    // If this device previously registered as a guest before the user signed in,
    // remove the guest target so the device never receives duplicate pushes.
    await unregisterGuestDeviceIfPresent(token: trimmedToken);
    return targetId;
  }

  /// Auto-registers an unauthenticated / newly installed mobile device into the
  /// Appwrite `all_users` topic via the `send_push` function so users receive
  /// broadcasts immediately after installing the app (even in Guest mode).
  Future<String?> registerGuestDeviceToken(String token) async {
    final trimmedToken = token.trim();
    if (trimmedToken.isEmpty || kIsWeb) return null;

    try {
      final execution = await _functions.createExecution(
        functionId: AppwriteBackendConfig.sendPushFunctionId,
        body: jsonEncode({
          'action': 'register_guest_device',
          'token': trimmedToken,
          'platform': defaultTargetPlatform.name,
        }),
        xasync: false,
      );

      final raw = execution.responseBody.trim();
      final decoded = raw.isNotEmpty
          ? Map<String, dynamic>.from(jsonDecode(raw) as Map)
          : <String, dynamic>{};

      if (execution.responseStatusCode >= 400 || decoded['error'] != null) {
        _logger.warning(
          'Guest push device registration failed (${execution.responseStatusCode}): '
          '${decoded['error'] ?? raw}',
        );
        return null;
      }

      final guestTargetId = decoded['targetId']?.toString() ?? '';
      if (guestTargetId.isNotEmpty) {
        await StorageService.instance.setString(StorageKeys.fcmToken, trimmedToken);
        await StorageService.instance.setString(
          StorageKeys.guestPushTargetId,
          guestTargetId,
        );
        _logger.info('Guest mobile device auto-registered for push: $guestTargetId');
        return guestTargetId;
      }
      return null;
    } catch (e) {
      _logger.warning('Guest push device registration error: $e');
      return null;
    }
  }

  /// Removes a prior guest push target once the user signs into a real account.
  Future<void> unregisterGuestDeviceIfPresent({String? token}) async {
    if (kIsWeb) return;
    try {
      final guestTargetId = await StorageService.instance
          .getString(StorageKeys.guestPushTargetId);
      final trimmedToken = (token ?? '').trim();
      if ((guestTargetId == null || guestTargetId.isEmpty) &&
          trimmedToken.isEmpty) {
        return;
      }

      await _functions.createExecution(
        functionId: AppwriteBackendConfig.sendPushFunctionId,
        body: jsonEncode({
          'action': 'unregister_guest_device',
          if (guestTargetId != null && guestTargetId.isNotEmpty)
            'targetId': guestTargetId,
          if (trimmedToken.isNotEmpty) 'token': trimmedToken,
        }),
        xasync: false,
      );
      await StorageService.instance.remove(StorageKeys.guestPushTargetId);
    } catch (e) {
      _logger.warning('Could not clean up prior guest push target: $e');
    }
  }

  /// Automatically subscribes current user device to 'admins' and 'approvals' topics
  /// if they hold an administrator or super_admin role.
  Future<void> subscribeAdminTopicsIfEligible({
    String? targetId,
    String? userId,
    String? userEmail,
  }) async {
    try {
      String? resolvedUserId = userId;
      String? resolvedEmail = userEmail;
      if (resolvedUserId == null || resolvedEmail == null) {
        try {
          final sdkUser = await _account.get();
          resolvedUserId ??= sdkUser.$id;
          resolvedEmail ??= sdkUser.email;
        } catch (_) {
          final user = AuthService.instance.currentUser ??
              await AuthService.instance.getCurrentUser();
          resolvedUserId ??= user?.uid;
          resolvedEmail ??= user?.email;
        }
      }
      if (resolvedUserId == null || resolvedUserId.isEmpty) return;

      final isSuperAdmin =
          AppwriteBackendConfig.isSuperAdminEmail(resolvedEmail ?? '');
      bool isAdmin = isSuperAdmin;

      if (!isAdmin) {
        final profile = await AuthService.instance.getCurrentUserProfile();
        final role = profile?.role.toLowerCase().trim() ?? '';
        if (role == 'admin' || role == 'super_admin') {
          isAdmin = true;
        }
      }

      if (isAdmin) {
        _logger.info(
          'User is admin/super_admin; subscribing target to admins and approvals topics',
        );
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

  /// Dispatches an admin push broadcast via the `send_push` Appwrite function.
  Future<Map<String, dynamic>> sendPushBroadcast({
    required String title,
    required String body,
    List<String> topics = const ['all_users'],
    String? route,
    String type = 'announcement',
    String priority = 'high',
  }) async {
    final execution = await _functions.createExecution(
      functionId: AppwriteBackendConfig.sendPushFunctionId,
      body: jsonEncode({
        'title': title,
        'body': body,
        'topics': topics,
        if (route != null && route.trim().isNotEmpty) 'route': route.trim(),
        'type': type,
        'priority': priority,
      }),
      xasync: false,
    );

    final raw = execution.responseBody.trim();
    final decoded = raw.isNotEmpty
        ? Map<String, dynamic>.from(jsonDecode(raw) as Map)
        : <String, dynamic>{};

    if (execution.responseStatusCode >= 400 || decoded['error'] != null) {
      throw Exception(
        decoded['error']?.toString() ??
            'Push broadcast failed (status ${execution.responseStatusCode})',
      );
    }
    return decoded;
  }

  /// Sends a targeted push notification to the author of a prayer request when
  /// another member prays for their request.
  Future<void> sendPrayerSupportPush({
    required String requestId,
    required String ownerUserId,
    required String requestTitle,
    String? intercessorName,
    int? prayerCount,
  }) async {
    final trimmedOwner = ownerUserId.trim();
    final trimmedReqId = requestId.trim();
    if (trimmedOwner.isEmpty || trimmedReqId.isEmpty) return;

    final actor = (intercessorName?.trim().isNotEmpty == true)
        ? intercessorName!.trim()
        : 'A fellow believer';
    final safeTitle =
        requestTitle.trim().isNotEmpty ? requestTitle.trim() : 'your prayer request';
    final count = prayerCount ?? 1;
    final route = '/prayer-wall?prayerId=${Uri.encodeComponent(trimmedReqId)}';
    final pushTitle = '🙏 Someone Prayed for Your Request';
    final pushBody = count > 1
        ? '$actor just prayed for "$safeTitle" ($count prayers lifted).'
        : '$actor just prayed for your request: "$safeTitle".';

    try {
      await _functions.createExecution(
        functionId: AppwriteBackendConfig.sendPushFunctionId,
        body: jsonEncode({
          'action': 'notify_prayer_support',
          'requestId': trimmedReqId,
          'intercessorName': actor,
          // Fallback fields if the deployed function handles direct user array pushes:
          'title': pushTitle,
          'body': pushBody,
          'users': [trimmedOwner],
          'topics': <String>[],
          'type': 'prayer_request',
          'route': route,
          'data': {
            'type': 'prayer_request',
            'id': trimmedReqId,
            'route': route,
          },
          'priority': 'high',
        }),
        xasync: true,
      );
      _logger.info(
        'Dispatched prayer support push notification for request $trimmedReqId to owner $trimmedOwner',
      );
    } catch (e) {
      _logger.warning('Could not dispatch prayer support push notification: $e');
    }
  }

  Future<void> _upsertPushTokenRecord(
    String userId,
    String token,
    String targetId, {
    String provider = 'fcm',
  }) async {
    final now = DateTime.now().toIso8601String();
    final data = {
      'user_id': userId,
      'token': token,
      'provider': provider,
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
