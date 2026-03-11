import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/app_models.dart';
import '../config/google_signin_config.dart';
import 'firebase_database_service.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';

/// Unified authentication service.
///
/// Supports email/password and Google Sign-In.  Profile creation and
/// retrieval is delegated to [FirebaseDatabaseService].
class AuthService {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();

  final FirebaseDatabaseService _firebaseService;
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  static final Logger _logger = Logger('AuthService');

  static const String _googleSignInCancelled = 'GOOGLE_SIGNIN_CANCELLED';
  static const String _googleSignInRedirecting = 'GOOGLE_SIGNIN_REDIRECTING';

  AuthService._({
    FirebaseDatabaseService? firebaseService,
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseService = firebaseService ?? FirebaseDatabaseService.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignInConfig.instance;

  @visibleForTesting
  factory AuthService.test({
    required FirebaseDatabaseService firebaseService,
    required FirebaseAuth auth,
    GoogleSignIn? googleSignIn,
  }) {
    return AuthService._(
      firebaseService: firebaseService,
      auth: auth,
      googleSignIn: googleSignIn,
    );
  }

  // ── Getters ──────────────────────────────────────────────────────────────

  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => _auth.currentUser != null;
  bool get isEmailVerified => currentUser?.emailVerified ?? false;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Email / Password ─────────────────────────────────────────────────────

  Future<AuthResult> signInWithEmailAndPassword(
      String email, String password) async {
    return signInWithEmail(email, password);
  }

  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        UserProfile? userProfile =
            await _firebaseService.getUserProfile(credential.user!.uid);

        if (userProfile == null) {
          userProfile = UserProfile(
            id: credential.user!.uid,
            email: credential.user!.email!,
            fullName: credential.user!.displayName ?? '',
            photoUrl: credential.user!.photoURL,
            isEmailVerified: credential.user!.emailVerified,
            createdAt: credential.user!.metadata.creationTime ?? DateTime.now(),
            updatedAt: DateTime.now(),
          );
          userProfile = await _firebaseService.createUserProfile(userProfile);
        }

        return AuthResult.success(credential.user!, userProfile);
      } else {
        return AuthResult.error('Sign in failed');
      }
    } on FirebaseAuthException catch (e) {
      _logger.warning('Sign in failed (Firebase): ${e.message} ($e)');
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      _logger.error('Sign in failed (Unexpected)', e);
      return AuthResult.error('An unexpected error occurred: $e');
    }
  }

  Future<AuthResult> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? fullName,
  }) async {
    return signUpWithEmail(email: email, password: password, fullName: fullName);
  }

  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        if (fullName != null && fullName.isNotEmpty) {
          await credential.user!.updateDisplayName(fullName);
        }

        // Send email verification
        await credential.user!.sendEmailVerification();

        final userProfile = UserProfile(
          id: credential.user!.uid,
          email: email,
          fullName: fullName ?? '',
          isEmailVerified: false,
          isApproved: false,
          approvalStatus: 'pending',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final createdProfile =
            await _firebaseService.createUserProfile(userProfile);

        return AuthResult.success(credential.user!, createdProfile);
      } else {
        return AuthResult.error('Sign up failed');
      }
    } on FirebaseAuthException catch (e) {
      _logger.warning('Sign up failed (Firebase): ${e.message} ($e)');
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      _logger.error('Sign up failed (Unexpected)', e);
      return AuthResult.error('An unexpected error occurred: $e');
    }
  }

  // ── Google Sign-In ───────────────────────────────────────────────────────

  Future<AuthResult> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');

        UserCredential credential;
        try {
          credential = await _auth.signInWithPopup(googleProvider);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'popup-blocked' ||
              e.code == 'popup-closed-by-user' ||
              e.code == 'cancelled-popup-request' ||
              e.code == 'web-context-cancelled') {
            await _auth.signInWithRedirect(googleProvider);
            return AuthResult.error(_googleSignInRedirecting);
          }
          rethrow;
        }

        if (credential.user != null) {
          final userProfile = await _getOrCreateGoogleProfile(credential.user!);
          return AuthResult.success(credential.user!, userProfile);
        }
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          return AuthResult.error(_googleSignInCancelled);
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final oauthCredential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final userCredential =
            await _auth.signInWithCredential(oauthCredential);

        if (userCredential.user != null) {
          final userProfile =
              await _getOrCreateGoogleProfile(userCredential.user!);
          return AuthResult.success(userCredential.user!, userProfile);
        }
      }

      return AuthResult.error('Google sign in failed');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return AuthResult.error(_googleSignInCancelled);
      }
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.error('Google sign in failed: $e');
    }
  }

  Future<UserProfile> _getOrCreateGoogleProfile(User user) async {
    UserProfile? existing = await _firebaseService.getUserProfile(user.uid);
    if (existing != null) return existing;

    final profile = UserProfile(
      id: user.uid,
      email: user.email!,
      fullName: user.displayName ?? '',
      photoUrl: user.photoURL,
      isEmailVerified: user.emailVerified,
      provider: 'google',
      createdAt: user.metadata.creationTime ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return await _firebaseService.createUserProfile(profile);
  }

  // ── Account Management ───────────────────────────────────────────────────

  Future<void> signOut() async {
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      await _auth.signOut();
    } catch (e) {
      throw AuthException('Sign out failed', originalError: e);
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_getErrorMessage(e), originalError: e);
    } catch (e) {
      throw AuthException('Password reset failed', originalError: e);
    }
  }

  Future<bool> updatePassword(String newPassword) async {
    try {
      await _auth.currentUser?.updatePassword(newPassword);
      return true;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_getErrorMessage(e), originalError: e);
    } catch (e) {
      throw AuthException('Password update failed', originalError: e);
    }
  }

  Future<bool> updateEmail(String newEmail) async {
    try {
      await _auth.currentUser?.verifyBeforeUpdateEmail(newEmail);
      return true;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_getErrorMessage(e), originalError: e);
    } catch (e) {
      throw AuthException('Email update failed', originalError: e);
    }
  }

  Future<void> resendEmailVerification() async {
    if (!isAuthenticated) return;
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_getErrorMessage(e), originalError: e);
    } catch (e) {
      throw AuthException('Failed to resend verification email',
          originalError: e);
    }
  }

  Future<void> deleteAccount() async {
    if (!isAuthenticated) return;
    try {
      await _auth.currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_getErrorMessage(e), originalError: e);
    } catch (e) {
      throw AuthException('Account deletion failed', originalError: e);
    }
  }

  // ── Profile Methods ──────────────────────────────────────────────────────

  Future<UserProfile?> getCurrentUserProfile() async {
    if (!isAuthenticated) throw AuthException('User not authenticated');
    try {
      return await _firebaseService.getUserProfile(currentUser!.uid);
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error getting user profile', e);
      throw DatabaseException('Failed to get user profile', originalError: e);
    }
  }

  Future<UserProfile?> updateUserProfile(UserProfile userProfile) async {
    if (!isAuthenticated) throw AuthException('User not authenticated');
    try {
      return await _firebaseService.updateUserProfile(userProfile);
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('Profile update failed', originalError: e);
    }
  }

  // ── Error Messages ───────────────────────────────────────────────────────

  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Please contact support.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email but different sign-in credentials.';
      case 'invalid-credential':
        return 'The provided credentials are invalid or expired.';
      case 'credential-already-in-use':
        return 'This credential is already associated with a different user account.';
      case 'requires-recent-login':
        return 'This operation requires recent authentication. Please sign in again.';
      default:
        return e.message ?? 'An error occurred during authentication.';
    }
  }
}

/// Result of an authentication operation.
class AuthResult {
  final bool isSuccess;
  final String? error;
  final User? user;
  final UserProfile? userProfile;

  AuthResult._(
      {required this.isSuccess, this.error, this.user, this.userProfile});

  factory AuthResult.success(User user, UserProfile userProfile) {
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
