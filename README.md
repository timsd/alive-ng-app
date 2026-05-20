# ALIVE-NG Ministry Flutter App

A comprehensive Flutter application for the ALIVE-NG Ministry, providing features for spiritual growth, community engagement, health tracking, and mission activities.

## Current Migration Status

The app is mid-migration from Firebase/Jitsi/GetStream pieces to Appwrite,
LiveKit, and Coolify. Estimated overall migration progress is about 81%.
Do not remove remaining Firebase files only because Appwrite files now exist;
some admin, library, kids, chapter, notification, analytics, and sync modules
still import Firebase services and must be replaced one workflow at a time.

- Appwrite now backs auth/profile bootstrap, chat, prayer, testimonies,
  notification settings/reminder records, admin notification records, study, health,
  onboarding content, events, announcements, app update settings, approval link
  tokens, daily verse records/generation settings, donation records, donation
  projects/settings reads, and the Paystack function flow.
- LiveKit is the current meeting stack through the `createLiveKitToken`
  Appwrite function.
- `scripts/appwrite_infrastructure_schema.mjs` is the source of truth for
  databases, collections, buckets, teams, webhooks, topics, and function IDs.
- The current Appwrite server is `1.7.4`; use `npm run appwrite:dry-run` first,
  then `npm run appwrite:provision:legacy` for provisioning.
- Coolify web hosting is supported through the root `Dockerfile`, which builds
  Flutter web and serves it with Nginx. Supply Flutter build-time values through
  the `FLUTTER_BUILD_ARGS` build argument, and supply Firebase web push bridge
  values as Docker build args so `scripts/configure_web.dart` can fill the web
  service worker during the image build.

## Features

### Core Functionality
- **User Authentication**: Secure login/signup with Appwrite Auth
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
- **Appwrite**: Auth, project settings, functions, storage-backed chat, and in-progress data migration
- **Firebase legacy**: Still present for modules that have not yet been fully migrated
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

3. **Configure Appwrite and local environment**
   - Copy the required values into `.env` locally; do not commit secrets.
   - Add Appwrite Android/Web platforms in the Appwrite Console.
   - Run `npm run appwrite:dry-run` to inspect infrastructure changes.
   - Run `npm run appwrite:provision:legacy` only after the dry run looks right.

4. **Run the app**
   ```bash
   flutter run
   ```

### Platform-Specific Setup

### Android Release Bundle For Google Play Testing

Before building a Play Store bundle on another machine:

1. Install Android Studio with Android SDK and Build Tools.
2. Install a stable Flutter SDK that matches the project constraints.
3. Ensure Java/JDK is installed and available to Gradle.
4. Restore required runtime config files while migration is still in progress:
   - `android/app/google-services.json` for Firebase Messaging compatibility
5. Restore Android signing files:
   - `android/key.properties`
   - `android/app/alive-release.keystore`

Build steps:

```bash
flutter clean
flutter pub get
flutter build appbundle
```

Expected output:

```text
build/app/outputs/bundle/release/app-release.aab
```

Notes:
- This repo now targets Android Gradle Plugin `8.9.1`.
- This repo now targets Gradle `8.11.1`.
- If a machine has unstable TLS/network issues during Gradle downloads, use a more reliable network before changing the repo config.

#### Android
- Minimum SDK: 21 (Android 5.0)
- Target SDK: 33 (Android 13)
- Permissions configured in `android/app/src/main/AndroidManifest.xml`

#### iOS
- Minimum iOS version: 11.0
- Permissions configured in `ios/Runner/Info.plist`
- Firebase iOS configuration is needed only if remaining Firebase-compatible
  features are enabled for iOS before full migration.

## Configuration

### Environment Setup & Security
**CRITICAL**: This app requires environment variables for API keys and signing configurations. 
Please read [SETUP_ENV.md](SETUP_ENV.md) for detailed instructions on how to configure:
- API keys and endpoints for Appwrite, Paystack, LiveKit, Google OAuth, and any
  remaining Firebase-compatible native notification setup.
- Android Release Signing
- Development vs Production setups

### Environment Variables
Use Flutter `--dart-define` at build time. See [SETUP_ENV.md](SETUP_ENV.md) for the full list of required variables.

