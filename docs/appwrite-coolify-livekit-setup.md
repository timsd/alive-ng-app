# Appwrite, Coolify, and LiveKit Setup

This project is in the final live-deployment stage of the Firebase-to-Appwrite migration. Appwrite is the active backend target. Firebase remains only for FCM push delivery compatibility until Appwrite Messaging has a verified FCM provider.

## Appwrite Dashboard

- Use project `6a3bef53002f5090dedf` at `https://api.alivenigeria.org/v1`.
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
- Messaging provider verification: `npm run appwrite:providers`.
- FCM provider auto-creation requires `APPWRITE_FCM_PROVIDER_ID` plus either `APPWRITE_FCM_SERVICE_ACCOUNT_PATH` or `APPWRITE_FCM_SERVICE_ACCOUNT_JSON`.

Provisioned resources include storage buckets for chat files, profile files, board documents, tracts, podcasts, content media, meeting files, and exports; teams for administrators, BOD, trustees, directors, chapter leaders, content editors, and moderators; and messaging topics for users, leaders, approvals, prayer, chat, donations, events, study, kids, health, and content.

Current production provisioning status:

- `npm run appwrite:ping` reaches Appwrite at `https://api.alivenigeria.org/v1`.
- `npm run appwrite:provision:legacy` completed against Appwrite `1.7.4`.
- `npm run appwrite:app-version` created `app_settings/app_version`.
- `npm run appwrite:function-vars` synced LiveKit, Paystack, and Resend variables.
- `npm run appwrite:deploy-functions` uploaded active deployments for `createLiveKitToken`, `paystack_payments`, `paystack_webhook`, and `send_email`.
- TablesDB mode is still unavailable on the current Appwrite server. Legacy Databases mode created the live schema, but some optional long/wide fields were skipped because of legacy collection attribute limits. Upgrade Appwrite to a TablesDB-capable version or split those optional fields into companion detail tables before calling the schema 100% equivalent.

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
- Flutter web env values are compile-time values. In Coolify set `FLUTTER_BUILD_ARGS` as a Docker build argument, not only as a runtime environment variable.
- Do not put secret keys in `FLUTTER_BUILD_ARGS`. Use public/client values only.
- Current required shape:

```bash
--dart-define=APPWRITE_ENDPOINT=https://api.alivenigeria.org/v1 --dart-define=APPWRITE_PROJECT_ID=6a3bef53002f5090dedf --dart-define=APPWRITE_DATABASE_ID=6a089307002e54291a32 --dart-define=APPWRITE_FCM_PROVIDER_ID=6a0cbd1600215f960c03 --dart-define=LIVEKIT_URL=wss://livekit.alivenigeria.org --dart-define=PAYSTACK_PUBLIC_KEY=pk_live_xxx --dart-define=PAYSTACK_CALLBACK_URL=https://app.alivenigeria.org/payment/callback --dart-define=GOOGLE_WEB_CLIENT_ID=xxx --dart-define=WEB_PUSH_CERT_KEY=xxx --dart-define=GLITCHTIP_DSN=https://example@glitchtip.example/1 --dart-define=GLITCHTIP_ENVIRONMENT=production --dart-define=GLITCHTIP_RELEASE=alive-ng-app@1.1.0+2 --dart-define=GLITCHTIP_TRACES_SAMPLE_RATE=0 --dart-define=APPWRITE_RESOURCES_BASE_URL=https://app.alivenigeria.org/resources
```

- If `https://app.alivenigeria.org` returns `503`, check Coolify in this order:
  - Application > Deployments: confirm the latest deployment finished successfully.
  - Application > General/Network: exposed port must be `80`.
  - Application > Domains: domain must be `https://app.alivenigeria.org`; SSL must be issued and active.
  - Application > Build Variables: confirm `FLUTTER_BUILD_ARGS` is under build arguments.
  - Application > Logs: look for Flutter build failure, Nginx startup failure, or container health failure.
  - Server DNS: `A app.alivenigeria.org` points to the server public IP.
  - Proxy: ensure Coolify proxy routes `app.alivenigeria.org` to the Flutter web app, not Appwrite or LiveKit.

## LiveKit

