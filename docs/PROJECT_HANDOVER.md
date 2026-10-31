# ALIVE Nigeria App — Project Handover & Operations Guide

**Version:** `2.0.5+12`
**Last Updated:** 2026-10-31
**Production Web URL:** https://app.alivenigeria.org
**Appwrite Endpoint:** https://api.alivenigeria.org/v1
**Appwrite Project ID:** `6a3bef53002f5090dedf`
**Appwrite Database ID:** `6a089307002e54291a32`

---

## 1. Architecture Overview

The ALIVE Nigeria App uses **Ports & Adapters (Hexagonal Architecture)** to isolate all external SDKs:

- **Ports (`lib/services/ports/`)**:
  - `AuthGateway` (`auth_gateway.dart`)
  - `MeetingGateway` (`meeting_gateway.dart`)
  - `PaymentGateway` (`payment_gateway.dart`)
- **Adapters (`lib/services/adapters/`)**:
  - `AppwriteAuthGateway` (`appwrite_auth_gateway.dart`)
  - `LiveKitMeetingGateway` (`livekit_meeting_gateway.dart`)
  - `PaystackPaymentGateway` (`paystack_payment_gateway.dart`)
- **UID Validation (`lib/utils/appwrite_id_utils.dart`)**:
  - `AppwriteIdUtils.isValidUid`, `AppwriteIdUtils.uniqueId`, and `AppwriteIdUtils.toValidUid` ensure every Appwrite 1.8 `TablesDB` `rowId` satisfies `^[a-zA-Z0-9][a-zA-Z0-9_]{0,35}$` (max 36 chars, no hyphens or spaces, no leading underscore).
- **SQLite Isolation**:
  - `sqflite` is confined strictly to `lib/services/*_database_helper.dart` (`bible_database_helper.dart`, `sop_database_helper.dart`).

---

## 2. Backend Infrastructure (Appwrite 1.8)

### TablesDB (`6a089307002e54291a32`)
- **81 Live Tables**: 80 application tables defined in `scripts/appwrite_infrastructure_schema.mjs` plus 1 server-only `officer_registry` table used by `bind_office_identity`.
- **Schema Verification & Audit**:
  - Test schema column budgets: `node --test scripts/appwrite_schema_sizes.test.mjs`
  - Audit live TablesDB against code & schema: `node scripts/audit_database.mjs`
  - Dry-run schema provisioning: `npm run appwrite:dry-run`
  - Apply schema changes: `npm run appwrite:provision`

### Storage Buckets (9 Live Buckets)
1. `chat_files` — Chat image, audio, video, and document attachments
2. `profile_files` — User profile avatars
3. `board_documents` — Board & Trustee governance documents
4. `tract_files` — Evangelism tracts & books (PDFs and cover images)
5. `podcast_media` — Podcast audio (`mp3`, `m4a`, `wav`, `aac`, `ogg`) and cover images
6. `content_media` — General CMS & devotional media
7. `meeting_files` — Shared LiveKit meeting documents (`pdf`, `doc`, `docx`, `xls`, `xlsx`, `ppt`, `pptx`, `txt`, `md`, images)
8. `system_exports` — Admin CSV/JSON data exports
9. `app_releases` — Direct Android APK release hosting (`alive_ng_android_release`)

### Appwrite Functions (8 Live Functions in `appwrite_functions/`)
1. `createLiveKitToken` — Generates signed LiveKit room tokens for authenticated members and leaders.
2. `paystack_payments` — Initializes and verifies Paystack transactions server-side.
3. `paystack_webhook` — Verifies `x-paystack-signature` (HMAC-SHA512), updates `donation_records`, increments project totals, and sends receipts.
4. `send_email` — Transactional email delivery via Resend.
5. `bind_office_identity` — Automatically binds official `@alivenigeria.org` accounts to their designated ministry role and team on sign-in.
6. `delete_account` — Self-service and admin-triggered GDPR/Play Store compliant account and profile deletion.
7. `monthly_donation_reminder` — Scheduled monthly donor pledge reminder with one-click opt-out support.
8. `notify_admin_signup` — Sends email and in-app admin notification records with signed approval links when a new member registers.

---

## 3. Build, Release & Deployment Workflows

### A. Static Analysis & Tests
```bash
dart analyze lib
flutter test
node --test scripts/appwrite_schema_sizes.test.mjs
```

### B. Coolify Web Deployment (`https://app.alivenigeria.org`)
- **Coolify Application UUID:** `o8splgp9v0w1ak7cn7t2ecgq`
- Trigger a production web deployment after pushing to `origin/master`:
```bash
node scripts/deploy_coolify_app.mjs
```

### C. Android Release Build (APK + Play Store AAB) & Upload
- Build both Release APK (`build/app/outputs/flutter-apk/app-release.apk`) and Play Store AAB (`build/app/outputs/bundle/release/app-release.aab`) with production `--dart-define` values from `.env`:
```bash
node scripts/build_android_release.mjs all
```
- Upload the Release APK to Appwrite Storage (`app_releases` / `alive_ng_android_release`) and sync `app_settings.app_version`:
```bash
node --env-file=.env scripts/upload_android_release.mjs
npm run appwrite:app-version
```

### D. Appwrite Function Deployment
- Sync environment variables and deploy all functions:
```bash
npm run appwrite:function-vars
npm run appwrite:deploy-functions
```
- Deploy a single function:
```bash
node scripts/deploy_function.mjs <functionId>
```
