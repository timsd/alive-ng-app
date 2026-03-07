import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/firebase_database_service.dart';
import '../services/auth_service.dart';

// Auth State Provider
final authStateProvider = StreamProvider<User?>((ref) {
  try {
    if (Firebase.apps.isEmpty) {
      return Stream<User?>.value(null);
    }
    return FirebaseAuth.instance.authStateChanges();
  } catch (_) {
    return Stream<User?>.value(null);
  }
});

// Current User Provider
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user,
    loading: () => null,
    error: (_, __) => null,
  );
});

// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService.instance;
});

// Firebase Database Service Provider
final firebaseDatabaseServiceProvider =
    Provider<FirebaseDatabaseService>((ref) {
  return FirebaseDatabaseService.instance;
});
