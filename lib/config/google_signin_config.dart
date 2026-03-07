import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class GoogleSignInConfig {
  // Web client ID from Firebase Console - using correct client ID
  static const String webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '234909240985-1dernhsf9qmkau7idp4hn1nudegpd5ju.apps.googleusercontent.com',
  );

  // Android client ID (from google-services.json)
  static const String androidClientId = String.fromEnvironment(
    'GOOGLE_ANDROID_CLIENT_ID',
    defaultValue:
        '234909240985-8fvqsqs734jgtnqf38d7e6uesp4rbn78.apps.googleusercontent.com',
  );

  // iOS client ID (from GoogleService-Info.plist)
  static const String iosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue:
        '234909240985-jr2767d4lmp9plt62fk6j3colff51gue.apps.googleusercontent.com',
  );

  static GoogleSignIn get instance {
    if (kIsWeb) {
      return GoogleSignIn(
        clientId: webClientId,
        scopes: [
          'email',
          'profile',
        ],
      );
    } else {
      // For mobile platforms, the client ID is automatically read from
      // google-services.json (Android) or GoogleService-Info.plist (iOS)
      return GoogleSignIn(
        scopes: [
          'email',
          'profile',
        ],
      );
    }
  }

  /// Initialize Google Sign-In for the current platform
  static Future<void> initialize() async {
    try {
      // The GoogleSignIn instance will be automatically configured
      // based on the platform-specific configuration files
      await instance.signInSilently();
    } catch (e) {
      // Silent sign-in failed, which is normal for first-time users
      if (kDebugMode) {
        debugPrint('Google Sign-In silent sign-in failed: $e');
      }
    }
  }
}
