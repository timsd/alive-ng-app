# Oracle Free Tier Deployment Roadmap For ALIVE Nigeria

Last updated: 2026-05-26

This guide is the clean start-to-finish path for hosting the ALIVE Nigeria stack
on Oracle Cloud Infrastructure (OCI), beginning with the Morocco region, a
2 OCPU / 12 GB RAM / 100 GB server, Appwrite, Coolify, LiveKit, GlitchTip,
Resend, Paystack, Android builds, and Flutter web deployment.

Use this as a checklist. Do not paste private keys into GitHub or Flutter web
build output.

## Official References

- Oracle Free Tier: <https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier.htm>
- Oracle VCN/subnet management: <https://docs.oracle.com/en-us/iaas/Content/Network/Tasks/managingVCNs.htm>
- Oracle instance creation: <https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/launchinginstance.htm>
- Oracle public IPs: <https://docs.oracle.com/en-us/iaas/Content/Network/Tasks/managingpublicIPs.htm>
- Coolify installation: <https://coolify.io/docs/get-started/installation>
- Appwrite self-hosting: <https://appwrite.io/docs/advanced/self-hosting>
- LiveKit deployment: <https://docs.livekit.io/transport/self-hosting/deployment/>
- GlitchTip install: <https://glitchtip.com/documentation/install/>

## Target Architecture

```text
Domain/DNS
  app.alivenigeria.org      -> Coolify Flutter web app
  api.alivenigeria.org      -> Appwrite
  livekit.alivenigeria.org  -> LiveKit websocket/RTC service
  glitchtip.alivenigeria.org optional -> GlitchTip

OCI VM, Morocco region
  Ubuntu 24.04 LTS or 22.04 LTS
  VM.Standard.A1.Flex, 2 OCPU, 12 GB RAM
  100 GB boot volume
  Coolify manages Docker apps and SSL

External providers
  Resend for email
  Paystack for payments
  Firebase Cloud Messaging only as Appwrite Messaging Android/Web push bridge
```

## Phase 1: Create The Oracle Account

1. Go to <https://signup.cloud.oracle.com/>.
2. Choose your country and verify email/phone.
3. Choose Morocco / Casablanca as the home region if it is available to you.
4. Add the card for identity verification. Oracle says the card should not be
   charged unless you upgrade.
5. Finish the Free Tier signup.
6. When the console opens, turn on MFA for your Oracle account.
7. After setup, create a budget alert:
   - Open the menu.
   - Billing & Cost Management.
   - Budgets.
   - Create Budget.
   - Amount: a tiny warning value, for example USD 1.
   - Alert at 50%, 80%, and 100%.

Important: OCI Always Free Ampere A1 capacity is limited by region. If Morocco
has no capacity when you try, wait and retry. Do not choose a paid shape by
mistake.

## Phase 2: Create A Compartment

1. Open OCI Console.
2. Menu > Identity & Security > Compartments.
3. Create compartment:
   - Name: `alive-production`
   - Description: `ALIVE Nigeria production resources`
4. Use this compartment for VCN, reserved IP, instance, and volumes.

## Phase 3: Create The VCN Before The Instance

1. Menu > Networking > Virtual Cloud Networks.
2. Select compartment: `alive-production`.
3. Click Start VCN Wizard.
4. Choose Create VCN with Internet Connectivity.
5. Use:
   - VCN name: `alive-prod-vcn`
   - VCN CIDR: `10.0.0.0/16`
   - Public subnet CIDR: `10.0.0.0/24`
   - Private subnet CIDR: `10.0.1.0/24`
6. Create.

The wizard creates the VCN, public subnet, private subnet, internet gateway,
route table, and default security lists.

## Phase 4: Reserve A Public IP

1. Menu > Networking > IP Management > Reserved Public IPs.
2. Select compartment: `alive-production`.
3. Create Reserved Public IP:
   - Name: `alive-prod-public-ip`
   - IP address source: Oracle
4. Keep the IP address somewhere safe.

This IP will later be assigned to the instance VNIC, then your DNS records will
point to it.

## Phase 5: Create The Compute Instance

1. Menu > Compute > Instances.
2. Select compartment: `alive-production`.
3. Create instance.
4. Basic:
   - Name: `alive-prod-01`
   - Image: Ubuntu 24.04 LTS, or Ubuntu 22.04 LTS if 24.04 is unavailable
   - Shape series: Ampere
   - Shape: `VM.Standard.A1.Flex`
   - OCPUs: `2`
   - Memory: `12 GB`
5. Networking:
   - VCN: `alive-prod-vcn`
   - Subnet: public subnet
   - Assign public IPv4 address: yes for now
