# ALIVE Nigeria App

ALIVE Nigeria is a Flutter ministry app for discipleship, prayer, Bible study,
health education, missions, donations, chat, meetings, kids content, tracts,
podcasts, and administrative coordination.

The app is built as a single Flutter codebase for Android, web, Windows, and
other Flutter-supported platforms. The current production direction is Appwrite
for backend services, Coolify for web deployment, LiveKit for meetings, Paystack
for payments, and Resend-backed Appwrite Functions for email.

## What The App Provides

- Appwrite email/OAuth authentication and user profile management
- Admin approval flow with approval links and notification records
- Real-time Appwrite chat with attachments, mentions, and channel metadata
- Prayer requests, testimonies, daily verses, study guides, and Bible progress
- Bible reader and offline local Bible support
- Tracts, books, podcasts, kids stories, kids missions, and learning resources
- Donation projects, downloadable materials, Paystack payment initialization,
  and secure webhook processing
- Chapter, board, leadership, discipleship, and meeting-file administration
- LiveKit meetings through an Appwrite token function
- Appwrite Messaging records and local reminders, with Firebase Cloud Messaging
  retained only as the Android/Web push delivery bridge

## Current Stack

- **Architecture:** Ports & Adapters (Hexagonal Architecture) — all 3rd-party SDKs (Appwrite, LiveKit, Paystack, SQLite) are strictly isolated behind abstract ports in `lib/services/ports/` and implemented via concrete adapters in `lib/services/adapters/`. Full details in [Architecture ADR](docs/architecture.md).
- **Frontend:** Flutter, Riverpod (pinned `^2.6.1`), GoRouter (pinned `^14.0.0`), Material 3 theming
- **Backend:** Appwrite Dart SDK (`^26.1.0`), Auth, Databases/TablesDB, Storage, Functions, Teams,
  Messaging topics, and Webhooks
- **Web hosting:** Coolify Docker build serving Flutter web through Nginx
- **Meetings:** LiveKit (isolated behind `MeetingGateway` port)
- **Payments:** Paystack (isolated behind `PaymentGateway` port; server-side functions for verification/webhooks)
- **Email:** Resend via the `send_email` Appwrite Function
- **Local data:** SQLite/Sqflite (confined to `*_database_helper.dart`), SharedPreferences, Secure Storage
- **Remaining compatibility:** Firebase remains only for the FCM web/Android
  bridge used by Appwrite Messaging push delivery.
- **Crash reporting:** GlitchTip using the Sentry-compatible Flutter SDK
- **Analytics:** Appwrite `analytics_events` plus local session/event storage

## Repository Layout

```text
lib/
  config/          Build-time config and backend IDs
  constants/       App constants
  models/          Owned domain models (AppUser, MeetingSession, PaymentRequest, BibleVerse)
  providers/       Riverpod state providers (consume ports, zero SDK imports)
  screens/         User and admin UI (consume providers and domain models)
  services/
    ports/         Abstract gateway contracts (AuthGateway, MeetingGateway, PaymentGateway)
    adapters/      Concrete SDK implementations (AppwriteAuthGateway, LiveKitMeetingGateway, PaystackPaymentGateway)
    ...            Feature services and database helpers
  utils/           Routing, theming, helpers, validation, responsiveness
  widgets/         Reusable UI components

docs/              Architecture ADR, setup guides, and operational notes
scripts/           Appwrite provisioning, build config, and content tooling
appwrite_functions/ Appwrite Functions source
assets/            Bundled images, fonts, Bible/content assets
```

## Required Local Setup

Install:

- Flutter SDK
- Dart SDK
- Node.js 20+
- Android Studio or the Android command-line tools
- Git

Install dependencies:

```bash
flutter pub get
npm install
```

Create a local `.env` for scripts and server-side provisioning. Do not commit
secrets. Flutter runtime values should be passed with `--dart-define` or through
Coolify build arguments.

Key public Flutter build values:

