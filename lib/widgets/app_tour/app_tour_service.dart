import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_tour_overlay.dart';

class AppTourService {
  static const String tourCompletedKey = 'app_feature_tour_v2_completed';
  static bool _isTourActive = false;

  /// Returns true if the user has already viewed or dismissed the app tour.
  static Future<bool> hasCompletedTour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(tourCompletedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Marks the app tour as completed so it won't pop up automatically again.
  static Future<void> markTourCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(tourCompletedKey, true);
    } catch (_) {}
  }

  /// Resets the tour status so it can be re-run manually.
  static Future<void> resetTour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
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

    _isTourActive = true;
    try {
      await showGeneralDialog(
        context: context,
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
