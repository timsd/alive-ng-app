import 'dart:async';

import '../models/app_models.dart';
import '../models/auth_models.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';
import 'appwrite_auth_service.dart';
import 'appwrite_profile_service.dart';
import 'email_service.dart';

export '../models/auth_models.dart' show AppUser;

/// Appwrite-backed authentication service.
///
/// App-level auth facade backed by Appwrite.
class AuthService {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();

  final AppwriteAuthService _appwriteAuth;
  final AppwriteProfileService _profileService;
  final EmailService _emailService = EmailService.instance;
  static final Logger _logger = Logger('AuthService');
  final StreamController<AppUser?> _authStateController =
      StreamController<AppUser?>.broadcast();

  AuthService._({
    AppwriteAuthService? appwriteAuth,
    AppwriteProfileService? profileService,
  })  : _appwriteAuth = appwriteAuth ?? AppwriteAuthService(),
        _profileService = profileService ?? AppwriteProfileService();

  /// Expose the underlying AppwriteAuthService for admin operations
  AppwriteAuthService get appwriteAuth => _appwriteAuth;

  AppUser? _mapUser(dynamic user) {
    if (user == null) return null;
    String? prefPhoto;
    try {
      final prefsData = user.prefs?.data;
      if (prefsData is Map) {
        final raw = prefsData['avatar_url'] ??
            prefsData['photo_url'] ??
            prefsData['photoUrl'];
        if (raw is String && raw.trim().isNotEmpty) {
          prefPhoto = raw.trim();
        }
      }
    } catch (_) {}
    return AppUser(
      uid: user.$id as String,
      email: user.email as String,
      displayName: (user.name as String).isEmpty ? null : user.name as String,
      photoUrl: prefPhoto,
      isEmailVerified: user.emailVerification as bool,
      isAnonymous: false,
    );
  }

  AppUser? get currentUser => _mapUser(_appwriteAuth.currentUser);
  bool get isAuthenticated => currentUser != null;
  bool get isEmailVerified => currentUser?.isEmailVerified ?? false;
  Stream<AppUser?> get authStateChanges => _authStateController.stream;

  /// Asynchronously refresh and return the currently authenticated user.
  Future<AppUser?> getCurrentUser() async {
    try {
      final sdkUser = await _appwriteAuth.getCurrentUser();
      final user = _mapUser(sdkUser);
      if (user != null) {
        _authStateController.add(user);
      }
      return user;
    } catch (_) {
      return null;
    }
  }

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

  /// Sends a password-reset link to [email].
  ///
  /// Appwrite's `createRecovery` mints the recovery token and delivers it in
  /// Appwrite's own recovery email. The branded Resend message is only sent when
  /// the API actually hands back a usable secret, because a branded link built
  /// from an empty secret reaches the reset screen with nothing to submit and
  /// the member can never set a new password.
  ///
  /// On Appwrite 1.8.1 the secret always comes back empty, so in practice this
  /// relies entirely on Appwrite's own mail, and that mail is only delivered if
  /// SMTP is configured on the Appwrite project. With no SMTP, nothing is sent
  /// at all -- see scripts/check_appwrite_smtp.mjs.
  ///
  /// Exactly one email should go out. When both paths are live, two emails
  /// arrive, and the Appwrite one, with a different template, is the one members
  /// tend to click first.
  Future<bool> resetPassword(String email) async {
    final normalized = email.trim();
    if (normalized.isEmpty) {
      throw AuthException('Please enter your email address.');
    }

    final token = await _appwriteAuth.sendPasswordRecovery(normalized);

    // Appwrite 1.8.1 returns `secret: ""` from createRecovery -- the token is
    // only ever delivered by its own recovery mail, not in the API response.
    // The branded link below is therefore built from an empty secret, which
    // produced a link that reached the reset screen with nothing to submit and
    // the member could never set a new password.
    //
    // So do not send a broken link. Appwrite's own recovery mail is the only
    // one carrying a usable secret, and it is built from the `url` passed to
    // createRecovery above.
    final secret = token.secret.trim();
    if (secret.isEmpty) {
      _logger.warning(
        'createRecovery returned no secret for $normalized; relying on Appwrite\'s '
        'own recovery email rather than sending a branded link with an empty secret.',
      );
      return true;
    }

    final displayName =
        currentUser?.displayName ?? normalized.split('@').first;
    try {
      await _emailService.sendPasswordResetEmail(
        toEmail: normalized,
        toName: displayName,
        userId: token.userId,
        secret: secret,
      );
    } catch (e) {
      _logger.warning('Branded password-reset email failed for $normalized: $e');
    }

    return true;
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
    try {
      await _appwriteAuth.updatePassword(newPassword);
      return true;
    } catch (e) {
      throw AuthException(
        'Unable to update your password. Please sign in again and try.',
        originalError: e,
      );
    }
  }

  Future<bool> updateEmail(String newEmail, {String password = ''}) async {
    try {
      await _appwriteAuth.updateEmail(newEmail, password: password);
      return true;
    } catch (e) {
      throw AuthException(
        'Unable to update your email. Please verify your password and try again.',
        originalError: e,
      );
    }
  }

  Future<void> resendEmailVerification() async {
    try {
      await _appwriteAuth.sendEmailVerification();
    } catch (e) {
      throw AuthException(
        'Unable to send verification email. Please try again later.',
        originalError: e,
      );
    }
  }

  /// Permanently deletes the signed-in member's profile data.
  ///
  /// A confirmation email is dispatched to the member *before* the profile is
  /// removed (the address lives on the profile). Email delivery is best-effort:
  /// a mail failure must never block the deletion the user explicitly asked for.
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) return;

    UserProfile? profile;
    try {
      profile = await getCurrentUserProfile();
    } catch (e) {
      _logger.warning('Could not load profile before account deletion: $e');
    }

    final recipientEmail = profile?.email ?? user.email;
    final recipientName = profile?.fullName ?? user.displayName ?? '';

    if (recipientEmail.trim().isNotEmpty) {
      try {
        await _emailService.sendAccountDeletionEmail(
          toEmail: recipientEmail.trim(),
          toName: recipientName,
        );
        _logger.info('Account deletion email sent to $recipientEmail');
      } catch (e) {
        _logger.warning('Account deletion email failed for $recipientEmail: $e');
      }
    }

    await _profileService.deleteUserProfile(user.uid);

    // Remove the Appwrite auth account so a stale session / lingering user row
    // can never make the "deleted" account reappear.
    try {
      await _appwriteAuth.deleteAuthAccount();
      _logger.info('Auth account removed for ${user.uid}');
    } catch (e) {
      _logger.warning('Auth account removal skipped for ${user.uid}: $e');
    }

    await signOut();
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
