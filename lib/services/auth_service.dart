import 'dart:async';

import '../models/app_models.dart';
import '../models/auth_models.dart';
import '../utils/app_exception.dart';
import 'appwrite_auth_service.dart';
import 'appwrite_profile_service.dart';

export '../models/auth_models.dart' show AppUser;

/// Appwrite-backed authentication service.
///
/// App-level auth facade backed by Appwrite.
class AuthService {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();

  final AppwriteAuthService _appwriteAuth;
  final AppwriteProfileService _profileService;
  final StreamController<AppUser?> _authStateController =
      StreamController<AppUser?>.broadcast();

  AuthService._({
    AppwriteAuthService? appwriteAuth,
    AppwriteProfileService? profileService,
  })  : _appwriteAuth = appwriteAuth ?? AppwriteAuthService(),
        _profileService = profileService ?? AppwriteProfileService();

  AppUser? _mapUser(dynamic user) {
    if (user == null) return null;
    return AppUser(
      uid: user.$id as String,
      email: user.email as String,
      displayName: (user.name as String).isEmpty ? null : user.name as String,
      isEmailVerified: user.emailVerification as bool,
      isAnonymous: false,
    );
  }

  AppUser? get currentUser => _mapUser(_appwriteAuth.currentUser);
  bool get isAuthenticated => currentUser != null;
  bool get isEmailVerified => currentUser?.isEmailVerified ?? false;
  Stream<AppUser?> get authStateChanges => _authStateController.stream;

  Future<AuthResult> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return signInWithEmail(email, password);
  }

  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      await _appwriteAuth.loginWithEmail(email: email, password: password);
      final sdkUser = await _appwriteAuth.getCurrentUser();
      final user = _mapUser(sdkUser);
      _authStateController.add(user);

      if (user == null) {
        return AuthResult.error('Unable to sign in. Please try again.');
      }

      return AuthResult.success(user, await _profileForUser(user));
    } catch (e) {
      final errorMsg = _getFriendlyErrorMessage(e);
      return AuthResult.error(errorMsg);
    }
  }

  /// Converts technical error messages into user-friendly messages
  String _getFriendlyErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    // Invalid credentials
    if (errorStr.contains('invalid credentials') ||
        errorStr.contains('invalid email or password') ||
        errorStr.contains('user_unauthorized')) {
      return 'Incorrect email or password. Please check and try again.';
    }

    // User not found
    if (errorStr.contains('user not found') ||
        errorStr.contains('user_not_found')) {
      return 'No account found with this email. Please sign up first.';
    }

    // Email already exists
    if (errorStr.contains('already exists') ||
        errorStr.contains('duplicate') ||
        errorStr.contains('user_already_exists')) {
      return 'An account with this email already exists. Please sign in instead.';
    }

    // Password too weak
    if (errorStr.contains('password') &&
        (errorStr.contains('weak') || errorStr.contains('short') || errorStr.contains('minimum'))) {
      return 'Your password is too weak. Please use at least 8 characters with letters and numbers.';
    }

    // Invalid email format
    if (errorStr.contains('invalid email') || errorStr.contains('email format')) {
      return 'Please enter a valid email address.';
    }

    // Network/connection issues
    if (errorStr.contains('network') ||
        errorStr.contains('connection') ||
        errorStr.contains('timeout') ||
        errorStr.contains('unreachable')) {
      return 'Unable to connect. Please check your internet connection and try again.';
    }

    // Too many requests
    if (errorStr.contains('too many requests') ||
        errorStr.contains('rate limit') ||
        errorStr.contains('429')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }

    // Session already exists
    if (errorStr.contains('session') && errorStr.contains('already')) {
      return 'You are already signed in on another device. Please try again.';
    }

    // Generic fallback
    return 'Something went wrong. Please try again.';
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
      final sdkUser = await _appwriteAuth.signUpWithEmail(
        email: email,
        password: password,
        name: fullName ?? email.split('@').first,
        profileData: profileData,
      );
      final user = _mapUser(sdkUser);
      _authStateController.add(user);

      if (user == null) {
        return AuthResult.error('Unable to create your account. Please try again.');
      }

      return AuthResult.success(user, await _profileForUser(user));
    } catch (e) {
      final errorMsg = _getFriendlyErrorMessage(e);
      return AuthResult.error(errorMsg);
    }
  }

  Future<AuthResult> signInWithGoogle() async {
    try {
      await _appwriteAuth.signInWithGoogle();
      final sdkUser = await _appwriteAuth.getCurrentUser();
      final user = _mapUser(sdkUser);
      _authStateController.add(user);

      if (user == null) {
        return AuthResult.error('Google sign-in was unsuccessful. Please try again.');
      }

      return AuthResult.success(user, await _profileForUser(user));
    } catch (e) {
      final errorMsg = _getFriendlyErrorMessage(e);
      return AuthResult.error(errorMsg);
    }
  }

  Future<void> signOut() async {
    try {
      await _appwriteAuth.logout();
      _authStateController.add(null);
    } catch (e) {
      throw AuthException('Unable to sign out. Please try again.', originalError: e);
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      await _appwriteAuth.sendPasswordRecovery(email);
      return true;
    } catch (e) {
      throw AuthException('Unable to send password reset. Please check your email and try again.', originalError: e);
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
      throw AuthException('Unable to reset password. The link may have expired. Please try again.', originalError: e);
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
    final user = currentUser;
    if (user == null) return null;
    return _profileForUser(user);
  }

  Future<UserProfile> _profileForUser(AppUser user) async {
    final document = await _profileService.ensureUserProfile(
      userId: user.uid,
      email: user.email,
      fullName: user.displayName ?? user.email.split('@').first,
    );
    return _profileService.userProfileFromDocument(
      document,
      fallbackEmail: user.email,
      fallbackFullName: user.displayName,
      isEmailVerified: user.isEmailVerified,
      isAnonymous: user.isAnonymous,
      photoUrl: user.photoUrl,
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
  final AppUser? user;
  final UserProfile? userProfile;

  AuthResult._({
    required this.isSuccess,
    this.error,
    this.user,
    this.userProfile,
  });

  factory AuthResult.success(AppUser user, UserProfile userProfile) {
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
