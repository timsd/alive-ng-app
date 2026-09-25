# Appwrite Functions, Coolify Deployment, and Administration Guide

## Overview
This document specifies all required environment variables, configuration keys, and operational procedures for **Appwrite Functions**, **Coolify Hosting**, and **Role Management (Admin & Content Managers)** for ALIVE Nigeria.

---

## 1. Appwrite Functions Environment Variables Matrix

The repository includes 5 serverless Node.js 20 functions under `appwrite_functions/`:

| Function Name | Function ID | Runtime | Required Environment Variables | Scopes Needed |
|---|---|---|---|---|
| **createLiveKitToken** | `6a08e9010035dc8c1e51` | `node-20.0` | `LIVEKIT_API_KEY`<br>`LIVEKIT_API_SECRET`<br>`APPWRITE_ENDPOINT`<br>`APPWRITE_PROJECT_ID`<br>`APPWRITE_DATABASE_ID`<br>`APPWRITE_USERS_TABLE_ID`<br>`APPWRITE_FUNCTION_API_KEY` | `databases.read`<br>`documents.read` |
| **paystackPayments** | `paystack_payments` | `node-20.0` | `PAYSTACK_SECRET_KEY`<br>`APPWRITE_ENDPOINT`<br>`APPWRITE_PROJECT_ID`<br>`APPWRITE_DATABASE_ID`<br>`APPWRITE_FUNCTION_API_KEY`<br>`APPWRITE_PAYMENT_LOGS_COLLECTION_ID`<br>`RESEND_API_KEY` (for receipts)<br>`RECEIPT_SENDER_EMAIL`<br>`SENDER_EMAIL`<br>`REPLY_TO_EMAIL` | `databases.read`<br>`databases.write` |
| **paystackWebhook** | `paystack_webhook` | `node-20.0` | `PAYSTACK_SECRET_KEY`<br>`APPWRITE_ENDPOINT`<br>`APPWRITE_PROJECT_ID`<br>`APPWRITE_DATABASE_ID`<br>`APPWRITE_FUNCTION_API_KEY`<br>`APPWRITE_DONATION_RECORDS_COLLECTION_ID`<br>`APPWRITE_PROJECTS_COLLECTION_ID`<br>`APPWRITE_PAYMENT_LOGS_COLLECTION_ID`<br>`RESEND_API_KEY` (for receipts)<br>`RECEIPT_SENDER_EMAIL`<br>`SENDER_EMAIL`<br>`REPLY_TO_EMAIL`<br>`ALIVE_LOGO_URL` (optional branding) | `databases.read`<br>`databases.write` |
| **sendEmail** | `send_email` | `node-20.0` | `RESEND_API_KEY`<br>`RECEIPT_SENDER_EMAIL`<br>`SENDER_EMAIL`<br>`REPLY_TO_EMAIL`<br>`ALIVE_LOGO_URL` (optional branding) | None (external API) |
| **deleteAccount** | `delete_account` | `node-20.0` | `APPWRITE_ENDPOINT`<br>`APPWRITE_PROJECT_ID`<br>`APPWRITE_FUNCTION_API_KEY` (must include `users.write`)<br>`APPWRITE_FUNCTION_API_ENDPOINT`<br>`APPWRITE_FUNCTION_PROJECT_ID` | `users.write` |
| **monthlyDonationReminder** | `monthly_donation_reminder` | `node-20.0` | `APPWRITE_ENDPOINT`<br>`APPWRITE_PROJECT_ID`<br>`APPWRITE_FUNCTION_API_KEY`<br>`DONATE_DEEP_LINK` (optional, default `alivenigeria://donate`) | `users.read`<br>`targets.read`<br>`targets.write` |

### Monthly Donation Reminder
Runs on a monthly schedule (configure a cron trigger for the 1st of each month) and pushes a
localised reminder to every active member, encouraging support of the ministry and honouring
monthly commitments. Tapping the notification deep-links to the donation screen.

