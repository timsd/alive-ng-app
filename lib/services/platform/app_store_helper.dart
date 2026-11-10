import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Helper for redirecting users directly to the official ALIVE Nigeria app on Google Play Store
/// whenever an activity or feature requires the native mobile app.
class AppStoreHelper {
  static const String androidPackageName = 'com.alive.alivengandroidapp';
  static const String playStoreWebUrl =
      'https://play.google.com/store/apps/details?id=$androidPackageName';
  static const String playStoreMarketUri =
      'market://details?id=$androidPackageName';

  /// Launches Google Play Store directly.
  /// On Android native devices, opens the Play Store app.
  /// On Web, iOS, or other platforms, opens the Play Store web page in a new window/tab.
  static Future<bool> openPlayStore() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final marketUri = Uri.parse(playStoreMarketUri);
        if (await canLaunchUrl(marketUri)) {
          final launched = await launchUrl(marketUri, mode: LaunchMode.externalApplication);
          if (launched) return true;
        }
      }

      final webUri = Uri.parse(playStoreWebUrl);
      return await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } catch (e) {
      debugPrint('[AppStoreHelper] Error launching Play Store: $e');
      try {
        final fallbackUri = Uri.parse(playStoreWebUrl);
        return await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        return false;
      }
    }
  }

  /// Automatically redirects the user directly to the Google Play Store
  /// for activities that are only compatible with the mobile app.
  static Future<bool> redirectToPlayStore() async {
    return await openPlayStore();
  }

  /// Determines whether an error or notice indicates a mobile-only / web-restricted feature.
  static bool isMobileOnlyNotice(dynamic messageOrError) {
    if (messageOrError == null) return false;
    final lower = messageOrError.toString().toLowerCase();
    return lower.contains('screen sharing on mobile') ||
        lower.contains('installed alive mobile app') ||
        lower.contains('play store') ||
        lower.contains('playstore') ||
        lower.contains('biometric sign-in') ||
        lower.contains('only compatible on mobile') ||
        lower.contains('available on mobile') ||
        lower.contains('use the installed alive') ||
        lower.contains('download the app') ||
        lower.contains('getdisplaymedia');
  }
}
