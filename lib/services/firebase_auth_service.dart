import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
// Removed supabase_flutter import - using Firebase now

import '../models/app_models.dart';
import '../config/google_signin_config.dart';
import '../services/auth_service.dart';
import '../utils/app_exception.dart';

class FirebaseAuthService {
  static FirebaseAuthService? _instance;
  static FirebaseAuthService get instance =>
      _instance ??= FirebaseAuthService._();

  FirebaseAuthService._();

  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignInConfig.instance;

  // Get current user
  firebase_auth.User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => _auth.currentUser != null;

  // Authentication state stream
  Stream<firebase_auth.User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<AuthResult> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Create user profile from Firebase user
        final userProfile = UserProfile(
          id: credential.user!.uid,
          email: credential.user!.email!,
          fullName: credential.user!.displayName ?? '',
          photoUrl: credential.user!.photoURL,
          isEmailVerified: credential.user!.emailVerified,
          createdAt: credential.user!.metadata.creationTime ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );

        return AuthResult.success(credential.user!, userProfile);
      } else {
        return AuthResult.error('Sign in failed');
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.error('An unexpected error occurred: $e');
    }
  }

  // Sign up with email and password
  Future<AuthResult> signUpWithEmailAndPassword({
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
        // Update display name if provided
        if (fullName != null && fullName.isNotEmpty) {
          await credential.user!.updateDisplayName(fullName);
        }

        // Send email verification
        await credential.user!.sendEmailVerification();

        // Create user profile
        final userProfile = UserProfile(
          id: credential.user!.uid,
          email: email,
          fullName: fullName ?? '',
          isEmailVerified: false,
          isApproved: false, // New users require approval
          approvalStatus: 'pending',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        return AuthResult.success(credential.user!, userProfile);
      } else {
        return AuthResult.error('Sign up failed');
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.error('An unexpected error occurred: $e');
    }
  }

  // Sign in with Google
  Future<AuthResult> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web-specific Google Sign-In
        final firebase_auth.GoogleAuthProvider googleProvider =
            firebase_auth.GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');

        final credential = await _auth.signInWithPopup(googleProvider);

        if (credential.user != null) {
          final userProfile = UserProfile(
            id: credential.user!.uid,
            email: credential.user!.email!,
            fullName: credential.user!.displayName ?? '',
            photoUrl: credential.user!.photoURL,
            isEmailVerified: credential.user!.emailVerified,
            provider: 'google',
            createdAt: credential.user!.metadata.creationTime ?? DateTime.now(),
            updatedAt: DateTime.now(),
          );

          return AuthResult.success(credential.user!, userProfile);
        }
      } else {
        // Mobile Google Sign-In
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

        if (googleUser == null) {
          return AuthResult.error('Google sign in was cancelled');
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final credential = firebase_auth.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential = await _auth.signInWithCredential(credential);

        if (userCredential.user != null) {
          final userProfile = UserProfile(
            id: userCredential.user!.uid,
            email: userCredential.user!.email!,
            fullName: userCredential.user!.displayName ?? '',
            photoUrl: userCredential.user!.photoURL,
            isEmailVerified: userCredential.user!.emailVerified,
            provider: 'google',
            createdAt:
                userCredential.user!.metadata.creationTime ?? DateTime.now(),
            updatedAt: DateTime.now(),
          );

          return AuthResult.success(userCredential.user!, userProfile);
        }
      }

      return AuthResult.error('Google sign in failed');
    } on firebase_auth.FirebaseAuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.error('Google sign in failed: $e');
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw AuthException(_getErrorMessage(e), originalError: e);
    } catch (e) {
      throw AuthException('Password reset failed', originalError: e);
    }
  }

  // Update password
  Future<bool> updatePassword(String newPassword) async {
    try {
      await _auth.currentUser?.updatePassword(newPassword);
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw AuthException(_getErrorMessage(e), originalError: e);
    } catch (e) {
      throw AuthException('Password update failed', originalError: e);
    }
  }

  // Update email
  Future<bool> updateEmail(String newEmail) async {
    try {
      await _auth.currentUser?.verifyBeforeUpdateEmail(newEmail);
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw AuthException(_getErrorMessage(e), originalError: e);
    } catch (e) {
      throw AuthException('Email update failed', originalError: e);
    }
  }

  // Send email verification
  Future<void> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw AuthException(_getErrorMessage(e), originalError: e);
    } catch (e) {
      throw AuthException('Failed to send verification email',
          originalError: e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Sign out from Google if signed in with Google
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }

      await _auth.signOut();
    } catch (e) {
      throw AuthException('Sign out failed', originalError: e);
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      await _auth.currentUser?.delete();
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw AuthException(_getErrorMessage(e), originalError: e);
    } catch (e) {
      throw AuthException('Account deletion failed', originalError: e);
    }
  }

  // Get user-friendly error messages
  String _getErrorMessage(firebase_auth.FirebaseAuthException e) {
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
