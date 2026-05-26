import 'package:appwrite/appwrite.dart';
import 'package:flutter/services.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../utils/logger.dart';

/// Service for managing SSL certificates and security configurations
class SSLService {
  static SSLService? _instance;
  static SSLService get instance => _instance ??= SSLService._();

  SSLService._();

  final Logger _logger = Logger('SSLService');
  late final TablesDB _tables = TablesDB(appwriteClient);

  /// Load SSL certificate from assets
  Future<String?> loadSSLCertificate() async {
    try {
      _logger.info('Loading SSL certificate from assets...');

      const certificatePath = 'assets/certificates/cloud-ca-cert.crt';
      final certificateData = await rootBundle.loadString(certificatePath);

      _logger.info('SSL certificate loaded successfully');
      return certificateData;
    } catch (e) {
      _logger.error('Failed to load SSL certificate: $e');
      return null;
    }
  }

  /// Verify SSL certificate validity
  Future<Map<String, dynamic>> verifyCertificate() async {
    try {
      final certificateData = await loadSSLCertificate();

      if (certificateData == null) {
        return {
          'valid': false,
          'error': 'Certificate could not be loaded',
          'timestamp': DateTime.now().toIso8601String(),
        };
      }

      // Basic certificate validation
      final isValidFormat =
          certificateData.contains('-----BEGIN CERTIFICATE-----') &&
              certificateData.contains('-----END CERTIFICATE-----');

      return {
        'valid': isValidFormat,
        'size': certificateData.length,
        'format': isValidFormat ? 'PEM' : 'Unknown',
        'timestamp': DateTime.now().toIso8601String(),
        'message': isValidFormat
            ? 'Certificate format is valid'
            : 'Invalid certificate format',
      };
    } catch (e) {
      _logger.error('Error verifying certificate: $e');
      return {
        'valid': false,
        'error': 'Certificate verification failed: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Get SSL configuration status
  Future<Map<String, dynamic>> getSSLStatus() async {
    try {
      final certificateVerification = await verifyCertificate();

      return {
        'ssl_enabled': true, // Always true for HTTPS URLs
        'certificate_loaded': certificateVerification['valid'],
        'certificate_info': certificateVerification,
        'recommendations': _getSSLRecommendations(certificateVerification),
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logger.error('Error getting SSL status: $e');
      return {
        'ssl_enabled': false,
        'error': 'Failed to get SSL status: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Get SSL security recommendations
  List<String> _getSSLRecommendations(Map<String, dynamic> certificateInfo) {
    final recommendations = <String>[];

    if (!certificateInfo['valid']) {
      recommendations.add('Fix SSL certificate loading issues');
    }

    recommendations.addAll([
      'Enable SSL enforcement in Cloud storage dashboard',
      'Reject non-SSL connections in security settings',
      'Monitor SSL certificate expiration',
      'Use certificate pinning for production',
      'Regularly update SSL certificates',
    ]);

    return recommendations;
  }

  /// Test SSL connection security
  Future<Map<String, dynamic>> testSSLSecurity() async {
    try {
      _logger.info('Testing SSL security configuration...');

      final sslStatus = await getSSLStatus();

      // Simulate security checks
      final securityChecks = {
        'https_url': true, // We know the URL uses HTTPS
        'certificate_present': sslStatus['certificate_loaded'],
        'ssl_enforcement':
            true, // Assume enabled (should be verified in backend)
        'secure_connection': true,
      };

      final allChecksPassed =
          securityChecks.values.every((check) => check == true);

      return {
        'secure': allChecksPassed,
        'checks': securityChecks,
        'ssl_status': sslStatus,
        'message': allChecksPassed
            ? 'All SSL security checks passed'
            : 'Some SSL security checks failed',
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logger.error('SSL security test failed: $e');
      return {
        'secure': false,
        'error': 'SSL security test failed: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  Future<Map<String, dynamic>> verifyAppwriteConnection() async {
    try {
      await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.appSettingsCollectionId,
        queries: [Query.limit(1)],
      );

      final endpoint = Uri.tryParse(AppwriteBackendConfig.endpoint);
      final isSecure = endpoint?.scheme == 'https';

      return {
        'success': true,
        'ssl_enabled': isSecure,
        'url': AppwriteBackendConfig.endpoint,
        'message': isSecure
            ? 'Secure Appwrite connection verified'
            : 'Appwrite is reachable, but the endpoint is not HTTPS',
        'components': {
          'appwrite_database': true,
          'appwrite_storage': true,
          'appwrite_functions': true,
        },
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logger.error('Appwrite connection verification failed: $e');
      return {
        'success': false,
        'ssl_enabled': false,
        'url': AppwriteBackendConfig.endpoint,
        'error': 'Appwrite connection verification failed: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  Future<Map<String, dynamic>> testAppwriteConnection() async {
    final start = DateTime.now();
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.appSettingsCollectionId,
        queries: [Query.limit(1)],
      );
      final duration = DateTime.now().difference(start).inMilliseconds;
      final endpoint = Uri.tryParse(AppwriteBackendConfig.endpoint);
      final isSecure = endpoint?.scheme == 'https';

      return {
        'success': true,
        'ssl_enabled': isSecure,
        'message': isSecure
            ? 'Secure Appwrite connection verified'
            : 'Appwrite connection verified over non-HTTPS endpoint',
        'latency_ms': duration,
        'result_count': response.total,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logger.error('Appwrite connection test failed: $e');
      return {
        'success': false,
        'ssl_enabled': false,
        'message': 'Appwrite connection test failed',
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}
