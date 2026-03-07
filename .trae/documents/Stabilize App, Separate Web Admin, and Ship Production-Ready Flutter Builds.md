## Goals
- Deliver a well-running Flutter app (Android/iOS) with stable builds, clean architecture, and verified features
- Keep mobile as the primary end-user experience; make web the admin/landing/legal surface with auto-sync to the app
- Hardening: security rules, platform configs, crash/analytics, CI/CD

## Current State Highlights
- Riverpod + GoRouter, responsive helpers are in place (`lib/utils/responsive_utils.dart`)
- Rich feature set (Prayer, Study, Health, Missions, Kids, Admin) with Firebase backend
- Web folder contains static landing/legal pages and FCM service worker
- Minor tech debt: duplicated providers and mixed use of deprecated MobileUtils

## Phase 1: Codebase Audit & Fixes
- Remove duplicate provider definitions to avoid DI confusion
  - Unify `firebaseDatabaseServiceProvider` (duplicates in `lib/providers/auth_provider.dart:28` and `lib/providers/firebase_database_provider.dart:5`)
- Migrate deprecated MobileUtils calls toward `ResponsiveUtils` and context extensions for consistency
  - Example call site opened: `lib/screens/prayer_screen.dart:428` uses `MobileUtils.getResponsiveHorizontalPadding(context)`; plan to move to `context.responsivePadding` or `ResponsiveUtils.getResponsivePadding(context)` where appropriate
- Standardize imports to `package:alive_flutter_app/...` across screens/components
- Lint and cleanup: run analyzer, resolve warnings, ensure null-safety idioms throughout

## Phase 2: Platform Configuration (Android/iOS)
- Android
  - Set up real release signing config and keystore; current release uses debug signing (`android/app/build.gradle.kts:38–41`)
  - Verify `google-services.json` and Firebase BOM usage; keep multidex and target SDK from Flutter
- iOS
  - Tighten ATS: remove `NSAllowsArbitraryLoads` if not strictly required, set domain-specific exceptions (`ios/Runner/Info.plist:101–105`)
  - Confirm push notification entitlements, background modes and `GoogleService-Info.plist` placement
- Common
  - Replace hardcoded FirebaseOptions with generated `firebase_options.dart` using FlutterFire CLI (keeps secrets out of source)
  - Ensure runtime checks skip unsupported services on web (Crashlytics already skipped)

## Phase 3: Web Strategy (Admin + Landing)
- Keep mobile as primary user experience
- Web surfaces:
  - Admin console: build with Flutter (existing entry: `lib/admin_preview_main.dart`) and host on `/admin` subdomain or path
  - Landing + legal + downloads: use static pages in `web/` (`index.html`, `privacy-policy.html`, `terms-conditions.html`, `legal.html`)
  - Add Play Store and App Store buttons and basic product overview/onboarding to `web/index.html`
- Build targets
  - `flutter build web --target=lib/admin_preview_main.dart` for admin
  - `flutter build web --target=lib/main.dart` only if PWA user view is desired; otherwise keep mobile-only for user-facing

## Phase 4: Admin Content → Auto-sync to App
- Use Firestore as single source of truth; app already reads via `FirebaseDatabaseService` (e.g., `getDynamicContent`, `getContentPageBySlug`)
- Admin screens exist for content management (`lib/screens/admin/content_management_screen.dart`, `content_page_editor_screen.dart`, approvals, roles)
- Implement/verify composite indexes for queries that use `where + orderBy` (e.g., prayer requests at `lib/services/firebase_database_service.dart:276–285`)
- Ensure RoleAccess gating for admin routes is enforced (GoRouter redirects already present in `lib/utils/app_router.dart:200–211`)

## Phase 5: UX Polish & Onboarding
- In-app onboarding and help:
  - Expand About/Help screens (`lib/screens/about/*`, `lib/screens/help/help_support_screen.dart`) with a guided walkthrough of app features and navigation
  - Provide “User Guides” content via Firestore so admins can update onboarding copy dynamically
- Responsive consistency:
  - Replace remaining `MobileUtils` spacing/width with `context.responsive*` where feasible to keep one design system
- Error/empty states: standardize loading/error widgets via shared components (`lib/widgets/error_widget.dart`, `loading_widget.dart`)

## Phase 6: Security & Privacy
- Firestore Security Rules
  - Enforce role-based reads/writes for collections: `prayer_requests`, `content_pages`, `board_documents`, `profiles`, etc.
  - Prevent anonymous writes except where explicitly allowed; log audits for admin operations
- FCM Topics
  - Confirm role-subscriptions (`lib/config/firebase_config.dart:302–359`) and keep topic lists server-driven
- ReCAPTCHA / spam protection
  - Keep web-only recaptcha (`web/recaptcha_integration.html`) for public forms; mobile can rely on authenticated writes

## Phase 7: Observability & QA
- Crash/Analytics
  - Enable Crashlytics/Analytics on mobile release, set user IDs when logged in (`lib/config/firebase_config.dart:394–406`)
- Testing
  - Add widget tests for critical screens (Auth, Prayer list/filter, Admin approvals)
  - Smoke tests for router and role gated redirects
- CI/CD
  - GitHub Actions or local scripts to build Android/iOS releases and admin web bundle; sign Android bundle with secure keystore

## Deliverables
- Cleaned providers and responsive utils usage
- Production-ready Android/iOS builds with proper signing/permissions
- Admin web build with landing/legal pages and store download links
- Documented Firestore indexes + hardened security rules
- Onboarding content accessible in app and maintained from admin

## How The Sync Works (Best Practices)
- Admin edits content in web console → Firestore updates → app listens via streams (`subscribeToPrayerRequests` etc.) or fetches on demand; offline sync service handles persistence
- Keep schema consistent and versioned; index queries that combine `where` and `orderBy`
- Use role-based topics for targeted notifications; avoid exposing secrets on client

## Next Steps
1. Approve this plan
2. Implement Phase 1 fixes and verify builds (`flutter analyze`, `flutter run`)
3. Configure platform signing and FlutterFire env
4. Build and deploy admin web + update landing page with download buttons
5. Harden security rules and add indexes
6. Add onboarding guides/content managed via admin
