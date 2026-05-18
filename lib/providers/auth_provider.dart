import 'dart:async';

import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/appwrite_auth_service.dart';
export '../utils/appwrite_user_extensions.dart';

// Auth State Provider
final authStateProvider = StreamProvider<models.User?>((ref) {
  final controller = StreamController<models.User?>();

  void emitUser(models.User? user) {
    if (!controller.isClosed) {
      controller.add(user);
    }
  }

  emitUser(ref.read(appwriteUserProvider));
  ref.listen<models.User?>(appwriteUserProvider, (_, next) => emitUser(next));

  ref.onDispose(controller.close);
  return controller.stream;
});

// Current User Provider
final currentUserProvider = Provider<models.User?>((ref) {
  return ref.watch(appwriteUserProvider);
});

// Auth Service Provider
final authServiceProvider = Provider<AppwriteAuthService>((ref) {
  return ref.watch(appwriteAuthServiceProvider);
});

// Temporary compatibility provider while Firebase database calls are migrated.
final firebaseDatabaseServiceProvider = Provider<dynamic>((ref) {
  throw UnimplementedError(
    'FirebaseDatabaseService has been removed. Use an Appwrite data service.',
  );
});
