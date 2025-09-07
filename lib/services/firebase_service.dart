import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

class FirebaseService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final Logger _logger = Logger('FirebaseService');

  // Initialize Firebase services
  static Future<void> initialize() async {
    try {
      // Initialize Firebase
      await Firebase.initializeApp();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Request notification permissions
      await _requestNotificationPermissions();

      // Set up message handlers
      _setupMessageHandlers();

      _logger.info('Firebase services initialized successfully');
    } catch (e) {
      _logger.error('Error initializing Firebase services', e);
    }
  }

  // Initialize local notifications
  static Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
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
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  // Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      // Handle navigation based on payload
      _handleNotificationNavigation(payload);
    }
  }

  // Handle notification navigation
  static void _handleNotificationNavigation(String payload) {
    // Parse payload and navigate to appropriate screen
    try {
      // This would integrate with your app's navigation system
      _logger.info('Navigating based on notification payload: $payload');
    } catch (e) {
      _logger.error('Error handling notification navigation: $e');
    }
  }

  // Request notification permissions
  static Future<bool> _requestNotificationPermissions() async {
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

      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      _logger.error('Error requesting notification permissions: $e');
      return false;
    }
  }

  // Get FCM token
  static Future<String?> getToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveTokenToDatabase(token);
      }
      return token;
    } catch (e) {
      _logger.error('Error getting FCM token: $e');
      return null;
    }
  }

  // Save FCM token to database
  static Future<void> _saveTokenToDatabase(String token) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase.from('push_tokens').upsert({
          'user_id': user.id,
          'token': token,
          'device_type': 'mobile',
          'is_active': true,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      _logger.error('Error saving FCM token to database: $e');
    }
  }

  // Set up message handlers
  static void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

    // Handle notification opened app
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Handle initial message (when app is opened from terminated state)
    _handleInitialMessage();
  }

  // Handle foreground messages
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    _logger.info('Received foreground message: ${message.messageId}');

    // Show local notification when app is in foreground
    await _showLocalNotification(message);
  }

  // Handle background messages
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    _logger.info('Received background message: ${message.messageId}');
    // Background message handling is automatic
  }

  // Handle message opened app
  static Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    _logger.info('Message opened app: ${message.messageId}');

    // Navigate to appropriate screen based on message data
    final data = message.data;
    if (data.isNotEmpty) {
      _handleNotificationNavigation(data.toString());
    }
  }

  // Handle initial message
  static Future<void> _handleInitialMessage() async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _logger.info(
          'App opened from terminated state via notification: ${initialMessage.messageId}');
      _handleMessageOpenedApp(initialMessage);
    }
  }

  // Show local notification
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'alive_channel',
      'ALIVE Notifications',
      channelDescription: 'Notifications for ALIVE app',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'ALIVE Nigeria',
      message.notification?.body ?? 'You have a new notification',
      details,
      payload: message.data.toString(),
    );
  }

  // Subscribe to topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      _logger.info('Subscribed to topic: $topic');
    } catch (e) {
      _logger.error('Error subscribing to topic $topic', e);
    }
  }

  // Unsubscribe from topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      _logger.info('Unsubscribed from topic: $topic');
    } catch (e) {
      _logger.error('Error unsubscribing from topic $topic', e);
    }
  }

  // Delete FCM token
  static Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();

      // Remove token from database
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase
            .from('push_tokens')
            .update({'is_active': false}).eq('user_id', user.id);
      }

      _logger.info('FCM token deleted');
    } catch (e) {
      _logger.error('Error deleting FCM token', e);
    }
  }

  // Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    try {
      final settings = await _messaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      _logger.error('Error checking notification settings', e);
      return false;
    }
  }

  // Send notification to specific user (server-side function)
  static Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // This would typically be done server-side
      // Here we're calling a Supabase Edge Function
      await _supabase.functions.invoke(
        'send-notification',
        body: {
          'user_id': userId,
          'title': title,
          'body': body,
          'data': data ?? {},
        },
      );
    } catch (e) {
      _logger.error('Error sending notification', e);
    }
  }

  // Send notification to topic (server-side function)
  static Future<void> sendNotificationToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _supabase.functions.invoke(
        'send-topic-notification',
        body: {
          'topic': topic,
          'title': title,
          'body': body,
          'data': data ?? {},
        },
      );
    } catch (e) {
      _logger.error('Error sending topic notification', e);
    }
  }

  // Get notification history
  static Future<List<Map<String, dynamic>>> getNotificationHistory(
      String userId) async {
    try {
      final response = await _supabase
          .from('notification_history')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _logger.error('Error fetching notification history', e);
      return [];
    }
  }

  // Mark notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notification_history')
          .update({'read_at': DateTime.now().toIso8601String()}).eq(
              'id', notificationId);
    } catch (e) {
      _logger.error('Error marking notification as read', e);
    }
  }
}