```bash
--dart-define=APPWRITE_ENDPOINT=...
--dart-define=APPWRITE_PROJECT_ID=...
--dart-define=APPWRITE_DATABASE_ID=...
--dart-define=APPWRITE_FCM_PROVIDER_ID=...
--dart-define=LIVEKIT_URL=...
--dart-define=PAYSTACK_PUBLIC_KEY=...
--dart-define=PAYSTACK_CALLBACK_URL=...
--dart-define=GLITCHTIP_DSN=...
--dart-define=GLITCHTIP_ENVIRONMENT=production
```

Keep private values such as `APPWRITE_API_KEY`, `PAYSTACK_SECRET_KEY`,
`LIVEKIT_API_SECRET`, and `RESEND_API_KEY` server-side only. They belong in
local `.env`, Appwrite Function variables, or deployment secrets, not in Flutter
web output.

## Appwrite Infrastructure

The source of truth for Appwrite infrastructure is:

```text
scripts/appwrite_infrastructure_schema.mjs
scripts/provision_appwrite_infrastructure.mjs
```

Preview changes:

```bash
npm run appwrite:dry-run
```

Apply changes when the Appwrite endpoint is reachable:

```bash
npm run appwrite:provision
```

If the current Appwrite server requires legacy database endpoints:

```bash
npm run appwrite:provision:legacy
```

Sync function variables and deploy function code:

```bash
npm run appwrite:function-vars
npm run appwrite:deploy-functions
```

Useful setup docs:

- `docs/appwrite-coolify-livekit-setup.md`
- `docs/appwrite-migration-readiness.md`
- `docs/oracle-free-tier-deployment-roadmap.md`
- `docs/paystack_functions_reference.md`

## Run The App

Run on Chrome:

```bash
flutter run -d chrome
```

Run on Android:

```bash
flutter run -d android
```

Run analysis:

```bash
flutter analyze
```

Run tests:

```bash
flutter test
```

## Web Deployment With Coolify

The root `Dockerfile` builds Flutter web and serves it with Nginx.

Set Coolify build argument:

```text
FLUTTER_BUILD_ARGS=--dart-define=APPWRITE_ENDPOINT=... --dart-define=APPWRITE_PROJECT_ID=... --dart-define=APPWRITE_DATABASE_ID=... --dart-define=LIVEKIT_URL=... --dart-define=GLITCHTIP_DSN=...
```

Also configure public FCM web-push bridge values only while the web service
worker remains in use. Do not pass private secrets as build args.

## Android Release

Required private files are intentionally not committed:

```text
android/key.properties
android/app/alive-release.keystore
android/app/google-services.json
```

Build a Play Store bundle:

```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

Output:

```text
build/app/outputs/bundle/release/app-release.aab
```

## Security Notes

- Paystack card data must never touch this app server. Paystack handles card
  entry and PCI-sensitive processing.
- Paystack webhook endpoints must verify Paystack signatures before updating
  donation records.
- LiveKit API secret, Appwrite API key, Resend API key, and Paystack secret key
  must stay server-side.
- Appwrite platform entries must include the Android package name and the final
  web domain, for example `https://app.alivenigeria.org`.

## Migration And Archive Policy

The app is code-side migrated to Appwrite for database, storage, auth,
analytics/event tracking, and function-backed workflows. Firebase is retained
only for FCM push delivery. Legacy Firebase Functions, Firestore rules/indexes,
Firebase Hosting config, and the old Express/Firebase Admin sidecar have been
removed from the active repository after replacement by `appwrite_functions/`
and Appwrite infrastructure scripts.

Current remaining migration targets are primarily:

- Appwrite Messaging provider validation for the final FCM delivery path
- Browser QA once the Coolify/Appwrite endpoint is reachable

## Project Health Commands

```bash
flutter analyze
npm run appwrite:dry-run
npm run appwrite:ping
```

Duplicate Dart filename check:

```bash
dart scripts/duplicate_dart_files.dart android appwrite_functions assets build docs ios lib scripts test tool tools web windows
```

## Support

Project repository:

```text
https://github.com/timsd/alive-ng-app
```

Production app domain:

```text
https://app.alivenigeria.org
```
