import 'dart:async';

import 'package:appwrite/models.dart' as models;

import '../models/app_models.dart';
import '../utils/app_exception.dart';
import '../utils/appwrite_user_extensions.dart';
import 'appwrite_auth_service.dart';
import 'appwrite_profile_service.dart';

export '../utils/appwrite_user_extensions.dart';

/// Appwrite-backed authentication service.
///
/// App-level auth facade backed by Appwrite.
class AuthService {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();

  final AppwriteAuthService _appwriteAuth;
  final AppwriteProfileService _profileService;
  final StreamController<models.User?> _authStateController =
      StreamController<models.User?>.broadcast();

  AuthService._({
    AppwriteAuthService? appwriteAuth,
    AppwriteProfileService? profileService,
  })  : _appwriteAuth = appwriteAuth ?? AppwriteAuthService(),
        _profileService = profileService ?? AppwriteProfileService();

  models.User? get currentUser => _appwriteAuth.currentUser;
  bool get isAuthenticated => currentUser != null;
  bool get isEmailVerified => currentUser?.emailVerified ?? false;
  Stream<models.User?> get authStateChanges => _authStateController.stream;

  Future<AuthResult> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return signInWithEmail(email, password);
  }

  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      await _appwriteAuth.loginWithEmail(email: email, password: password);
      final user = await _appwriteAuth.getCurrentUser();
      _authStateController.add(user);

      if (user == null) {
        return AuthResult.error('Sign in failed');
      }

      return AuthResult.success(user, await _profileForUser(user));
    } catch (e) {
      return AuthResult.error('Sign in failed: $e');
    }
  }

  Future<AuthResult> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? fullName,
    Map<String, dynamic>? profileData,
  }) async {
    return signUpWithEmail(
      email: email,
      password: password,
      fullName: fullName,
      profileData: profileData,
    );
  }

  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
    Map<String, dynamic>? profileData,
  }) async {
    try {
      final user = await _appwriteAuth.signUpWithEmail(
        email: email,
        password: password,
        name: fullName ?? email.split('@').first,
        profileData: profileData,
      );
      await _appwriteAuth.getCurrentUser();
      _authStateController.add(user);

      return AuthResult.success(user, await _profileForUser(user));
    } catch (e) {
      return AuthResult.error('Sign up failed: $e');
    }
  }

  Future<AuthResult> signInWithGoogle() async {
    try {
      await _appwriteAuth.signInWithGoogle();
      final user = await _appwriteAuth.getCurrentUser();
      _authStateController.add(user);

      if (user == null) {
        return AuthResult.error('Google sign-in did not return a user.');
      }

      return AuthResult.success(user, await _profileForUser(user));
    } catch (e) {
      return AuthResult.error('Google sign-in failed: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _appwriteAuth.logout();
      _authStateController.add(null);
    } catch (e) {
      throw AuthException('Sign out failed', originalError: e);
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      await _appwriteAuth.sendPasswordRecovery(email);
      return true;
    } catch (e) {
      throw AuthException('Password reset failed', originalError: e);
    }
  }

  Future<bool> completePasswordRecovery({
    required String userId,
    required String secret,
    required String password,
  }) async {
    try {
      await _appwriteAuth.completePasswordRecovery(
        userId: userId,
        secret: secret,
        password: password,
      );
      return true;
    } catch (e) {
      throw AuthException('Password recovery failed', originalError: e);
    }
  }

  Future<bool> updatePassword(String newPassword) async {
    throw AuthException('Password update is pending Appwrite wiring.');
  }

  Future<bool> updateEmail(String newEmail) async {
    throw AuthException('Email update is pending Appwrite wiring.');
  }

  Future<void> resendEmailVerification() async {
    throw AuthException('Email verification is pending Appwrite wiring.');
  }

  Future<void> deleteAccount() async {
    throw AuthException('Account deletion is pending Appwrite wiring.');
  }

  Future<UserProfile?> getCurrentUserProfile() async {
    final user = currentUser ?? await _appwriteAuth.getCurrentUser();
    if (user == null) return null;
    return _profileForUser(user);
  }

  Future<UserProfile> _profileForUser(models.User user) async {
    final document = await _profileService.ensureUserProfile(
      userId: user.uid,
      email: user.email,
      fullName: user.displayName ?? user.email.split('@').first,
    );
    return _profileService.userProfileFromDocument(
      document,
      fallbackEmail: user.email,
      fallbackFullName: user.displayName,
      isEmailVerified: user.emailVerified,
      isAnonymous: user.isAnonymous,
      photoUrl: user.photoURL,
    );
  }

  Future<UserProfile?> updateUserProfile(UserProfile userProfile) async {
    await _profileService.updateUserProfile(
      userId: userProfile.id,
      profileData: _profileService.userProfileToAppwriteData(userProfile),
    );
    return userProfile;
  }
}

class AuthResult {
  final bool isSuccess;
  final String? error;
  final models.User? user;
  final UserProfile? userProfile;

  AuthResult._({
    required this.isSuccess,
    this.error,
    this.user,
    this.userProfile,
  });

  factory AuthResult.success(models.User user, UserProfile userProfile) {
    return AuthResult._(
      isSuccess: true,
      user: user,
      userProfile: userProfile,
    );
  }

  factory AuthResult.error(String error) {
    return AuthResult._(
      isSuccess: false,
      error: error,
    );
  }
}
