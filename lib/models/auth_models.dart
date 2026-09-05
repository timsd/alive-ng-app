/// Domain models for the authentication layer.
///
/// These models are SDK-agnostic: they MUST NOT import `package:appwrite`,
/// `package:firebase`, or any other third-party auth SDK.
/// They form the innermost ring of our Hexagonal Architecture and are
/// consumed by UI, providers, and business logic without coupling them
/// to a concrete backend.
library;

/// Represents an authenticated user in the ALIVE Nigeria app domain.
///
/// This is our *owned* type — a thin, immutable value object that the rest of
/// the app passes around instead of `models.User` from Appwrite (or any other
/// backend SDK).
class AppUser {
  /// Unique user identifier (matches the backend's user ID).
  final String uid;

  /// The user's primary email address.
  final String email;

  /// Human-readable display name (may be `null` for anonymous / new users).
  final String? displayName;

  /// URL to the user's profile photo, if available.
  final String? photoUrl;

  /// Whether the user's email has been verified by the backend.
  final bool isEmailVerified;

  /// Whether this represents an anonymous (guest) session.
  final bool isAnonymous;

  const AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.isEmailVerified = false,
    this.isAnonymous = false,
  });

  /// Convenience — returns [displayName] if available, otherwise the local
  /// part of [email].
  String get displayNameOrFallback =>
      displayName ?? email.split('@').first;

  /// Compatibility getter for legacy callers expecting `emailVerified`.
  bool get emailVerified => isEmailVerified;

  /// Compatibility getter for legacy callers expecting `photoURL`.
  String? get photoURL => photoUrl;

  /// Compatibility getter for legacy callers expecting `$id`.
  String get $id => uid;

  /// Compatibility getter for legacy callers expecting `name`.
  String get name => displayName ?? '';

  /// Creates a copy with the given fields replaced.
  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    bool? isEmailVerified,
    bool? isAnonymous,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          email == other.email &&
          displayName == other.displayName &&
          photoUrl == other.photoUrl &&
          isEmailVerified == other.isEmailVerified &&
          isAnonymous == other.isAnonymous;

  @override
  int get hashCode => Object.hash(
        uid,
        email,
        displayName,
        photoUrl,
        isEmailVerified,
        isAnonymous,
      );

  @override
  String toString() =>
      'AppUser(uid: $uid, email: $email, displayName: $displayName, '
      'isEmailVerified: $isEmailVerified, isAnonymous: $isAnonymous)';
}

/// Encapsulates the result of an authentication operation.
///
/// This replaces the old `AuthResult` that returned `models.User` directly.
/// Downstream code should switch to consuming [AppAuthResult] once the
/// adapters are wired (Phase 2).
class AppAuthResult {
  /// Whether the operation succeeded.
  final bool isSuccess;

  /// A user-facing error message when [isSuccess] is `false`.
  final String? error;

  /// The authenticated user, when [isSuccess] is `true`.
  final AppUser? user;

  const AppAuthResult._({
    required this.isSuccess,
    this.error,
    this.user,
  });

  /// Shorthand factory for a successful auth result.
  factory AppAuthResult.success(AppUser user) =>
      AppAuthResult._(isSuccess: true, user: user);

  /// Shorthand factory for a failed auth result.
  factory AppAuthResult.failure(String error) =>
      AppAuthResult._(isSuccess: false, error: error);
}
