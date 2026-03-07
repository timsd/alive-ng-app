import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';
import '../utils/toast_utils.dart';
import 'firebase_database_service.dart';
import 'auth_service.dart';
import '../config/firebase_config.dart';

/// Base class for Firebase messaging functionality
/// Consolidates common Firebase messaging operations to reduce code duplication
abstract class FirebaseMessagingBase {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseDatabaseService _firebase = FirebaseDatabaseService.instance;
  static final Logger _logger = Logger('FirebaseMessagingBase');
  static String? _fcmToken;

  /// Get the current FCM token
  static String? get fcmToken => _fcmToken;

  /// Initialize Firebase and messaging services
  static Future<void> initializeFirebase() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: FirebaseConfig.currentPlatform);
        _logger.info('Firebase initialized successfully');
      } else {
        _logger.info('Firebase already initialized');
      }
    } catch (e) {
      _logger.error('Error initializing Firebase', e);
      rethrow;
    }
  }

  /// Initialize local notifications with common settings
  static Future<void> initializeLocalNotifications({
    Function(NotificationResponse)? onNotificationTapped,
  }) async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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
      settings,
      onDidReceiveNotificationResponse: onNotificationTapped ?? _defaultNotificationTap,
    );
  }

  /// Default notification tap handler
  static void _defaultNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      _logger.info('Notification tapped with payload: $payload');
    }
  }

  /// Request notification permissions with standard settings
  static Future<bool> requestNotificationPermissions() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      final isAuthorized = settings.authorizationStatus == AuthorizationStatus.authorized;
      
      if (isAuthorized) {
        _logger.info('Notification permissions granted');
      } else {
        _logger.warning('Notification permissions denied');
        ToastUtils.showError('Notification permission denied');
      }
      
      return isAuthorized;
    } catch (e) {
      _logger.error('Error requesting notification permissions', e);
      return false;
    }
  }

  /// Get and save FCM token
  static Future<String?> getAndSaveToken() async {
    try {
      if (kIsWeb) {
        // On web, require VAPID key for token retrieval
        final vapidKey = FirebaseConfig.webPushCertificateKey;
        if (vapidKey.isEmpty) {
          _logger.warning('Web VAPID key missing; skipping FCM token retrieval on web');
          return null;
        }
        _fcmToken = await _messaging.getToken(vapidKey: vapidKey);
      } else {
        _fcmToken = await _messaging.getToken();
      }
      
      if (_fcmToken != null) {
        await _saveTokenToDatabase(_fcmToken!);
        _logger.info('FCM token obtained and saved');
      }
      
      return _fcmToken;
    } catch (e) {
      _logger.error('Error getting FCM token', e);
      return null;
    }
  }

  /// Save FCM token to database
  static Future<void> _saveTokenToDatabase(String token) async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) {
        _logger.warning('No authenticated user to save token for');
        return;
      }

      await _firebase.updateFCMToken(user.uid, token);

      _logger.info('FCM token saved for user: ${user.uid}');
    } catch (e) {
      _logger.error('Error saving FCM token to database', e);
    }
  }

  /// Setup message handlers with custom callbacks
  static void setupMessageHandlers({
    Function(RemoteMessage)? onForegroundMessage,
    BackgroundMessageHandler? onBackgroundMessage,
    Function(RemoteMessage)? onMessageOpenedApp,
  }) {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(
      onForegroundMessage ?? _defaultForegroundHandler,
    );

    // Handle background messages
    if (onBackgroundMessage != null) {
      FirebaseMessaging.onBackgroundMessage(onBackgroundMessage);
    }

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(
      onMessageOpenedApp ?? _defaultMessageOpenedHandler,
    );

    // Handle initial message when app is opened from terminated state
    _handleInitialMessage(onMessageOpenedApp);
  }

  /// Default foreground message handler
  static void _defaultForegroundHandler(RemoteMessage message) {
    _logger.info('Received foreground message: ${message.messageId}');
    
    if (message.notification != null) {
      final title = message.notification!.title ?? 'Alive App';
      final body = message.notification!.body ?? '';
      ToastUtils.showInfo('$title: $body');
    }
  }

  /// Default message opened handler
  static void _defaultMessageOpenedHandler(RemoteMessage message) {
    _logger.info('Message opened: ${message.messageId}');
    
    final data = message.data;
    if (data.containsKey('screen')) {
      _logger.info('Should navigate to: ${data['screen']}');
    }
  }

  /// Handle initial message when app is opened from terminated state
  static Future<void> _handleInitialMessage(
    Function(RemoteMessage)? onMessageOpenedApp,
  ) async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      (onMessageOpenedApp ?? _defaultMessageOpenedHandler)(initialMessage);
    }
  }

  /// Subscribe to topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      if (kIsWeb) {
        _logger.warning('Skipping topic subscription on web in development');
        return;
      }
      await _messaging.subscribeToTopic(topic);
      _logger.info('Subscribed to topic: $topic');
    } catch (e) {
      _logger.error('Error subscribing to topic $topic', e);
    }
  }

  /// Unsubscribe from topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      if (kIsWeb) {
        _logger.warning('Skipping topic unsubscribe on web in development');
        return;
      }
      await _messaging.unsubscribeFromTopic(topic);
      _logger.info('Unsubscribed from topic: $topic');
    } catch (e) {
      _logger.error('Error unsubscribing from topic $topic', e);
    }
  }

  /// Get current FCM token
  static Future<String?> getCurrentToken() async {
    try {
      if (kIsWeb) {
        final vapidKey = FirebaseConfig.webPushCertificateKey;
        if (vapidKey.isEmpty) {
          _logger.warning('Web VAPID key missing; cannot get current FCM token');
          return null;
        }
        return await _messaging.getToken(vapidKey: vapidKey);
      }
      return await _messaging.getToken();
    } catch (e) {
      _logger.error('Error getting current FCM token', e);
      return null;
    }
  }

  /// Delete FCM token
  static Future<void> deleteToken() async {
    try {
      if (kIsWeb) {
        _logger.warning('Skipping deleteToken on web');
        return;
      }
      await _messaging.deleteToken();
      
      final user = AuthService.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('push_tokens')
            .doc(user.uid)
            .set({'is_active': false, 'updated_at': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      }
      
      _logger.info('FCM token deleted');
    } catch (e) {
      _logger.error('Error deleting FCM token', e);
    }
  }

  /// Setup token refresh listener
  static void setupTokenRefreshListener() {
    _messaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      _logger.info('FCM token refreshed');
      _saveTokenToDatabase(newToken);
    });
  }

  /// Create notification channel (Android)
  static Future<void> createNotificationChannel({
    required String id,
    required String name,
    String? description,
    Importance importance = Importance.defaultImportance,
  }) async {
    final channel = AndroidNotificationChannel(
      id,
      name,
      description: description,
      importance: importance,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Show local notification
  static Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? channelId,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default Notifications',
      channelDescription: 'Default notification channel',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  /// Get messaging instance (for advanced usage)
  static FirebaseMessaging get messaging => _messaging;

  /// Get local notifications instance (for advanced usage)
  static FlutterLocalNotificationsPlugin get localNotifications => _localNotifications;
}