- LiveKit is not a built-in Coolify service in this setup. Add it as a custom Docker Compose resource.
- Create DNS `A livekit.alivenigeria.org YOUR_PUBLIC_IP`, then in Coolify add a Docker Compose / Empty Compose resource with domain `https://livekit.alivenigeria.org` and HTTP port `7880`.
- Use this compose:

```yaml
services:
  livekit:
    image: livekit/livekit-server:latest
    restart: unless-stopped
    command: --config /etc/livekit.yaml
    ports:
      - "7880:7880/tcp"
      - "7881:7881/tcp"
      - "50100-50200:50100-50200/udp"
    volumes:
      - ./livekit.yaml:/etc/livekit.yaml:ro
```

- Add `livekit.yaml` beside the compose in Coolify and replace placeholders there only. Do not commit real keys.

```yaml
port: 7880
log_level: info
rtc:
  tcp_port: 7881
  port_range_start: 50100
  port_range_end: 50200
  use_external_ip: true
keys:
  YOUR_LIVEKIT_API_KEY: YOUR_LIVEKIT_API_SECRET
```

- Open OCI and `ufw` ports: TCP `7880`, TCP `7881`, UDP `50100-50200`.
- If deploy fails with `failed to bind host port ... address already in use`, pick a different unused UDP range and update both the compose `ports` range and `rtc.port_range_start/end`.
- Production web should use `wss://`, not `ws://`.
- Set `LIVEKIT_URL` through Coolify `FLUTTER_BUILD_ARGS`.
- Deploy Appwrite function `createLiveKitToken` from `appwrite_functions/createLiveKitToken`.
- Set function env vars `LIVEKIT_API_KEY` and `LIVEKIT_API_SECRET` in Appwrite.
- Keep the function execution role to authenticated users and confirm function ID `6a08e9010035dc8c1e51`, because the Flutter app calls that ID.
- Ensure the LiveKit host/proxy allows WebSocket and media traffic needed for camera, mic, publish, and subscribe.
- If `https://livekit.alivenigeria.org` reports a self-signed certificate, reissue SSL in Coolify for the LiveKit domain and confirm DNS points to the server public IP. Keep Flutter configured with `wss://livekit.alivenigeria.org` once TLS is valid.

## GlitchTip

- The Flutter app already uses `sentry_flutter` through `CrashReportingService`.
- Keep the real DSN in local `.env` and Coolify variables/build args only.
- Required build defines:
  - `GLITCHTIP_DSN`
  - `GLITCHTIP_ENVIRONMENT`
  - `GLITCHTIP_RELEASE`
  - `GLITCHTIP_TRACES_SAMPLE_RATE`
- Add the same defines to Android release build commands.
- After deployment, confirm a test event arrives in the GlitchTip project before public launch.

## FCM Provider

Use Firebase only as the push transport provider for Appwrite Messaging.

To create/verify the provider automatically:

1. Open Firebase Console > project `alive-ng-flutter-app`.
2. Go to Project settings > Service accounts.
3. Generate a new private key and save it outside git, for example `E:\gradle-cache-alive-ng\secrets\firebase-fcm-service-account.json`.
4. In local `.env`, set:

```bash
APPWRITE_FCM_PROVIDER_ID=6a0cbd1600215f960c03
APPWRITE_FCM_SERVICE_ACCOUNT_PATH=E:\gradle-cache-alive-ng\secrets\firebase-fcm-service-account.json
```

5. Run `npm run appwrite:providers`.
6. Keep `APPWRITE_FCM_PROVIDER_ID` in Coolify `FLUTTER_BUILD_ARGS`.

## Current Migration Notes

- Appwrite production infrastructure is provisioned and function deployments are active.
- Local Flutter dependencies were restored with `PUB_CACHE=E:\gradle-cache-alive-ng\pub-cache`.
- A local `flutter analyze` attempt stalled after dependency restoration; no analyzer process remains, but rerun analyze after restarting VS Code/terminal.
- `https://app.alivenigeria.org` currently returns `503`; fix Coolify app deployment/proxy before web smoke testing.
- `https://api.alivenigeria.org/v1/health` is reachable and returns Appwrite.
- `https://livekit.alivenigeria.org` currently presents a self-signed certificate; fix SSL before production calls.
- Firebase Hosting was disabled for project `alive-ng-flutter-app` on 2026-05-18; Coolify is now the intended web deployment path.
- Do not remove active FCM platform config until Appwrite Messaging push is verified end to end.
