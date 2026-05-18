# Project Tools And Platforms

This file lists the major tools, platforms, SDKs, and external services currently used in this project.

Last updated from codebase review: 2026-05-18

## Migration Snapshot

The app is migrating from Firebase, Jitsi, and GetStream to Appwrite, LiveKit, and Coolify. Treat Firebase as a legacy compatibility layer until the remaining modules below are migrated.

Estimated overall migration progress: about 70%.

- Appwrite-backed and validated with `flutter analyze`: auth/profile bootstrap, chat, LiveKit token flow, Paystack payment functions, prayer, testimonies, notification settings records, study screen, health screen, onboarding content, events, announcements, and donation project/settings reads.
- Appwrite infrastructure schema is maintained in `scripts/appwrite_infrastructure_schema.mjs`.
- Provision safely against the current Appwrite 1.7.4 server with `npm run appwrite:dry-run` and then `npm run appwrite:provision:legacy`.
- Coolify web hosting is supported by the root `Dockerfile`; pass Flutter values through the `FLUTTER_BUILD_ARGS` build argument.
- Firebase rules, indexes, and config files remain in place because several modules still import Firebase directly.

## Core App Stack

- Flutter and Dart: main app framework and language.
- Flutter Riverpod: primary state management.
- Go Router: app navigation.
- Appwrite Dart SDK: primary backend SDK for migrated app flows.
- Local storage: Shared Preferences, Flutter Secure Storage, SQLite/Sqflite, and bundled assets.

## Primary Backend: Appwrite

- Auth: email/password, OAuth redirects, profile synchronization, and team-based admin sync.
- Databases: project data, chat, prayer, testimonies, donation records, study, health, content pages, events, announcements, settings, and admin migration targets.
- Storage buckets: chat files, profile files, board documents, tract files, podcast media, content media, meeting files, and system exports.
- Functions:
  - `createLiveKitToken`
  - `paystack_payments`
  - `paystack_webhook`
- Teams: admin and ministry role/team configuration from the infrastructure schema.
- Webhooks/topics: declared in `scripts/appwrite_infrastructure_schema.mjs` for migrated storage, profile approval, donation, and messaging flows.

## Hosting And Deployment

- Coolify: intended production host for Flutter web through the root `Dockerfile`.
- Nginx: runtime web server inside the Docker image.
- GitHub: source control and deployment trigger source.
- GitHub Actions Play Store deployment is not currently enabled because Android signing and Play Console credentials must be provided as secrets first.

## Payments And Donation Services

- Paystack remains the payment processor.
- Public Paystack key is client-side build configuration.
- Secret Paystack key belongs only in Appwrite function variables.
- Donation records and project metadata are now read/written through Appwrite services in migrated flows.

## Communication

- Chat: Appwrite database + Appwrite Storage attachments through the existing `lib/screens/chat` UI.
- Meetings: LiveKit client SDK and the Appwrite `createLiveKitToken` function.
- Notifications:
  - Local notifications still use `flutter_local_notifications`.
  - Push token/device delivery still uses Firebase Messaging compatibility while Appwrite Messaging provider setup is completed.

## Legacy Firebase Compatibility

Firebase packages remain in `pubspec.yaml` for modules not migrated yet. Do not delete these until the direct imports are gone and `flutter analyze` stays clean.

- Firebase Core, Auth, Firestore, Storage, Functions, Messaging, Analytics, and Crashlytics are still present.
- Root Firebase files still needed during migration:
  - `.firebaserc`
  - `firebase.json`
  - `firestore.indexes.json`
  - `firestore.rules`
  - `android/app/google-services.json`
- These can move to `oldfirebasedelete/` only after all dependent modules are migrated or intentionally retired.

## Remaining Migration Areas

- Admin console screens and services: user archive, role management, content management, board reports/documents/decisions, kids admin, tract/podcast admin, and dashboard stats.
- Library, books, tracts, podcasts, kids stories/missions, missions, chapters, leadership, discipleship, daily verse, analytics, sync/offline sync, app update, email/approval links, and notification delivery internals.
- Firebase Storage wrappers should be replaced by Appwrite Storage wrappers bucket by bucket.
- Firebase Cloud Functions callers should move to Appwrite functions or direct Appwrite service calls.
- Firebase rules/indexes can be archived after the last Firestore caller is removed.

## Secrets And Runtime Parameters

Keep these out of Git. Configure them in `.env`, Coolify build variables, or Appwrite function variables as appropriate.

- `APPWRITE_ENDPOINT`
- `APPWRITE_PROJECT_ID`
- `APPWRITE_DATABASE_ID`
- `APPWRITE_API_KEY`
- `FLUTTER_BUILD_ARGS`
- `LIVEKIT_URL`
- `LIVEKIT_API_KEY`
- `LIVEKIT_API_SECRET` or legacy-compatible `LIVEKIT_SECRET`
- `PAYSTACK_PUBLIC_KEY`
- `PAYSTACK_SECRET_KEY`
- `PAYSTACK_CALLBACK_URL`
- `RESEND_API_KEY`
- `RECEIPT_SENDER_EMAIL`
- `WEB_PUSH_CERT_KEY`
- `WEB_PUSH_PRIVATE_KEY` when Appwrite/web push provider setup is ready

## Maintenance Notes

- Run `flutter analyze` after each migration slice.
- Run `dart tool/scripts/duplicate_dart_files.dart` to inspect duplicate Dart filenames.
- Keep migrated Firebase files in `oldfirebasedelete/` only after confirming the replacement path is live.
- Keep `scripts/appwrite_infrastructure_schema.mjs` as the source of truth for Appwrite infrastructure until `appwrite.config.json` can fully represent this self-hosted Appwrite version.
