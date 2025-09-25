import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import '../utils/logger.dart';
import 'notification_service.dart';
import '../widgets/custom_snackbar.dart';
import 'firebase_messaging_base.dart';

class FirebaseMessagingService extends FirebaseMessagingBase {
  static final Logger _logger = Logger('FirebaseMessagingService');

  /// Initialize Firebase Messaging
  static Future<void> initialize() async {
    try {
      // Initialize Firebase
      await FirebaseMessagingBase.initializeFirebase();

      // Request permissions
      final hasPermission = await FirebaseMessagingBase.requestNotificationPermissions();
      if (!hasPermission) {
        _logger.warning('Firebase messaging permissions not granted');
        return;
      }

      // Get and save FCM token
      await FirebaseMessagingBase.getAndSaveToken();

      // Setup message handlers with static callbacks
      FirebaseMessagingBase.setupMessageHandlers(
        onForegroundMessage: handleForegroundMessage,
        onBackgroundMessage: handleBackgroundMessage,
        onMessageOpenedApp: handleNotificationTap,
      );

      // Setup token refresh listener
      FirebaseMessagingBase.setupTokenRefreshListener();

      _logger.info('FirebaseMessagingService initialized successfully');
    } catch (e) {
      _logger.error('Error initializing FirebaseMessagingService', e);
      rethrow;
    }
  }

  /// Handle background messages
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    final logger = Logger('FirebaseMessagingBackgroundHandler');
    logger.info('Handling background message: ${message.messageId}');

    // Handle background message logic here
    // For example, update local database, show notification, etc.
  }

  /// Handle foreground messages
  static void handleForegroundMessage(RemoteMessage message) {
    _logger.info('Received foreground message: ${message.messageId}');

    // Show in-app notification or update UI
    if (message.notification != null) {
      final title = message.notification!.title ?? 'New Message';
      final body = message.notification!.body ?? '';
      
      // Show in-app toast notification
      final context = NotificationService.navigatorKey.currentContext;
      if (context != null) {
        ToastNotification.show(
          context: context,
          message: body,
          title: title,
          type: SnackBarType.info,
          duration: const Duration(seconds: 4),
          position: ToastPosition.top,
        );
      } else {
        _logger.warning('No context available for showing in-app notification');
      }
    }
  }

  /// Handle notification tap
  static void handleNotificationTap(RemoteMessage message) {
    _logger.info('Notification tapped: ${message.messageId}');

    // Navigate to specific screen based on message data
    final data = message.data;
    if (data.containsKey('screen')) {
      _logger.info('Navigate to: ${data['screen']}');
      
      // Use the global navigator key to navigate
      final context = NotificationService.navigatorKey.currentContext;
      if (context != null) {
        final screen = data['screen'] as String;
        // Ensure the screen path starts with '/'
        final screenPath = screen.startsWith('/') ? screen : '/$screen';
        context.go(screenPath);
        _logger.info('Successfully navigated to: $screenPath');
      } else {
        _logger.warning('Navigation context not available for screen navigation');
      }
    }
  }

  /// Subscribe to a topic
  static Future<void> subscribeToTopic(String topic) async {
    await FirebaseMessagingBase.subscribeToTopic(topic);
  }

  /// Unsubscribe from a topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    await FirebaseMessagingBase.unsubscribeFromTopic(topic);
  }

  /// Get current FCM token
  static Future<String?> getCurrentToken() async {
    return await FirebaseMessagingBase.getCurrentToken();
  }

  /// Delete FCM token
  static Future<void> deleteToken() async {
    await FirebaseMessagingBase.deleteToken();
  }
}