6. SSH:
   - Generate a new SSH key pair in OCI, or upload your own public key.
   - Download the private key if OCI generated it.
7. Boot volume:
   - Custom boot volume size: `100 GB`
8. Create.

After the instance is running:

1. Open the instance.
2. Resources > Attached VNICs.
3. Open the primary VNIC.
4. IPv4 Addresses.
5. Edit the public IP.
6. Choose Reserved Public IP.
7. Select `alive-prod-public-ip`.

## Phase 6: Open OCI Network Ports

Open only what this project needs.

1. Go to Networking > Virtual Cloud Networks > `alive-prod-vcn`.
2. Open Network Security Groups, or use the public subnet Security List.
3. Add ingress rules:

```text
TCP 22      source: your current public IP only
TCP 80      source: 0.0.0.0/0
TCP 443     source: 0.0.0.0/0
TCP 8000    source: your current public IP only, for first Coolify setup
TCP 7880    source: 0.0.0.0/0, LiveKit websocket/signaling
TCP 7881    source: 0.0.0.0/0, LiveKit TCP RTC fallback
UDP 50000-60000 source: 0.0.0.0/0, LiveKit RTC media
TCP/UDP 3478 optional source: 0.0.0.0/0, TURN if enabled
TCP/UDP 5349 optional source: 0.0.0.0/0, TURN TLS if enabled
```

If you later put LiveKit behind a dedicated reverse proxy/TURN setup, adjust the
ports to match that final LiveKit config.

## Phase 7: First SSH Login

On your Windows machine, put your private SSH key somewhere safe, for example:

```powershell
C:\Users\Zavolah\.ssh\alive-prod-oci.key
```

Connect:

```powershell
ssh -i C:\Users\Zavolah\.ssh\alive-prod-oci.key ubuntu@YOUR_PUBLIC_IP
```

On the server:

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y curl git unzip jq ca-certificates gnupg ufw fail2ban
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 7880/tcp
sudo ufw allow 7881/tcp
sudo ufw allow 50000:60000/udp
sudo ufw enable
```

If you enabled OCI port `8000` for Coolify setup, also run:

```bash
sudo ufw allow 8000/tcp
```

After Coolify has a domain and SSL, remove public 8000 access:

```bash
sudo ufw delete allow 8000/tcp
```

## Phase 8: Install Coolify

Coolify recommends a fresh server and provides a one-command installer.

Run as root-capable user:

```bash
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | sudo bash
```

When it finishes:

1. Open `http://YOUR_PUBLIC_IP:8000`.
2. Create the first Coolify admin immediately.
3. Add the local server in Coolify if it is not already attached.
4. Connect your GitHub account/repository:
   - Repository: `timsd/alive-ng-app`
   - Branch: `master` unless you choose a different production branch.

## Phase 9: DNS Records

In the DNS provider for `alivenigeria.org`, create:

```text
A  app.alivenigeria.org       YOUR_PUBLIC_IP
A  api.alivenigeria.org       YOUR_PUBLIC_IP
A  livekit.alivenigeria.org   YOUR_PUBLIC_IP
A  glitchtip.alivenigeria.org YOUR_PUBLIC_IP optional
```

Wait for DNS propagation. You can check from your machine:

```powershell
nslookup app.alivenigeria.org
nslookup api.alivenigeria.org
nslookup livekit.alivenigeria.org
```

## Phase 10: Deploy Appwrite

Use Coolify Services if Appwrite is available there. If not, create a Docker
Compose service from the official Appwrite self-hosting documentation.

Recommended domain:

```text
https://api.alivenigeria.org/v1
```

After Appwrite starts:

1. Open Appwrite Console.
2. Create project:
   - Name: `ALIVE App Core`
   - Project ID: keep existing `6a088e5f0003764bde50` if you are restoring the
     same project identity; otherwise update `.env` and Flutter build args.
3. Settings > Platforms:
   - Add Web platform: `app.alivenigeria.org`
   - Add Web platform: your Coolify preview domain if you use one
   - Add Android platform:
     - Name: `ALIVE Nigeria Android`
     - Package name: `com.alive.alivengandroidapp`
4. Settings > API Keys:
   - Create a server key for provisioning scripts.
   - Give it database, storage, functions, messaging, teams, webhooks, and
     project scopes needed by the scripts.
   - Put the key in local `.env` only as `APPWRITE_API_KEY`.

## Phase 11: Populate Appwrite From This Repo

On your local Windows project:

```powershell
cd "C:\Users\Zavolah\Documents\ZavTech Projects\alive-ng-app"
npm install
flutter pub get
```

Update local `.env`:

