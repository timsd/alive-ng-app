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
import 'dart:convert';

import 'package:appwrite/models.dart' as sdk;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/auth_models.dart';
import '../appwrite_auth_service.dart';
import '../notification_service.dart';
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
    String? prefPhoto;
    try {
      final raw = user.prefs.data['avatar_url'] ??
          user.prefs.data['photo_url'] ??
          user.prefs.data['photoUrl'];
      if (raw is String && raw.trim().isNotEmpty) {
        prefPhoto = raw.trim();
      }
    } catch (_) {}

    return AppUser(
      uid: user.$id,
      email: user.email,
      displayName: user.name.isEmpty ? null : user.name,
      photoUrl: prefPhoto,
      isEmailVerified: user.emailVerification,
      isAnonymous: false, // Appwrite has no anonymous session on User model
    );
  }

  static const String _offlineUserKey = 'appwrite_auth_offline_user';

  Future<void> _persistOfflineUser(AppUser user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_offlineUserKey, jsonEncode(user.toJson()));
    } catch (_) {}
  }

  Future<AppUser?> _loadPersistedOfflineUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_offlineUserKey);
      if (raw != null && raw.isNotEmpty) {
        return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _clearPersistedOfflineUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_offlineUserKey);
    } catch (_) {}
  }

  /// Emits [user] to listeners and triggers mobile push registration sync so
  /// newly signed-up or signed-in users immediately link their device token.
  void _emitAuthState(AppUser? user) {
    _authStateController.add(user);
    if (!kIsWeb) {
      unawaited(NotificationService.instance.onAuthUserChanged(user));
    }
  }

  /// Refreshes [_cachedUser] from the service and emits on the stream.
  Future<void> _refreshCachedUser() async {
    try {
      final sdkUser = await _service.getCurrentUser();
      if (sdkUser != null) {
        _cachedUser = _mapSdkUserToAppUser(sdkUser);
        unawaited(_persistOfflineUser(_cachedUser!));
      } else {
        _cachedUser = null;
      }
    } catch (e) {
      debugPrint('AppwriteAuthGateway: failed to refresh cached user: $e');
      // If network failed, fall back to persisted offline user
      _cachedUser ??= await _loadPersistedOfflineUser();
    }
    _emitAuthState(_cachedUser);
  }

  // ──────────────────────────────────────────────────────────
  //  AuthGateway — Session / current user
  // ──────────────────────────────────────────────────────────

  @override
  Future<AppUser?> getCurrentUser() async {
    try {
      final sdkUser = await _service.getCurrentUser();
      if (sdkUser != null) {
        _cachedUser = _mapSdkUserToAppUser(sdkUser);
        unawaited(_persistOfflineUser(_cachedUser!));
      } else {
        _cachedUser = null;
      }
    } catch (_) {
      // Offline fallback
      _cachedUser ??= await _loadPersistedOfflineUser();
    }
    return _cachedUser;
  }

  @override
  AppUser? get currentUser => _cachedUser;

  @override
  bool get isAuthenticated => _cachedUser != null;

  @override
  Stream<AppUser?> get authStateChanges => _authStateController.stream;

  @override
  Future<AppAuthResult> signInOffline(AppUser user) async {
    _cachedUser = user;
    await _persistOfflineUser(user);
    _emitAuthState(_cachedUser);
    return AppAuthResult.success(user);
  }

  // ──────────────────────────────────────────────────────────
  //  AuthGateway — Email / password
  // ──────────────────────────────────────────────────────────

  @override
  Future<AppAuthResult> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
    SignupProfile? profile,
  }) async {
    try {
      final sdkUser = await _service.signUpWithEmail(
        email: email,
        password: password,
        name: displayName ?? email.split('@').first,
        profileData: profile?.toMap(),
      );
      _cachedUser = _mapSdkUserToAppUser(sdkUser);
      unawaited(_persistOfflineUser(_cachedUser!));
      _emitAuthState(_cachedUser);
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
      unawaited(_persistOfflineUser(_cachedUser!));
      _emitAuthState(_cachedUser);
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
      if (kIsWeb) {
        // On web, launchUrl in _self navigates the current tab directly to Google OAuth.
        return AppAuthResult.success(const AppUser(
          uid: 'pending_web_oauth',
          email: '',
          displayName: 'Redirecting...',
        ));
      }
      final sdkUser = await _service.getCurrentUser();
      if (sdkUser == null) {
        return AppAuthResult.failure(
            'Google sign-in succeeded but user was null.');
      }
      _cachedUser = _mapSdkUserToAppUser(sdkUser);
      unawaited(_persistOfflineUser(_cachedUser!));
      _emitAuthState(_cachedUser);
      return AppAuthResult.success(_cachedUser!);
    } catch (e) {
      debugPrint('AppwriteAuthGateway.signInWithGoogle error: $e');
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('canceled') ||
          errorStr.contains('cancelled') ||
          errorStr.contains('user_canceled')) {
        return AppAuthResult.failure('canceled');
      }
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
    try {
      await _service.logout();
    } catch (_) {}
    _cachedUser = null;
    await _clearPersistedOfflineUser();
    _emitAuthState(null);
  }
}
