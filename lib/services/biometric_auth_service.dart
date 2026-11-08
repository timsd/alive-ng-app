import 'dart:convert';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';
import '../utils/logger.dart';
import '../utils/app_exception.dart';

/// Service to handle biometric authentication for registered users
class BiometricAuthService {
  static final BiometricAuthService _instance =
      BiometricAuthService._internal();
  factory BiometricAuthService() => _instance;
  BiometricAuthService._internal();

  static BiometricAuthService get instance => _instance;

  static final Logger _logger = Logger('BiometricAuthService');

  final LocalAuthentication _localAuth = LocalAuthentication();
  final StorageService _storage = StorageService.instance;

  static const String _credentialsKey = 'biometric_credentials';
  static const String _sessionCredentialsKey = 'biometric_session_credentials';

  /// Check if biometric authentication is available on the device
  Future<bool> isBiometricAvailable() async {
    try {
      if (kIsWeb) {
        return false;
      }

      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable || isDeviceSupported;
    } catch (e) {
      _logger.warning('Error checking biometric availability: $e');
      return false;
    }
  }

  /// Check if biometric authentication is enabled for the current user
  Future<bool> isBiometricEnabled() async {
    try {
      if (kIsWeb) return false;
      final enabled =
          await _storage.getSecureString(StorageKeys.biometricEnabled);
      if (enabled != 'true') return false;
      final creds = await _storage.getSecureString(_credentialsKey);
      return creds != null && creds.isNotEmpty;
    } catch (e) {
      _logger.error('Error checking biometric enabled status', e);
      return false;
    }
  }

  /// Returns the email address currently bound to biometric sign-in, if any.
  Future<String?> getBoundEmail() async {
    try {
      if (kIsWeb) return null;
      final raw = await _storage.getSecureString(_credentialsKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return (decoded['email'] as String?)?.trim();
    } catch (_) {
      return null;
    }
  }

  /// Caches encrypted email/password from a normal login so the user can toggle
  /// Biometric Sign-In ON later from Profile without re-typing their password.
  Future<void> cacheSessionCredentials({
    required String email,
    required String password,
  }) async {
    try {
      if (kIsWeb || email.trim().isEmpty || password.isEmpty) return;
      final payload = jsonEncode({
        'email': email.trim(),
        'password': password,
        'cached_at': DateTime.now().toIso8601String(),
      });
      await _storage.setSecureString(_sessionCredentialsKey, payload);

      // If biometric auth is already enabled for this email, keep the stored password fresh
      final isEnabled = await isBiometricEnabled();
      final boundEmail = await getBoundEmail();
      if (isEnabled &&
          boundEmail != null &&
          boundEmail.toLowerCase() == email.trim().toLowerCase()) {
        await _storage.setSecureString(_credentialsKey, payload);
      }
    } catch (e) {
      _logger.warning('Could not cache session credentials: $e');
    }
  }

  /// Retrieves cached session credentials for [email] (if available).
  Future<Map<String, String>?> getCachedCredentials({String? email}) async {
    try {
      if (kIsWeb) return null;
      for (final key in [_credentialsKey, _sessionCredentialsKey]) {
        final raw = await _storage.getSecureString(key);
        if (raw == null || raw.isEmpty) continue;
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final savedEmail = (map['email'] as String?)?.trim() ?? '';
        final savedPassword = (map['password'] as String?) ?? '';
        if (savedEmail.isEmpty || savedPassword.isEmpty) continue;
        if (email == null ||
            email.trim().isEmpty ||
            savedEmail.toLowerCase() == email.trim().toLowerCase()) {
          return {'email': savedEmail, 'password': savedPassword};
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _promptOSBiometric(String reason) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      // Fallback for Android devices with Class-2 Face Unlock or combined biometric/credential prompt
      return await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    }
  }

  /// Enable biometric authentication for a user by storing their credentials securely
  Future<bool> enableBiometricAuth({
    required String email,
    required String password,
  }) async {
    try {
      if (kIsWeb) {
        return false;
      }

      final isAuthenticated = await _promptOSBiometric(
        'Authenticate with your fingerprint or face to enable Biometric Sign-In',
      );

      if (!isAuthenticated) {
        return false;
      }

      final credentials = {
        'email': email.trim(),
        'password': password,
        'enabled_at': DateTime.now().toIso8601String(),
      };

      final encoded = jsonEncode(credentials);
      await _storage.setSecureString(_credentialsKey, encoded);
      await _storage.setSecureString(_sessionCredentialsKey, encoded);
      await _storage.setSecureString(StorageKeys.biometricEnabled, 'true');

      return true;
    } catch (e) {
      _logger.error('Error enabling biometric auth', e);
      throw AuthException('Error enabling biometric auth', originalError: e);
    }
  }

  /// Disable biometric authentication
  Future<void> disableBiometricAuth() async {
    try {
      await _storage.removeSecure(_credentialsKey);
      await _storage.setSecureString(StorageKeys.biometricEnabled, 'false');
    } catch (e) {
      _logger.error('Error disabling biometric auth', e);
      throw AuthException('Error disabling biometric auth', originalError: e);
    }
  }

  /// Authenticate using biometrics and return stored credentials
  Future<Map<String, String>?> authenticateWithBiometrics() async {
    try {
      if (kIsWeb) {
        return null;
      }

      final isEnabled = await isBiometricEnabled();
      if (!isEnabled) {
        return null;
      }

      final isAuthenticated = await _promptOSBiometric(
        'Scan your fingerprint or face to sign in to ALIVE Nigeria',
      );

      if (!isAuthenticated) {
        return null;
      }

      final credentialsJson = await _storage.getSecureString(_credentialsKey);
      if (credentialsJson == null) {
        return null;
      }

      final credentials = jsonDecode(credentialsJson) as Map<String, dynamic>;
      return {
        'email': (credentials['email'] as String).trim(),
        'password': credentials['password'] as String,
      };
    } catch (e) {
      _logger.error('Error authenticating with biometrics', e);
      throw AuthException('Error authenticating with biometrics',
          originalError: e);
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      // Check if running on web platform - biometrics not supported
      if (kIsWeb) {
        return [];
      }

      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      // Log platform exceptions for web or unsupported platforms
      _logger.warning('Error getting available biometrics: $e');
      throw AuthException('Error getting available biometrics',
          originalError: e);
    }
  }
}
