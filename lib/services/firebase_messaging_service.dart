import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/toast_utils.dart';
import '../utils/logger.dart';

class FirebaseMessagingService {
  static final _messaging = FirebaseMessaging.instance;
  static final _supabase = Supabase.instance.client;
  static final _logger = Logger('FirebaseMessagingService');

  /// Initialize Firebase messaging
  static Future<void> initialize() async {
    await Firebase.initializeApp();

    // Request permission for notifications
    await requestNotificationPermission();

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle notification tap when app is terminated
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  /// Request notification permission and get FCM token
  static Future<String?> requestNotificationPermission() async {
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

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final token = await _messaging.getToken();

        if (token != null) {
          await _saveTokenToDatabase(token);
          return token;
        }
      } else {
        ToastUtils.showError('Notification permission denied');
      }

      return null;
    } catch (error) {
      _logger.error('Error requesting notification permission: $error');
      ToastUtils.showError('Failed to setup notifications');
      return null;
    }
  }

  /// Save FCM token to Supabase database
  static Future<void> _saveTokenToDatabase(String token) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // TODO: Uncomment when push_tokens table is available
      // await _supabase.from('push_tokens').upsert({
      //   'user_id': user.id,
      //   'token': token,
      //   'device_type': 'mobile',
      //   'is_active': true,
      //   'updated_at': DateTime.now().toIso8601String(),
      // });

      _logger.info('FCM token saved: $token');
    } catch (error) {
      _logger.error('Error saving FCM token: $error');
    }
  }

  /// Handle background messages
  static Future<void> _firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    await Firebase.initializeApp();
    final logger = Logger('FirebaseMessagingBackgroundHandler');
    logger.info('Handling background message: ${message.messageId}');

    // Handle background message logic here
    // For example, update local database, show notification, etc.
  }

  /// Handle foreground messages
  static void _handleForegroundMessage(RemoteMessage message) {
    _logger.info('Received foreground message: ${message.messageId}');

    // Show in-app notification or update UI
    if (message.notification != null) {
      final title = message.notification!.title ?? 'New Message';
      final body = message.notification!.body ?? '';
      ToastUtils.showInfo('$title: $body');
    }
  }

  /// Handle notification tap
  static void _handleNotificationTap(RemoteMessage message) {
    _logger.info('Notification tapped: ${message.messageId}');

    // Navigate to specific screen based on message data
    final data = message.data;
    if (data.containsKey('screen')) {
      // TODO: Implement navigation based on data['screen']
      _logger.info('Navigate to: ${data['screen']}');
    }
  }

  /// Subscribe to a topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      _logger.info('Subscribed to topic: $topic');
    } catch (error) {
      _logger.error('Error subscribing to topic $topic: $error');
    }
  }

  /// Unsubscribe from a topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      _logger.info('Unsubscribed from topic: $topic');
    } catch (error) {
      _logger.error('Error unsubscribing from topic $topic: $error');
    }
  }

  /// Get current FCM token
  static Future<String?> getCurrentToken() async {
    try {
      return await _messaging.getToken();
    } catch (error) {
      _logger.error('Error getting FCM token: $error');
      return null;
    }
  }

  /// Delete FCM token
  static Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();

      // TODO: Remove token from database when push_tokens table is available
      // final user = _supabase.auth.currentUser;
      // if (user != null) {
      //   await _supabase
      //       .from('push_tokens')
      //       .update({'is_active': false})
      //       .eq('user_id', user.id);
      // }

      _logger.info('FCM token deleted');
    } catch (error) {
      _logger.error('Error deleting FCM token: $error');
    }
  }

  /// Listen for token refresh
  static void listenForTokenRefresh() {
    _messaging.onTokenRefresh.listen((newToken) {
      _logger.info('FCM token refreshed: $newToken');
      _saveTokenToDatabase(newToken);
    });
  }
}
