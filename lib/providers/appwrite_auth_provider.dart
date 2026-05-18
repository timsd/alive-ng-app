import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_models.dart';
import '../services/appwrite_auth_service.dart';
import '../services/appwrite_profile_service.dart';
import '../utils/appwrite_user_extensions.dart';
import 'auth_provider.dart' hide authStateProvider;
import 'auth_provider.dart' as core_auth;

export '../utils/appwrite_user_extensions.dart';

final appwriteAuthControllerProvider = Provider<AppwriteAuthService>((ref) {
  return ref.watch(appwriteAuthServiceProvider);
});

final appwriteUserStreamProvider = core_auth.authStateProvider;

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
    isEmailVerified: user.emailVerified,
    isAnonymous: user.isAnonymous,
    photoUrl: user.photoURL,
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
  final models.User? user;

  const AuthState._({
    required this.isAuthenticated,
    required this.isLoading,
    this.error,
    this.user,
  });

  factory AuthState.authenticated(models.User user) {
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
  final authService = ref.read(appwriteAuthControllerProvider);
  final userNotifier = ref.read(appwriteUserProvider.notifier);
  return SignInController(authService, userNotifier);
});

class SignInController extends StateNotifier<AsyncValue<void>> {
  final AppwriteAuthService _authService;
  final AppwriteUserNotifier _userNotifier;

  SignInController(this._authService, this._userNotifier)
      : super(const AsyncValue.data(null));

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    state = const AsyncValue.loading();

    try {
      await _userNotifier.login(email, password);
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
      await _authService.signUpWithEmail(
        email: email,
        password: password,
        name: fullName ?? email.split('@').first,
        profileData: profileData,
      );
      await _userNotifier.refresh();
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();

    try {
      await _userNotifier.signInWithGoogle();
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> resetPassword(String email) async {
    state = const AsyncValue.loading();

    try {
      await _authService.sendPasswordRecovery(email);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();

    try {
      await _userNotifier.logout();
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
