/// Abstract port (driven-side) for authentication.
///
/// This defines the **contract** that any concrete auth backend must satisfy.
/// The rest of the app depends on [AuthGateway], never on a specific SDK.
///
/// Concrete adapters live in `lib/services/adapters/` and import the
/// backend SDK internally.
///
/// ```text
///   UI / Providers  ──▶  AuthGateway (port)  ◀──  AppwriteAuthAdapter
///                                              ◀──  MockAuthAdapter (tests)
/// ```
library;

import '../../models/auth_models.dart';

/// The primary authentication port.
///
/// Every method uses [AppUser] and [AppAuthResult] — our owned domain types —
/// so that callers never need to know whether Appwrite, Firebase, or
/// a mock is behind this interface.
abstract class AuthGateway {
  // ──────────────────────────────────────────────────────────
  //  Session / current user
  // ──────────────────────────────────────────────────────────

  /// Returns the currently authenticated [AppUser], or `null` if no valid
  /// session exists.
  Future<AppUser?> getCurrentUser();

  /// Synchronous accessor for the last-known user (may be stale).
  AppUser? get currentUser;

  /// Whether there is a currently authenticated session.
  bool get isAuthenticated;

  /// A broadcast stream that emits the latest [AppUser?] whenever the
  /// auth state changes (sign in, sign out, token refresh, etc.).
  Stream<AppUser?> get authStateChanges;

  // ──────────────────────────────────────────────────────────
  //  Email / password
  // ──────────────────────────────────────────────────────────

  /// Creates a new account and signs the user in.
  Future<AppAuthResult> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
    SignupProfile? profile,
  });

  /// Signs in with existing email + password credentials.
  Future<AppAuthResult> signInWithEmail({
    required String email,
    required String password,
  });

  // ──────────────────────────────────────────────────────────
  //  OAuth / Social
  // ──────────────────────────────────────────────────────────

  /// Initiates a Google OAuth sign-in flow.
  Future<AppAuthResult> signInWithGoogle();

  // ──────────────────────────────────────────────────────────
  //  Password recovery
  // ──────────────────────────────────────────────────────────

  /// Sends a password-recovery email to [email].
  ///
  /// Returns `true` if the request was accepted by the backend.
  Future<bool> sendPasswordRecovery(String email);

  /// Completes a password-recovery flow using the token delivered via email.
  Future<bool> completePasswordRecovery({
    required String userId,
    required String secret,
    required String newPassword,
  });

  // ──────────────────────────────────────────────────────────
  //  Session lifecycle
  // ──────────────────────────────────────────────────────────

  /// Ends the current session and clears cached user state.
  Future<void> signOut();
}
