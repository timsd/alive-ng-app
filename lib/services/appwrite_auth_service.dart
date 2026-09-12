import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart' as appwrite_enums;
import 'package:appwrite/models.dart' as models;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../utils/web_launch_params.dart';
import 'package:url_launcher/url_launcher.dart';
import 'appwrite_profile_service.dart';
import 'role_access_service.dart';

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
  static models.User? _sharedCurrentUser;

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
      _sharedCurrentUser = await _account.get();
      if (_sharedCurrentUser != null) {
        await verifyAndSyncAdminRights(_sharedCurrentUser!.$id);
      }
      return _sharedCurrentUser;
    } on AppwriteException catch (e) {
      // A 401 / session error means a stale session is poisoning requests.
      // Clean it up so the next auth attempt starts fresh.
      if (e.code == 401 ||
          e.type == 'user_unauthorized' ||
          (e.type?.contains('session') ?? false)) {
        await _clearStaleSessions();
      }
      debugPrint('No active Appwrite session found: $e');
      _sharedCurrentUser = null;
      return null;
    } catch (e) {
      debugPrint('No active Appwrite session found: $e');
      _sharedCurrentUser = null;
      return null;
    }
  }

  models.User? get currentUser => _sharedCurrentUser;
  set currentUser(models.User? user) => _sharedCurrentUser = user;
  bool get isAuthenticated => _sharedCurrentUser != null;

  /// Kills ALL active sessions (not just the current one) and clears the web
  /// fallback cookie so a stale browser session can never block a fresh login
  /// with `appwrite_user_session_already_exists`.
  Future<void> _clearStaleSessions() async {
    try {
      await _account.deleteSessions();
    } catch (e) {
      // No active session (e.g. user_unauthorized) is fine — log for diagnosis.
      debugPrint('Pre-auth session cleanup (non-fatal): $e');
    }
    if (kIsWeb) {
      clearAppwriteCookieFallback();
    }
  }

  Future<void> verifyAndSyncAdminRights(String userId) async {
    try {
      final email = _sharedCurrentUser?.email.toLowerCase() ?? '';
      final isSuperAdmin = AppwriteBackendConfig.isSuperAdminEmail(email);

      bool isInAdminTeam = false;
      try {
        final teamList = await _teams.list();
        isInAdminTeam = teamList.teams.any(
          (team) => team.$id == AppwriteBackendConfig.adminTeamId,
        );
      } catch (te) {
        debugPrint('Appwrite team check skipped: $te');
      }

      bool isExistingAdminRow = false;
      try {
        final row = await _tables.getRow(
          databaseId: databaseId,
          tableId: usersCollectionId,
          rowId: userId,
        );
        final currentRole = (row.data['role'] ?? '').toString().toLowerCase();
        if (currentRole == 'admin' || currentRole == 'staff') {
          isExistingAdminRow = true;
        }
      } catch (_) {}

      final isAdmin = isSuperAdmin || isInAdminTeam || isExistingAdminRow;

      if (!isAdmin) return;

      await _tables.updateRow(
        databaseId: databaseId,
        tableId: usersCollectionId,
        rowId: userId,
        data: {
          'role': 'admin',
          'approval_status': 'approved',
          'is_approved': true,
          'approved_by': isSuperAdmin
              ? 'super_admin_email:$email'
              : isInAdminTeam
                  ? 'appwrite_team:${AppwriteBackendConfig.adminTeamId}'
                  : 'database_role:admin',
          'approved_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
      debugPrint('Admin privileges synced for: $userId ($email)');
      // Immediately warm the RoleAccessService cache so the UI reflects the
      // admin role without waiting for the next scheduled cache refresh.
      await RoleAccessService.instance.forceRefreshCache();
    } catch (e) {
      debugPrint('Skipping Appwrite admin sync: $e');
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
      // Session-proof: remove every leftover session + the web fallback cookie
      // before creating a new one, so a stale session can never trigger
      // `appwrite_user_session_already_exists`.
      await _clearStaleSessions();
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
      _sharedCurrentUser = null;
      if (kIsWeb) {
        clearAppwriteCookieFallback();
      }
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
    if (kIsWeb) {
      final successUrl = AppwriteBackendConfig.oauthSuccessUrl;
      final failureUrl = AppwriteBackendConfig.oauthFailureUrl;
      final oauthUrl =
          '${AppwriteBackendConfig.endpoint}/account/sessions/oauth2/google'
          '?project=${Uri.encodeComponent(AppwriteBackendConfig.projectId)}'
          '&success=${Uri.encodeComponent(successUrl)}'
          '&failure=${Uri.encodeComponent(failureUrl)}'
          '&scopes%5B%5D=email&scopes%5B%5D=profile';
      await launchUrl(Uri.parse(oauthUrl), webOnlyWindowName: '_self');
      return;
    }

    const callbackScheme =
        'appwrite-callback-${AppwriteBackendConfig.projectId}://';
    await _account.createOAuth2Session(
      provider: appwrite_enums.OAuthProvider.google,
      success: callbackScheme,
      failure: callbackScheme,
      scopes: const ['email', 'profile'],
    );
    await getCurrentUser();
    final user = _sharedCurrentUser;
    if (user != null) {
      await _profileService.ensureUserProfile(
        userId: user.$id,
        email: user.email,
        fullName: user.name.isEmpty ? user.email.split('@').first : user.name,
      );
      await verifyAndSyncAdminRights(user.$id);
    }
  }

  /// Update the current user's password.
  /// Requires the user to have an active session.
  Future<void> updatePassword(String newPassword) async {
    try {
      await _account.updatePassword(password: newPassword);
    } catch (e) {
      debugPrint('Appwrite Update Password Error: $e');
      rethrow;
    }
  }

  /// Update the current user's email.
  /// Requires the user to have an active session and current password.
  Future<void> updateEmail(String newEmail, {String password = ''}) async {
    try {
      await _account.updateEmail(email: newEmail, password: password);
    } catch (e) {
      debugPrint('Appwrite Update Email Error: $e');
      rethrow;
    }
  }

  /// Send a verification email to the current user.
  Future<void> sendEmailVerification() async {
    try {
      await _account.createEmailVerification(
        url: AppwriteBackendConfig.oauthSuccessUrl,
      );
    } catch (e) {
      debugPrint('Appwrite Email Verification Error: $e');
      rethrow;
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
    if (!kIsWeb) {
      state = await _authService.getCurrentUser();
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = null;
  }
}
