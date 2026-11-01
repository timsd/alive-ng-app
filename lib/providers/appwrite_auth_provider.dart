import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/appwrite_backend_config.dart';
import '../models/app_models.dart';
import '../models/auth_models.dart';
import '../services/appwrite_profile_service.dart';
import '../services/ports/auth_gateway.dart';
import 'auth_provider.dart';

/// Alias kept for backward-compat; consumers should migrate to
/// [authGatewayProvider] from `auth_provider.dart`.
final appwriteAuthControllerProvider = Provider<AuthGateway>((ref) {
  return ref.watch(authGatewayProvider);
});

final appwriteUserStreamProvider = authStateProvider;

/// In-memory bytes for newly picked/uploaded avatar to render instantly (0ms)
/// across all screens (GreetingHeader, ProfileScreen, EditProfileScreen)
/// before and during network upload, ensuring immediate updates even on repeated changes.
final pendingAvatarBytesProvider = StateProvider<Uint8List?>((ref) => null);

/// Reactive in-memory override for the user's most recently uploaded avatar URL.
/// Ensures all screens (Home GreetingHeader, ProfileScreen, EditProfileScreen)
/// switch from the initial representative avatar to the uploaded photo
/// immediately upon upload without waiting for a database round-trip.
/// - `null`: no override in this session yet (use database profile URL)
/// - `''`: avatar was explicitly removed in this session
/// - non-empty string: newly uploaded avatar URL
final uploadedAvatarUrlProvider = StateProvider<String?>((ref) {
  // Reset automatically whenever the authenticated user changes.
  ref.watch(appwriteUserStreamProvider);
  return null;
});

/// The SINGLE CENTER OF TRUTH for current user's profile image / avatar URL across the entire app.
/// Feeds GreetingHeader, CustomAppBar, ProfileScreen, EditProfileScreen, Chat, and ALIVE Meet.
/// Priority:
/// 1. Newly uploaded avatar override in this session (instant feedback)
/// 2. User profile `avatarUrl` from database / persistent cache
/// 3. User profile `photoUrl`
/// 4. Google account image (from OAuth login / user session)
final currentUserAvatarUrlProvider = Provider<String?>((ref) {
  final override = ref.watch(uploadedAvatarUrlProvider);
  if (override != null) {
    return override.trim().isEmpty ? null : override.trim();
  }
  final profile = ref.watch(currentUserProfileProvider).value;
  if (profile?.avatarUrl != null && profile!.avatarUrl!.trim().isNotEmpty) {
    return profile.avatarUrl!.trim();
  }
  if (profile?.photoUrl != null && profile!.photoUrl!.trim().isNotEmpty) {
    return profile.photoUrl!.trim();
  }
  final authUser = ref.watch(currentUserProvider);
  if (authUser?.photoUrl != null && authUser!.photoUrl!.trim().isNotEmpty) {
    return authUser.photoUrl!.trim();
  }
  return null;
});

