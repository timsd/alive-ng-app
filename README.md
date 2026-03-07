# ALIVE-NG Ministry Flutter App

A comprehensive Flutter application for the ALIVE-NG Ministry, providing features for spiritual growth, community engagement, health tracking, and mission activities.

## Features

### Core Functionality
- **User Authentication**: Secure login/signup with Firebase Auth
- **Prayer Requests**: Submit and track prayer requests
- **Health Activities**: Monitor physical and spiritual wellness
- **Study Programs**: Access Bible studies and educational content
- **Mission Activities**: Participate in outreach and evangelism
- **Daily Verses**: Receive daily scripture and devotionals
- **Community**: Connect with other ministry members
- **Notifications**: Push and local notifications for reminders
- **Location Services**: Find nearby churches and events

### Technical Features
- **Offline Support**: Local data storage and sync
- **Real-time Updates**: Live data synchronization
- **Analytics**: User behavior tracking and insights
- **Multi-platform**: Android and iOS support
- **Responsive Design**: Adaptive UI for different screen sizes
- **Internationalization**: Multi-language support

## Architecture

### State Management
- **Riverpod**: For state management and dependency injection
- **Provider Pattern**: Clean separation of business logic

### Data Layer
- **Firebase**: Firestore, Auth, Storage, Messaging, Analytics, Crashlytics
- **Local Storage**: SharedPreferences and Secure Storage
- **Sync Service**: Automatic data synchronization

### Services
- **Authentication Service**: User management and security
- **Notification Service**: Push and local notifications
- **Analytics Service**: User behavior tracking
- **Location Service**: GPS and location-based features
- **Storage Service**: Local data persistence
- **API Service**: HTTP requests and caching

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── user_model.dart
│   ├── prayer_request_model.dart
│   ├── health_activity_model.dart
│   └── ...
├── screens/                  # UI screens
│   ├── auth/
│   ├── dashboard/
│   ├── prayer/
│   ├── health/
│   └── ...
├── widgets/                  # Reusable UI components
│   ├── custom_button.dart
│   ├── custom_card.dart
│   ├── custom_form.dart
│   ├── custom_image.dart
│   ├── custom_layout.dart
│   └── ...
├── services/                 # Business logic services
│   ├── auth_service.dart
│   ├── notification_service.dart
│   ├── analytics_service.dart
│   ├── location_service.dart
│   ├── storage_service.dart
│   ├── api_service.dart
│   ├── sync_service.dart
│   └── native_service.dart
├── utils/                    # Utility functions
│   ├── constants.dart
│   ├── helpers.dart
│   ├── validators.dart
│   └── theme.dart
└── l10n/                     # Internationalization
    ├── app_en.arb
    └── app_localizations.dart
```

## Setup Instructions

### Prerequisites
- Flutter SDK (3.0.0 or higher)
- Dart SDK (2.17.0 or higher)
- Android Studio / VS Code
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd alive_flutter_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Add Android and iOS apps to your Firebase project
   - Download and replace the configuration files:
     - `android/app/google-services.json` (Android)
     - `ios/Runner/GoogleService-Info.plist` (iOS)

4. **Configure Firebase**
   - Create a Firebase project 
   - Update the Firebase configuration in your environment variables or constants file

5. **Run the app**
   ```bash
   flutter run
   ```

### Platform-Specific Setup

#### Android
- Minimum SDK: 21 (Android 5.0)
- Target SDK: 33 (Android 13)
- Permissions configured in `android/app/src/main/AndroidManifest.xml`

#### iOS
- Minimum iOS version: 11.0
- Permissions configured in `ios/Runner/Info.plist`
- Firebase configuration in `ios/Runner/GoogleService-Info.plist`

## Configuration

### Environment Setup & Security
**CRITICAL**: This app requires environment variables for API keys and signing configurations. 
Please read [SETUP_ENV.md](SETUP_ENV.md) for detailed instructions on how to configure:
- API Keys (Firebase, Paystack, reCAPTCHA, etc.)
- Android Release Signing
- Development vs Production setups

### Environment Variables
Use Flutter `--dart-define` at build time. See [SETUP_ENV.md](SETUP_ENV.md) for the full list of required variables.

```bash
flutter run -d chrome \
  --dart-define=PAYSTACK_PUBLIC_KEY=... \
  --dart-define=RECAPTCHA_SITE_KEY=... \
  --dart-define=FIREBASE_WEB_API_KEY=...
```

### Firebase Services
- **Authentication**: Email/password, social login
- **Cloud Messaging**: Push notifications
- **Analytics**: User behavior tracking
- **Crashlytics**: Error reporting
- **Authentication**: User management
- **Storage**: File uploads and management
- **Edge Functions**: Server-side logic
- **Database**: with real-time subscriptions


## Development

### Code Style
- Follow [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use `flutter analyze` for static analysis
- Use `flutter test` for running tests

### State Management Patterns
```dart
// Provider definition
final userProvider = StateNotifierProvider<UserNotifier, User?>((ref) {
  return UserNotifier(ref.read(authServiceProvider));
});

