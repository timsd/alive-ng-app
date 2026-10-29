# ALIVE Nigeria App — Project Handover & Engineering Documentation

**Document Version:** 2.0.4  
**Date:** October 2026  
**Application Name:** ALIVE Nigeria (Flutter)  
**Package:** `alive_flutter_app`  
**Current Production Version:** `2.0.4+11`  
**Target Platforms:** Android (APK & AAB), Web (Coolify Docker / Nginx), Windows  

---

## 1. Executive Summary

ALIVE Nigeria is a comprehensive Christian ministry mobile and web application built using **Flutter** and powered by a self-hosted **Appwrite** backend (`api.alivenigeria.org`), deployed on **Coolify**, with **Paystack** for donations/subscriptions, **LiveKit** for interactive meetings/livestreams, **Resend** for transactional email, and **GlitchTip** (Sentry-compatible) for crash analytics.

The application serves discipleship, daily devotionals, Bible reading (offline SQLite), podcast audio streaming, tracts and literature distribution, children's ministry, health education, prayer requests, and organizational administration across local chapters.

---

## 2. Architecture & Design Patterns

### 2.1 Hexagonal (Ports & Adapters) Architecture
The codebase strictly adheres to Hexagonal Architecture:
- **Domain Models (`lib/models/`)**: Owned, SDK-agnostic domain objects (`AppUser`, `UserProfile`, `PaymentRequest`, `MeetingSession`, `BibleVerse`). They have zero third-party SDK dependencies.
- **Ports (`lib/services/ports/`)**: Pure abstract interfaces defining external boundary contracts:
  - `AuthGateway`: Authentication, session lifecycle, password recovery.
  - `PaymentGateway`: Payment initiation, verification, subscription management.
  - `MeetingGateway`: Video/audio conferencing, token minting, room connection.
- **Adapters (`lib/services/adapters/`)**: Concrete implementations talking to third-party SDKs:
  - `AppwriteAuthGateway` wraps Appwrite Account/Users.
  - `LiveKitMeetingGateway` wraps LiveKit Client SDK.
  - `PaystackPaymentGateway` wraps server-side Paystack Cloud Functions.
- **State Management (`lib/providers/`)**: `flutter_riverpod` (v2.6.1). Screens consume providers which talk only to Ports or Domain Services, keeping UI completely decoupled from backend SDKs.
- **Navigation (`lib/utils/app_router.dart`)**: `go_router` (v14.8.1) with declarative routes and role-based redirect guards.

---

## 3. Core Systems & Implementation Details

### 3.1 Authentication & Profile Lifecycle
1. **Email / Password Sign-Up**:
   - Collects user full name, contact, local church, chapter, and commitment.
   - Automatically sets account preference `'profile_setup_completed': true` upon creation.
   - Email/password users **never** see the "Complete Profile" interstitial.
2. **Google OAuth Sign-Up**:
   - Creates an account using Google metadata.
   - The provider `profileSetupRequiredProvider` detects missing phone/chapter/commitment and routes user to `/profile-setup` for one-time onboarding.
3. **Biometrics (Mobile)**:
   - Uses `local_auth` and `flutter_secure_storage`.
   - Offered immediately after a successful initial email/password sign-in.
   - Provides options: "Enable", "Skip", and "Don't ask again" (`_biometricDismissedKey` persisted in `SharedPreferences`).
   - Can be toggled at any time from Profile Preferences.
4. **Dynamic Avatar Handling**:
   - Supports Appwrite Storage uploads (`uploadProfileFile`) with immediate optimistic local byte rendering.
   - Automatically invalidates `currentUserProfileProvider` and evicts `CachedNetworkImageProvider` and Flutter `imageCache` to prevent stale avatar displays.
   - `GreetingHeader` dynamically loads the user's avatar image or falls back to their first initial.
   - Profile edit supports smooth horizontal step swiping with interactive step indicators (`ProfilePageCues`).

### 3.2 Indigenous Language Support
- Fully localized in **English (`en`)**, **Yorùbá (`yo`)**, **Hausa (`ha`)**, and **Igbo (`ig`)**.
- First card of Onboarding flow features an indigenous language selector.
- Daily devotionals and Scripture memory verses dynamically display in the user's chosen indigenous language.
- Preferences language picker allows on-the-fly language switching across the entire app.

