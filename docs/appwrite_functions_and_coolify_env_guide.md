# Appwrite Functions, Coolify Deployment, and Administration Guide

## Overview
This document specifies all required environment variables, configuration keys, and operational procedures for **Appwrite Functions**, **Coolify Hosting**, and **Role Management (Admin & Content Managers)** for ALIVE-NG.

---

## 1. Appwrite Functions Environment Variables Matrix

The repository includes 4 serverless Node.js 20 functions under `appwrite_functions/`:

| Function Name | Function ID | Runtime | Required Environment Variables | Scopes Needed |
|---|---|---|---|---|
| **createLiveKitToken** | `6a08e9010035dc8c1e51` | `node-20.0` | `LIVEKIT_API_KEY`<br>`LIVEKIT_API_SECRET`<br>`APPWRITE_ENDPOINT`<br>`APPWRITE_PROJECT_ID`<br>`APPWRITE_DATABASE_ID`<br>`APPWRITE_USERS_TABLE_ID`<br>`APPWRITE_FUNCTION_API_KEY` | `rows.read` |
| **paystackPayments** | `paystack_payments` | `node-20.0` | `PAYSTACK_SECRET_KEY`<br>`APPWRITE_ENDPOINT`<br>`APPWRITE_PROJECT_ID`<br>`APPWRITE_DATABASE_ID`<br>`APPWRITE_FUNCTION_API_KEY`<br>`APPWRITE_PAYMENT_LOGS_COLLECTION_ID` | `databases.read`<br>`databases.write` |
| **paystackWebhook** | `paystack_webhook` | `node-20.0` | `PAYSTACK_SECRET_KEY`<br>`APPWRITE_ENDPOINT`<br>`APPWRITE_PROJECT_ID`<br>`APPWRITE_DATABASE_ID`<br>`APPWRITE_FUNCTION_API_KEY`<br>`APPWRITE_DONATION_RECORDS_COLLECTION_ID`<br>`APPWRITE_PROJECTS_COLLECTION_ID`<br>`APPWRITE_PAYMENT_LOGS_COLLECTION_ID`<br>`RESEND_API_KEY` (for receipts) | `databases.read`<br>`databases.write` |
| **sendEmail** | `send_email` | `node-20.0` | `RESEND_API_KEY`<br>`RECEIPT_SENDER_EMAIL`<br>`SENDER_EMAIL` | None (external API) |

### Automated Sync Script:
All variables above can be updated and synchronized in bulk directly from your local `.env` file by running:
```bash
node scripts/upsert_appwrite_function_variables.mjs
```

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
- When a user signs up on ALIVE-NG, their default role is `member`.
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
