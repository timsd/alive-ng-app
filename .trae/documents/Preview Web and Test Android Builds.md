## Remaining Work
- Fix web build version mismatch for Firebase web plugins
- Generate `firebase_options.dart` via FlutterFire and refactor config
- Configure Android signing for release builds (debug works now)
- Harden Firestore security rules and composite indexes
- Reduce analyzer warnings (deprecated `.withOpacity`, unused fields, async context use)

## Web Preview Plan
- Upgrade packages: `flutter clean && flutter pub upgrade && flutter pub get`
- If web build still errors, pin compatible web plugin versions:
  - Ensure `firebase_core_web`, `firebase_auth_web`, `firebase_messaging_web`, `firebase_storage_web` align with Flutter 3.35.3
  - Prefer upgrading all Firebase packages together to latest compatible
- Run admin web locally: `flutter run -d chrome --target=lib/admin_preview_main.dart`
- Validate:
  - Admin dashboard navigation
  - Kids content admin (role-gated)
  - Landing page (`web/index.html`) hero + Play/App Store buttons + legal links
- After successful run, provide preview URL

## Android Test Plan
- Verify environment: `flutter doctor -v`
- Run debug build on device/emulator: `flutter run -d <device_id>`
- Smoke tests:
  - Auth (email/password), pending approval banners
  - Prayer wall: list, filter, create, pray count path
  - Study guides list and detail
  - Health screens (enhanced routes)
  - Push notifications (FCM token logs)
  - Router redirects and role-gating (admin routes)
- Optional release build: `flutter build apk --release`
  - If signing not yet configured, generate keystore and update `android/app/build.gradle.kts`

## FlutterFire Configuration
- Install CLI: `dart pub global activate flutterfire_cli`
- Configure: `flutterfire configure -o lib/firebase_options.dart`
- Refactor `lib/config/firebase_config.dart` to use `DefaultFirebaseOptions.currentPlatform`
- Remove hardcoded keys after refactor

## Firestore Rules & Indexes
- Add rules for collections: `profiles`, `prayer_requests`, `content_pages`, `board_documents` with role checks (`is_approved`, `role`)
- Create indexes for queries combining `where` and `orderBy` (e.g., prayer_requests by `category` + `created_at`)
- Keep `firestore.rules` and `firestore.indexes.json` in repo

## Analyzer Cleanup Focus
- Replace `.withOpacity(...)` with `.withValues(alpha: ...)` in files flagged (study, testimonies, theme_icon_utils, custom_app_bar)
- Remove unused fields/methods in services (admin_service, chapter_service, chat_service, etc.)
- Fix async context warnings by checking `mounted` or capturing local refs

## Next Actions (Upon Approval)
1) Attempt web preview on Chrome and share live preview link
2) Run Android app on connected device and report smoke test results
3) Generate FlutterFire options and refactor config
4) Draft Firestore rules/indexes for your review
5) Start warning cleanup pass on high-traffic screens