### 3.3 Security & Role-Based Access Control (RBAC)
- **Production RBAC Enforced**: `development_config.dart` has been **completely removed**.
- **No Bypass in Production**: Role access checks in `RoleAccessService` and `RoleGuard` strictly evaluate Appwrite user claims and roles (`admin`, `leader`, `dietist`, `member`, `guest`).
- **Paystack Secret Isolation**: Paystack secret key exists **only** inside Appwrite server-side Functions (`paystack_payments`). The client app receives only the public key via Coolify `--dart-define` (`PAYSTACK_PUBLIC_KEY`) and dynamic runtime sync. Hardcoded fallback keys have been completely eliminated.
- **Circular Imports Decoupled**: Appwrite client instances (`appwriteClient`, `appwriteAccount`, `appwriteStorage`, `appwriteRealtime`) reside in `lib/services/appwrite_client.dart` and are re-exported by `main.dart` for backwards compatibility.

---

## 4. Single Source of Truth for Versioning

To eliminate version drift between `pubspec.yaml`, Dart constants, and Web metadata:
1. **The Single Source of Truth is `pubspec.yaml`** (`version: 2.0.4+11`).
2. **Automated Synchronization**:
   - Script: `scripts/sync_version_from_pubspec.mjs`
   - Command: `npm run version:sync`
   - Automatically called before all web and mobile builds (`npm run build:apk`, `npm run build:aab`, `npm run build:web`).
   - Syncs version directly into `lib/constants/app_constants.dart` (`AppConstants.appVersion`) and `web/index.html` (`<meta name="version">`).
3. **Runtime App Version**:
   - `AboutAppScreen`, `InAppUpdateService`, and `AnalyticsService` read dynamically from the compiled platform bundle using `package_info_plus`.

---

## 5. Build & Deployment Runbook

### 5.1 Prerequisites
- **Flutter SDK**: `>=3.10.0 <4.0.0`
- **Node.js**: `>=20.0.0`
- **Android SDK & Build Tools**: API 34+
- **Coolify Admin Access** / `.env` file configured on build machine

### 5.2 Build Commands

```bash
# 1. Sync version from pubspec.yaml
npm run version:sync

# 2. Build Release APK (Coolify production environment injected)
npm run build:apk

# 3. Upload APK to Appwrite Storage bucket & update version setting
npm run appwrite:upload-android-release
npm run appwrite:app-version

# 4. Build Release Android App Bundle (AAB for Google Play Console)
npm run build:aab

# 5. Build Web Release
npm run build:web
```

### 5.3 Output Locations
- **APK**: `build/app/outputs/flutter-apk/app-release.apk`
- **AAB**: `build/app/outputs/bundle/release/app-release.aab`
- **Web**: `build/web/`
- **Public APK Download**: `https://api.alivenigeria.org/v1/storage/buckets/app_releases/files/alive_ng_android_release/download?project=6a3bef53002f5090dedf`

---

## 6. Environment & Secret Management

- **Local Development**: Copy `.env.example` to `.env`. Never commit `.env` to git.
- **Coolify Production Web**: Environment variables are managed in the Coolify App Dashboard (`FLUTTER_BUILD_ARGS`).
- **Secret Rotation Checklist**:
  - `APPWRITE_API_KEY`: Appwrite Console → Project Settings → API Keys.
  - `PAYSTACK_SECRET_KEY`: Paystack Dashboard → Settings → API Keys & Webhooks. Also update in Appwrite Function variables for `paystack_payments`.
  - `LIVEKIT_API_SECRET`: LiveKit Cloud / Server → Keys. Update in `createLiveKitToken` Appwrite Function.
  - `RESEND_API_KEY`: Resend Console → API Keys. Update in `send_email` Appwrite Function.

---

## 7. Key Contacts & Handover Verification

| Area | Verified Status |
| :--- | :--- |
| **Flutter Analysis** | 0 errors across all screens and widgets |
| **Android APK Release** | Built & Hosted on Appwrite Storage (`v2.0.4`) |
| **Android AAB Release** | Built & ready for Play Store Console (`v2.0.4+11`) |
| **RBAC Security** | Tested; `development_config.dart` removed |
| **Git Repository** | Up to date with `origin/master` |

