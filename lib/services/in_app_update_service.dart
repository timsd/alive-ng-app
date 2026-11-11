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
  static bool _isChecking = false;

  static const String playStorePackageName = 'com.alive.alivengandroidapp';
  static const String playStoreMarketUri =
      'market://details?id=$playStorePackageName';
  static const String playStoreWebUri =
      'https://play.google.com/store/apps/details?id=$playStorePackageName';

  /// Launches Google Play Store directly to the app listing page.
  static Future<bool> openPlayStore() async {
    try {
      final marketUri = Uri.parse(playStoreMarketUri);
      if (await canLaunchUrl(marketUri)) {
        return await launchUrl(marketUri, mode: LaunchMode.externalApplication);
      }
      final webUri = Uri.parse(playStoreWebUri);
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Failed to open Play Store via market URI: $e');
      try {
        final webUri = Uri.parse(playStoreWebUri);
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        return false;
      }
    }
  }

  /// Automatically checks for updates on Google Play Store, falling back to
  /// Appwrite remote version control.
  static Future<void> checkForUpdates([
    BuildContext? context,
    bool manual = false,
  ]) async {
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;
    if (_isChecking) return;

    _isChecking = true;
    try {
      var googlePlayHandled = false;

      // 1. Google Play In-App Updates API (official Play Store mechanism)
      try {
        final info = await InAppUpdate.checkForUpdate();
        debugPrint(
          'InAppUpdate info: availability=${info.updateAvailability}, '
          'immediateAllowed=${info.immediateUpdateAllowed}, '
          'flexibleAllowed=${info.flexibleUpdateAllowed}, '
          'installStatus=${info.installStatus}',
        );

        // A. If an update was previously downloaded via flexible mode, complete it
        if (info.installStatus == InstallStatus.downloaded) {
          await InAppUpdate.completeFlexibleUpdate();
          googlePlayHandled = true;
          return;
        }

        // B. If an immediate update is already in progress, resume it
        if (info.updateAvailability ==
            UpdateAvailability.developerTriggeredUpdateInProgress) {
          await InAppUpdate.performImmediateUpdate();
          googlePlayHandled = true;
          return;
        }

        // C. An update is available on Google Play
        if (info.updateAvailability == UpdateAvailability.updateAvailable) {
          if (info.immediateUpdateAllowed == true) {
            // Full-screen native Google Play immediate update dialog
            await InAppUpdate.performImmediateUpdate();
            googlePlayHandled = true;
            return;
          } else if (info.flexibleUpdateAllowed == true) {
            // Flexible update in background
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
          } else {
            // Update is available on Google Play, but in-app flags weren't set by priority.
            // Automatically prompt or navigate to Google Play Store listing.
            final ctx = context ?? rootNavigatorKey.currentContext;
            if (ctx != null && ctx.mounted && !_updateDialogShown) {
              _updateDialogShown = true;
              _showPlayStoreUpdatePrompt(ctx);
              googlePlayHandled = true;
              return;
            } else {
              await openPlayStore();
              googlePlayHandled = true;
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('Google Play in-app update check skipped/failed: $e');
        // May fail on sideloaded APKs or if Play Core service is unreachable.
      }

      // 2. Fallback: Appwrite-managed remote version check
      if (!googlePlayHandled) {
        await _checkRemoteAppUpdate(context, manual);
      }
    } finally {
      _isChecking = false;
    }
  }

  static void _showPlayStoreUpdatePrompt(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                'A newer version of ALIVE Nigeria is available on Google Play.',
                style: Theme.of(dialogCtx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'Please update to the latest version to ensure continuous access to community, study, and meeting features.',
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
            TextButton(
              onPressed: () {
                _updateDialogShown = false;
                Navigator.of(dialogCtx).pop();
              },
              child: const Text('Later'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.shop_two_rounded, size: 18),
              onPressed: () async {
                _updateDialogShown = false;
                Navigator.of(dialogCtx).pop();
                await openPlayStore();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(dialogCtx).colorScheme.primary,
                foregroundColor: Theme.of(dialogCtx).colorScheme.onPrimary,
              ),
              label: const Text('Update on Google Play'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _checkRemoteAppUpdate([
    BuildContext? context,
    bool manual = false,
  ]) async {
    if (_updateDialogShown) return;

    try {
      final databases = Databases(appwriteClient);
      // ignore: deprecated_member_use
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
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
      final latestBuildNumber = data['build_number'] is int
          ? data['build_number'] as int
          : (int.tryParse(data['build_number']?.toString() ?? '') ?? 0);

      final isNewerVersion = _isVersionNewer(latestVersion, currentVersion);
      final isNewerBuild =
          latestBuildNumber > 0 && latestBuildNumber > currentBuildNumber;

      if (isNewerVersion || isNewerBuild) {
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
      } else if (manual) {
        final ctx = context ?? rootNavigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(
                'You are using the latest version of ALIVE Nigeria (v$currentVersion).',
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Remote app update check failed: $e');
    }
  }

  /// Compares semantic versions (e.g. 2.0.9 > 2.0.7)
  static bool _isVersionNewer(String latest, String current) {
    try {
      final lParts = latest.split('.').map(int.parse).toList();
      final cParts = current.split('.').map(int.parse).toList();
      final length =
          lParts.length > cParts.length ? lParts.length : cParts.length;
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                'A new version ($latestVersion) of ALIVE Nigeria is available on Google Play. '
                'You are currently using version $currentVersion.',
                style: Theme.of(dialogCtx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                forceUpdate
                    ? 'This update is required to continue using the application.'
                    : 'We recommend updating now from Google Play Store to enjoy the latest features and fixes.',
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
                onPressed: () {
                  _updateDialogShown = false;
                  Navigator.of(dialogCtx).pop();
                },
                child: const Text('Later'),
              ),
            TextButton.icon(
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Direct APK', style: TextStyle(fontSize: 12)),
              onPressed: () async {
                if (!forceUpdate) {
                  _updateDialogShown = false;
                  Navigator.of(dialogCtx).pop();
                }
                final uri = Uri.parse(updateUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.shop_two_rounded, size: 18),
              onPressed: () async {
                if (!forceUpdate) {
                  _updateDialogShown = false;
                  Navigator.of(dialogCtx).pop();
                }
                await openPlayStore();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(dialogCtx).colorScheme.primary,
                foregroundColor: Theme.of(dialogCtx).colorScheme.onPrimary,
              ),
              label: const Text('Update on Google Play'),
            ),
          ],
        ),
      ),
    );
  }
}
