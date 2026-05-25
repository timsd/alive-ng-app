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
- Appwrite Messaging/FCM-compatible notification direction, with local reminder
  support while final messaging migration is completed

## Current Stack

- **Frontend:** Flutter, Riverpod, GoRouter, Material theming
- **Backend:** Appwrite Auth, Databases/TablesDB, Storage, Functions, Teams,
  Messaging topics, and Webhooks
- **Web hosting:** Coolify Docker build serving Flutter web through Nginx
- **Meetings:** LiveKit
- **Payments:** Paystack, handled server-side through Appwrite Functions
- **Email:** Resend via the `send_email` Appwrite Function
- **Local data:** SQLite/Sqflite, SharedPreferences, Secure Storage
- **Remaining compatibility:** Some legacy Firebase bridge code remains only
  where active screens still depend on it. Do not delete Firebase config, rules,
  indexes, or packages until those imports are fully gone.

## Repository Layout

```text
lib/
  config/          Build-time config and backend IDs
  constants/       App constants
  models/          Shared data models
  providers/       Riverpod providers
  screens/         User and admin UI
  services/        Appwrite, local, payment, messaging, and feature services
  utils/           Routing, theming, helpers, validation, responsiveness
  widgets/         Reusable UI components

scripts/           Appwrite provisioning, build config, and content tooling
functions/         Appwrite Functions source
server/            Supporting Node server utilities
assets/            Bundled images, fonts, Bible/content assets
docs/              Operational setup and migration notes
oldfirebasedelete/ Archived legacy files kept for reference during migration
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
FLUTTER_BUILD_ARGS=--dart-define=APPWRITE_ENDPOINT=... --dart-define=APPWRITE_PROJECT_ID=... --dart-define=APPWRITE_DATABASE_ID=... --dart-define=LIVEKIT_URL=...
```

Also configure public Firebase web-push bridge values only while the FCM web
service worker remains in use. Do not pass private secrets as build args.

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

The app is almost fully migrated to Appwrite, but a few active modules still use
the compatibility bridge. Legacy files that are no longer imported are moved to
`oldfirebasedelete/` first instead of being deleted immediately. This keeps a
safe rollback/reference trail while the final Firebase removal is completed.

Current remaining migration targets are primarily:

- Firebase Messaging bridge to final Appwrite Messaging/FCM flow
- Admin/library/offline screens still importing `FirebaseDatabaseService`
- Legacy Firebase config/rules/indexes after all active imports are gone

## Project Health Commands

```bash
flutter analyze
npm run appwrite:dry-run
npm run appwrite:ping
```

Duplicate Dart filename check:

```bash
dart scripts/duplicate_dart_files.dart android appwrite_functions assets build docs firebase functions ios lib scripts server test tool tools web windows
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
