import 'dart:convert';
import 'dart:io' show Platform;
import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/appwrite_backend_config.dart';
import '../main.dart' show appwriteClient;
import '../utils/navigation_keys.dart';

class InAppUpdateService {
  static bool _updateDialogShown = false;

  static Future<void> checkForUpdates([BuildContext? context]) async {
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;

    // 1. Try Google Play In-App Update API first (for Play Store installs)
    var googlePlayHandled = false;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.immediateUpdateAllowed == true) {
        await InAppUpdate.performImmediateUpdate();
        googlePlayHandled = true;
        return;
      } else if (info.flexibleUpdateAllowed == true) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
        googlePlayHandled = true;
        final ctx = context ?? rootNavigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('App updated successfully')),
          );
        }
        return;
      }
    } catch (_) {
      // Not installed via Google Play or Play Store update not available.
    }

    // 2. Fallback to Appwrite-managed OTA updates (for direct APK downloads)
    if (!googlePlayHandled) {
      await _checkSelfHostedOtaUpdate(context);
    }
  }

  static Future<void> _checkSelfHostedOtaUpdate([BuildContext? context]) async {
    if (_updateDialogShown) return;

    try {
      final databases = Databases(appwriteClient);
      final doc = await databases.getDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.appSettingsCollectionId,
        documentId: 'app_version',
      );

      final dynamic rawValue = doc.data['value'];
      if (rawValue == null) return;

      final Map<String, dynamic> data = rawValue is String
          ? jsonDecode(rawValue) as Map<String, dynamic>
          : Map<String, dynamic>.from(rawValue as Map);

      final latestVersion = (data['latest_version'] as String?)?.trim();
      final forceUpdate = data['force_update'] == true;
      final updateUrl = (data['update_url'] as String?)?.trim() ??
          'https://api.alivenigeria.org/v1/storage/buckets/app_releases/files/alive_ng_android_release/download?project=6a3bef53002f5090dedf';

      if (latestVersion == null || latestVersion.isEmpty) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version.trim();

      if (_isVersionNewer(latestVersion, currentVersion)) {
        final ctx = context ?? rootNavigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          _updateDialogShown = true;
          _showOtaUpdateDialog(
            ctx,
            latestVersion: latestVersion,
            currentVersion: currentVersion,
            updateUrl: updateUrl,
            forceUpdate: forceUpdate,
          );
        }
      }
    } catch (e) {
      debugPrint('Self-hosted OTA check failed: $e');
    }
  }

  /// Compares semantic versions (e.g. 1.0.1 > 1.0.0)
  static bool _isVersionNewer(String latest, String current) {
    try {
      final lParts = latest.split('.').map(int.parse).toList();
      final cParts = current.split('.').map(int.parse).toList();
      final length = lParts.length > cParts.length ? lParts.length : cParts.length;
      for (var i = 0; i < length; i++) {
        final l = i < lParts.length ? lParts[i] : 0;
        final c = i < cParts.length ? cParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
      return false;
    } catch (_) {
      return latest != current;
    }
  }

  static void _showOtaUpdateDialog(
    BuildContext context, {
    required String latestVersion,
    required String currentVersion,
    required String updateUrl,
    required bool forceUpdate,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (dialogCtx) => PopScope(
        canPop: !forceUpdate,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                Icons.system_update_rounded,
                color: Theme.of(dialogCtx).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('Update Available')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A new version ($latestVersion) of ALIVE Nigeria is available. '
                'You are currently using version $currentVersion.',
                style: Theme.of(dialogCtx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                forceUpdate
                    ? 'This update is required to continue using the application.'
                    : 'We recommend updating now to enjoy the latest features and bug fixes.',
                style: Theme.of(dialogCtx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(dialogCtx)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
              ),
            ],
          ),
          actions: [
            if (!forceUpdate)
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Later'),
              ),
            ElevatedButton.icon(
              icon: const Icon(Icons.download_rounded, size: 18),
              onPressed: () async {
                if (!forceUpdate) Navigator.of(dialogCtx).pop();
                final uri = Uri.parse(updateUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(dialogCtx).colorScheme.primary,
                foregroundColor: Theme.of(dialogCtx).colorScheme.onPrimary,
              ),
              label: const Text('Download & Update'),
            ),
          ],
        ),
      ),
    );
  }
}