```bash
flutter run -d chrome \
  --dart-define=APPWRITE_ENDPOINT=... \
  --dart-define=APPWRITE_PROJECT_ID=... \
  --dart-define=APPWRITE_DATABASE_ID=... \
  --dart-define=LIVEKIT_URL=... \
  --dart-define=PAYSTACK_PUBLIC_KEY=... \
  --dart-define=PAYSTACK_CALLBACK_URL=...
```

For Coolify, configure these as Docker build arguments:

- `FLUTTER_BUILD_ARGS`
- `FIREBASE_API_KEY` or `FIREBASE_WEB_API_KEY`
- `FIREBASE_AUTH_DOMAIN` or `FIREBASE_WEB_AUTH_DOMAIN`
- `FIREBASE_PROJECT_ID` or `FIREBASE_WEB_PROJECT_ID`
- `FIREBASE_STORAGE_BUCKET` or `FIREBASE_WEB_STORAGE_BUCKET`
- `FIREBASE_MESSAGING_SENDER_ID` or `FIREBASE_WEB_MESSAGING_SENDER_ID`
- `FIREBASE_APP_ID` or `FIREBASE_WEB_APP_ID`
- `FIREBASE_MEASUREMENT_ID` or `FIREBASE_WEB_MEASUREMENT_ID`
- `RECAPTCHA_SITE_KEY` if web recaptcha is enabled

Do not pass private server secrets such as `APPWRITE_API_KEY`,
`PAYSTACK_SECRET_KEY`, `LIVEKIT_API_SECRET`, or `RESEND_API_KEY` to the Flutter
web image. Sync Appwrite function variables from local `.env` with:

```bash
npm run appwrite:function-vars
```

### Backend Services
- **Appwrite Auth**: email/password and OAuth-backed account flows
- **Appwrite Databases**: primary data store for migrated features
- **Appwrite Storage**: files and media for migrated upload flows
- **Appwrite Functions**: LiveKit token creation and Paystack server logic
- **Firebase compatibility**: push messaging, analytics/crash reporting, and
  legacy modules until their imports are removed


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

### Appwrite Services
- `AuthService` and `AppwriteAuthService`: account, profile, OAuth, and admin team sync.
- `AppwriteChatService`: real-time chat messages, attachments, and mentions.
- `DonationService` and `PaymentService`: donation records, Paystack initialization, projects, and settings.
- `AppwritePrayerService`, `AppwriteStudyService`, `AppwriteHealthService`, `AppwriteEventsService`, and `AppwriteContentService`: migrated app feature data.
- Legacy `FirebaseDatabaseService` remains only for modules not migrated yet.

```dart
final content = await AppwriteContentService.instance
    .getContentPageBySlug('onboarding');
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
- Legacy periodic and real-time sync layer.
- Still contains Firebase callers and is a remaining migration target.
- Do not remove Firebase rules/indexes until this area and related offline services are migrated.

```dart
final sync = SyncService.instance;
final result = await sync.syncAll();
```

### Chat And Meetings
- Chat uses the existing `lib/screens/chat` UI with Appwrite-backed services.
- Meetings use LiveKit with the Appwrite `createLiveKitToken` function.
- GetStream and Jitsi files/packages should stay removed or archived unless a remaining legacy file still references them.

```dart
final chat = AppwriteChatService();
await chat.loadMessageHistory(roomId);
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

### Utility Scripts
```bash
dart scripts/duplicate_dart_files.dart
npm run appwrite:ping
```

`npm run appwrite:ping` simulates the Appwrite platform handshake from this
repo. A 401 response from `/account` is acceptable for the ping because no user
session is supplied; the useful signal is that Appwrite responds for the project
and the web origin is allowed.

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

3. **Appwrite configuration**
   - Verify `APPWRITE_ENDPOINT`, `APPWRITE_PROJECT_ID`, and `APPWRITE_DATABASE_ID`
   - Confirm Android/Web platforms are present in the Appwrite Console
   - Run `npm run appwrite:dry-run` before provisioning
   - Run `npm run appwrite:ping` to confirm endpoint/project/web-origin reachability

4. **Legacy Firebase compatibility**
   - Keep Firebase config files while Firebase imports remain
   - Do not archive `firestore.rules`, `firestore.indexes.json`, or storage rules until all dependent modules migrate

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
