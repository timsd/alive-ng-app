# Appwrite Migration Readiness

Last reviewed: 2026-05-25

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

Current blocker: the Appwrite endpoint and `app.alivenigeria.org` are not reachable from this workspace, so real provisioning cannot be rerun yet. Continue code migration locally and rerun `npm run appwrite:provision:legacy` after server/proxy/firewall/DNS/Coolify is restored.

## Deployment Gate

Do not run `appwrite push all --all` or a blind full Firebase-to-Appwrite
migration. The safer path for this Appwrite 1.7.4 server is the checked
provisioning script in legacy Databases mode, followed by per-service data
migration and verification.

Use this safer sequence for remaining migration:

1. Keep running `npm run appwrite:dry-run` before schema changes.
2. Apply schema with `npm run appwrite:provision:legacy`.
3. Deploy functions one group at a time after dashboard env vars are set.
4. Run Firebase data migration per collection/bucket after each Appwrite target is verified.
5. Move Firebase files into `oldfirebasedelete` only after the active app path no longer imports or executes them.

## Firebase Files

Firebase files still exist and should not be moved blindly. Firebase Hosting is
disabled and the old `public/` hosting files have been moved to
`oldfirebasedelete/firebase_hosting_public`, but several app areas still import
Firebase services, including sync/offline sync, admin internals,
discipleship, notifications, native analytics/crash compatibility, web push,
and legacy server/functions code. Only files already replaced should go into
`oldfirebasedelete`.

## Current Appwrite Client Migration

- Appwrite auth/profile, chat, LiveKit token creation, testimonies, notification settings storage, donation records/material downloads, gift submissions, Paystack initialization/webhook code, kids content CRUD/seeding, tract/podcast admin flows, enhanced health service, leadership records/transitions, and meeting file storage/metadata are now wired.
- Push notification delivery still uses Firebase Messaging compatibility while Appwrite Messaging targeting is being completed.
- `DonationService` no longer imports Firebase; downloadable material URLs should now be Appwrite/external URLs, not Firebase Storage URLs.
- The old `FirebaseStorageService` facade has been renamed to `AppwriteStorageCompatService`; it remains a temporary compatibility layer for board and tract storage methods.

## Play Store GitHub Actions

GitHub Actions can build Android release artifacts on a free GitHub account for
normal repository usage, but Play Store upload requires secrets such as the
keystore, key aliases/passwords, and Google Play service account JSON. A deploy
workflow should only be committed after those secret names and signing strategy
are finalized.
