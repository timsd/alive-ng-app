/// Appwrite-specific implementation of [AuthGateway].
///
/// This is the ONLY file that may import `package:appwrite/models.dart` for
/// auth user types. It translates between the Appwrite SDK's `models.User`
/// and our domain-owned [AppUser].
///
/// ```text
///   UI / Providers  ──▶  AuthGateway (port)  ◀──  AppwriteAuthGateway (this)
/// ```
library;

import 'dart:async';

import 'package:appwrite/models.dart' as sdk;
import 'package:flutter/foundation.dart';

import '../../models/auth_models.dart';
import '../appwrite_auth_service.dart';
import '../ports/auth_gateway.dart';

/// Concrete [AuthGateway] backed by Appwrite.
///
/// Delegates the heavy lifting to [AppwriteAuthService] (the existing
/// low-level wrapper around `package:appwrite`) and maps every SDK type to
/// our owned domain models before returning.
class AppwriteAuthGateway implements AuthGateway {
  final AppwriteAuthService _service;

  /// Internal cache of the last-known domain user.
  AppUser? _cachedUser;

  /// Broadcast controller for [authStateChanges].
  final StreamController<AppUser?> _authStateController =
      StreamController<AppUser?>.broadcast();

  AppwriteAuthGateway(this._service) {
    // Seed the cached user on construction.
    _refreshCachedUser();
  }

  // ──────────────────────────────────────────────────────────
  //  Internal helpers
  // ──────────────────────────────────────────────────────────

  /// Maps an Appwrite SDK [sdk.User] into our owned [AppUser].
  AppUser _mapSdkUserToAppUser(sdk.User user) {
    return AppUser(
      uid: user.$id,
      email: user.email,
      displayName: user.name.isEmpty ? null : user.name,
      photoUrl: null, // Appwrite doesn't expose a photo URL on the User model
      isEmailVerified: user.emailVerification,
      isAnonymous: false, // Appwrite has no anonymous session on User model
    );
  }

  /// Refreshes [_cachedUser] from the service and emits on the stream.
  Future<void> _refreshCachedUser() async {
    try {
      final sdkUser = await _service.getCurrentUser();
      _cachedUser = sdkUser != null ? _mapSdkUserToAppUser(sdkUser) : null;
    } catch (e) {
      debugPrint('AppwriteAuthGateway: failed to refresh cached user: $e');
      _cachedUser = null;
    }
    _authStateController.add(_cachedUser);
  }

  // ──────────────────────────────────────────────────────────
  //  AuthGateway — Session / current user
  // ──────────────────────────────────────────────────────────

  @override
  Future<AppUser?> getCurrentUser() async {
    final sdkUser = await _service.getCurrentUser();
    _cachedUser = sdkUser != null ? _mapSdkUserToAppUser(sdkUser) : null;
    return _cachedUser;
  }

  @override
  AppUser? get currentUser => _cachedUser;

  @override
  bool get isAuthenticated => _cachedUser != null;

  @override
  Stream<AppUser?> get authStateChanges => _authStateController.stream;

  // ──────────────────────────────────────────────────────────
  //  AuthGateway — Email / password
  // ──────────────────────────────────────────────────────────

  @override
  Future<AppAuthResult> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
    Map<String, dynamic>? profileData,
  }) async {
    try {
      final sdkUser = await _service.signUpWithEmail(
        email: email,
        password: password,
        name: displayName ?? email.split('@').first,
        profileData: profileData,
      );
      _cachedUser = _mapSdkUserToAppUser(sdkUser);
      _authStateController.add(_cachedUser);
      return AppAuthResult.success(_cachedUser!);
    } catch (e) {
      debugPrint('AppwriteAuthGateway.signUpWithEmail error: $e');
      return AppAuthResult.failure('Sign up failed: $e');
    }
  }

  @override
  Future<AppAuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _service.loginWithEmail(email: email, password: password);
      final sdkUser = await _service.getCurrentUser();
      if (sdkUser == null) {
        return AppAuthResult.failure('Sign in succeeded but user was null.');
      }
      _cachedUser = _mapSdkUserToAppUser(sdkUser);
      _authStateController.add(_cachedUser);
      return AppAuthResult.success(_cachedUser!);
    } catch (e) {
      debugPrint('AppwriteAuthGateway.signInWithEmail error: $e');
      return AppAuthResult.failure('Sign in failed: $e');
    }
  }

  // ──────────────────────────────────────────────────────────
  //  AuthGateway — OAuth / Social
  // ──────────────────────────────────────────────────────────

  @override
  Future<AppAuthResult> signInWithGoogle() async {
    try {
      await _service.signInWithGoogle();
      final sdkUser = await _service.getCurrentUser();
      if (sdkUser == null) {
        return AppAuthResult.failure(
            'Google sign-in succeeded but user was null.');
      }
      _cachedUser = _mapSdkUserToAppUser(sdkUser);
      _authStateController.add(_cachedUser);
      return AppAuthResult.success(_cachedUser!);
    } catch (e) {
      debugPrint('AppwriteAuthGateway.signInWithGoogle error: $e');
      return AppAuthResult.failure('Google sign-in failed: $e');
    }
  }

  // ──────────────────────────────────────────────────────────
  //  AuthGateway — Password recovery
  // ──────────────────────────────────────────────────────────

  @override
  Future<bool> sendPasswordRecovery(String email) async {
    try {
      await _service.sendPasswordRecovery(email);
      return true;
    } catch (e) {
      debugPrint('AppwriteAuthGateway.sendPasswordRecovery error: $e');
      return false;
    }
  }

  @override
  Future<bool> completePasswordRecovery({
    required String userId,
    required String secret,
    required String newPassword,
  }) async {
    try {
      await _service.completePasswordRecovery(
        userId: userId,
        secret: secret,
        password: newPassword,
      );
      return true;
    } catch (e) {
      debugPrint('AppwriteAuthGateway.completePasswordRecovery error: $e');
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────
  //  AuthGateway — Session lifecycle
  // ──────────────────────────────────────────────────────────

  @override
  Future<void> signOut() async {
    await _service.logout();
    _cachedUser = null;
    _authStateController.add(null);
  }
}
