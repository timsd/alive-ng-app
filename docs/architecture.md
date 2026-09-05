# ALIVE Nigeria App — Architecture Decision Record

> **Last Updated**: September 4, 2026
> **Status**: Active & Enforced

---

## 1. Ports & Adapters (Hexagonal Architecture)

### Rule

> **No third-party SDK type (Appwrite, LiveKit, Paystack, SQLite) may cross into `lib/providers/` or `lib/screens/`.
> All SDKs must be isolated inside `lib/services/adapters/` behind an abstract contract in `lib/services/ports/`.**

### Rationale

Third-party SDKs change their public API surface across major versions. If SDK types leak into UI screens and Riverpod providers, a single SDK bump can cascade into dozens of broken files. By confining every SDK behind a port (abstract class) and implementing it in exactly one adapter file, an upgrade only touches one file per SDK.

### Directory Structure

```
lib/
├── models/                          # Owned domain types (zero SDK imports)
│   ├── auth_models.dart             # AppUser, AppAuthResult
│   ├── meeting_models.dart          # MeetingSession, ParticipantInfo, RoomStatus
│   ├── payment_models.dart          # PaymentRequest, PaymentResponse, PaymentStatus
│   └── bible_models.dart            # BibleVerse, BibleChapter, BibleUserProgress
│
├── services/
│   ├── ports/                       # Abstract contracts (zero SDK imports)
│   │   ├── auth_gateway.dart        # AuthGateway
│   │   ├── meeting_gateway.dart     # MeetingGateway
│   │   └── payment_gateway.dart     # PaymentGateway
│   │
│   ├── adapters/                    # Concrete implementations (SDK imports confined here)
│   │   ├── appwrite_auth_gateway.dart      # implements AuthGateway  → imports appwrite
│   │   ├── livekit_meeting_gateway.dart    # implements MeetingGateway → imports livekit_client
│   │   └── paystack_payment_gateway.dart   # implements PaymentGateway → imports paystack_flutter_sdk
│   │
│   ├── bible_database_helper.dart   # SQLite layer (sqflite confined here)
│   ├── tract_database_helper.dart   # SQLite layer (sqflite confined here)
│   ├── admin_database_helper.dart   # SQLite layer (sqflite confined here)
│   └── offline_bible_service.dart   # Facade over bible_database_helper
│
├── providers/                       # Riverpod providers (consume ports, never SDKs)
└── screens/                         # UI layer (consume providers & domain models only)
```

### Enforcement

Run the following command before every PR merge:

```bash
flutter analyze lib/
```

Additionally, verify SDK isolation with:

```bash
# Appwrite must only appear in adapters and service wrappers
grep -r "import.*package:appwrite" lib/ --include="*.dart" | grep -v "services/"

# LiveKit must only appear in its adapter
grep -r "import.*package:livekit_client" lib/ --include="*.dart" | grep -v "adapters/"

# Paystack must only appear in its adapter
grep -r "import.*package:paystack_flutter_sdk" lib/ --include="*.dart" | grep -v "adapters/"

# sqflite must only appear in *_database_helper.dart files
grep -r "import.*package:sqflite" lib/ --include="*.dart" | grep -v "database_helper"
```

All four commands should return **zero results**.

### Adding a New SDK

1. Create owned domain types in `lib/models/<domain>_models.dart`.
2. Define an abstract port in `lib/services/ports/<domain>_gateway.dart`.
3. Implement the adapter in `lib/services/adapters/<sdk>_<domain>_gateway.dart`.
4. Register a Riverpod provider that returns the port type, not the adapter.
5. UI screens consume only the provider and domain models.

---

## 2. Framework Dependency Freeze Policy

### Rule

> **Keep `flutter_riverpod` pinned to `2.6.x` and `go_router` pinned to `14.x` until feature requirements strictly mandate an upgrade.**

### Current Pinned Versions

| Package | Pinned Version | Reason |
|---|---|---|
| `flutter_riverpod` | `^2.6.1` | Stable Riverpod 2.x API; avoid Generator/Notifier migration churn |
| `go_router` | `^14.0.0` | Stable routing API; v15+ may introduce StatefulShellRoute changes |
| `appwrite` | `^26.1.0` | Latest SDK; upgraded from v21 via adapter pattern (Phase 4) |
| `livekit_client` | `^2.7.0` | Stable; isolated behind `MeetingGateway` adapter |
| `paystack_flutter_sdk` | `^0.0.1-alpha.2` | Alpha; isolated behind `PaymentGateway` adapter |
| `sqflite` | `^2.4.2` | Stable; confined to `*_database_helper.dart` files |

### Upgrade Protocol

1. **Check the changelog** of the target package for breaking changes.
2. **Update only the adapter file** that imports the package.
3. **Run `flutter analyze lib/`** — must show 0 issues.
4. **Run the SDK isolation grep checks** above — must show 0 leaks.
5. **Update this document** with the new pinned version and date.

---

## 3. Migration History

| Phase | Date | Description |
|---|---|---|
| Phase 1 | 2026-09-04 | Auth domain models (`AppUser`, `AppAuthResult`) and `AuthGateway` port |
| Phase 2 | 2026-09-04 | `AppwriteAuthGateway` adapter + Riverpod provider rewiring |
| Phase 3 | 2026-09-04 | Removed `appwrite/models.dart` from all UI screens and controllers |
| Phase 4 | 2026-09-04 | Upgraded Appwrite SDK v21 → v26 (adapter-only changes) |
| Phase 5 | 2026-09-04 | LiveKit decoupled via `MeetingGateway` + `LiveKitMeetingGateway` |
| Phase 6 | 2026-09-04 | Payment decoupled via `PaymentGateway` + `PaystackPaymentGateway` |
| Phase 7 | 2026-09-04 | Bible storage cleanup — typed domain models replace raw `Map<String, dynamic>` |
| Phase 8 | 2026-09-04 | Architecture documentation and dependency version freeze |
