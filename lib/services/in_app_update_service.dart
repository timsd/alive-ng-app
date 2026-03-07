import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

class InAppUpdateService {
  static Future<void> checkForUpdates([BuildContext? context]) async {
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.immediateUpdateAllowed == true) {
        await InAppUpdate.performImmediateUpdate();
      } else if (info.flexibleUpdateAllowed == true) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
        // Optionally show a snackbar to inform user update was applied
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('App updated in background')),
          );
        }
      }
    } catch (_) {
      // Ignore errors; update flow is best-effort
    }
  }
}