* Languages: English (`en`), Yoruba (`yo`), Igbo (`ig`), Hausa (`ha`). The user's preferred
  language is read from `user.prefs.language`; unknown values fall back to English.
* Message style is deliberately warm and non-pushy, and it fires as a native phone
  notification (not an in-app banner).
* The admin can let members opt out from the app: Admin Dashboard →
  **Content Management → Monthly Support Reminder**. The flag is stored in the
  `app_settings` collection as document `monthly_reminder` with
  `value.user_toggle_enabled`. While the flag is `false` (the default) the toggle
  in *Settings → Notifications* is greyed out and every member receives the reminder.
* Deployment docs: `appwrite_functions/monthlyDonationReminder/README.md`.

> [!NOTE]
> **Why `databases.read` / `documents.read` instead of `rows.read`?**
> Appwrite Console uses document/collection terminology rather than SQL row terminology. When configuring API keys or function scopes in the Appwrite Console, select **`databases.read`** and/or **`documents.read`** (under the Databases section). `createLiveKitToken` reads the user's role from the users collection/document (`APPWRITE_USERS_TABLE_ID`).

### Automated Sync Script:
All variables above can be updated and synchronized in bulk directly from your local `.env` file by running:
```bash
node scripts/upsert_appwrite_function_variables.mjs
```

### Transactional Email Delivery Rules (Resend)

> [!IMPORTANT]
> **Only `app.alivenigeria.org` is verified for sending in Resend.**
> A `From` address on the bare `alivenigeria.org` domain (e.g. `app@alivenigeria.org`)
> is rejected by Resend with:
> `403 validation_error — "The alivenigeria.org domain is not verified."`
> This silently broke donation receipts and welcome emails in production, so keep the
> rule below in mind whenever email configuration changes.

| Setting | Value in this project | Notes |
|---|---|---|
| `SENDER_EMAIL` | `ALIVE Nigeria App <msg@app.alivenigeria.org>` | Default `From` for `send_email`. Must stay on a verified domain. |
| `RECEIPT_SENDER_EMAIL` | `ALIVE Nigeria App <receipts@app.alivenigeria.org>` | `From` for donation receipts (all three functions). Must stay on a verified domain. |
| `REPLY_TO_EMAIL` | `app@alivenigeria.org` | Added as `reply_to` to **every** outbound email so member/donor replies reach a monitored inbox. Reply-To does **not** need to be a verified domain. |

* Verify the current state at any time:
  ```bash
  node scripts/check_resend_domains.mjs          # which domains are verified
  node scripts/verify_email_delivery.mjs         # sends a probe + prints reply_to
  node scripts/test_send_email.mjs you@example.com   # end-to-end function test
  ```
* Redeploy only the email/account functions (also repairs the `users.*.create`
  trigger that powers automatic welcome emails):
  ```bash
  node scripts/deploy_email_functions.mjs
  ```
* Full recurring-donation + email smoke test (NGN **and** USD):
  ```bash
  node scripts/smoke_test_payments.mjs
  ```
* `paystack_payments` **must** have `RESEND_API_KEY`: without it the
  `if (process.env.RESEND_API_KEY && customerEmail)` guard skips receipt
  delivery entirely (this was a second, independent cause of missing receipts).
* Receipt dispatch is now logged explicitly. Look for either
  `Receipt email dispatched to <email>: status 200` or
  `Receipt email FAILED for <email> (<status>): <resend response>` in the
  function execution logs on `api.alivenigeria.org`.

---

## 2. Coolify Environment Configuration

When deploying the Web App or Appwrite instances on Coolify:

### Flutter Web / HTML Frontend (Coolify Application):
- **Build Pack**: Nixpacks / Dockerfile
- **Build Command**: `npx -y serve build/web -p 3000` (or Nginx container pointing to `build/web`)
- **Port**: `3000` (or `80`)
- **Environment Variables**:
  ```env
  APPWRITE_ENDPOINT=https://api.alivenigeria.org/v1
  APPWRITE_PROJECT_ID=6a3bef53002f5090dedf
  APPWRITE_DATABASE_ID=6a089307002e54291a32
  PAYSTACK_PUBLIC_KEY=pk_live_xxxxxxxxx
  LIVEKIT_URL=wss://meet.alivenigeria.org
  ```

