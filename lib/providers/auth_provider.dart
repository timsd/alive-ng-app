import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../services/auth_service.dart';

// Auth State Provider
final authStateProvider = StreamProvider<User?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange.map(
    (data) => data.session?.user,
  );
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

// Supabase Service Provider
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService.instance;
});
