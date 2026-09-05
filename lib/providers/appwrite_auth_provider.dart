import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_models.dart';
import '../services/appwrite_profile_service.dart';
import '../services/ports/auth_gateway.dart';
import 'auth_provider.dart';

/// Alias kept for backward-compat; consumers should migrate to
/// [authGatewayProvider] from `auth_provider.dart`.
final appwriteAuthControllerProvider = Provider<AuthGateway>((ref) {
  return ref.watch(authGatewayProvider);
});

final appwriteUserStreamProvider = authStateProvider;

// Current User Profile Provider
final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(appwriteUserStreamProvider).value;

  if (user == null) return null;

  final profileService = ref.watch(appwriteProfileServiceProvider);
  final document = await profileService.ensureUserProfile(
    userId: user.uid,
    email: user.email,
    fullName: user.displayName ?? user.email.split('@').first,
  );
  return profileService.userProfileFromDocument(
    document,
    fallbackEmail: user.email,
    fallbackFullName: user.displayName,
    isEmailVerified: user.isEmailVerified,
    isAnonymous: user.isAnonymous,
    photoUrl: user.photoUrl,
  );
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
    Map<String, dynamic>? profileData,
  }) async {
    state = const AsyncValue.loading();

    try {
      final result = await _gateway.signUpWithEmail(
        email: email,
        password: password,
        displayName: fullName ?? email.split('@').first,
        profileData: profileData,
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
        throw Exception(result.error ?? 'Google sign-in failed');
      }
      state = const AsyncValue.data(null);
    } catch (e, stack) {
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