### Appwrite Self-Hosted Server (Coolify Service):
- **Domain**: `api.alivenigeria.org`
- **Docker Compose**: Standard Appwrite stack
- **Key Env Settings**:
  - `_APP_ENV=production`
  - `_APP_OPENSSL_KEY_V1=...`
  - `_APP_DOMAIN=api.alivenigeria.org`
  - `_APP_DOMAIN_TARGET=api.alivenigeria.org`
  - `_APP_REDIS_HOST=redis`
  - `_APP_DB_HOST=mariadb`

---

## 3. Admin & Content Manager Login Status

### Do Admin and Content Managers need to be invited or can they log in directly?
**Answer**: They can register and log in directly with their email and password!
- When a user signs up on ALIVE Nigeria, their default role is `member`.
- **Assigning Admin & Content Manager privileges**:
  1. **Primary Admin Account**: The email `alivenigeria2011@gmail.com` is automatically recognized by the system as the Root Administrator.
  2. **Inviting / Promoting Staff**:
     - The Root Admin can log in at `/admin` (or `/role-management`).
     - Go to **Role Management** &rarr; select the user &rarr; assign role `admin` or `content_editor`.
     - Alternatively, in the Appwrite Console under **Auth &rarr; Teams**, add their email to the `Administrators` (`admin`) or `Content Editors` (`editor`) team.
     - As soon as they are assigned the role or team membership, logging into the web or mobile app automatically gives them access to:
       - `/admin` &mdash; System Analytics, Approvals, Archive
       - `/content-management` &mdash; Dynamic pages, banners, announcements
       - `/admin-study-guides` &mdash; Creating & publishing Bible study guides
       - `/admin-kids-stories` & `/admin-kids-missions` &mdash; Managing children's material
       - `/tract-podcast-admin` &mdash; Uploading tracts and podcast episodes

---

## 4. Smoke Testing Procedures

### A. Quick Health Check:
Run the infrastructure ping script to verify connection to Appwrite:
```bash
node scripts/appwrite_platform_ping.mjs
```

### B. Core Features Smoke Test Checklist:
1. **Bible Reader**:
   - Open `/bible`. Select Yoruba (`BM`) and Igbo (`IGBOB`).
   - Verify verses load cleanly with zero `<pb/>`, `<t>`, or XML artifact tags.
   - Verify header shows current book and chapter, and auto-hides when scrolling.
2. **Donations**:
   - Open `/donation` (or Support ALIVE).
   - Verify dynamic years: "For more than 15 years..." (calculated from 2011).
   - Verify all 8 mission categories + Custom Purpose are selectable.
3. **Bottom Navigation & More**:
   - Verify Home is the first tab (index 0).
   - Open More &rarr; verify modern 2-column card grid.
   - Verify duplicate account items (Sign Out, Delete Account) are placed properly under Profile.
4. **Daily Tasks**:
   - Open `/daily`. Verify Duolingo-style streak counter.
   - Tap any task &rarr; verify it opens the feature directly and records completion.
5. **Help & Support**:
   - Open `/help-support`. Tap any guide item &rarr; expands inline directly with no redundant modal popups.

---

## 5. Google Sign-In Setup & Unblocking Guide

If users or testers encounter a blockage with **"Continue with Google"**, verify the following 3 configuration checkpoints:

### Checkpoint 1: Google Cloud Console (Credentials &rarr; OAuth 2.0 Client IDs)
Under your Web application Client ID:
- **Authorized JavaScript origins**:
  - `https://api.alivenigeria.org`
  - `https://app.alivenigeria.org`
  - `http://localhost` (for local development)
- **Authorized redirect URIs**:
  - `https://api.alivenigeria.org/v1/account/sessions/oauth2/callback/google`
  *(CRITICAL: Must point to the Appwrite API server `api.alivenigeria.org`, NOT the web app).*

