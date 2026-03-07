import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// Removed supabase_flutter import - using Firebase now
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'auth_service.dart';
import 'firebase_database_service.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';
import 'firebase_messaging_base.dart';

class FirebaseService extends FirebaseMessagingBase {
  // Removed Supabase client. Using Firebase services instead
  static final Logger _logger = Logger('FirebaseService');
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static bool _isInitialized = false;

  /// Initialize Firebase services
  static Future<void> initialize() async {
    if (_isInitialized) {
      _logger.info('Firebase already initialized');
      return;
    }

    try {
      // Initialize Firebase using base class
      await FirebaseMessagingBase.initializeFirebase();

      // Initialize local notifications with custom handler
      await FirebaseMessagingBase.initializeLocalNotifications(
        onNotificationTapped: _onNotificationTapped,
      );

      // Request notification permissions
      await FirebaseMessagingBase.requestNotificationPermissions();

      // Set up message handlers
      _setupMessageHandlers();

      _isInitialized = true;
      _logger.info('Firebase services initialized successfully');
    } catch (e) {
      _logger.error('Error initializing Firebase services', e);
      throw DatabaseException('Failed to initialize Firebase services',
          originalError: e);
    }
  }

  /// Handle notification tap with custom logic
  static void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      _logger.info('Notification tapped with payload: $payload');
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
      throw DatabaseException('Failed to get FCM token', originalError: e);
    }
  }

  // Save FCM token to database (Firestore)
  static Future<void> _saveTokenToDatabase(String token) async {
    try {
      final user = AuthService.instance.currentUser;
      if (user != null) {
        await FirebaseDatabaseService.instance.updateFCMToken(user.uid, token);
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

      // Remove/deactivate token in Firestore
      final user = AuthService.instance.currentUser;
      if (user != null) {
        await _firestore.collection('push_tokens').doc(user.uid).set(
            {'is_active': false, 'updated_at': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
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

  // Send notification to specific user via Cloud Functions
  static Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _functions.httpsCallable('sendNotificationToUser').call(
          {'userId': userId, 'title': title, 'body': body, 'data': data ?? {}});
    } catch (e) {
      _logger.error('Error sending notification', e);
      throw DatabaseException('Failed to send notification', originalError: e);
    }
  }

  // Send notification to topic via Cloud Functions
  static Future<void> sendNotificationToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _functions.httpsCallable('sendTopicNotification').call(
          {'topic': topic, 'title': title, 'body': body, 'data': data ?? {}});
    } catch (e) {
      _logger.error('Error sending topic notification', e);
      throw DatabaseException('Failed to send topic notification',
          originalError: e);
    }
  }

  // Get notification history from Firestore
  static Future<List<Map<String, dynamic>>> getNotificationHistory(
      String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notification_history')
          .where('user_id', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      _logger.error('Error fetching notification history', e);
      return [];
    }
  }

  // Mark notification as read in Firestore
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notification_history')
          .doc(notificationId)
          .set({'read_at': FieldValue.serverTimestamp()},
              SetOptions(merge: true));
    } catch (e) {
      _logger.error('Error marking notification as read', e);
    }
  }
}
