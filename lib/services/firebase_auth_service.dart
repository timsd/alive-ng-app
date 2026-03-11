// Backwards-compatibility shim.
//
// All authentication logic now lives in auth_service.dart.
// This file re-exports AuthService as FirebaseAuthService so existing
// importers (e.g. firebase_auth_provider.dart) continue to compile.

import 'auth_service.dart';
export 'auth_service.dart' show AuthService, AuthResult;

/// Alias kept for callers that reference `FirebaseAuthService`.
typedef FirebaseAuthService = AuthService;