### Checkpoint 2: Appwrite Console (Auth &rarr; Settings &rarr; OAuth2 Providers)
- Locate **Google** and ensure it is **Enabled**.
- Paste the **Client ID** (App ID) and **Client Secret** (App Secret) from Google Cloud Console.

### Checkpoint 3: Appwrite Console &rarr; Overview / Settings &rarr; Platforms
Appwrite blocks any OAuth redirect if the calling platform is not explicitly registered:
1. **Web Platform**:
   - **Name**: `ALIVE Web App`
   - **Hostname**: `app.alivenigeria.org` (and `localhost` for local dev)
2. **Android Platform**:
   - **Name**: `ALIVE Nigeria`
   - **Package Name**: `com.alive.alivengandroidapp`
   *(This matches `android/app/build.gradle.kts` and the callback scheme `appwrite-callback-6a3bef53002f5090dedf` configured in `AndroidManifest.xml`).*
3. **Apple Platform** (for iOS):
   - **Name**: `ALIVE Nigeria`
   - **Bundle ID**: `com.alive.alivengandroidapp`

### Checkpoint 4: Coolify Appwrite Server `.env`
In Coolify, check your Appwrite service Environment Variables:
```env
_APP_DOMAIN=api.alivenigeria.org
_APP_DOMAIN_TARGET=api.alivenigeria.org
_APP_ENV=production
```
If `_APP_DOMAIN` was left as default `localhost`, Appwrite generates an invalid redirect URI to Google. Updating it to `api.alivenigeria.org` and redeploying the Appwrite container in Coolify resolves this immediately.

---

## 6. Coolify Appwrite Environment Automation

If you have multiple Appwrite (or other) services in Coolify and cannot easily locate the right one, use the automation script below to **automatically find the Appwrite service** and update critical env vars like `_APP_DOMAIN`.

### Step 1: Create a Coolify API Token

1. Log into your Coolify dashboard (e.g. `https://coolify.yourdomain.com`).
2. Click your **profile icon** (top-right) → **Settings** → **API Tokens** (or navigate to **Security → API Tokens**).
3. Click **"Create Token"**.
4. Give it a descriptive name, e.g. `alive-deploy`.
5. Ensure it has **read + write** permissions.
6. Copy the generated token immediately — it will not be shown again.

### Step 2: Add Coolify credentials to `.env`

Add the following to your project root `.env` file:

```env
# Coolify API Configuration
COOLIFY_API_URL=https://coolify.yourdomain.com
COOLIFY_API_TOKEN=your-api-token-here

# Optional: If you have multiple Appwrite services and want to target a specific one
# COOLIFY_SERVICE_UUID=abc123-uuid-here
```

### Step 3: Run the automation script

```bash
# Preview changes without applying (recommended first run):
node scripts/coolify_update_appwrite_env.mjs --dry-run

# Apply changes:
node scripts/coolify_update_appwrite_env.mjs

# Apply changes AND redeploy the Appwrite service immediately:
node scripts/coolify_update_appwrite_env.mjs --redeploy
```

### What the script does:

1. **Lists all services** in your Coolify instance via the API.
2. **Auto-identifies** the Appwrite service by scanning names, descriptions, and Docker Compose content.
3. **Checks** `_APP_DOMAIN`, `_APP_DOMAIN_TARGET`, and `_APP_ENV` against expected values.
4. **Reports** which variables are correct and which need updating.
5. **Applies** changes via the Coolify API (unless `--dry-run` is used).
6. **Optionally redeploys** the service (if `--redeploy` flag is passed).

### Manual fallback

If the API approach doesn't work for your Coolify version, update manually:

1. Coolify Dashboard → **Services** → find your Appwrite stack.
2. Click the Appwrite service → **Environment Variables** tab.
3. Find or add: `_APP_DOMAIN=api.alivenigeria.org`
4. Find or add: `_APP_DOMAIN_TARGET=api.alivenigeria.org`
5. Click **Save** → **Redeploy**.

