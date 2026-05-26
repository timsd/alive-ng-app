import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
// Removed dart:io import for web compatibility

/// Firebase Cloud Messaging configuration for ALIVE-NG App.
///
/// Firebase is retained only as the Android/Web push delivery bridge used by
/// Appwrite Messaging providers. Product analytics are stored in Appwrite, and
/// crash reporting is handled by GlitchTip/Sentry-compatible reporting.
class FirebaseConfig {
  // Firebase Project Details
  static const String projectName = 'aliveng-ministry-app';
  static const String projectId = 'alive-ng-flutter-app';
  static const String projectNumber = '234909240985';
  static const String senderId = '234909240985';

  // Read compile-time defines safely (String.fromEnvironment must be const).
  static String _readDefine(String key) {
    switch (key) {
      case 'WEB_PUSH_CERT_KEY':
        return const String.fromEnvironment('WEB_PUSH_CERT_KEY');
      case 'FIREBASE_ANDROID_API_KEY':
        return const String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
      case 'FIREBASE_ANDROID_APP_ID':
        return const String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
      case 'FIREBASE_IOS_API_KEY':
        return const String.fromEnvironment('FIREBASE_IOS_API_KEY');
      case 'FIREBASE_IOS_APP_ID':
        return const String.fromEnvironment('FIREBASE_IOS_APP_ID');
      case 'FIREBASE_WEB_API_KEY':
        return const String.fromEnvironment('FIREBASE_WEB_API_KEY');
      case 'FIREBASE_WEB_APP_ID':
        return const String.fromEnvironment('FIREBASE_WEB_APP_ID');
      case 'FIREBASE_WEB_MESSAGING_SENDER_ID':
        return const String.fromEnvironment('FIREBASE_WEB_MESSAGING_SENDER_ID');
      case 'FIREBASE_WEB_PROJECT_ID':
        return const String.fromEnvironment('FIREBASE_WEB_PROJECT_ID');
      case 'FIREBASE_WEB_AUTH_DOMAIN':
        return const String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN');
      case 'FIREBASE_WEB_STORAGE_BUCKET':
        return const String.fromEnvironment('FIREBASE_WEB_STORAGE_BUCKET');
      case 'FIREBASE_WEB_MEASUREMENT_ID':
        return const String.fromEnvironment('FIREBASE_WEB_MEASUREMENT_ID');
      default:
        return '';
    }
  }

  // Helper to get value from dart-define with fallback defaults.
  static String _getEnv(String key, String defaultValue) {
    final fromEnv = _readDefine(key);
    if (fromEnv.isNotEmpty) return fromEnv;
    return defaultValue;
  }

  // Web Push Certificate Keys
  static String get webPushCertificateKey => _getEnv('WEB_PUSH_CERT_KEY', '');

  // Private key should NEVER be in client code
  // static const String webPushPrivateKey = '...';

  // Firebase Admin SDK Service Account
  static const String serviceAccountEmail =
      'firebase-adminsdk-fbsvc@alive-ng-flutter-app.iam.gserviceaccount.com';

  /// Load Firebase Admin SDK configuration
  /// Note: Reading local files is not supported in client apps or on web.
  /// This method returns null to maintain web compatibility.
  static Future<Map<String, dynamic>?> getAdminConfig() async {
    return null;
  }

  // Firebase Options for different platforms
  static FirebaseOptions get android => FirebaseOptions(
        apiKey: _getEnv('FIREBASE_ANDROID_API_KEY',
            'AIzaSyDmpl9Idp9Q0ult4BfWPg5J7A1URQOpDoU'),
        appId: _getEnv('FIREBASE_ANDROID_APP_ID',
            '1:234909240985:android:9d703098e9fcce3e8e3208'),
        messagingSenderId: '234909240985',
        projectId: 'alive-ng-flutter-app',
        storageBucket: 'alive-ng-flutter-app.appspot.com',
      );

  static FirebaseOptions get ios => FirebaseOptions(
        apiKey: _getEnv(
            'FIREBASE_IOS_API_KEY', 'AIzaSyBiDmtEjFx84binj7uKkROtx39NYcp3Q80'),
        appId: _getEnv(
            'FIREBASE_IOS_APP_ID', '1:234909240985:ios:17ffc2d5b91ce9718e3208'),
        messagingSenderId: '234909240985',
        projectId: 'alive-ng-flutter-app',
        storageBucket: 'alive-ng-flutter-app.appspot.com',
        iosBundleId: 'com.alive.alivengiosapp',
      );

  static FirebaseOptions get web => FirebaseOptions(
        apiKey: _getEnv(
            'FIREBASE_WEB_API_KEY', 'AIzaSyDmpl9Idp9Q0ult4BfWPg5J7A1URQOpDoU'),
        appId: _getEnv(
            'FIREBASE_WEB_APP_ID', '1:234909240985:web:9d703098e9fcce3e8e3208'),
        messagingSenderId:
            _getEnv('FIREBASE_WEB_MESSAGING_SENDER_ID', '234909240985'),
        projectId: _getEnv('FIREBASE_WEB_PROJECT_ID', 'alive-ng-flutter-app'),
        authDomain: _getEnv(
            'FIREBASE_WEB_AUTH_DOMAIN', 'alive-ng-flutter-app.firebaseapp.com'),
        storageBucket: _getEnv('FIREBASE_WEB_STORAGE_BUCKET',
            'alive-ng-flutter-app.firebasestorage.app'),
        measurementId: _getEnv('FIREBASE_WEB_MEASUREMENT_ID', 'G-CC6JE7224Q'),
      );

