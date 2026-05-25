# CHANGELOG

All notable changes to the ALIVE-NG App are documented here.
Format: [Semantic Versioning](https://semver.org) - `MAJOR.MINOR.PATCH+BUILD`

---

## Unreleased

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
