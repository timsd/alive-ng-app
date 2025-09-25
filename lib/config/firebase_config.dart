import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Configuration for ALIVE NG App
/// Contains all Firebase project settings and initialization
class FirebaseConfig {
  // Firebase Project Details
  static const String projectName = 'aliveng-ministry-app';
  static const String projectId = 'alive-ng-flutter-app';
  static const String projectNumber = '234909240985';
  static const String senderId = '234909240985';

  // Web Push Certificate Keys
  static const String webPushCertificateKey =
      'BMFvrKu5q_mKn80IaIsX3hREab1nodMrdKDlMGOL_lVCIuTwxq4mTZiFG1SYUcCy6G-TrjK9X4H08Jll1PQjkYg';
  static const String webPushPrivateKey =
      '_pnCJVOtxL2g6Q7OzEpZz_lkqySK406yx2EuaYFV8uI';

  // Firebase Admin SDK Service Account
  static const String serviceAccountEmail =
      'firebase-adminsdk-fbsvc@alive-ng-app.iam.gserviceaccount.com';

  // Firebase Options for different platforms
  static const FirebaseOptions android = FirebaseOptions(
    apiKey:
        'AIzaSyDmpl9Idp9Q0ult4BfWPg5J7A1URQOpDoU', // From google-services.json
    appId:
        '1:234909240985:android:9d703098e9fcce3e8e3208',
    messagingSenderId: '234909240985',
    projectId: 'alive-ng-flutter-app',
    storageBucket: 'alive-ng-flutter-app.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:
        'AIzaSyBiDmtEjFx84binj7uKkROtx39NYcp3Q80', // From GoogleService-Info.plist
    appId:
        '1:234909240985:ios:17ffc2d5b91ce9718e3208',
    messagingSenderId: '234909240985',
    projectId: 'alive-ng-flutter-app',
    storageBucket: 'alive-ng-flutter-app.appspot.com',
    iosBundleId: 'com.alive.alivengiosapp',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey:
        'AIzaSyDmpl9Idp9Q0ult4BfWPg5J7A1URQOpDoU', // Using Android API key for web
    appId:
        '1:234909240985:web:9d703098e9fcce3e8e3208', // Web App ID based on Android config
    messagingSenderId: '234909240985',
    projectId: 'alive-ng-flutter-app',
    authDomain: 'alive-ng-flutter-app.firebaseapp.com',
    storageBucket: 'alive-ng-flutter-app.appspot.com',
    measurementId: 'G-234909240985', // Measurement ID based on project number
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

      // Initialize Firebase Messaging
      await _initializeMessaging();

      // Initialize Firebase Analytics
      await _initializeAnalytics();

      // Initialize Firebase Crashlytics
      await _initializeCrashlytics();

      debugPrint('Firebase initialized successfully');
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

  /// Initialize Firebase Analytics
  static Future<void> _initializeAnalytics() async {
    try {
      final analytics = FirebaseAnalytics.instance;

      // Enable analytics collection
      await analytics.setAnalyticsCollectionEnabled(true);

      // Set default event parameters
      await analytics.setDefaultEventParameters({
        'app_version': '1.0.0',
        'platform': defaultTargetPlatform.name,
        'project': projectName,
      });

      debugPrint('Firebase Analytics initialized');
    } catch (e) {
      debugPrint('Error initializing Firebase Analytics: $e');
    }
  }

  /// Initialize Firebase Crashlytics
  static Future<void> _initializeCrashlytics() async {
    try {
      final crashlytics = FirebaseCrashlytics.instance;

      // Enable crashlytics collection
      await crashlytics.setCrashlyticsCollectionEnabled(true);

      // Set user identifier
      // This will be set when user logs in

      // Pass all uncaught "fatal" errors from the framework to Crashlytics
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      };

      // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      debugPrint('Firebase Crashlytics initialized');
    } catch (e) {
      debugPrint('Error initializing Firebase Crashlytics: $e');
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

  /// Send analytics event
  static Future<void> logEvent(
      String eventName, Map<String, dynamic> parameters) async {
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: eventName,
        parameters: parameters.cast<String, Object>(),
      );
    } catch (e) {
      debugPrint('Error logging analytics event: $e');
    }
  }

  /// Log user properties
  static Future<void> setUserProperties(Map<String, String> properties) async {
    try {
      final analytics = FirebaseAnalytics.instance;

      for (final entry in properties.entries) {
        await analytics.setUserProperty(
          name: entry.key,
          value: entry.value,
        );
      }
    } catch (e) {
      debugPrint('Error setting user properties: $e');
    }
  }

  /// Set user ID for analytics and crashlytics
  static Future<void> setUserId(String userId) async {
    try {
      // Set user ID for Analytics
      await FirebaseAnalytics.instance.setUserId(id: userId);

      // Set user identifier for Crashlytics
      await FirebaseCrashlytics.instance.setUserIdentifier(userId);

      debugPrint('User ID set: $userId');
    } catch (e) {
      debugPrint('Error setting user ID: $e');
    }
  }
}