```text
APPWRITE_ENDPOINT=https://api.alivenigeria.org/v1
APPWRITE_PROJECT_ID=6a088e5f0003764bde50
APPWRITE_DATABASE_ID=alive_main_db
APPWRITE_API_KEY=your_server_api_key
LIVEKIT_URL=wss://livekit.alivenigeria.org
LIVEKIT_API_KEY=your_livekit_api_key
LIVEKIT_API_SECRET=your_livekit_api_secret
PAYSTACK_PUBLIC_KEY=pk_live_or_test_key
PAYSTACK_SECRET_KEY=sk_live_or_test_key
PAYSTACK_CALLBACK_URL=https://app.alivenigeria.org/donation
RESEND_API_KEY=your_resend_key
SENDER_EMAIL=ALIVE Nigeria <app@alivenigeria.org>
GLITCHTIP_DSN=your_glitchtip_dsn
GLITCHTIP_ENVIRONMENT=production
APPWRITE_FCM_PROVIDER_ID=your_appwrite_fcm_provider_id_if_not_default
WEB_PUSH_CERT_KEY=your_fcm_web_push_public_key
```

Then run:

```powershell
npm run appwrite:ping
npm run appwrite:dry-run
npm run appwrite:provision
npm run appwrite:function-vars
npm run appwrite:deploy-functions
npm run appwrite:app-version
```

If your self-hosted Appwrite server needs legacy database endpoints, use:

```powershell
npm run appwrite:provision:legacy
```

What these automate:

- Tables/collections and indexes from `scripts/appwrite_infrastructure_schema.mjs`
- Buckets
- Teams
- Topics
- Optional webhooks when URLs are set
- Function variables for LiveKit, Paystack, and Resend
- App version document in `app_settings`

What you still set manually:

- Appwrite platform entries
- Appwrite API key creation
- Appwrite Messaging FCM provider credentials
- OAuth redirect/domain settings, if Google sign-in is enabled
- DNS records
- Paystack webhook URL
- Resend domain verification
- GlitchTip project creation/DSN

## Phase 12: Appwrite Messaging With FCM

Firebase stays only for push delivery.

1. Open Firebase Console for the existing Firebase project.
2. Project Settings > Cloud Messaging.
3. Get the Web Push certificate public key for `WEB_PUSH_CERT_KEY`.
4. For Appwrite Messaging, create or upload the FCM provider credentials in
   Appwrite Console > Messaging > Providers.
5. Copy the Appwrite provider ID into local `.env`:

```text
APPWRITE_FCM_PROVIDER_ID=provider_id_from_appwrite
```

6. Keep `android/app/google-services.json` locally for Android builds.
7. Keep `web/firebase-messaging-sw.js` because browsers still need the FCM
   service worker for web push tokens.

## Phase 13: Deploy LiveKit

Use Coolify Docker Compose or a dedicated service.

Production client URL:

```text
LIVEKIT_URL=wss://livekit.alivenigeria.org
```

Do not use `ws://` in production once TLS is working. `ws://` is only for
temporary private testing.

Minimum LiveKit config:

```yaml
port: 7880
log_level: info
rtc:
  tcp_port: 7881
  port_range_start: 50000
  port_range_end: 60000
  use_external_ip: true
keys:
  YOUR_LIVEKIT_API_KEY: YOUR_LIVEKIT_API_SECRET
```

Put `LIVEKIT_API_KEY` and `LIVEKIT_API_SECRET` into the Appwrite
`createLiveKitToken` function variables, not into Flutter public build output.

## Phase 14: Deploy GlitchTip

Option A, easiest: use GlitchTip hosted service and copy the DSN.

Option B, self-host: deploy GlitchTip in Coolify if your server still has enough
headroom after Appwrite and LiveKit. Create the project, then copy the DSN into:

```text
GLITCHTIP_DSN=...
GLITCHTIP_ENVIRONMENT=production
GLITCHTIP_RELEASE=alive-ng-app@VERSION
```

Flutter uses the Sentry-compatible SDK to send errors to GlitchTip.

## Phase 15: Configure Resend

1. Open Resend.
2. Add domain: `alivenigeria.org`.
3. Add the DNS records Resend shows:
   - SPF
   - DKIM
   - DMARC, recommended
4. Use sender:

```text
ALIVE Nigeria <app@alivenigeria.org>
```

5. Put `RESEND_API_KEY` and `SENDER_EMAIL` in Appwrite `sendEmail` function
   variables using:

```powershell
npm run appwrite:function-vars
```

## Phase 16: Configure Paystack

1. Open Paystack dashboard.
2. Use Paystack Checkout or the app's Appwrite `paystack_payments` function.
3. Never collect raw card number, CVV, or expiry in your server/app.
4. Set callback URL:

```text
https://app.alivenigeria.org/donation
```

