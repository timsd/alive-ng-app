import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_models.dart';
import '../services/adapters/appwrite_auth_gateway.dart';
import '../services/appwrite_auth_service.dart';
import '../services/ports/auth_gateway.dart';

export '../models/auth_models.dart' show AppUser;

// ──────────────────────────────────────────────────────────
//  Core Auth Providers (SDK-agnostic)
// ──────────────────────────────────────────────────────────

/// The single [AuthGateway] instance used throughout the app.
///
/// Swap the concrete adapter here to switch backends (Appwrite → Firebase,
/// mock, etc.) without touching any other file.
final authGatewayProvider = Provider<AuthGateway>((ref) {
  final service = ref.watch(appwriteAuthServiceProvider);
  return AppwriteAuthGateway(service);
});

/// Reactive stream of auth state changes, emitting [AppUser?].
final authStateProvider = StreamProvider<AppUser?>((ref) {
  final gateway = ref.watch(authGatewayProvider);
  final controller = StreamController<AppUser?>();

  // Seed with the current cached user.
  controller.add(gateway.currentUser);

  // Forward all gateway auth-state events.
  final sub = gateway.authStateChanges.listen(
    (user) {
      if (!controller.isClosed) controller.add(user);
    },
    onError: (Object e) {
      if (!controller.isClosed) controller.addError(e);
    },
  );

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Synchronous accessor for the current [AppUser].
final currentUserProvider = Provider<AppUser?>((ref) {
  // Derive from the stream so it stays reactive.
  return ref.watch(authStateProvider).value;
});
