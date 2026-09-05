# CHANGELOG

All notable changes to the ALIVE-NG App are documented here.
Format: [Semantic Versioning](https://semver.org) - `MAJOR.MINOR.PATCH+BUILD`

---

## Unreleased

---

## [1.2.0] - 2026-09-04

### Added
- **Hexagonal Architecture (Ports & Adapters)** across all third-party integrations:
  - **Authentication**: Isolated behind `AuthGateway` port (`lib/services/ports/auth_gateway.dart`) and `AppwriteAuthGateway` adapter (`lib/services/adapters/appwrite_auth_gateway.dart`). Created owned `AppUser` and `AppAuthResult` models (`lib/models/auth_models.dart`). Decoupled all screens, widgets, and Riverpod providers from `package:appwrite/models.dart`.
  - **Video Meetings (LiveKit)**: Isolated behind `MeetingGateway` port (`lib/services/ports/meeting_gateway.dart`) and `LiveKitMeetingGateway` adapter (`lib/services/adapters/livekit_meeting_gateway.dart`). Created owned `MeetingSession`, `ParticipantInfo`, and `RoomStatus` models (`lib/models/meeting_models.dart`). Confined `package:livekit_client` strictly to the adapter.
  - **Payment Processing (Paystack)**: Isolated behind `PaymentGateway` port (`lib/services/ports/payment_gateway.dart`) and `PaystackPaymentGateway` adapter (`lib/services/adapters/paystack_payment_gateway.dart`). Created owned `PaymentRequest`, `PaymentResponse`, and `PaymentStatus` models (`lib/models/payment_models.dart`). Standardized reference generation (`ALIVE-WEB-APP-` for web and `ALIVE-FLUTTER-` for mobile) and clean browser redirect vs. native SDK execution.
  - **Bible Storage & SQLite**: Created `BibleUserProgress` domain model in `lib/models/bible_models.dart`. Refactored `BibleDatabaseHelper` and `OfflineBibleService` to return typed domain models instead of raw `Map<String, dynamic>`. Refactored `bible_reader_screen.dart` to consume `models.BibleVerse` instead of raw maps. Confined `sqflite` imports strictly to `*_database_helper.dart`.
- **Architecture Documentation & Freeze Policy**: Added `docs/architecture.md` defining the Ports & Adapters rules, verification grep commands, upgrade protocol, and framework freeze policy (`flutter_riverpod: ^2.6.1`, `go_router: ^14.0.0`).

### Changed
- **Appwrite Dart SDK**: Upgraded from `^21.3.0` to `^26.1.0` in `pubspec.yaml`. All breaking changes resolved strictly within the adapter layer (`lib/services/adapters/appwrite_auth_gateway.dart`) without leaking to any UI screens.

### Changed
- Continued Firebase-to-Appwrite migration; project status is about 99.5% migrated.
- Stabilized Bible game state handling, multiple-choice answer checking, fill-gap blank selection, speech/TTS cleanup, and daily verse randomization.
- Improved UI/theme consistency for shared buttons, admin settings/board/meeting file surfaces, podcast cards, tract reader progress text, and role access screens in light and dark mode.
- Kids content CRUD and default seeding now use Appwrite instead of Firestore.
- Meeting file sharing now stores files and metadata through Appwrite Storage/Databases.
- Enhanced health service now uses Appwrite Databases instead of Firestore.
- Leadership records and leadership transition history now use Appwrite Databases instead of Firestore.
- Discipleship contacts, interactions, study sessions, prayer tracking, milestones, and reports now use dedicated Appwrite collections instead of Firestore.
- Chapter management, memberships, activities, tasks, reports, and task assignments now use Appwrite collections instead of Firestore.
- Archived unused legacy `AdminService` into `oldfirebasedelete`.
- Archived unused `FirestoreService` into `oldfirebasedelete`.
- Renamed the Appwrite-backed storage compatibility facade from `FirebaseStorageService` to `AppwriteStorageCompatService`.
- Updated Appwrite/Coolify/LiveKit/Paystack documentation to reflect current migration state and server reachability blocker.

### Notes
- Firebase Messaging, native Firebase config, legacy server/functions code, and the mixed `FirebaseDatabaseService` compatibility bridge remain until their active Firebase internals are replaced.
- Real Appwrite provisioning is blocked while the current server/domain is unreachable; `npm run appwrite:dry-run` remains the safe local validation command.

---

## [1.1.0+2] - 2026-03-12

### Added
- **View Projects modal** on Donation screen - fetches live ministry projects from Firestore, ordered by priority. Each card shows image, title, summary, description, goal/raised in NGN, and status badge.
- **Per-project donate button** - pre-selects a project on the donation form (works for guests and signed-in users).
- **App-wide Material 3 text hierarchy** - consistent `textTheme` (`displayLarge` to `labelSmall`) in both light and dark themes.
- **Dev admin bypass** (`lib/debug/dev_admin_override.dart`) - debug-mode-only floating button for testing admin screens without Firebase custom claims.

### Fixed
- Study guide screen grey colors replaced with theme-aware colors (dark mode visibility).
- Podcast bottom sheet drag handle now theme-aware.
- Donation dialog: removed non-Paystack payment options (PayPal, bank transfer, mobile money) - Paystack is the only provider.
- `donation_dialog.dart` hardcoded `Colors.grey` replaced with `colorScheme.onSurface` equivalents.
- Web `index.html`: "Donate for this item" donation flow confirmation + GA event tracking.

### Changed
- `PaymentMethod` enum: Paystack is the only active payment provider. Legacy enum values kept for backward compatibility with Firestore records.
- Projects Firestore query: now orders by `priority` (matching web modal). Shows all statuses (active, planning, completed) in app picker.

---

## [1.0.0+1] - Initial Release

### Added
- Bible reader with multiple translations, book/chapter navigation.
- Bible game (fill-the-gaps, multiple choice).
- Daily devotional verse rotation from local bundled Bible corpus.
- Prayer journal and testimonies.
- Study guides and programs.
- Discipleship modules.
- Podcast listing and playback.
- Books & Tracts (download with donation).
- Health tracker (activities, fasting, wellness).
- Donation screen with Paystack integration.
- Admin dashboard (announcements, content, users, board).
- Firebase Auth (email/password + Google Sign-In).
- Push notifications (Firebase Messaging).
- Light and dark theme support.
- Responsive layout (mobile, tablet, desktop).
