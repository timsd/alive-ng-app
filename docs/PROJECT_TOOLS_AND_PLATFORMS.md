# Project Tools And Platforms

This file lists the major tools, platforms, SDKs, and external services currently used in this project.

Last updated from codebase review: 2026-10-31 (v2.0.5+12)

## Architecture & Migration Snapshot

The app follows the **Ports & Adapters (Hexagonal Architecture)** design pattern across all external integrations:
- **Zero SDK Leaks**: No third-party SDK type (Appwrite, LiveKit, Paystack, SQLite) may cross into `lib/providers/` or `lib/screens/`.
- **Abstract Ports**: Defined under `lib/services/ports/` (`AuthGateway`, `MeetingGateway`, `PaymentGateway`).
- **Concrete Adapters**: Confined under `lib/services/adapters/` (`AppwriteAuthGateway`, `LiveKitMeetingGateway`, `PaystackPaymentGateway`).
- **Owned Domain Models**: `AppUser`, `MeetingSession`, `ParticipantInfo`, `RoomStatus`, `PaymentRequest`, `PaymentResponse`, `PaymentStatus`, and `BibleUserProgress` in `lib/models/`.
- **Database Isolation**: `sqflite` is strictly confined to `lib/services/*_database_helper.dart`. UI layers consume typed domain models (`models.BibleVerse`) rather than raw database maps.
- **UID Validation**: `AppwriteIdUtils` (`lib/utils/appwrite_id_utils.dart`) guarantees all `rowId` parameters satisfy Appwrite 1.8's 36-char alphanumeric/underscore constraint.
- **SDK Upgrade & Freezes**: Appwrite Dart SDK upgraded to `^26.1.0`. `flutter_riverpod` is pinned to `^2.6.1` and `go_router` is pinned to `^14.0.0` (see `docs/architecture.md`).

Migration status: **100% live in production** on Appwrite 1.8 (`https://api.alivenigeria.org/v1`) and Coolify (`https://app.alivenigeria.org`).

## Core App Stack

- Flutter and Dart: main app framework and language (`v2.0.5+12`).
- Architecture: Ports & Adapters (Hexagonal Architecture) isolating third-party SDKs behind abstract contracts.
- Flutter Riverpod: primary state management (pinned `^2.6.1`).
- Go Router: app navigation (pinned `^14.0.0`).
- Appwrite Dart SDK: primary backend SDK (`^26.1.0`), isolated behind `AuthGateway` adapter and `TablesDB` services.
- Local storage: Shared Preferences, Flutter Secure Storage, SQLite/Sqflite (confined to `*_database_helper.dart`), and bundled assets.

## Primary Backend: Appwrite 1.8

- **Endpoint**: `https://api.alivenigeria.org/v1` (Project `6a3bef53002f5090dedf`, Database `6a089307002e54291a32`).
- **Auth**: email/password, OAuth redirects, office-identity auto-binding (`bind_office_identity`), profile synchronization, and team-based admin sync.
- **TablesDB (81 live tables)**: 80 app tables + 1 server-only `officer_registry` table covering profiles, chat, prayer, testimonies, donation records, study guides/questions, health, content pages, events, announcements, board decisions, chapters, leadership, discipleship, kids content, settings, and analytics.
- **Storage buckets (9 live buckets)**: `chat_files`, `profile_files`, `board_documents`, `tract_files`, `podcast_media`, `content_media`, `meeting_files`, `system_exports`, and `app_releases` (direct Android APK distribution).
- **Functions (8 live functions in `appwrite_functions/`)**:
  - `createLiveKitToken`
  - `paystack_payments`
  - `paystack_webhook`
  - `send_email`
  - `bind_office_identity`
  - `delete_account`
  - `monthly_donation_reminder`
  - `notify_admin_signup`
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

## Analytics And Crash Reporting

- App analytics/event tracking uses `lib/services/analytics_service.dart` and persists authenticated events to the Appwrite `analytics_events` table.
- Firebase Analytics has been removed from the active dependency graph.
- Crash/error reporting uses GlitchTip through the Sentry-compatible Flutter SDK.
- Configure GlitchTip from the GlitchTip project DSN:
  - `GLITCHTIP_DSN`
  - `GLITCHTIP_ENVIRONMENT` such as `production`, `staging`, or `development`
  - `GLITCHTIP_RELEASE` optional, for example `alive-ng-app@1.1.0+2`
  - `GLITCHTIP_TRACES_SAMPLE_RATE` optional, default `0`

## Legacy Firebase Compatibility

Firebase packages remain in `pubspec.yaml` only where still imported by the FCM notification bridge. Firestore/Auth/Storage/Functions/Analytics/Crashlytics packages have been removed from the active dependency graph.

- Firebase Core and Messaging are still present for Appwrite Messaging FCM delivery.
- Legacy `FirebaseDatabaseService`, Firebase Cloud Functions, and old archived
  migration copies have been deleted after active imports were removed and
  Appwrite replacements passed analysis.
- Root Firebase Hosting, Firestore rules/indexes, Firebase Cloud Functions, and
  the legacy Firebase Admin Express server have been removed from the active
  repository. Keep `android/app/google-services.json` locally for FCM Android
  builds; it must stay out of Git.

## Remaining Migration Areas

- Appwrite Messaging FCM provider validation and final target/subscriber QA.
- Browser QA for Coolify web once `app.alivenigeria.org` and the Appwrite endpoint are reachable.
- Podcast offline download persistence can be improved beyond opening the Appwrite file URL externally.
- The board/tract storage compatibility facade is now `AppwriteStorageCompatService`; remove it only after those screens move to narrower feature-specific services.
- Static web Firebase project/donation pages have been replaced by the Flutter
  Appwrite donation route.

## Secrets And Runtime Parameters

Keep these out of Git. Configure them in `.env`, Coolify build variables, or Appwrite function variables as appropriate.

- `APPWRITE_ENDPOINT`
- `APPWRITE_PROJECT_ID`
- `APPWRITE_DATABASE_ID`
- `APPWRITE_API_KEY`
- `APPWRITE_FCM_PROVIDER_ID` only if the Appwrite FCM provider ID is not the default/only push provider
- `GLITCHTIP_DSN`
- `GLITCHTIP_ENVIRONMENT`
- `GLITCHTIP_RELEASE`
- `GLITCHTIP_TRACES_SAMPLE_RATE`
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
- Run `dart scripts/duplicate_dart_files.dart android appwrite_functions assets build docs ios lib scripts test tool tools web windows` to inspect duplicate Dart filenames across the project.
- Do not restore deleted Firebase Functions, Firestore rules/indexes, Firebase
  Hosting config, or the old Express/Firebase Admin sidecar unless you are
  intentionally testing a historical migration path.
- Keep `scripts/appwrite_infrastructure_schema.mjs` as the source of truth for Appwrite infrastructure until `appwrite.config.json` can fully represent this self-hosted Appwrite version.

## Standard Functionality Review Targets

- Tract reader: ensure PDF extraction is available when stored rich text is missing, keep the PDF download path reliable after donation, and replace any sample-only fallback with real readable content.
- Bible reader: verify narrow-phone verse action controls do not overflow, and add reader comfort controls only after the remaining backend migration is stable.
- Theme polish: audit tract reader callouts, admin dialogs, meeting file sharing, and board/document metadata surfaces for hard-coded light colors in dark mode.
- Web hosting: `app.alivenigeria.org` and the Appwrite endpoint must respond before provisioning and browser QA can be completed.
