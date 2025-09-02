import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/toast_utils.dart';

class FirebaseMessagingService {
  static final _messaging = FirebaseMessaging.instance;
  static final _supabase = Supabase.instance.client;

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
      print('Error requesting notification permission: $error');
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

      print('FCM token saved: $token');
    } catch (error) {
      print('Error saving FCM token: $error');
    }
  }

  /// Handle background messages
  static Future<void> _firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    await Firebase.initializeApp();
    print('Handling background message: ${message.messageId}');

    // Handle background message logic here
    // For example, update local database, show notification, etc.
  }

  /// Handle foreground messages
  static void _handleForegroundMessage(RemoteMessage message) {
    print('Received foreground message: ${message.messageId}');

    // Show in-app notification or update UI
    if (message.notification != null) {
      ToastUtils.showInfo(
        message.notification!.title ?? 'New Message',
        description: message.notification!.body,
      );
    }
  }

  /// Handle notification tap
  static void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.messageId}');

    // Navigate to specific screen based on message data
    final data = message.data;
    if (data.containsKey('screen')) {
      // TODO: Implement navigation based on data['screen']
      print('Navigate to: ${data['screen']}');
    }
  }

  /// Subscribe to a topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      print('Subscribed to topic: $topic');
    } catch (error) {
      print('Error subscribing to topic $topic: $error');
    }
  }

  /// Unsubscribe from a topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      print('Unsubscribed from topic: $topic');
    } catch (error) {
      print('Error unsubscribing from topic $topic: $error');
    }
  }

  /// Get current FCM token
  static Future<String?> getCurrentToken() async {
    try {
      return await _messaging.getToken();
    } catch (error) {
      print('Error getting FCM token: $error');
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

      print('FCM token deleted');
    } catch (error) {
      print('Error deleting FCM token: $error');
    }
  }

  /// Listen for token refresh
  static void listenForTokenRefresh() {
    _messaging.onTokenRefresh.listen((newToken) {
      print('FCM token refreshed: $newToken');
      _saveTokenToDatabase(newToken);
    });
  }
}
