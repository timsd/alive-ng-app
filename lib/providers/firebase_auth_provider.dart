import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_auth_service.dart';
import '../models/app_models.dart';

// Firebase Auth Service Provider
final firebaseAuthServiceProvider = Provider<FirebaseAuthService>((ref) {
  return FirebaseAuthService.instance;
});

// Current Firebase User Provider
final firebaseUserProvider = StreamProvider<User?>((ref) {
  final authService = ref.read(firebaseAuthServiceProvider);
  return authService.authStateChanges;
});

// Current User Profile Provider
final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(firebaseUserProvider).value;
  
  if (user == null) return null;

  // Create UserProfile from Firebase User
  return UserProfile(
    id: user.uid,
    email: user.email,
    fullName: user.displayName,
    photoUrl: user.photoURL,
    isEmailVerified: user.emailVerified,
    isAnonymous: user.isAnonymous,
    provider: user.providerData.isNotEmpty 
        ? user.providerData.first.providerId 
        : 'email',
    createdAt: user.metadata.creationTime ?? DateTime.now(),
    updatedAt: DateTime.now(),
  );
});

// Authentication State Provider
final authStateProvider = StateProvider<AuthState>((ref) {
  final userAsync = ref.watch(firebaseUserProvider);
  
  return userAsync.when(
    data: (user) => user != null 
        ? AuthState.authenticated(user) 
        : AuthState.unauthenticated(),
    loading: () => AuthState.loading(),
    error: (error, stack) => AuthState.error(error.toString()),
  );
});

// Authentication State Class
class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;
  final User? user;

  const AuthState._({
    required this.isAuthenticated,
    required this.isLoading,
    this.error,
    this.user,
  });

  factory AuthState.authenticated(User user) {
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

// Sign In Controller Provider
final signInControllerProvider = StateNotifierProvider<SignInController, AsyncValue<void>>((ref) {
  final authService = ref.read(firebaseAuthServiceProvider);
  return SignInController(authService);
});

class SignInController extends StateNotifier<AsyncValue<void>> {
  final FirebaseAuthService _authService;

  SignInController(this._authService) : super(const AsyncValue.data(null));

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    state = const AsyncValue.loading();
    
    try {
      final result = await _authService.signInWithEmailAndPassword(email, password);
      
      if (result.isSuccess) {
        state = const AsyncValue.data(null);
      } else {
        state = AsyncValue.error(result.error!, StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? fullName,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      final result = await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        fullName: fullName,
      );
      
      if (result.isSuccess) {
        state = const AsyncValue.data(null);
      } else {
        state = AsyncValue.error(result.error!, StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    
    try {
      final result = await _authService.signInWithGoogle();
      
      if (result.isSuccess) {
        state = const AsyncValue.data(null);
      } else {
        state = AsyncValue.error(result.error!, StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }



  Future<void> resetPassword(String email) async {
    state = const AsyncValue.loading();
    
    try {
      await _authService.resetPassword(email);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    
    try {
      await _authService.signOut();
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
