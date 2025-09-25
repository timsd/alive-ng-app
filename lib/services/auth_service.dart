import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_models.dart';
import 'supabase_service.dart';

class AuthService {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();

  AuthService._();

  final SupabaseService _supabaseService = SupabaseService.instance;

  // Get current user
  User? get currentUser => _supabaseService.currentUser;
  bool get isAuthenticated => _supabaseService.isAuthenticated;

  // Authentication state stream
  Stream<AuthState> get authStateChanges =>
      _supabaseService.client.auth.onAuthStateChange;

  // Sign in with email and password (wrapper for compatibility)
  Future<AuthResult> signInWithEmailAndPassword(
      String email, String password) async {
    return signInWithEmail(email, password);
  }

  // Sign in with email and password
  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      final response = await _supabaseService.signInWithEmail(email, password);

      if (response.user != null) {
        // Get or create user profile
        UserProfile? userProfile =
            await _supabaseService.getUserProfile(response.user!.id);

        if (userProfile == null) {
          // Create profile if it doesn't exist
          userProfile = UserProfile(
            id: response.user!.id,
            email: response.user!.email!,
            fullName: response.user!.userMetadata?['full_name'] ?? '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          userProfile = await _supabaseService.createUserProfile(userProfile);
        }

        return AuthResult.success(response.user!, userProfile);
      } else {
        return AuthResult.error('Sign in failed');
      }
    } on AuthException catch (e) {
      return AuthResult.error(e.message);
    } catch (e) {
      return AuthResult.error('An unexpected error occurred');
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
      final response = await _supabaseService.signUpWithEmail(
        email,
        password,
        fullName: fullName,
      );

      if (response.user != null) {
        // Create user profile with approval status set to pending
        final userProfile = UserProfile(
          id: response.user!.id,
          email: email,
          fullName: fullName ?? '',
          isApproved: false, // New users require approval
          approvalStatus: 'pending',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final createdProfile =
            await _supabaseService.createUserProfile(userProfile);

        return AuthResult.success(response.user!, createdProfile);
      } else {
        return AuthResult.error('Sign up failed');
      }
    } on AuthException catch (e) {
      return AuthResult.error(e.message);
    } catch (e) {
      return AuthResult.error('An unexpected error occurred');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _supabaseService.signOut();
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    try {
      await _supabaseService.resetPassword(email);
      return true;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Password reset failed');
    }
  }

  // Update password
  Future<bool> updatePassword(String newPassword) async {
    try {
      await _supabaseService.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return true;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Password update failed');
    }
  }

  // Update email
  Future<bool> updateEmail(String newEmail) async {
    try {
      await _supabaseService.client.auth.updateUser(
        UserAttributes(email: newEmail),
      );
      return true;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Email update failed');
    }
  }

  // Get current user profile
  Future<UserProfile?> getCurrentUserProfile() async {
    if (!isAuthenticated) return null;

    try {
      return await _supabaseService.getUserProfile(currentUser!.id);
    } catch (e) {
      return null;
    }
  }

  // Update user profile
  Future<UserProfile?> updateUserProfile(UserProfile userProfile) async {
    if (!isAuthenticated) return null;

    try {
      return await _supabaseService.updateUserProfile(userProfile);
    } catch (e) {
      throw Exception('Profile update failed: $e');
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    if (!isAuthenticated) return;

    try {
      // Note: Supabase doesn't have a direct delete user method
      // This would typically be handled by a server-side function
      // For now, we'll just sign out
      await signOut();
    } catch (e) {
      throw Exception('Account deletion failed: $e');
    }
  }

  // Check if email is verified
  bool get isEmailVerified => currentUser?.emailConfirmedAt != null;

  // Resend email verification
  Future<void> resendEmailVerification() async {
    if (!isAuthenticated) return;

    try {
      await _supabaseService.client.auth.resend(
        type: OtpType.signup,
        email: currentUser!.email!,
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to resend verification email');
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
