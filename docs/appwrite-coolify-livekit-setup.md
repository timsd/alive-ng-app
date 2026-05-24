# Appwrite, Coolify, and LiveKit Setup

This project is about 99% through the Firebase-to-Appwrite migration. Keep Firebase enabled only for active compatibility paths until each remaining service is replaced and verified.

## Appwrite Dashboard

- Use project `6a088e5f0003764bde50` at `http://appwrite-he4p5j9b9dj42v5nzeklu2u3.84.8.219.248.sslip.io/v1`.
- Enable Account, Databases, Storage, Teams, Users, Functions, Messaging, GraphQL, and Sites.
- Enable auth methods used by the app: email/password, Google OAuth, JWT, phone, invites, anonymous, email OTP, and magic URL.
- Add web platforms / allowed origins for `https://app.alivenigeria.org` and the active Coolify app domain.
- Configure Google OAuth redirects:
  - Success: `https://app.alivenigeria.org/#/home`
  - Failure: `https://app.alivenigeria.org/#/auth`
- Configure password recovery redirect: `https://app.alivenigeria.org/#/reset-password`.
- Provision infrastructure with `npm run appwrite:provision:legacy` while the server is Appwrite `1.7.4`.
- `npm run appwrite:dry-run` is the safe local validation command and should pass before any apply.
- Required local/provisioning env: `APPWRITE_API_KEY`.
- Optional provisioning env: `APPWRITE_ENDPOINT`, `APPWRITE_PROJECT_ID`, `APPWRITE_DATABASE_ID`, `APPWRITE_PROVISION_DELAY_MS`, `APPWRITE_VERBOSE_WARNINGS`.
- Optional webhook env before provisioning: `APPWRITE_PROFILE_APPROVAL_WEBHOOK_URL`, `APPWRITE_CHAT_FILE_WEBHOOK_URL`, `APPWRITE_DONATION_WEBHOOK_URL`, `APPWRITE_WEBHOOK_SECRET`.

Provisioned resources include storage buckets for chat files, profile files, board documents, tracts, podcasts, content media, meeting files, and exports; teams for administrators, BOD, trustees, directors, chapter leaders, content editors, and moderators; and messaging topics for users, leaders, approvals, prayer, chat, donations, events, study, kids, health, and content.

## Appwrite Functions

- Deploy function `createLiveKitToken` from `appwrite_functions/createLiveKitToken`.
- Deploy function `paystackPayments` from `appwrite_functions/paystackPayments` with function ID `paystack_payments`; execution should be limited to authenticated users.
- Deploy function `paystackWebhook` from `appwrite_functions/paystackWebhook` with function ID `paystack_webhook`; execution must allow `any` because Paystack posts server-to-server.
- Required Paystack function env vars:
  - `PAYSTACK_SECRET_KEY`
  - `APPWRITE_FUNCTION_API_ENDPOINT` or `APPWRITE_ENDPOINT`
  - `APPWRITE_FUNCTION_PROJECT_ID` or `APPWRITE_PROJECT_ID`
  - `APPWRITE_FUNCTION_API_KEY` or `APPWRITE_API_KEY` with database read/write scope
  - `APPWRITE_DATABASE_ID` if the default database changes
- In the Paystack dashboard, configure the webhook URL to the deployed Appwrite `paystack_webhook` execution endpoint.
- Keep Firebase Paystack webhooks disabled or pointed away after Appwrite webhook verification to avoid double-processing donation records.

## Coolify

- Deploy from the root `Dockerfile`; it builds Flutter web and serves through Nginx on port `80`.
- Point the public domain to the Coolify app and configure the service port as `80`.
- Keep the SPA fallback in `nginx.conf`.
- Flutter web env values are compile-time values. Set Coolify build arg `FLUTTER_BUILD_ARGS` with needed `--dart-define` values, for example:

```bash
--dart-define=LIVEKIT_URL=wss://livekit.example.com --dart-define=PAYSTACK_PUBLIC_KEY=pk_live_xxx --dart-define=GOOGLE_WEB_CLIENT_ID=xxx
```

- Add build-time values for Paystack, Google sign-in, reCAPTCHA, web push, LiveKit, Appwrite endpoint/project IDs, and any Firebase compatibility values still used by active legacy modules.

## LiveKit

- Run a LiveKit server reachable by the deployed app. Production web should use `wss://`, not `ws://`.
- Set `LIVEKIT_URL` through Coolify `FLUTTER_BUILD_ARGS`.
- Deploy Appwrite function `createLiveKitToken` from `appwrite_functions/createLiveKitToken`.
- Set function env vars `LIVEKIT_API_KEY` and `LIVEKIT_API_SECRET` in Appwrite.
- Keep the function execution role to authenticated users and confirm function ID `6a08e9010035dc8c1e51`, because the Flutter app calls that ID.
- Ensure the LiveKit host/proxy allows WebSocket and media traffic needed for camera, mic, publish, and subscribe.

## Current Migration Notes

- `flutter analyze` is clean with the current Appwrite-backed migration slices.
- Appwrite dry-run is clean, but real provisioning is currently blocked while the Appwrite endpoint and `app.alivenigeria.org` are unreachable from this workspace.
- Firebase Hosting was disabled for project `alive-ng-flutter-app` on 2026-05-18; Coolify is now the intended web deployment path.
- Do not remove active Firebase platform config, Firebase functions, storage rules, messaging compatibility, or central mixed Firebase services until their Appwrite replacements are wired and verified.
- `AppwriteStorageCompatService` is the current Appwrite-backed compatibility layer for board and tract storage methods.