5. Set webhook URL to the Appwrite function domain for `paystack_webhook`.
6. Confirm the function verifies `x-paystack-signature` with `PAYSTACK_SECRET_KEY`.

## Phase 17: Deploy Flutter Web In Coolify

Create an Application in Coolify:

1. Source: GitHub.
2. Repository: `timsd/alive-ng-app`.
3. Branch: `master`.
4. Build Pack: Dockerfile.
5. Domain: `https://app.alivenigeria.org`.
6. Build arg:

```text
FLUTTER_BUILD_ARGS=--dart-define=APPWRITE_ENDPOINT=https://api.alivenigeria.org/v1 --dart-define=APPWRITE_PROJECT_ID=6a088e5f0003764bde50 --dart-define=APPWRITE_DATABASE_ID=alive_main_db --dart-define=APPWRITE_FCM_PROVIDER_ID=YOUR_PROVIDER_ID --dart-define=LIVEKIT_URL=wss://livekit.alivenigeria.org --dart-define=PAYSTACK_PUBLIC_KEY=YOUR_PAYSTACK_PUBLIC_KEY --dart-define=PAYSTACK_CALLBACK_URL=https://app.alivenigeria.org/donation --dart-define=GLITCHTIP_DSN=YOUR_GLITCHTIP_DSN --dart-define=GLITCHTIP_ENVIRONMENT=production --dart-define=WEB_PUSH_CERT_KEY=YOUR_WEB_PUSH_PUBLIC_KEY --dart-define=APPWRITE_RESOURCES_BASE_URL=https://api.alivenigeria.org/v1/storage/buckets/resources/files
```

Never include:

- `APPWRITE_API_KEY`
- `PAYSTACK_SECRET_KEY`
- `LIVEKIT_API_SECRET`
- `RESEND_API_KEY`
- FCM private keys

Coolify should rebuild automatically on Git push if GitHub webhook integration
is enabled.

## Phase 18: Build Android APK/AAB

Required local private files:

```text
android/app/google-services.json
android/key.properties
android/app/alive-release.keystore
```

Build APK:

```powershell
flutter clean
flutter pub get
flutter build apk --release --dart-define=APPWRITE_ENDPOINT=https://api.alivenigeria.org/v1 --dart-define=APPWRITE_PROJECT_ID=6a088e5f0003764bde50 --dart-define=APPWRITE_DATABASE_ID=alive_main_db --dart-define=LIVEKIT_URL=wss://livekit.alivenigeria.org --dart-define=PAYSTACK_PUBLIC_KEY=YOUR_PAYSTACK_PUBLIC_KEY --dart-define=GLITCHTIP_DSN=YOUR_GLITCHTIP_DSN --dart-define=GLITCHTIP_ENVIRONMENT=production
```

Build Play Store bundle:

```powershell
flutter build appbundle --release --dart-define=APPWRITE_ENDPOINT=https://api.alivenigeria.org/v1 --dart-define=APPWRITE_PROJECT_ID=6a088e5f0003764bde50 --dart-define=APPWRITE_DATABASE_ID=alive_main_db --dart-define=LIVEKIT_URL=wss://livekit.alivenigeria.org --dart-define=PAYSTACK_PUBLIC_KEY=YOUR_PAYSTACK_PUBLIC_KEY --dart-define=GLITCHTIP_DSN=YOUR_GLITCHTIP_DSN --dart-define=GLITCHTIP_ENVIRONMENT=production
```

Outputs:

```text
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/bundle/release/app-release.aab
```

## Phase 19: Final Smoke Test

Check these before calling the migration complete:

- `https://app.alivenigeria.org` opens the web app.
- Appwrite Console shows Web and Android platforms.
- `npm run appwrite:ping` passes.
- `npm run appwrite:dry-run` shows no missing required schema.
- User signup/login works.
- Profile photo upload works.
- Chat send and file upload works.
- Bible reader opens and text is visible in light/dark mode.
- Tract PDF upload/extraction flow writes rich text and keeps PDF download.
- Paystack initializes without raw card data touching your server.
- Paystack webhook confirms donation records.
- Resend email function sends from `app@alivenigeria.org`.
- LiveKit meeting token function returns a token and rooms connect.
- Appwrite Messaging creates Android/Web push targets.
- GlitchTip receives a test error.
- Android APK installs and opens.

## Phase 20: Backup And Maintenance

Weekly:

- Export or snapshot Appwrite volumes/database.
- Back up Coolify `/data/coolify`.
- Back up LiveKit config and keys.
- Pull latest code and rerun:

```powershell
flutter analyze
npm run appwrite:dry-run
```

Before major updates:

- Take an OCI boot volume backup.
- Export Appwrite database/storage backups.
- Keep one known-good Git tag.

