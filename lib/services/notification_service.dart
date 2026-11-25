import 'dart:convert';

import 'package:appwrite/appwrite.dart' hide Locale;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:go_router/go_router.dart';
import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../utils/logger.dart';
import '../utils/app_exception.dart';
import '../utils/navigation_keys.dart';
import 'auth_service.dart';
import 'appwrite_push_service.dart';
import 'storage_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handled automatically by system notification tray when notification payload exists
}

class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance =>
      _instance ??= NotificationService._();

  NotificationService._();

  late final AuthService _authService = AuthService.instance;
  final Logger _logger = Logger('NotificationService');
  late final TablesDB _tables = TablesDB(appwriteClient);

  // Local notifications plugin (shared with ReminderService so tap handlers
  // are never overwritten by a second plugin instance)
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  FlutterLocalNotificationsPlugin get localNotificationsPlugin =>
      _localNotifications;

  // Global navigator key for navigation from background contexts
  static GlobalKey<NavigatorState> get navigatorKey => rootNavigatorKey;

  static bool _tzInitialized = false;

  /// Initializes the timezone database and configures [tz.local] to match the
  /// device's current UTC offset so daily [zonedSchedule] reminders fire at the
  /// exact local wall-clock time chosen by the user.
  static void configureLocalTimeZone() {
    if (!_tzInitialized) {
      tz.initializeTimeZones();
      _tzInitialized = true;
    }
    try {
      final now = DateTime.now();
      final targetOffset = now.timeZoneOffset;
      // Prefer Africa/Lagos for WAT (UTC+1) since ALIVE Nigeria is based in Nigeria
      if (targetOffset == const Duration(hours: 1)) {
        tz.setLocalLocation(tz.getLocation('Africa/Lagos'));
        return;
      }
      for (final loc in tz.timeZoneDatabase.locations.values) {
        if (loc.currentTimeZone.offset == targetOffset) {
          tz.setLocalLocation(loc);
          return;
        }
      }
    } catch (_) {
      // Keep default tz.local if lookup fails
    }
  }

  bool _isInitialized = false;
  bool _fcmListenersAttached = false;
  bool _isRegisteringPush = false;
  bool _splashCompleted = false;
  bool _initialFcmMessageChecked = false;
  String? _currentToken;
  String? _lastRegisteredKey;
  String? _pendingNotificationRoute;

  /// Consumes any notification deep-link route captured during cold start
  /// (before splash finished) and marks splash handoff complete so subsequent
  /// notification taps navigate immediately.
  String? consumePendingNotificationRoute() {
    _splashCompleted = true;
    final route = _pendingNotificationRoute;
    _pendingNotificationRoute = null;
    return route;
  }

  /// Marks splash handoff complete and immediately dispatches any notification
  /// route that arrived right before splash finished.
  void markSplashCompleted() {
    _splashCompleted = true;
    final route = _pendingNotificationRoute;
    if (route != null && route.isNotEmpty) {
      _pendingNotificationRoute = null;
      _navigateToResolvedRoute(route);
    }
  }

  // Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      configureLocalTimeZone();

      // Initialize local notifications
      const androidSettings =
          AndroidInitializationSettings('ic_notification');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      await _localNotifications.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Capture cold-start launch from a local/scheduled notification BEFORE
      // any slow network/permission work so splash hands off to the exact route.
      if (!kIsWeb) {
        try {
          final launchDetails =
              await _localNotifications.getNotificationAppLaunchDetails();
          if (launchDetails?.didNotificationLaunchApp == true) {
            final launchResponse = launchDetails?.notificationResponse;
            if (launchResponse != null) {
              _onNotificationTapped(launchResponse);
            }
          }
        } catch (e) {
          _logger.warning('Could not read local notification launch details: $e');
        }

        // Capture cold-start native Appwrite Push launch (non-GMS fallback)
        await AppwritePushService.instance.checkInitialNativePushNotification(
          handleMessageOpenedApp,
        );

        // Capture cold-start FCM launch IMMEDIATELY (independent of token/network)
        // and attach onMessageOpenedApp listener right away.
        try {
          if (await _ensureFirebaseReady()) {
            final fcm = FirebaseMessaging.instance;
            _attachFcmListenersOnce(fcm);
            if (!_initialFcmMessageChecked) {
              _initialFcmMessageChecked = true;
              final initialMessage = await fcm.getInitialMessage();
              if (initialMessage != null) {
                _logger.info(
                  'Launched from terminated state by push notification: ${initialMessage.messageId}',
                );
                handleMessageOpenedApp(initialMessage.data);
              }
            }
          }
        } catch (e) {
          _logger.warning('Could not inspect initial FCM message: $e');
        }
      }

      // Listen for auth state changes BEFORE the (slow) permission/token steps.
      // Note: AppwriteAuthGateway also calls onAuthUserChanged() directly so
      // login/signup/OAuth via Riverpod always registers the push target too.
      _authService.authStateChanges.listen((user) async {
        await onAuthUserChanged(user);
      });

      // Ensure Android notification channels (sound & silent) exist with high importance
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              'alive_ng_notifications',
              'ALIVE Nigeria Notifications',
              description: 'Ministry updates, broadcasts, and ALIVE Meet alerts',
              importance: Importance.high,
              playSound: true,
            ),
          );
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              'alive_ng_notifications_silent',
              'ALIVE Nigeria Notifications (Silent)',
              description: 'Muted ministry updates and broadcasts',
              importance: Importance.high,
              playSound: false,
            ),
          );
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              'reminder_channel',
              'Reminders',
              description: 'Daily reminders for ALIVE Nigeria app',
              importance: Importance.high,
              playSound: true,
            ),
          );
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              'reminder_channel_silent',
              'Reminders (Silent)',
              description: 'Muted daily reminders for ALIVE Nigeria app',
              importance: Importance.high,
              playSound: false,
            ),
          );
        }
      }

      // Auto-register push immediately on download/install (both guest & signed-in)
      await ensurePushRegistered(requestPermission: true);

      _isInitialized = true;
    } catch (e) {
      _logger.error('Failed to initialize notifications', e);
    }
  }

  /// Called whenever authentication state changes (from AppwriteAuthGateway or
  /// AuthService) so newly signed-up / signed-in mobile users immediately link
  /// their device push target to their Appwrite account & `all_users` topic.
  Future<void> onAuthUserChanged(AppUser? user) async {
    if (kIsWeb) return;
    try {
      if (user != null) {
        _logger.info(
          'Auth user active (${user.uid}); syncing mobile push registration',
        );
        await ensurePushRegistered(
          userId: user.uid,
          userEmail: user.email,
          force: true,
        );
        try {
          final profile = await _authService.getCurrentUserProfile();
          await updateAdminTopicSubscriptions(profile?.role);
        } catch (e) {
          _logger.warning('Could not resolve user profile for admin topics: $e');
        }
      } else {
        AppwritePushService.instance.closeNativeAppwritePushFallback();
        await updateAdminTopicSubscriptions(null);
        // Keep device reachable for `all_users` broadcasts even after sign-out.
        await ensurePushRegistered(force: true);
      }
    } catch (e) {
      _logger.warning('onAuthUserChanged push sync error: $e');
    }
  }

  /// Idempotently ensures this mobile device has an FCM token registered with
  /// Appwrite Messaging (`all_users` topic). Safe to call on launch, login, and
  /// `AppLifecycleState.resumed` — retries automatically if an earlier attempt
  /// failed due to offline startup, delayed APNs token, or newly granted permission.
  Future<String?> ensurePushRegistered({
    String? userId,
    String? userEmail,
    bool requestPermission = false,
    bool force = false,
  }) async {
    if (kIsWeb) {
      return _registerWebPushToken();
    }
    if (_isRegisteringPush && !force) return null;
    _isRegisteringPush = true;
    try {
      return await _registerPushToken(
        userId: userId,
        userEmail: userEmail,
        requestPermission: requestPermission,
        force: force,
      );
    } finally {
      _isRegisteringPush = false;
    }
  }

  // --- Push token registration (Appwrite via FCM transport) ---

  Future<String?> registerPushToken() =>
      ensurePushRegistered(requestPermission: true, force: true);

  /// Registers [token] with Appwrite and logs (rather than drops) any failure.
  Future<String?> _safeRegister(
    String token, {
    String? userId,
    String? userEmail,
  }) async {
    try {
      return await AppwritePushService.instance.registerToken(
        token,
        userId: userId,
        userEmail: userEmail,
      );
    } catch (e) {
      _logger.error('Appwrite push target registration failed', e);
      return null;
    }
  }

  void _attachFcmListenersOnce(FirebaseMessaging fcm) {
    if (_fcmListenersAttached) return;
    _fcmListenersAttached = true;

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Listen for token refreshes
    fcm.onTokenRefresh.listen((newToken) async {
      _logger.info('FCM token refreshed');
      _currentToken = newToken;
      _lastRegisteredKey = null;
      final targetId = await _safeRegister(newToken);
      if (targetId != null) {
        _lastRegisteredKey = '${_authService.currentUser?.uid ?? 'guest'}:$newToken';
      }
      try {
        await fcm.subscribeToTopic('all_users');
      } catch (_) {}
    });

    // Listen for foreground FCM messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      _logger.info('Foreground FCM message received: ${message.messageId}');
      final notification = message.notification;
      final data = message.data;
      final title =
          notification?.title ?? (data['title'] as String?) ?? 'ALIVE Nigeria';
      final body = notification?.body ?? (data['body'] as String?) ?? '';
      bool playSound = true;
      try {
        final saved = await StorageHelper.getNotificationSettings();
        if (saved != null && saved['sound_enabled'] is bool) {
          playSound = saved['sound_enabled'] as bool;
        }
      } catch (_) {}
      await showNotification(
        id: message.hashCode,
        title: title,
        body: body,
        payload: jsonEncode(data),
        playSound: playSound,
      );
    });

    // Listen for notification open events from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _logger.info('Notification tapped in background: ${message.messageId}');
      handleMessageOpenedApp(message.data);
    });
  }

  Future<bool> _ensureFirebaseReady() async {
    if (kIsWeb) return false;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      return Firebase.apps.isNotEmpty;
    } catch (e) {
      _logger.warning('Firebase unavailable (e.g. non-GMS device): $e');
      return false;
    }
  }

  Future<String?> _activateAppwritePushFallback({
    String? userId,
    String? userEmail,
  }) async {
    final ok = await AppwritePushService.instance.activateNativeAppwritePushFallback(
      userId: userId,
      userEmail: userEmail,
      onNotificationOpened: handleMessageOpenedApp,
      onForegroundMessage: (title, body, data) async {
        bool playSound = true;
        try {
          final saved = await StorageHelper.getNotificationSettings();
          if (saved != null && saved['sound_enabled'] is bool) {
            playSound = saved['sound_enabled'] as bool;
          }
        } catch (_) {}
        await showNotification(
          id: Object.hash(title, body, data['id'] ?? data['route']),
          title: title,
          body: body,
          payload: jsonEncode(data),
          playSound: playSound,
        );
      },
    );
    return ok ? 'appwrite_push' : null;
  }

  Future<String?> _registerPushToken({
    String? userId,
    String? userEmail,
    bool requestPermission = false,
    bool force = false,
  }) async {
    if (kIsWeb) {
      return _registerWebPushToken();
    }

    if (!await _ensureFirebaseReady()) {
      _logger.info(
        'FCM unavailable on this device; falling back to built-in Appwrite Push',
      );
      return _activateAppwritePushFallback(
        userId: userId,
        userEmail: userEmail,
      );
    }

    try {
      final fcm = FirebaseMessaging.instance;
      _attachFcmListenersOnce(fcm);

      // Ensure cold-start FCM message is also checked if initialize() ran
      // before Firebase finished booting.
      if (!_initialFcmMessageChecked) {
        _initialFcmMessageChecked = true;
        try {
          final initialMessage = await fcm.getInitialMessage();
          if (initialMessage != null) {
            _logger.info(
              'Launched from terminated state by push notification: ${initialMessage.messageId}',
            );
            handleMessageOpenedApp(initialMessage.data);
          }
        } catch (_) {}
      }

      // Request notification permissions cleanly once via FCM (handles iOS + Android 13+)
      if (requestPermission) {
        final notifSettings = await fcm.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        _logger.info(
          'FCM authorization status: ${notifSettings.authorizationStatus}',
        );
      }

      // On iOS, APNs token may take a moment after first install
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        String? apnsToken = await fcm.getAPNSToken();
        for (int attempt = 0; attempt < 3 && apnsToken == null; attempt++) {
          await Future<void>.delayed(const Duration(seconds: 1));
          apnsToken = await fcm.getAPNSToken();
        }
        _logger.info(
          'APNs token status: ${apnsToken != null ? "obtained" : "pending"}',
        );
      }

      String? token = _currentToken;
      if (token == null || token.isEmpty || force) {
        token = await fcm.getToken();
      }
      if (token != null && token.isNotEmpty) {
        // GMS FCM succeeded — ensure MQTT fallback is closed so this device
        // never receives duplicate pushes.
        AppwritePushService.instance.closeNativeAppwritePushFallback();
        _currentToken = token;
        _logger.info(
          'FCM token acquired: ${token.substring(0, token.length > 8 ? 8 : token.length)}...',
        );

        final registrationScope = userId ?? _authService.currentUser?.uid ?? 'guest';
        final registrationKey = '$registrationScope:$token';

        String? targetId;
        if (force || _lastRegisteredKey != registrationKey) {
          targetId = await _safeRegister(
            token,
            userId: userId,
            userEmail: userEmail,
          );
          if (targetId != null) {
            _lastRegisteredKey = registrationKey;
          }
          try {
            await fcm.subscribeToTopic('all_users');
          } catch (_) {}
        }

        return targetId;
      } else {
        _logger.warning(
          'FCM getToken returned null or empty; falling back to built-in Appwrite Push',
        );
        return await _activateAppwritePushFallback(
          userId: userId,
          userEmail: userEmail,
        );
      }
    } catch (e) {
      _logger.warning(
        'FCM push registration failed ($e); falling back to built-in Appwrite Push',
      );
      return _activateAppwritePushFallback(
        userId: userId,
        userEmail: userEmail,
      );
    }
  }

  /// Automatically subscribes or unsubscribes the current device to the
  /// 'admins' and 'approvals' FCM topics based on the authenticated user's role.
  Future<void> updateAdminTopicSubscriptions(String? role) async {
    if (kIsWeb) return;
    if (!await _ensureFirebaseReady()) return;
    try {
      final fcm = FirebaseMessaging.instance;
      final normalizedRole = (role ?? '').trim().toLowerCase();
      final isAdmin = normalizedRole == 'admin' ||
          normalizedRole == 'super_admin' ||
          normalizedRole == 'coordinator';

      if (isAdmin) {
        _logger.info('Subscribing admin user ($normalizedRole) to topics: admins, approvals');
        await fcm.subscribeToTopic('admins');
        await fcm.subscribeToTopic('approvals');
      } else {
        await fcm.unsubscribeFromTopic('admins');
        await fcm.unsubscribeFromTopic('approvals');
      }
    } catch (e) {
      _logger.warning('Failed to update admin topic subscriptions: $e');
    }
  }

  // --- Web push (browser): not supported ---
  //
  // Push is native-only. A browser would need a Firebase *Web app*, a VAPID key
  // and a registered service worker to mint a token, and none were ever
  // provisioned, so no browser could hold a real push target.
  //
  // Rather than leave a toggle that silently does nothing, this logs the reason
  // once. Reminder toggles still work in the browser -- they are handled by
  // flutter_local_notifications while the page is open, which is local, not push.
  Future<String?> _registerWebPushToken() async {
    _logger.info(
      'Push is native-only; this browser build uses in-page local notifications. '
      'Server-originated push arrives in the Android/iOS app.',
    );
    return null;
  }

  // --- Foreground / background message handling (Appwrite push payloads) ---

  void handleForegroundMessage(Map<String, dynamic> data) {
    _logger.info('Received foreground push: ${data.keys.toList()}');
    final title = data['title'] as String? ?? 'ALIVE Nigeria';
    final body = data['body'] as String? ?? '';
    showNotification(
      id: data.hashCode,
      title: title,
      body: body,
      payload: jsonEncode(data),
    );
  }

  // Show a local notification immediately
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = 'alive_ng_notifications',
    bool playSound = true,
  }) async {
    if (kIsWeb) return;
    if (!_isInitialized) {
      await initialize();
    }
    final effectiveChannelId = playSound ? channelId : '${channelId}_silent';
    final effectiveChannelName = playSound
        ? 'ALIVE Nigeria Notifications'
        : 'ALIVE Nigeria Notifications (Silent)';

    NotificationDetails buildDetails({required bool includeLargeIcon}) {
      final androidDetails = AndroidNotificationDetails(
        effectiveChannelId,
        effectiveChannelName,
        channelDescription: 'Ministry updates, broadcasts, and ALIVE Meet alerts',
        icon: 'ic_notification',
        largeIcon: includeLargeIcon
            ? const DrawableResourceAndroidBitmap('ic_notification_large')
            : null,
        color: const Color(0xFF0F9A07),
        importance: Importance.high,
        priority: Priority.high,
        playSound: playSound,
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: playSound,
      );

      return NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
    }

    try {
      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: buildDetails(includeLargeIcon: true),
        payload: payload,
      );
    } on PlatformException catch (e) {
      if (e.code == 'invalid_large_icon') {
        _logger.warning(
          'Large notification icon unavailable on device; retrying with small icon only',
        );
        await _localNotifications.show(
          id: id,
          title: title,
          body: body,
          notificationDetails: buildDetails(includeLargeIcon: false),
          payload: payload,
        );
      } else {
        rethrow;
      }
    }
  }

  /// Called by the host (main.dart) when an Appwrite push arrives in background.
  static Future<void> handleBackgroundMessage(
    Map<String, dynamic> data,
  ) async {
    // Background pushes are displayed by the system tray on Android /
    // Notification Service on iOS. No additional handling needed here.
    }

  /// Resolves the exact in-app GoRouter route from a push/local notification payload.
  /// Supports relative routes (`/donate`), full ALIVE URLs (`https://app.alivenigeria.org/donate?projectId=...`),
  /// and `type` + `id` structured payloads.
  String resolveNotificationRoute(Map<String, dynamic> data) {
    String? extractAppRoute(dynamic raw) {
      if (raw == null) return null;
      final s = raw.toString().trim();
      if (s.isEmpty) return null;
      if (s.startsWith('/')) return s;
      final uri = Uri.tryParse(s);
      if (uri != null &&
          (uri.scheme == 'https' || uri.scheme == 'http' || uri.scheme == 'aliveng') &&
          uri.path.startsWith('/') &&
          uri.path.length > 1) {
        return uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
      }
      return null;
    }

    for (final key in const [
      'route',
      'deep_link',
      'deepLink',
      'target_route',
      'path',
      'url',
      'link',
      'action',
    ]) {
      final candidate = extractAppRoute(data[key]);
      if (candidate != null && candidate != '/') {
        return candidate;
      }
    }

    final type = (data['type'] ?? '').toString().trim().toLowerCase();
    final rawId = (data['id'] ??
            data['itemId'] ??
            data['item_id'] ??
            data['targetId'] ??
            data['target_id'])
        ?.toString()
        .trim();
    final id = (rawId != null && rawId.isNotEmpty) ? rawId : null;

    switch (type) {
      case 'prayer_request':
      case 'prayer_support':
        return id != null ? '/prayer-requests/$id' : '/prayer-wall';
      case 'prayer_reminder':
      case 'prayer':
        return '/prayer-wall';
      case 'announcement':
      case 'announcements':
        return id != null
            ? '/announcements?id=${Uri.encodeComponent(id)}'
            : '/announcements';
      case 'event':
      case 'events':
        return id != null
            ? '/events?id=${Uri.encodeComponent(id)}'
            : '/events';
      case 'podcast':
      case 'podcasts':
        return id != null
            ? '/podcasts?podcastId=${Uri.encodeComponent(id)}'
            : '/podcasts';
      case 'tract':
      case 'tracts':
        return id != null
            ? '/tracts?id=${Uri.encodeComponent(id)}'
            : '/tracts';
      case 'lesson':
      case 'interactive_lesson':
      case 'interactive_lessons':
        return id != null
            ? '/interactive-lessons?id=${Uri.encodeComponent(id)}'
            : '/interactive-lessons';
      case 'donation':
      case 'donate':
      case 'monthly_donation_reminder':
        return '/donate';
      case 'chat':
      case 'message':
      case 'chat_message':
        return id != null
            ? '/chat?channelId=${Uri.encodeComponent(id)}'
            : '/chat';
      case 'testimony':
      case 'testimonies':
        return '/testimonies';
      case 'chapter':
      case 'chapters':
        return '/chapters';
      case 'mission':
      case 'missions':
      case 'mission_reminder':
        return '/missions';
      case 'daily_verse':
      case 'devotional':
        return '/daily';
      case 'health_reminder':
      case 'health':
        return '/health';
      case 'study_reminder':
      case 'study':
        return '/study';
      case 'bible_memorization':
      case 'bible_game':
        return '/bible-game';
      case 'bible':
        return '/bible';
      case 'billboard':
      case 'showcase':
        return '/billboard';
      case 'meeting_started':
      case 'meeting':
      case 'conference':
        final meetingId =
            (id ?? data['roomName'] ?? data['room'])?.toString().trim();
        if (meetingId != null && meetingId.isNotEmpty) {
          return '/meet/${Uri.encodeComponent(meetingId)}';
        }
        return '/conference';
      case 'board_decision':
      case 'board':
        return '/admin/board-decisions';
      case 'admin_approval':
      case 'approvals':
      case 'approval':
      case 'pending_registration_approval':
      case 'coordinator_approval':
        return '/admin-approval';
      default:
        return '/home';
    }
  }

  void _navigateToResolvedRoute(String targetRoute) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) {
        _pendingNotificationRoute = targetRoute;
        _logger.warning(
          'Navigation context unavailable; queued notification route: $targetRoute',
        );
        return;
      }
      dismissActivePopups();
      _logger.info('Navigating from notification to: $targetRoute');
      ctx.go(targetRoute);
    });
  }

  void handleMessageOpenedApp(Map<String, dynamic> data) {
    _logger.info('Notification opened: ${data.keys.toList()}');
    final targetRoute = resolveNotificationRoute(data);
    // If splash is still active (cold start) or navigator isn't mounted yet,
    // queue the destination so AnimatedSplashScreen hands off directly to it
    // instead of overwriting it with /home.
    if (!_splashCompleted || navigatorKey.currentContext == null) {
      _pendingNotificationRoute = targetRoute;
      _logger.info(
        'Queued cold-start notification route for post-splash handoff: $targetRoute',
      );
      return;
    }
    _navigateToResolvedRoute(targetRoute);
  }

  // Handle local notification tap with custom logic
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload?.trim();
    if (payload != null && payload.isNotEmpty) {
      _logger.info('Local notification tapped with payload: $payload');

      try {
        if (payload.startsWith('{')) {
          final decoded = jsonDecode(payload);
          if (decoded is Map) {
            handleMessageOpenedApp(Map<String, dynamic>.from(decoded));
          }
        } else if (payload.startsWith('/') || payload.startsWith('http')) {
          handleMessageOpenedApp({'route': payload});
        } else {
          handleMessageOpenedApp({'type': payload});
        }
      } catch (e) {
        _logger.error('Error parsing notification payload: $e');
      }
    }
  }

  // Show local notification using base class method
  // Schedule local notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String channelId = 'alive_ng_notifications',
    Map<String, dynamic>? payload,
    bool repeatDaily = false,
  }) async {
    if (kIsWeb) return;
    if (!_isInitialized) {
      await initialize();
    }
    configureLocalTimeZone();

    bool playSound = true;
    try {
      final saved = await StorageHelper.getNotificationSettings();
      if (saved != null && saved['sound_enabled'] is bool) {
        playSound = saved['sound_enabled'] as bool;
      }
    } catch (_) {}

    final resolvedChannelId =
        channelId.trim().isNotEmpty ? channelId.trim() : 'alive_ng_notifications';
    final (channelName, channelDescription) = switch (resolvedChannelId) {
      'daily_verse' => (
          'Daily Bible Verse',
          'Daily scripture verse and devotional reminders',
        ),
      'health_reminders' => (
          'Health & Wellness Reminders',
          'Water intake, sleep, and daily health habit reminders',
        ),
      'study_reminders' => (
          'Bible Study Reminders',
          'Interactive lesson and study guide reminders',
        ),
      'prayer_reminders' => (
          'Prayer Reminders',
          'Scheduled prayer time and intercession reminders',
        ),
      _ => (
          'ALIVE Nigeria Notifications',
          'Ministry updates, broadcasts, and ALIVE Meet alerts',
        ),
    };

    NotificationDetails buildDetails({required bool includeLargeIcon}) {
      final androidDetails = AndroidNotificationDetails(
        resolvedChannelId,
        channelName,
        channelDescription: channelDescription,
        icon: 'ic_notification',
        largeIcon: includeLargeIcon
            ? const DrawableResourceAndroidBitmap('ic_notification_large')
            : null,
        color: const Color(0xFF0F9A07),
        importance: Importance.high,
        priority: Priority.high,
        playSound: playSound,
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: playSound,
      );

      return NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
    }

    final encodedPayload = payload != null ? jsonEncode(payload) : null;
    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    try {
      await _localNotifications.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzDate,
        notificationDetails: buildDetails(includeLargeIcon: true),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: repeatDaily ? DateTimeComponents.time : null,
        payload: encodedPayload,
      );
    } on PlatformException catch (e) {
      if (e.code == 'invalid_large_icon') {
        await _localNotifications.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tzDate,
          notificationDetails: buildDetails(includeLargeIcon: false),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: repeatDaily ? DateTimeComponents.time : null,
          payload: encodedPayload,
        );
      } else {
        rethrow;
      }
    }
  }

  // Schedule daily verse notification
  Future<void> scheduleDailyVerseNotification({
    required DateTime time,
    bool enabled = true,
  }) async {
    if (!enabled) {
      await cancelNotification(1001);
      return;
    }

    await scheduleNotification(
      id: 1001,
      title: 'Daily Verse',
      body: 'Your daily Bible verse is ready!',
      scheduledDate: time,
      channelId: 'daily_verse',
      payload: {'type': 'daily_verse'},
    );
  }

  // Schedule health reminder
  Future<void> scheduleHealthReminder({
    required DateTime time,
    required String activity,
    bool enabled = true,
  }) async {
    final id = activity.hashCode;

    if (!enabled) {
      await cancelNotification(id);
      return;
    }

    await scheduleNotification(
      id: id,
      title: 'Health Reminder',
      body: 'Time for your $activity activity!',
      scheduledDate: time,
      channelId: 'health_reminders',
      payload: {'type': 'health_reminder', 'activity': activity},
    );
  }

  // Schedule study reminder
  Future<void> scheduleStudyReminder({
    required DateTime time,
    required String programName,
    bool enabled = true,
  }) async {
    final id = programName.hashCode;

    if (!enabled) {
      await cancelNotification(id);
      return;
    }

    await scheduleNotification(
      id: id,
      title: 'Study Reminder',
      body: 'Time to continue your $programName study!',
      scheduledDate: time,
      channelId: 'study_reminders',
      payload: {'type': 'study_reminder', 'program': programName},
    );
  }

  // Schedule Bible memorization reminder
  Future<void> scheduleBibleMemorizationReminder({
    required DateTime time,
    String? verseName,
    bool enabled = true,
  }) async {
    const id = 1006;

    if (!enabled) {
      await cancelNotification(id);
      return;
    }

    final body = verseName != null
        ? 'Time to practice $verseName!'
        : 'Time to practice your Bible verses!';

    await scheduleNotification(
      id: id,
      title: 'Bible Memorization',
      body: body,
      scheduledDate: time,
      channelId: 'study_reminders',
      payload: {'type': 'bible_memorization', 'verse': verseName},
    );
  }

  // Cancel notification
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id: id);
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  // Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _localNotifications.pendingNotificationRequests();
  }

  // Update notification settings
  Future<void> updateNotificationSettings(Map<String, bool> settings) async {
    if (_authService.isAuthenticated) {
      try {
        final userId = _authService.currentUser!.uid;
        final data = {
          ...settings,
          'user_id': userId,
          'updated_at': DateTime.now().toIso8601String(),
        };
        await _upsertSettingsDocument(userId, data);
      } catch (e) {
        _logger.error('Failed to update notification settings', e);
        throw DatabaseException('Failed to update notification settings',
            originalError: e);
      }
    }
  }

  // Fetch notification settings for a user
  Future<NotificationSettings> fetchSettings(String userId) async {
    try {
      final row = await _tables.getRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.notificationSettingsCollectionId,
        rowId: userId,
      );

      return NotificationSettings.fromJson({...row.data, 'id': row.$id});
    } catch (e) {
      if (_isMissingDocument(e)) {
        return await createDefaultSettings(userId);
      }
      _logger.error('Failed to fetch settings, using defaults', e);
      return NotificationSettings.defaultSettings(userId);
    }
  }

  bool _isMissingDocument(Object error) {
    return error is AppwriteException && error.code == 404;
  }

  Future<void> _upsertSettingsDocument(
    String userId,
    Map<String, dynamic> data,
  ) async {
    final payload = _settingsPayload(data);
    try {
      await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.notificationSettingsCollectionId,
        rowId: userId,
        data: payload,
      );
    } catch (e) {
      if (!_isMissingDocument(e)) rethrow;
      await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.notificationSettingsCollectionId,
        rowId: userId,
        data: payload,
      );
    }
  }

  Map<String, dynamic> _settingsPayload(Map<String, dynamic> data) {
    final payload = Map<String, dynamic>.from(data)..remove('id');
    final healthReminders = payload['health_reminder_settings'];
    if (healthReminders is List) {
      payload['health_reminder_settings'] = jsonEncode(healthReminders);
    }
    final studyReminders = payload['study_reminder_settings'];
    if (studyReminders is List) {
      payload['study_reminder_settings'] = jsonEncode(studyReminders);
    }
    payload.removeWhere((_, value) => value == null);
    return payload;
  }

  // Create default notification settings
  Future<NotificationSettings> createDefaultSettings(String userId) async {
    try {
      final defaultSettings = NotificationSettings.defaultSettings(userId);
      await _upsertSettingsDocument(userId, defaultSettings.toJson());
      return defaultSettings;
    } catch (e) {
      _logger.error('Failed to create default settings', e);
      return NotificationSettings.defaultSettings(userId);
    }
  }

  // Update notification settings in database
  Future<NotificationSettings> updateSettingsInDatabase(
      NotificationSettings settings) async {
    try {
      final updatedSettings = settings.copyWith(updatedAt: DateTime.now());
      await _upsertSettingsDocument(settings.userId, updatedSettings.toJson());
      return updatedSettings;
    } catch (e) {
      _logger.error('Failed to update notification settings', e);
      throw DatabaseException('Failed to update notification settings',
          originalError: e);
    }
  }

  // Schedule notifications based on settings
  Future<void> scheduleNotificationsFromSettings(
      NotificationSettings settings) async {
    try {
      await cancelAllNotifications();

      if (!settings.pushNotificationsEnabled) return;

      final timeParts = settings.reminderTime.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      final now = DateTime.now();
      var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      if (settings.dailyVerseReminder) {
        await scheduleNotification(
          id: 1001,
          title: 'Daily Bible Verse',
          body: 'Your daily verse is ready!',
          scheduledDate: scheduledDate,
          channelId: 'daily_verse',
          payload: {'type': 'daily_verse'},
        );
      }

      if (settings.prayerReminder) {
        await scheduleNotification(
          id: 1002,
          title: 'Prayer Time',
          body: 'Time for prayer and reflection',
          scheduledDate: scheduledDate.add(const Duration(minutes: 5)),
          channelId: 'prayer_requests',
          payload: {'type': 'prayer_reminder'},
        );
      }

      if (settings.healthTrackingReminder) {
        await scheduleNotification(
          id: 1003,
          title: 'Health Tracking',
          body: 'Don\'t forget to log your health data',
          scheduledDate: scheduledDate.add(const Duration(minutes: 10)),
          channelId: 'health_reminders',
          payload: {'type': 'health_reminder'},
        );
      }

      if (settings.studyReminder) {
        await scheduleNotification(
          id: 1004,
          title: 'Bible Study',
          body: 'Continue your Bible study journey',
          scheduledDate: scheduledDate.add(const Duration(minutes: 15)),
          channelId: 'study_reminders',
          payload: {'type': 'study_reminder'},
        );
      }

      if (settings.missionReminder) {
        await scheduleNotification(
          id: 1005,
          title: 'Mission Activity',
          body: 'Check out today\'s mission activities',
          scheduledDate: scheduledDate.add(const Duration(minutes: 20)),
          channelId: 'missions',
          payload: {'type': 'mission_reminder'},
        );
      }

      if (settings.bibleMemorizationReminder) {
        await scheduleNotification(
          id: 1006,
          title: 'Bible Memorization',
          body: 'Time to practice your Bible verses!',
          scheduledDate: scheduledDate.add(const Duration(minutes: 25)),
          channelId: 'study_reminders',
          payload: {'type': 'bible_memorization'},
        );
      }
    } catch (e) {
      _logger.error('Failed to schedule notifications', e);
      throw AppException('Failed to schedule notifications', originalError: e);
    }
  }

  // Get push token
  String? get pushToken => _currentToken;

  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    // Try Android-specific implementation first
    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      return await androidImplementation.areNotificationsEnabled() ?? false;
    }

    // Fallback to iOS-specific implementation
    final iosImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosImplementation != null) {
      return await iosImplementation.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    // For web or other platforms, assume notifications are enabled if plugin is available
    if (kIsWeb) {
      // Web: flutter_local_notifications has limited/no support; treat as enabled
      return true;
    }

    // Default fallback
    return false;
  }

  // Request notification permissions
  Future<bool> requestPermissions() async {
    return await _requestPermissions();
  }

  Future<bool> _requestPermissions() async {
    if (!kIsWeb) {
      try {
        final notifSettings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        final status = notifSettings.authorizationStatus;
        if (status == AuthorizationStatus.authorized ||
            status == AuthorizationStatus.provisional) {
          return true;
        }
      } catch (e) {
        _logger.warning('FCM requestPermission fallback: $e');
      }
    }
    final android = await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    final ios = await _localNotifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
    final granted = (android == true || ios == true);
    if (!granted) {
      _logger.warning('Notification permissions not granted');
    }
    return granted;
  }
}