  /// Get Firebase options for current platform
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macOS - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  /// Initialize Firebase with all services
  static Future<void> initialize() async {
    try {
      // Initialize Firebase Core
      await Firebase.initializeApp(
        options: currentPlatform,
      );

      // Avoid blocking web startup on notification permission/token flows.
      // Requesting notification permissions should be user-driven on web.
      if (!kIsWeb) {
        await _initializeMessaging();
      } else {
        debugPrint('Skipping Firebase Messaging auto-init on web startup');
      }

      debugPrint('Firebase Cloud Messaging initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Firebase: $e');
      rethrow;
    }
  }

  /// Initialize Firebase Cloud Messaging
  static Future<void> _initializeMessaging() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Request permission for notifications
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('FCM permission status: ${settings.authorizationStatus}');

      // Get FCM token
      final token = await messaging.getToken(
        vapidKey: webPushCertificateKey, // For web push notifications
      );
      debugPrint('FCM Token: $token');

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Received foreground message: ${message.messageId}');
        _handleForegroundMessage(message);
      });

      // Handle notification taps
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('Notification tapped: ${message.messageId}');
        _handleNotificationTap(message);
      });
    } catch (e) {
      debugPrint('Error initializing Firebase Messaging: $e');
    }
  }

  /// Handle foreground messages
  static void _handleForegroundMessage(RemoteMessage message) {
    // Handle the message when app is in foreground
    // You can show local notifications here
    debugPrint('Foreground message data: ${message.data}');

    if (message.notification != null) {
      debugPrint('Message notification: ${message.notification!.title}');
      debugPrint('Message body: ${message.notification!.body}');
    }
  }

  /// Handle notification tap
  static void _handleNotificationTap(RemoteMessage message) {
    // Handle navigation when notification is tapped
    debugPrint('Notification tapped with data: ${message.data}');

    // Navigate to specific screen based on message data
    final data = message.data;
    if (data.containsKey('screen')) {
      // Navigate to specific screen
      // This would be handled by your navigation service
    }
  }

  /// Background message handler
  static Future<void> _firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    // If you're going to use other Firebase services in the background, such as Firestore,
    // make sure you call `initializeApp` before using other Firebase services.
    await Firebase.initializeApp(options: currentPlatform);

    debugPrint('Handling a background message: ${message.messageId}');
    debugPrint('Background message data: ${message.data}');
  }

  /// Notification categories for different types of messages
  static const Map<String, Map<String, dynamic>> notificationCategories = {
    'chat_message': {
      'title': 'New Message',
      'icon': 'chat_icon',
      'sound': 'message_sound.wav',
      'priority': 'high',
    },
    'prayer_request': {
      'title': 'Prayer Request',
      'icon': 'prayer_icon',
      'sound': 'prayer_sound.wav',
      'priority': 'high',
    },
    'chapter_update': {
      'title': 'Chapter Update',
      'icon': 'chapter_icon',
      'sound': 'default_sound.wav',
      'priority': 'normal',
    },
    'study_reminder': {
      'title': 'Study Reminder',
      'icon': 'study_icon',
      'sound': 'reminder_sound.wav',
      'priority': 'normal',
    },
    'health_tip': {
      'title': 'Health Tip',
      'icon': 'health_icon',
      'sound': 'default_sound.wav',
      'priority': 'low',
    },
    'conference_reminder': {
      'title': 'Conference Reminder',
      'icon': 'conference_icon',
      'sound': 'conference_sound.wav',
      'priority': 'high',
    },
  };

  /// Topic subscriptions for different user roles
  static const Map<String, List<String>> roleTopics = {
    'admin': [
      'admin_notifications',
      'system_alerts',
      'all_chapters',
      'leadership_updates',
      'general_announcements',
    ],
    'director': [
      'director_notifications',
      'leadership_updates',
      'chapter_reports',
      'general_announcements',
    ],
    'coordinator': [
      'coordinator_notifications',
      'chapter_updates',
      'discipleship_updates',
      'general_announcements',
    ],
    'member': [
      'member_notifications',
      'general_announcements',
      'health_tips',
      'study_reminders',
    ],
  };

  /// Subscribe to topics based on user role
  static Future<void> subscribeToRoleTopics(List<String> userRoles) async {
    try {
      final messaging = FirebaseMessaging.instance;

      for (final role in userRoles) {
        final topics = roleTopics[role] ?? [];
        for (final topic in topics) {
          await messaging.subscribeToTopic(topic);
          debugPrint('Subscribed to topic: $topic');
        }
      }
    } catch (e) {
      debugPrint('Error subscribing to topics: $e');
    }
  }

  /// Unsubscribe from topics
  static Future<void> unsubscribeFromRoleTopics(List<String> userRoles) async {
    try {
      final messaging = FirebaseMessaging.instance;

      for (final role in userRoles) {
        final topics = roleTopics[role] ?? [];
        for (final topic in topics) {
          await messaging.unsubscribeFromTopic(topic);
          debugPrint('Unsubscribed from topic: $topic');
        }
      }
    } catch (e) {
      debugPrint('Error unsubscribing from topics: $e');
    }
  }

  /// Product analytics are Appwrite-backed. Kept as a no-op compatibility hook.
  static Future<void> logEvent(
      String eventName, Map<String, dynamic> parameters) async {
    debugPrint('Appwrite analytics event requested: $eventName');
  }

  /// Product analytics are Appwrite-backed. Kept as a no-op compatibility hook.
  static Future<void> setUserProperties(Map<String, String> properties) async {
    debugPrint('Appwrite analytics user properties requested');
  }

  /// Product analytics/crash reporting are not Firebase-backed.
  static Future<void> setUserId(String userId) async {
    debugPrint('Firebase FCM user ID bridge ignored: $userId');
  }
}
