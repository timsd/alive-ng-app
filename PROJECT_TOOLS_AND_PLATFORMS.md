# Project Tools And Platforms

This file lists the major tools, platforms, SDKs, and external services currently used in this project.

Last updated from codebase review: 2026-05-21

## Migration Snapshot

The app is migrating from Firebase, Jitsi, and GetStream to Appwrite, LiveKit, and Coolify. Treat Firebase as a legacy compatibility layer until the remaining modules below are migrated.

Estimated overall migration progress: about 86%.

- Appwrite-backed and validated with `flutter analyze`: auth/profile bootstrap, chat, LiveKit token flow, Paystack payment functions, Resend email function wiring/deployment variables, Appwrite push target registration, prayer, testimonies, notification settings/reminder records, admin notification records, study screen, health screen, daily verse records/generation settings, onboarding content, events, announcement editing, public missions, podcast listing/episode provider, app update settings, approval link tokens, donation project/settings reads, kids stories/missions public screens, and the tract/board storage compatibility bridge.
- Appwrite infrastructure schema is maintained in `scripts/appwrite_infrastructure_schema.mjs`.
- Provision safely against the current Appwrite 1.7.4 server with `npm run appwrite:dry-run` and then `npm run appwrite:provision:legacy`.
- Coolify web hosting is supported by the root `Dockerfile`; pass Flutter values through the `FLUTTER_BUILD_ARGS` build argument and pass Firebase web push bridge values as Docker build args so the service worker is configured during image build.
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
  - `send_email`
- Teams: admin and ministry role/team configuration from the infrastructure schema.
- Topics: declared in `scripts/appwrite_infrastructure_schema.mjs` for migrated messaging flows.
- Optional webhooks: profile approval, chat file upload, and donation record event forwarding are declared but skipped unless external receiver URLs are supplied.
- App update prompts read Appwrite `app_settings` document `app_version`.
  Store either a plain version in `value`, or JSON such as `{"latest_version":"1.2.3","force_update":false,"update_url":"https://app.alivenigeria.org"}`.
  The project script `npm run appwrite:app-version` upserts this document automatically from `.env` and `pubspec.yaml`.
- Appwrite function variables for LiveKit, Paystack, Paystack webhook, and Resend email can be synced from `.env` with `npm run appwrite:function-vars`.
  The local Appwrite function code can be created/updated and deployed with `npm run appwrite:deploy-functions`.
  Use `npm run appwrite:provision:admin-notifications` when only the admin notification table needs to be applied.

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
- Paystack card entry must stay inside Paystack Checkout or Paystack SDK surfaces.
  The app and Appwrite functions must never accept raw card number, PAN, CVV/CVC, or expiry fields.
- Paystack webhook handling lives in the `paystack_webhook` Appwrite function and verifies `x-paystack-signature` with HMAC-SHA512 before mutating donation records.
  Configure Paystack to call the generated Appwrite Function domain for `paystack_webhook`; do not use the SDK execution endpoint unless the sender can supply Appwrite project headers.

## Communication

- Chat: Appwrite database + Appwrite Storage attachments through the existing `lib/screens/chat` UI.
- Meetings: LiveKit client SDK and the Appwrite `createLiveKitToken` function.
- Notifications:
  - Local notifications and reminders use `flutter_local_notifications`.
  - Appwrite notification settings and topics are provisioned.
  - Web FCM service worker is present only as the Appwrite Messaging/FCM browser push bridge.
  - Remote push delivery requires Appwrite Messaging provider setup and target/subscriber registration before Firebase Messaging can be fully removed.
  - Recommended provider path for this project:
    - Push notifications: Appwrite Messaging with FCM for Android/Web. Add APNs later if iOS shipping becomes active.
    - Transactional email: keep Resend server-side through the Coolify/server or Appwrite Function path; do not put the Resend API key in Flutter.
  - FCM setup requires Firebase project server credentials in Appwrite Messaging. The public `WEB_PUSH_CERT_KEY` helps the browser request a web push token, but it is not enough for Appwrite to send push by itself.
  - If the Appwrite FCM provider ID is not the default, pass it to Flutter as `APPWRITE_FCM_PROVIDER_ID`.

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

- Admin console screens and services: user archive, role management, content management, board reports/documents/decisions, kids admin/editing, tract/podcast admin, and dashboard stats.
- Library, books, tracts, podcast playback/download actions, chapters, leadership, discipleship, analytics, sync/offline sync, mission participation/progress internals, and notification delivery internals.
- Remaining Firebase Storage wrappers should be replaced by Appwrite Storage wrappers bucket by bucket.
- Firebase Cloud Functions callers should move to Appwrite functions or direct Appwrite service calls.
- Firebase rules/indexes can be archived after the last Firestore caller is removed.

## Secrets And Runtime Parameters

Keep these out of Git. Configure them in `.env`, Coolify build variables, or Appwrite function variables as appropriate.

- `APPWRITE_ENDPOINT`
- `APPWRITE_PROJECT_ID`
- `APPWRITE_DATABASE_ID`
- `APPWRITE_API_KEY`
- `APPWRITE_FCM_PROVIDER_ID` only if the Appwrite FCM provider ID is not the default/only push provider
- `FLUTTER_BUILD_ARGS`
- `LIVEKIT_URL`
- `LIVEKIT_API_KEY`
- `LIVEKIT_API_SECRET` or legacy-compatible `LIVEKIT_SECRET`
- `PAYSTACK_PUBLIC_KEY`
- `PAYSTACK_SECRET_KEY`
- `PAYSTACK_CALLBACK_URL`
- `RESEND_API_KEY`
- `RECEIPT_SENDER_EMAIL`
- `WEB_PUSH_PRIVATE_KEY` and matching public key only when Appwrite web push provider setup is ready
- `APPWRITE_PROFILE_APPROVAL_WEBHOOK_URL` only if forwarding profile approval updates to an external receiver
- `APPWRITE_CHAT_FILE_WEBHOOK_URL` only if forwarding chat upload events to an external receiver
- `APPWRITE_DONATION_WEBHOOK_URL` only if forwarding donation record events to an external receiver

## Maintenance Notes

- Run `flutter analyze` after each migration slice.
- Run `dart tool/scripts/duplicate_dart_files.dart` to inspect duplicate Dart filenames.
- Keep migrated Firebase files in `oldfirebasedelete/` only after confirming the replacement path is live.
- Keep `scripts/appwrite_infrastructure_schema.mjs` as the source of truth for Appwrite infrastructure until `appwrite.config.json` can fully represent this self-hosted Appwrite version.
