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
  static EdgeInsets getResponsivePadding(BuildContext context, [double? basePadding, bool vertical = false]) {
    double padding;
    if (basePadding != null) {
      if (isMobileScreen(context)) {
        padding = basePadding;
      } else if (isTabletScreen(context)) {
        padding = basePadding * 1.2;
      } else {
        padding = basePadding * 1.4;
      }
    } else {
      if (isMobileScreen(context)) {
        padding = 16.0;
      } else if (isTabletScreen(context)) {
        padding = 24.0;
      } else {
        padding = 32.0;
      }
    }
    
    if (vertical) {
      return EdgeInsets.symmetric(vertical: padding);
    } else {
      return EdgeInsets.all(padding);
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
    BuildContext context, 
    double baseWidth, {
    double? mobileWidth,
    double? tabletWidth,
    double? desktopWidth,
  }) {
    if (isMobileScreen(context)) {
      return mobileWidth ?? baseWidth;
    } else if (isTabletScreen(context)) {
      return tabletWidth ?? (baseWidth * 1.2);
    } else {
      return desktopWidth ?? (baseWidth * 1.4);
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

  /// Get responsive border radius based on screen size
  static double getResponsiveBorderRadius(
    BuildContext context,
    double baseBorderRadius, {
    double? mobileBorderRadius,
    double? tabletBorderRadius,
    double? desktopBorderRadius,
  }) {
    if (isMobileScreen(context)) {
      return mobileBorderRadius ?? baseBorderRadius;
    } else if (isTabletScreen(context)) {
      return tabletBorderRadius ?? (baseBorderRadius * 1.1);
    } else {
      return desktopBorderRadius ?? (baseBorderRadius * 1.2);
    }
  }

  /// Get responsive icon size based on screen size
  static double getResponsiveIconSize(BuildContext context, double baseSize) {
    if (isMobileScreen(context)) {
      return baseSize;
    } else if (isTabletScreen(context)) {
      return baseSize * 1.2;
    } else {
      return baseSize * 1.4;
    }
  }

  /// Get responsive spacing based on screen size
  static double getResponsiveSpacing(
    BuildContext context,
    double baseSpacing, {
    double? mobileSpacing,
    double? tabletSpacing,
    double? desktopSpacing,
  }) {
    if (isMobileScreen(context)) {
      return mobileSpacing ?? baseSpacing;
    } else if (isTabletScreen(context)) {
      return tabletSpacing ?? (baseSpacing * 1.2);
    } else {
      return desktopSpacing ?? (baseSpacing * 1.5);
    }
  }

  /// Get responsive height based on screen size
  static double getResponsiveHeight(BuildContext context, double baseHeight) {
    if (isMobileScreen(context)) {
      return baseHeight;
    } else if (isTabletScreen(context)) {
      return baseHeight * 1.2;
    } else {
      return baseHeight * 1.4;
    }
  }

  /// Get responsive horizontal padding based on screen size
  static EdgeInsets getResponsiveHorizontalPadding(BuildContext context) {
    if (isMobileScreen(context)) {
      return const EdgeInsets.symmetric(horizontal: 16.0);
    } else if (isTabletScreen(context)) {
      return const EdgeInsets.symmetric(horizontal: 24.0);
    } else {
      return const EdgeInsets.symmetric(horizontal: 32.0);
    }
  }

  /// Get responsive padding value as double
  static double getResponsivePaddingValue(BuildContext context) {
    if (isMobileScreen(context)) {
      return 16.0;
    } else if (isTabletScreen(context)) {
      return 24.0;
    } else {
      return 32.0;
    }
  }
}




