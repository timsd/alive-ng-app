import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

/// Provider to track if the user is in guest mode
final isGuestModeProvider = StateProvider<bool>((ref) => false);

/// Provider to check if user has authentication (either logged in or guest)
final hasAccessProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  final isGuest = ref.watch(isGuestModeProvider);

  final isAuthenticated = authState.when(
    data: (user) => user != null,
    loading: () => false,
    error: (_, __) => false,
  );

  return isAuthenticated || isGuest;
});

/// Provider to check if user is authenticated (not guest)
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) => user != null,
    loading: () => false,
    error: (_, __) => false,
  );
});