// Current User Profile Provider
final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(appwriteUserStreamProvider).value;

  if (user == null) return null;

  final avatarOverride = ref.watch(uploadedAvatarUrlProvider);

  try {
    final profileService = ref.watch(appwriteProfileServiceProvider);
    final document = await profileService.ensureUserProfile(
      userId: user.uid,
      email: user.email,
      fullName: user.displayName ?? user.email.split('@').first,
    );
    UserProfile profile = profileService.userProfileFromDocument(
      document,
      fallbackEmail: user.email,
      fallbackFullName: user.displayName,
      isEmailVerified: user.isEmailVerified,
      isAnonymous: user.isAnonymous,
      photoUrl: user.photoUrl,
    );

    // If Google account has a photoUrl and the profile has none, adopt Google photoUrl automatically!
    if ((profile.avatarUrl == null || profile.avatarUrl!.isEmpty) &&
        (user.photoUrl != null && user.photoUrl!.isNotEmpty)) {
      profile = profile.copyWith(avatarUrl: user.photoUrl, photoUrl: user.photoUrl);
      // Persist Google account avatar in the background so it's durable in Appwrite
      profileService.updateUserProfile(
        userId: user.uid,
        profileData: {'avatar_url': user.photoUrl, 'photo_url': user.photoUrl},
      ).catchError((_) => document);
    }

    // Fall back to locally cached avatar if remote document field is empty
    if (profile.avatarUrl == null || profile.avatarUrl!.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('cached_avatar_url_${user.uid}');
        if (cached != null && cached.isNotEmpty) {
          profile = profile.copyWith(avatarUrl: cached, photoUrl: cached);
        }
      } catch (_) {}
    }

    if (avatarOverride != null) {
      return profile.copyWith(
        avatarUrl: avatarOverride,
        photoUrl: avatarOverride,
      );
    }
    return profile;
  } catch (_) {
    final resolvedPhoto = avatarOverride != null
        ? (avatarOverride.isEmpty ? null : avatarOverride)
        : user.photoUrl;
    return UserProfile(
      id: user.uid,
      email: user.email,
      fullName: user.displayName ?? user.email.split('@').first,
      avatarUrl: resolvedPhoto,
      photoUrl: resolvedPhoto,
      isEmailVerified: user.isEmailVerified,
      isAnonymous: user.isAnonymous,
      role: AppwriteBackendConfig.isSuperAdminEmail(user.email)
          ? 'admin'
          : 'member',
      approvalStatus: AppwriteBackendConfig.isSuperAdminEmail(user.email)
          ? 'approved'
          : 'pending',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
});

// Authentication State Provider
final appwriteAuthStateProvider = StateProvider<AuthState>((ref) {
  final userAsync = ref.watch(appwriteUserStreamProvider);

  return userAsync.when(
    data: (user) => user != null
        ? AuthState.authenticated(user)
        : AuthState.unauthenticated(),
    loading: () => AuthState.loading(),
    error: (error, stack) => AuthState.error(error.toString()),
  );
});

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;
  final AppUser? user;

  const AuthState._({
    required this.isAuthenticated,
    required this.isLoading,
    this.error,
    this.user,
  });

  factory AuthState.authenticated(AppUser user) {
    return AuthState._(
      isAuthenticated: true,
      isLoading: false,
      user: user,
    );
  }

  factory AuthState.unauthenticated() {
    return const AuthState._(
      isAuthenticated: false,
      isLoading: false,
    );
  }

  factory AuthState.loading() {
    return const AuthState._(
      isAuthenticated: false,
      isLoading: true,
    );
  }

  factory AuthState.error(String error) {
    return AuthState._(
      isAuthenticated: false,
      isLoading: false,
      error: error,
    );
  }
}

final signInControllerProvider =
    StateNotifierProvider<SignInController, AsyncValue<void>>((ref) {
  final gateway = ref.read(authGatewayProvider);
  return SignInController(gateway);
});

class SignInController extends StateNotifier<AsyncValue<void>> {
  final AuthGateway _gateway;

  SignInController(this._gateway) : super(const AsyncValue.data(null));

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    state = const AsyncValue.loading();

    try {
      final result = await _gateway.signInWithEmail(
        email: email,
        password: password,
      );
      if (!result.isSuccess) {
        throw Exception(result.error ?? 'Sign in failed');
      }
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? fullName,
    SignupProfile? profile,
  }) async {
    state = const AsyncValue.loading();

    try {
      final result = await _gateway.signUpWithEmail(
        email: email,
        password: password,
        displayName: fullName ?? email.split('@').first,
        profile: profile,
      );
      if (!result.isSuccess) {
        throw Exception(result.error ?? 'Sign up failed');
      }
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();

    try {
      final result = await _gateway.signInWithGoogle();
      if (!result.isSuccess) {
        if (result.error == 'canceled') {
          // User canceled or closed the flow; reset cleanly
          state = const AsyncValue.data(null);
          return;
        }
        throw Exception(result.error ?? 'Google sign-in failed');
      }
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      final err = e.toString().toLowerCase();
      if (err.contains('canceled') || err.contains('cancelled')) {
        state = const AsyncValue.data(null);
        return;
      }
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> resetPassword(String email) async {
    state = const AsyncValue.loading();

    try {
      final ok = await _gateway.sendPasswordRecovery(email);
      if (!ok) throw Exception('Password recovery request failed');
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();

    try {
      await _gateway.signOut();
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
