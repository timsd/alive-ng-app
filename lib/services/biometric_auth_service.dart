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

  /// Check if biometric authentication is available on the device
  Future<bool> isBiometricAvailable() async {
    try {
      // Check if running on web platform - biometrics not supported
      if (kIsWeb) {
        return false;
      }

      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      // Log platform exceptions for web or unsupported platforms
      _logger.warning('Error checking biometric availability: $e');
      throw AuthException('Error checking biometric availability',
          originalError: e);
    }
  }

  /// Check if biometric authentication is enabled for the current user
  Future<bool> isBiometricEnabled() async {
    try {
      final enabled =
          await _storage.getSecureString(StorageKeys.biometricEnabled);
      return enabled == 'true';
    } catch (e) {
      _logger.error('Error checking biometric enabled status', e);
      throw AuthException('Error checking biometric enabled status',
          originalError: e);
    }
  }

  /// Enable biometric authentication for a user by storing their credentials securely
  Future<bool> enableBiometricAuth({
    required String email,
    required String password,
  }) async {
    try {
      // Check if running on web platform - biometrics not supported
      if (kIsWeb) {
        return false;
      }

      // First verify biometric authentication works
      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to enable biometric sign-in',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!isAuthenticated) {
        return false;
      }

      // Store credentials securely
      final credentials = {
        'email': email,
        'password': password, // In production, consider using tokens instead
        'enabled_at': DateTime.now().toIso8601String(),
      };

      await _storage.setSecureString(
          'biometric_credentials', jsonEncode(credentials));
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
      await _storage.removeSecure('biometric_credentials');
      await _storage.setSecureString(StorageKeys.biometricEnabled, 'false');
    } catch (e) {
      _logger.error('Error disabling biometric auth', e);
      throw AuthException('Error disabling biometric auth', originalError: e);
    }
  }

  /// Authenticate using biometrics and return stored credentials
  Future<Map<String, String>?> authenticateWithBiometrics() async {
    try {
      // Check if running on web platform - biometrics not supported
      if (kIsWeb) {
        return null;
      }

      // Check if biometric auth is enabled
      final isEnabled = await isBiometricEnabled();
      if (!isEnabled) {
        return null;
      }

      // Perform biometric authentication
      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to sign in',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!isAuthenticated) {
        return null;
      }

      // Retrieve stored credentials
      final credentialsJson =
          await _storage.getSecureString('biometric_credentials');
      if (credentialsJson == null) {
        return null;
      }

      final credentials = jsonDecode(credentialsJson) as Map<String, dynamic>;
      return {
        'email': credentials['email'] as String,
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