// Usage in widgets
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    return Text(user?.name ?? 'Guest');
  }
}
```

### Service Integration
```dart
// Service usage
final authService = ref.read(authServiceProvider);
final result = await authService.signIn(email, password);

if (result.success) {
  // Handle success
} else {
  // Handle error
}
```

## API Services

### ApiService
- Provides HTTP client with interceptors, retry, and optional caching
- Base URL switches by build mode (dev vs prod)
- Key methods: get, post, put, patch, delete, uploadFile, downloadFile
- Reference: [api_service.dart](file:///c:/Users/Zavolah/Documents/ZavTech%20Projects/alive-ng-app/lib/services/api_service.dart)

```dart
final res = await ApiService.instance.get<Map<String, dynamic>>(
  '/verses',
  queryParameters: {'q': 'john 3:16'},
  useCache: true,
  cacheMaxAge: const Duration(minutes: 10),
);
if (res.isSuccess) {
  final data = res.data;
}
```

### FirebaseDatabaseService
- Central Firestore, Auth, Storage, and Functions access
- Profiles, prayer requests, Bible data helpers
- Key methods: getUserProfile, createUserProfile, getPrayerRequests
- Reference: [firebase_database_service.dart](file:///c:/Users/Zavolah/Documents/ZavTech%20Projects/alive-ng-app/lib/services/firebase_database_service.dart)

```dart
final firebase = FirebaseDatabaseService.instance;
final profile = await firebase.getUserProfile(userId);
final requests = await firebase.getPrayerRequests();
```

### AuthService
- Auth flows with profile creation and helpers
- Key methods: signInWithEmail, signUpWithEmail, signOut, resetPassword
- Reference: [auth_service.dart](file:///c:/Users/Zavolah/Documents/ZavTech%20Projects/alive-ng-app/lib/services/auth_service.dart)

```dart
final auth = AuthService.instance;
final result = await auth.signInWithEmail('user@example.com', 'password');
if (result.isSuccess) {
  final user = result.user;
}
```

### NotificationService
- Push/local notifications and scheduling
- Supports navigation from notification payloads
- Key methods: initialize, scheduleNotification, updateNotificationSettings
- Reference: [notification_service.dart](file:///c:/Users/Zavolah/Documents/ZavTech%20Projects/alive-ng-app/lib/services/notification_service.dart)

```dart
await NotificationService.instance.initialize();
await NotificationService.instance.scheduleDailyVerseNotification(
  time: DateTime.now().add(const Duration(hours: 1)),
);
```

### SyncService
- Periodic and real-time Firestore synchronization
- Exposes status and updates via Riverpod streams
- Key methods: syncAll, enableRealtimeSync, disableRealtimeSync
- Reference: [sync_service.dart](file:///c:/Users/Zavolah/Documents/ZavTech%20Projects/alive-ng-app/lib/services/sync_service.dart)

```dart
final sync = SyncService.instance;
final result = await sync.syncAll();
```

### GetStreamChatService
- GetStream chat integration with Firebase profiles
- Channel creation, messaging, user search
- Reference: [getstream_chat_service.dart](file:///c:/Users/Zavolah/Documents/ZavTech%20Projects/alive-ng-app/lib/services/getstream_chat_service.dart)

```dart
final chat = GetStreamChatService();
await chat.initialize();
final channels = await chat.getUserChannels();
```

### OfflineBibleService
- Offline-first Bible access via bundled assets and local DB
- Chapter caching, search, version management
- Reference: [offline_bible_service.dart](file:///c:/Users/Zavolah/Documents/ZavTech%20Projects/alive-ng-app/lib/services/offline_bible_service.dart)

```dart
final bible = OfflineBibleService();
final books = await bible.getBibleBooks(language: 'en');
final chapter = await bible.getBibleChapter(book: 'John', chapter: 3, version: 'KJV', language: 'en');
```

## Testing

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
flutter test integration_test/
```

### Widget Tests
```bash
flutter test test/widget_test.dart
```

## Deployment

### Android
1. Build APK: `flutter build apk --release`
2. Build App Bundle: `flutter build appbundle --release`
3. Upload to Google Play Console

### iOS
1. Build iOS: `flutter build ios --release`
2. Archive in Xcode
3. Upload to App Store Connect

## Troubleshooting

### Common Issues

1. **Flutter not found**
   - Ensure Flutter is installed and added to PATH
   - Run `flutter doctor` to check setup

2. **Dependencies issues**
   - Run `flutter clean && flutter pub get`
   - Check pubspec.yaml for version conflicts

3. **Firebase configuration**
   - Verify configuration files are in correct locations
   - Check Firebase project settings

4. **Firebase connection**
   - Verify configuration files and project settings
   - Check network connectivity

### Debug Commands
```bash
# Check Flutter installation
flutter doctor

# Clean build cache
flutter clean

# Analyze code
flutter analyze

# Run with verbose logging
flutter run --verbose
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run tests and ensure they pass
6. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Email: dammyolodude@gmail.com
- Documentation: [Project Wiki](link-to-wiki)
- Issues: [GitHub Issues](link-to-issues)
