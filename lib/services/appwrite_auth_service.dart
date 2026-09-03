import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart' as appwrite_enums;
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import 'appwrite_profile_service.dart';

/// Provider to access the Appwrite authentication service instance.
final appwriteAuthServiceProvider = Provider<AppwriteAuthService>((ref) {
  return AppwriteAuthService();
});

/// Tracks the current logged-in Appwrite user.
final appwriteUserProvider =
    StateNotifierProvider<AppwriteUserNotifier, models.User?>((ref) {
  final authService = ref.watch(appwriteAuthServiceProvider);
  return AppwriteUserNotifier(authService);
});

class AppwriteAuthService {
  late final Account _account;
  late final TablesDB _tables;
  late final Teams _teams;
  late final AppwriteProfileService _profileService;
  models.User? _currentUser;

  static const String databaseId = AppwriteBackendConfig.databaseId;
  static const String usersCollectionId =
      AppwriteBackendConfig.usersCollectionId;

  AppwriteAuthService() {
    _account = Account(appwriteClient);
    _tables = TablesDB(appwriteClient);
    _teams = Teams(appwriteClient);
    _profileService = AppwriteProfileService();
  }

  /// Get the currently authenticated user details.
  Future<models.User?> getCurrentUser() async {
    try {
      _currentUser = await _account.get();
      if (_currentUser != null) {
        await verifyAndSyncAdminRights(_currentUser!.$id);
      }
      return _currentUser;
    } catch (e) {
      debugPrint('No active Appwrite session found: $e');
      _currentUser = null;
      return null;
    }
  }

  models.User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  Future<void> verifyAndSyncAdminRights(String userId) async {
    try {
      final teamList = await _teams.list();
      final isAdmin = teamList.teams.any(
        (team) => team.$id == AppwriteBackendConfig.adminTeamId,
      );

      if (!isAdmin) return;

      await _tables.updateRow(
        databaseId: databaseId,
        tableId: usersCollectionId,
        rowId: userId,
        data: {
          'role': 'admin',
          'approval_status': 'approved',
          'is_approved': true,
          'approved_by': 'appwrite_team:${AppwriteBackendConfig.adminTeamId}',
          'approved_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
      debugPrint('Admin privileges synced from Appwrite Team for: $userId');
    } catch (e) {
      debugPrint('Skipping Appwrite Team admin sync: $e');
    }
  }

  /// Email and password sign up.
  Future<models.User> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    Map<String, dynamic>? profileData,
  }) async {
    try {
      final user = await _account.create(
        userId: ID.unique(),
        email: email,
        password: password,
        name: name,
      );

      await loginWithEmail(
        email: email,
        password: password,
        profileData: profileData,
      );

      return user;
    } catch (e) {
      debugPrint('Appwrite Sign Up Error: $e');
      rethrow;
    }
  }

  /// Email and password login.
  Future<models.Session> loginWithEmail({
    required String email,
    required String password,
    Map<String, dynamic>? profileData,
  }) async {
    try {
      final session = await _account.createEmailPasswordSession(
        email: email,
        password: password,
      );
      final user = await getCurrentUser();
      if (user != null) {
        await _profileService.ensureUserProfile(
          userId: user.$id,
          email: user.email,
          fullName: user.name.isEmpty ? email.split('@').first : user.name,
          profileData: profileData,
        );
        await verifyAndSyncAdminRights(user.$id);
      }
      return session;
    } catch (e) {
      debugPrint('Appwrite Login Error: $e');
      rethrow;
    }
  }

  /// Log out of the current session.
  Future<void> logout() async {
    try {
      await _account.deleteSession(sessionId: 'current');
      _currentUser = null;
    } catch (e) {
      debugPrint('Appwrite Logout Error: $e');
      rethrow;
    }
  }

  Future<void> signOut() => logout();

  Future<models.Token> sendPasswordRecovery(String email) {
    return _account.createRecovery(
      email: email,
      url: AppwriteBackendConfig.passwordRecoveryUrl,
    );
  }

  Future<models.Token> completePasswordRecovery({
    required String userId,
    required String secret,
    required String password,
  }) {
    return _account.updateRecovery(
      userId: userId,
      secret: secret,
      password: password,
    );
  }

  Future<void> signInWithGoogle() async {
    final callbackScheme =
        'appwrite-callback-${AppwriteBackendConfig.projectId}://';
    await _account.createOAuth2Session(
      provider: appwrite_enums.OAuthProvider.google,
      success: kIsWeb ? AppwriteBackendConfig.oauthSuccessUrl : callbackScheme,
      failure: kIsWeb ? AppwriteBackendConfig.oauthFailureUrl : callbackScheme,
      scopes: const ['email', 'profile'],
    );
    await getCurrentUser();
    final user = _currentUser;
    if (user != null) {
      await _profileService.ensureUserProfile(
        userId: user.$id,
        email: user.email,
        fullName: user.name.isEmpty ? user.email.split('@').first : user.name,
      );
      await verifyAndSyncAdminRights(user.$id);
    }
  }
}

/// Manages the reactive state of the authenticated Appwrite user.
class AppwriteUserNotifier extends StateNotifier<models.User?> {
  final AppwriteAuthService _authService;

  AppwriteUserNotifier(this._authService) : super(null) {
    _initUser();
  }

  Future<void> _initUser() async {
    state = await _authService.getCurrentUser();
  }

  Future<void> refresh() async {
    state = await _authService.getCurrentUser();
  }

  Future<void> login(String email, String password) async {
    await _authService.loginWithEmail(email: email, password: password);
    state = await _authService.getCurrentUser();
  }

  Future<void> signInWithGoogle() async {
    await _authService.signInWithGoogle();
    state = await _authService.getCurrentUser();
  }

  Future<void> logout() async {
    await _authService.logout();
    state = null;
  }
}