// Notification settings model
class NotificationSettings {
  final String? id;
  final String userId;
  final bool prayerRequests;
  final bool missions;
  final bool dailyVerse;
  final bool healthReminders;
  final bool studyReminders;
  final DateTime? dailyVerseTime;
  final List<HealthReminderSetting> healthReminderSettings;
  final List<StudyReminderSetting> studyReminderSettings;
  final bool dailyVerseReminder;
  final bool prayerReminder;
  final bool healthTrackingReminder;
  final bool studyReminder;
  final bool missionReminder;
  final bool bibleMemorizationReminder;
  final String reminderTime;
  final bool pushNotificationsEnabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  NotificationSettings({
    this.id,
    required this.userId,
    this.prayerRequests = true,
    this.missions = true,
    this.dailyVerse = true,
    this.healthReminders = true,
    this.studyReminders = true,
    this.dailyVerseTime,
    this.healthReminderSettings = const [],
    this.studyReminderSettings = const [],
    required this.dailyVerseReminder,
    required this.prayerReminder,
    required this.healthTrackingReminder,
    required this.studyReminder,
    required this.missionReminder,
    this.bibleMemorizationReminder = true,
    required this.reminderTime,
    required this.pushNotificationsEnabled,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'prayer_requests': prayerRequests,
      'missions': missions,
      'daily_verse': dailyVerse,
      'health_reminders': healthReminders,
      'study_reminders': studyReminders,
      'daily_verse_time': dailyVerseTime?.toIso8601String(),
      'health_reminder_settings':
          healthReminderSettings.map((e) => e.toJson()).toList(),
      'study_reminder_settings':
          studyReminderSettings.map((e) => e.toJson()).toList(),
      'daily_verse_reminder': dailyVerseReminder,
      'prayer_reminder': prayerReminder,
      'health_tracking_reminder': healthTrackingReminder,
      'study_reminder': studyReminder,
      'mission_reminder': missionReminder,
      'bible_memorization_reminder': bibleMemorizationReminder,
      'reminder_time': reminderTime,
      'push_notifications_enabled': pushNotificationsEnabled,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      prayerRequests: json['prayer_requests'] ?? true,
      missions: json['missions'] ?? true,
      dailyVerse: json['daily_verse'] ?? true,
      healthReminders: json['health_reminders'] ?? true,
      studyReminders: json['study_reminders'] ?? true,
      dailyVerseTime: json['daily_verse_time'] != null
          ? DateTime.parse(json['daily_verse_time'])
          : null,
      healthReminderSettings:
          (_decodeJsonList(json['health_reminder_settings']))
                  ?.map((e) => HealthReminderSetting.fromJson(e))
                  .toList() ??
              [],
      studyReminderSettings: (_decodeJsonList(json['study_reminder_settings']))
              ?.map((e) => StudyReminderSetting.fromJson(e))
              .toList() ??
          [],
      dailyVerseReminder: json['daily_verse_reminder'] as bool? ?? true,
      prayerReminder: json['prayer_reminder'] as bool? ?? true,
      healthTrackingReminder: json['health_tracking_reminder'] as bool? ?? true,
      studyReminder: json['study_reminder'] as bool? ?? true,
      missionReminder: json['mission_reminder'] as bool? ?? true,
      bibleMemorizationReminder:
          json['bible_memorization_reminder'] as bool? ?? true,
      reminderTime: json['reminder_time'] as String? ?? '08:00',
      pushNotificationsEnabled:
          json['push_notifications_enabled'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  NotificationSettings copyWith({
    String? id,
    String? userId,
    bool? prayerRequests,
    bool? missions,
    bool? dailyVerse,
    bool? healthReminders,
    bool? studyReminders,
    DateTime? dailyVerseTime,
    List<HealthReminderSetting>? healthReminderSettings,
    List<StudyReminderSetting>? studyReminderSettings,
    bool? dailyVerseReminder,
    bool? prayerReminder,
    bool? healthTrackingReminder,
    bool? studyReminder,
    bool? missionReminder,
    bool? bibleMemorizationReminder,
    String? reminderTime,
    bool? pushNotificationsEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationSettings(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      prayerRequests: prayerRequests ?? this.prayerRequests,
      missions: missions ?? this.missions,
      dailyVerse: dailyVerse ?? this.dailyVerse,
      healthReminders: healthReminders ?? this.healthReminders,
      studyReminders: studyReminders ?? this.studyReminders,
      dailyVerseTime: dailyVerseTime ?? this.dailyVerseTime,
      healthReminderSettings:
          healthReminderSettings ?? this.healthReminderSettings,
      studyReminderSettings:
          studyReminderSettings ?? this.studyReminderSettings,
      dailyVerseReminder: dailyVerseReminder ?? this.dailyVerseReminder,
      prayerReminder: prayerReminder ?? this.prayerReminder,
      healthTrackingReminder:
          healthTrackingReminder ?? this.healthTrackingReminder,
      studyReminder: studyReminder ?? this.studyReminder,
      missionReminder: missionReminder ?? this.missionReminder,
      bibleMemorizationReminder:
          bibleMemorizationReminder ?? this.bibleMemorizationReminder,
      reminderTime: reminderTime ?? this.reminderTime,
      pushNotificationsEnabled:
          pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Create default settings
  factory NotificationSettings.defaultSettings(String userId) {
    return NotificationSettings(
      userId: userId,
      prayerRequests: true,
      missions: true,
      dailyVerse: true,
      healthReminders: true,
      studyReminders: true,
      dailyVerseReminder: true,
      prayerReminder: true,
      healthTrackingReminder: true,
      studyReminder: true,
      missionReminder: true,
      bibleMemorizationReminder: true,
      reminderTime: '08:00',
      pushNotificationsEnabled: true,
    );
  }
}

List<Map<String, dynamic>>? _decodeJsonList(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
  if (value is! String || value.isEmpty) return null;

  final decoded = jsonDecode(value);
  if (decoded is! List) return null;
  return decoded
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

class HealthReminderSetting {
  final String activity;
  final DateTime time;
  final bool enabled;

  HealthReminderSetting({
    required this.activity,
    required this.time,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'activity': activity,
      'time': time.toIso8601String(),
      'enabled': enabled,
    };
  }

  factory HealthReminderSetting.fromJson(Map<String, dynamic> json) {
    return HealthReminderSetting(
      activity: json['activity'],
      time: DateTime.parse(json['time']),
      enabled: json['enabled'] ?? true,
    );
  }
}

class StudyReminderSetting {
  final String programId;
  final String programName;
  final DateTime time;
  final bool enabled;

  StudyReminderSetting({
    required this.programId,
    required this.programName,
    required this.time,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'program_id': programId,
      'program_name': programName,
      'time': time.toIso8601String(),
      'enabled': enabled,
    };
  }

  factory StudyReminderSetting.fromJson(Map<String, dynamic> json) {
    return StudyReminderSetting(
      programId: json['program_id'],
      programName: json['program_name'],
      time: DateTime.parse(json['time']),
      enabled: json['enabled'] ?? true,
    );
  }
}

// Riverpod providers
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

final notificationSettingsProvider =
    FutureProvider<NotificationSettings>((ref) async {
  // This would typically fetch from local storage or database
  return NotificationSettings(
    userId: '',
    dailyVerseReminder: true,
    prayerReminder: true,
    healthTrackingReminder: true,
    studyReminder: true,
    missionReminder: true,
    reminderTime: '07:00',
    pushNotificationsEnabled: false,
  );
});
