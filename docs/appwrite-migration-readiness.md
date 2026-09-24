# Appwrite Migration Readiness

Last reviewed: 2026-05-26

## Chat UI

Gemini's proposed `lib/views/chat_room_screen.dart` should not be added as-is.
The app already has a richer Appwrite-backed chat surface in
`lib/screens/chat/chat_screen.dart`, using:

- `ChatService`, which delegates to `AppwriteChatService`.
- `ChatInputWidget`, which uploads chat images/files to Appwrite Storage.
- `ChatMessageWidget`, which supports attachments, mentions, replies, copy, and sender actions.
- LiveKit meeting entry from general chat channels.

The useful part of Gemini's idea is already present: message history, Appwrite
send flow, media upload, and a real-time-capable Appwrite service. The proposed
snippet would duplicate the existing screen, use the wrong `sendMessage`
signature, omit the app's channel list and mention tooling, and introduce a
new `lib/views` location that does not match the current `lib/screens/...`
organization.

## Appwrite Resource Status

- Settings: app settings are represented in the infrastructure schema and app code; dashboard values still need final production review after the server is reachable.
- Functions: `createLiveKitToken`, `paystack_payments`, `paystack_webhook`, and `send_email` are represented by local Appwrite function folders and deployment scripts.
- Databases / collections: the schema source of truth is `scripts/appwrite_infrastructure_schema.mjs`; `npm run appwrite:dry-run` is clean.
- Buckets: chat files, profile files, board documents, tracts/books, podcast media, content media, meeting files, and system exports are declared.
- Teams: administrators, BOD, trustees, directors, chapter leaders, content editors, and moderators are declared.
- Webhooks: profile approval, chat file, and donation record webhooks are optional and skipped until the corresponding `APPWRITE_*_WEBHOOK_URL` values are present.
- Topics / Messaging: all user, admin, BOD, directors, chapter leaders, approvals, prayer, chat, donations, events, study, kids, health, and content topics are declared.

Current blocker: the Appwrite endpoint and `app.alivenigeria.org` may still be
unreachable depending on the current server/proxy/firewall/DNS/Coolify state.
Local schema validation is clean with `npm run appwrite:dry-run`; rerun
`npm run appwrite:provision` or `npm run appwrite:provision:legacy` after the
server is reachable.

## Deployment Gate

Do not run `appwrite push all --all` or a blind full Firebase-to-Appwrite
migration. The safer path for this Appwrite 1.7.4 server is the checked
provisioning script in legacy Databases mode, followed by per-service data
migration and verification.

Use this safer sequence for remaining migration:

1. Keep running `npm run appwrite:dry-run` before schema changes.
2. Apply schema with `npm run appwrite:provision:legacy`.
3. Deploy functions one group at a time after dashboard env vars are set.
4. Run any remaining historical Firebase data migration per collection/bucket
   only after each Appwrite target is verified.
5. Push targets are Appwrite-native; no Firebase bridge files are needed in the app.

## Firebase Removal

Firebase has been **fully removed from the client app**. There is no Firebase
dependency, config file, or service worker left in the repository.

### Deleted
- `firebase_core` and `firebase_messaging` from `pubspec.yaml` (and `pubspec.lock`).
- `lib/config/firebase_config.dart`.
- `lib/services/firebase_messaging_base.dart`.
- `web/firebase-messaging-sw.js`.
- `"gcm_sender_id"` from `web/manifest.json`.
- `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`.
- The `com.google.gms.google-services` Gradle plugin (project + app level) and the
  `firebase-bom` / `firebase-messaging` Android dependencies.
- `FirebaseApp.configure()` and the Firebase imports in `ios/Runner/AppDelegate.swift`.
- Firebase `messaging` meta-data from `android/app/src/main/AndroidManifest.xml`.
- `FIREBASE_*` placeholders from `scripts/configure_web.dart`.

### Replacement
- **Push targets/subscriptions:** `lib/services/appwrite_push_service.dart`
  (Appwrite `Account.createPushTarget` + `Messaging.createSubscriber`).
- **Local/device notifications:** `flutter_local_notifications`, driven by
  `lib/services/notification_service.dart`.
- **Analytics:** `lib/services/analytics_service.dart` (Appwrite TablesDB).
- **Crash reporting:** `lib/services/crash_reporting_service.dart` (GlitchTip/Sentry).

Firebase Hosting config, Firestore rules/indexes, legacy Firebase Functions,
static Firebase donation/project pages, old archived service copies, and the old
Express/Firebase Admin sidecar had already been removed from the active repository.

## Current Appwrite Client Migration

- Appwrite auth/profile, chat, LiveKit token creation, testimonies, notification settings storage, donation records/material downloads, gift submissions, Paystack initialization/webhook code, kids content CRUD/seeding, tract/podcast admin flows, enhanced health service, chapter management, leadership records/transitions, discipleship tracking, and meeting file storage/metadata are now wired.
- **Hexagonal Architecture Decoupling**: All direct Appwrite SDK model types (`models.User`, etc.) have been completely removed from UI screens and controllers. Auth is encapsulated behind `AuthGateway` (`lib/services/ports/auth_gateway.dart`) and implemented via `AppwriteAuthGateway` (`lib/services/adapters/appwrite_auth_gateway.dart`), returning owned `AppUser` domain models.
- **SDK Upgrade**: The Appwrite Dart SDK has been upgraded to `^26.1.0` in `pubspec.yaml`, with breaking API changes resolved exclusively inside the adapter layer without touching UI screens.
- Bible game flow has been stabilized locally: nullable state reset works, multiple-choice options are stable per verse, blank generation avoids fragile words, and the daily verse corpus is no longer shuffled globally.
- Push notification delivery is Appwrite-native (`AppwritePushService` + Appwrite Messaging), with locally scheduled reminders via `flutter_local_notifications`.
- `DonationService` no longer imports Firebase; downloadable material URLs should now be Appwrite/external URLs, not Firebase Storage URLs.
- The old `FirebaseStorageService` facade has been renamed to `AppwriteStorageCompatService`; it remains a temporary compatibility layer for board and tract storage methods.
- Legacy service copies under `oldfirebasedelete/` were deleted after Appwrite replacements passed analysis.

## Play Store GitHub Actions

GitHub Actions can build Android release artifacts on a free GitHub account for
normal repository usage, but Play Store upload requires secrets such as the
keystore, key aliases/passwords, and Google Play service account JSON. A deploy
workflow should only be committed after those secret names and signing strategy
are finalized.
