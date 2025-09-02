import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class MobileUtils {
  /// Check if the current platform is mobile (iOS or Android)
  static bool get isMobile {
    if (kIsWeb) {
      return false;
    }
    return Platform.isIOS || Platform.isAndroid;
  }

  /// Check if the current platform is iOS
  static bool get isIOS {
    if (kIsWeb) {
      return false;
    }
    return Platform.isIOS;
  }

  /// Check if the current platform is Android
  static bool get isAndroid {
    if (kIsWeb) {
      return false;
    }
    return Platform.isAndroid;
  }

  /// Check if the current platform is web
  static bool get isWeb => kIsWeb;

  /// Check if the current platform is desktop (Windows, macOS, Linux)
  static bool get isDesktop {
    if (kIsWeb) {
      return false;
    }
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// Get the current platform name
  static String get platformName {
    if (kIsWeb) {
      return 'Web';
    }
    if (Platform.isIOS) {
      return 'iOS';
    }
    if (Platform.isAndroid) {
      return 'Android';
    }
    if (Platform.isWindows) {
      return 'Windows';
    }
    if (Platform.isMacOS) {
      return 'macOS';
    }
    if (Platform.isLinux) {
      return 'Linux';
    }
    return 'Unknown';
  }

  /// Check if the screen size is considered mobile-sized
  static bool isMobileScreen(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth < 768; // Breakpoint for mobile screens
  }

  /// Check if the screen size is considered tablet-sized
  static bool isTabletScreen(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth >= 768 && screenWidth < 1024;
  }

  /// Check if the screen size is considered desktop-sized
  static bool isDesktopScreen(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth >= 1024;
  }

  /// Get responsive padding based on screen size
  static EdgeInsets getResponsivePadding(BuildContext context) {
    if (isMobileScreen(context)) {
      return const EdgeInsets.all(16.0);
    } else if (isTabletScreen(context)) {
      return const EdgeInsets.all(24.0);
    } else {
      return const EdgeInsets.all(32.0);
    }
  }

  /// Get responsive font size based on screen size
  static double getResponsiveFontSize(
      BuildContext context, double baseFontSize) {
    if (isMobileScreen(context)) {
      return baseFontSize;
    } else if (isTabletScreen(context)) {
      return baseFontSize * 1.1;
    } else {
      return baseFontSize * 1.2;
    }
  }

  /// Get the number of columns for a grid based on screen size
  static int getGridColumns(
    BuildContext context, {
    int mobileColumns = 1,
    int tabletColumns = 2,
    int desktopColumns = 3,
  }) {
    if (isMobileScreen(context)) {
      return mobileColumns;
    } else if (isTabletScreen(context)) {
      return tabletColumns;
    } else {
      return desktopColumns;
    }
  }

  /// Get responsive width based on screen size
  static double getResponsiveWidth(
    BuildContext context, {
    double mobileWidth = 1.0,
    double tabletWidth = 0.8,
    double desktopWidth = 0.6,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (isMobileScreen(context)) {
      return screenWidth * mobileWidth;
    } else if (isTabletScreen(context)) {
      return screenWidth * tabletWidth;
    } else {
      return screenWidth * desktopWidth;
    }
  }

  /// Check if the device has a notch or safe area
  static bool hasNotch(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    return padding.top > 24; // Typical status bar height
  }

  /// Get safe area padding
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }

  /// Get the device orientation
  static Orientation getOrientation(BuildContext context) {
    return MediaQuery.of(context).orientation;
  }

  /// Check if the device is in landscape mode
  static bool isLandscape(BuildContext context) {
    return getOrientation(context) == Orientation.landscape;
  }

  /// Check if the device is in portrait mode
  static bool isPortrait(BuildContext context) {
    return getOrientation(context) == Orientation.portrait;
  }
}
