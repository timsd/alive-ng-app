import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/app_constants.dart';
import '../../utils/navigation_keys.dart';
import 'app_tour_overlay.dart';

class AppTourService {
  /// Bump this integer whenever you introduce new major features or workflows
  /// and want all users (even existing devices) to see the updated tour once.
  static const int currentTourVersion = 3;

  static const String _tourVersionKey = 'app_tour_seen_version';
  static const String tourCompletedKey = 'app_feature_tour_v3_completed';
  static bool _isTourActive = false;
  static bool isBiometricDialogActive = false;

  /// Returns true if the user has already viewed or dismissed the app tour
  /// for the current version on this device.
  static Future<bool> hasCompletedTour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seenVersion = prefs.getInt(_tourVersionKey) ?? 0;
      if (seenVersion >= currentTourVersion) return true;

      // Backward compatibility check with legacy boolean flag
      if (prefs.getBool(tourCompletedKey) == true) {
        await prefs.setInt(_tourVersionKey, currentTourVersion);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Marks the app tour version as completed on this device so it will not pop up automatically again.
  static Future<void> markTourCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_tourVersionKey, currentTourVersion);
      await prefs.setBool(tourCompletedKey, true);
    } catch (_) {}
  }

  /// Resets the tour status so it can be tested or re-run automatically.
  static Future<void> resetTour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tourVersionKey);
      await prefs.remove(tourCompletedKey);
    } catch (_) {}
  }

  /// Launches the interactive guided tour if not already shown (or if [force] is true).
  static Future<void> maybeStartTour(
    BuildContext context, {
    bool force = false,
    VoidCallback? onComplete,
  }) async {
    if (_isTourActive) return;

    if (!force) {
      final completed = await hasCompletedTour();
      if (completed) return;
    }

    if (!context.mounted) return;

    // When the user explicitly requests to replay or start the tour, ensure
    // the app is routed to the Home screen and any active dialogs/sheets are
    // dismissed so the tour spotlight aligns with the actual Home header and tabs.
    if (force) {
      try {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
      } catch (_) {}

      try {
        context.go(AppConstants.homeRoute);
      } catch (_) {}

      // Allow Home screen and app bar to render before painting the tour overlay
      await Future.delayed(const Duration(milliseconds: 320));
      if (!context.mounted) return;
    }

    // Wait if another modal dialog (e.g. Biometric setup or OTA prompt) is currently active
    // so the App Tour and Biometric dialog never collide on screen.
    if (!force &&
        (isBiometricDialogActive || ModalRoute.of(context)?.isCurrent == false)) {
      Future.delayed(const Duration(seconds: 2), () {
        if (context.mounted) {
          maybeStartTour(context, force: force, onComplete: onComplete);
        }
      });
      return;
    }

    _isTourActive = true;
    try {
      final activeContext = rootNavigatorKey.currentContext ?? context;
      await showGeneralDialog(
        context: activeContext,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        barrierLabel: 'App Tour',
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return AppTourOverlay(
            onDismiss: () {
              markTourCompleted();
              Navigator.of(dialogContext, rootNavigator: true).pop();
              onComplete?.call();
            },
          );
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutBack,
                ),
              ),
              child: child,
            ),
          );
        },
      );
    } finally {
      _isTourActive = false;
    }
  }
}
