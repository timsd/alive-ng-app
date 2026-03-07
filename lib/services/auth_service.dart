import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_models.dart';
import 'firebase_database_service.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';

class AuthService {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();

  final FirebaseDatabaseService _firebaseService;
  final FirebaseAuth _auth;
  static final Logger _logger = Logger('AuthService');

  AuthService._({
    FirebaseDatabaseService? firebaseService,
    FirebaseAuth? auth,
  })  : _firebaseService = firebaseService ?? FirebaseDatabaseService.instance,
        _auth = auth ?? FirebaseAuth.instance;

  @visibleForTesting
  factory AuthService.test({
    required FirebaseDatabaseService firebaseService,
    required FirebaseAuth auth,
  }) {
    return AuthService._(firebaseService: firebaseService, auth: auth);
  }

  // Get current user
  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => _auth.currentUser != null;

  // Authentication state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password (wrapper for compatibility)
  Future<AuthResult> signInWithEmailAndPassword(
      String email, String password) async {
    return signInWithEmail(email, password);
  }

  // Sign in with email and password
  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Get or create user profile
        UserProfile? userProfile =
            await _firebaseService.getUserProfile(credential.user!.uid);

        if (userProfile == null) {
          // Create profile if it doesn't exist
          userProfile = UserProfile(
            id: credential.user!.uid,
            email: credential.user!.email!,
            fullName: credential.user!.displayName ?? '',
            createdAt: DateTime.now(),
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
      return AuthResult.error(e.message ?? 'Authentication failed');
    } catch (e) {
      _logger.error('Sign in failed (Unexpected)', e);
      return AuthResult.error('An unexpected error occurred: $e');
    }
  }

  // Sign up with email and password (wrapper for compatibility)
  Future<AuthResult> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? fullName,
  }) async {
    return signUpWithEmail(
      email: email,
      password: password,
      fullName: fullName,
    );
  }

  // Sign up with email and password
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
        // Update display name if provided
        if (fullName != null && fullName.isNotEmpty) {
          await credential.user!.updateDisplayName(fullName);
        }

        // Create user profile with approval status set to pending
        final userProfile = UserProfile(
          id: credential.user!.uid,
          email: email,
          fullName: fullName ?? '',
          isApproved: false, // New users require approval
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
      return AuthResult.error(e.message ?? 'Registration failed');
    } catch (e) {
      _logger.error('Sign up failed (Unexpected)', e);
      return AuthResult.error('An unexpected error occurred: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw AuthException('Sign out failed', originalError: e);
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Password reset failed',
          originalError: e);
    } catch (e) {
      throw AuthException('Password reset failed', originalError: e);
    }
  }

  // Update password
  Future<bool> updatePassword(String newPassword) async {
    try {
      await _auth.currentUser?.updatePassword(newPassword);
      return true;
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Password update failed',
          originalError: e);
    } catch (e) {
      throw AuthException('Password update failed', originalError: e);
    }
  }

  // Update email
  Future<bool> updateEmail(String newEmail) async {
    try {
      await _auth.currentUser?.verifyBeforeUpdateEmail(newEmail);
      return true;
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Email update failed', originalError: e);
    } catch (e) {
      throw AuthException('Email update failed', originalError: e);
    }
  }

  // Get current user profile
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

  // Update user profile
  Future<UserProfile?> updateUserProfile(UserProfile userProfile) async {
    if (!isAuthenticated) throw AuthException('User not authenticated');

    try {
      return await _firebaseService.updateUserProfile(userProfile);
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('Profile update failed', originalError: e);
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    if (!isAuthenticated) return;

    try {
      await _auth.currentUser?.delete();
    } catch (e) {
      throw AuthException('Account deletion failed', originalError: e);
    }
  }

  // Check if email is verified
  bool get isEmailVerified => currentUser?.emailVerified ?? false;

  // Resend email verification
  Future<void> resendEmailVerification() async {
    if (!isAuthenticated) return;

    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Failed to send verification email',
          originalError: e);
    } catch (e) {
      throw AuthException('Failed to resend verification email',
          originalError: e);
    }
  }
}

// Auth result class
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
