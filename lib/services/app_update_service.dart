import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/logger.dart';

class AppUpdateService {
  static final AppUpdateService instance = AppUpdateService._();
  AppUpdateService._();
  
  final Logger _logger = Logger('AppUpdateService');

  /// Checks for upates. On Android, uses in_app_update.
  /// On iOS/Web, compares local version against Firestore `config/app_version`.
  Future<void> checkForUpdates(BuildContext context) async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        // Android native in-app update checking
        final updateInfo = await InAppUpdate.checkForUpdate();
        if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
          if (updateInfo.immediateUpdateAllowed) {
            await InAppUpdate.performImmediateUpdate();
          } else if (updateInfo.flexibleUpdateAllowed) {
            await InAppUpdate.startFlexibleUpdate();
            await InAppUpdate.completeFlexibleUpdate();
          }
        }
      } else {
        // iOS or Web custom update checking via Firestore config
        final snapshot = await FirebaseFirestore.instance.collection('config').doc('app_version').get();
        if (!snapshot.exists) return;
        
        final data = snapshot.data()!;
        final latestVersion = data['latest_version'] as String?;
        final forceUpdate = data['force_update'] as bool? ?? false;
        final updateUrl = data['update_url'] as String?;
        
        if (latestVersion == null) return;
        
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;
        
        if (_isNewerVersion(currentVersion, latestVersion)) {
          if (context.mounted) {
            _showUpdateDialog(context, latestVersion, forceUpdate, updateUrl);
          }
        }
      }
    } catch (e) {
      _logger.error('Failed to check for updates: $e');
    }
  }

  void _showUpdateDialog(BuildContext context, String newVersion, bool force, String? updateUrl) {
    showDialog(
      context: context,
      barrierDismissible: !force,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Available'),
        content: Text('A new version ($newVersion) of ALIVE-NG is available. Please update to continue getting the best experience.'),
        actions: [
          if (!force)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Later'),
            ),
          ElevatedButton(
            onPressed: () async {
              if (updateUrl != null) {
                final url = Uri.parse(updateUrl);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              }
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  // Very simplified semver comparison (e.g. 1.0.0 vs 1.1.0)
  bool _isNewerVersion(String current, String latest) {
    List<int> currentParts = current.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    List<int> latestParts = latest.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    
    // Pad lists if needed
    while (currentParts.length < 3) {
      currentParts.add(0);
    }
    while (latestParts.length < 3) {
      latestParts.add(0);
    }
    
    for (int i = 0; i < 3; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }
}
