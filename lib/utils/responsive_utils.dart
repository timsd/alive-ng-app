import 'package:flutter/material.dart';

class ResponsiveUtils {
  static const double mobileBreakpoint = 768.0;
  static const double tabletBreakpoint = 1024.0;
  static const double desktopBreakpoint = 1200.0;

  // Check if the current screen is mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  // Check if the current screen is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < desktopBreakpoint;
  }

  // Check if the current screen is desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  // Get responsive value based on screen size
  static T getResponsiveValue<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context) && desktop != null) {
      return desktop;
    } else if (isTablet(context) && tablet != null) {
      return tablet;
    } else {
      return mobile;
    }
  }

  // Get responsive padding
  static EdgeInsets getResponsivePadding(BuildContext context) {
    return getResponsiveValue(
      context: context,
      mobile: const EdgeInsets.all(16.0),
      tablet: const EdgeInsets.all(24.0),
      desktop: const EdgeInsets.all(32.0),
    );
  }

  // Get responsive font size
  static double getResponsiveFontSize(
      BuildContext context, double baseFontSize) {
    return getResponsiveValue(
      context: context,
      mobile: baseFontSize,
      tablet: baseFontSize * 1.1,
      desktop: baseFontSize * 1.2,
    );
  }

  // Get responsive grid columns
  static int getResponsiveGridColumns(BuildContext context) {
    return getResponsiveValue(
      context: context,
      mobile: 1,
      tablet: 2,
      desktop: 3,
    );
  }

  // Get responsive card width
  static double getResponsiveCardWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return getResponsiveValue(
      context: context,
      mobile: screenWidth * 0.9,
      tablet: screenWidth * 0.7,
      desktop: screenWidth * 0.5,
    );
  }

  // Get responsive app bar height
  static double getResponsiveAppBarHeight(BuildContext context) {
    return getResponsiveValue(
      context: context,
      mobile: kToolbarHeight,
      tablet: kToolbarHeight + 8,
      desktop: kToolbarHeight + 16,
    );
  }

  // Get responsive bottom navigation height
  static double getResponsiveBottomNavHeight(BuildContext context) {
    return getResponsiveValue(
      context: context,
      mobile: 60.0,
      tablet: 70.0,
      desktop: 80.0,
    );
  }

  // Check if device is in landscape mode
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  // Check if device is in portrait mode
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  // Get safe area padding
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }

  // Get responsive margin
  static EdgeInsets getResponsiveMargin(BuildContext context) {
    return getResponsiveValue(
      context: context,
      mobile: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      tablet: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      desktop: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
    );
  }

  // Get responsive border radius
  static BorderRadius getResponsiveBorderRadius(BuildContext context) {
    return getResponsiveValue(
      context: context,
      mobile: BorderRadius.circular(8.0),
      tablet: BorderRadius.circular(12.0),
      desktop: BorderRadius.circular(16.0),
    );
  }

  // Get responsive icon size
  static double getResponsiveIconSize(BuildContext context, double baseSize) {
    return getResponsiveValue(
      context: context,
      mobile: baseSize,
      tablet: baseSize * 1.2,
      desktop: baseSize * 1.4,
    );
  }

  // Get responsive button height
  static double getResponsiveButtonHeight(BuildContext context) {
    return getResponsiveValue(
      context: context,
      mobile: 48.0,
      tablet: 52.0,
      desktop: 56.0,
    );
  }

  // Get responsive dialog width
  static double getResponsiveDialogWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return getResponsiveValue(
      context: context,
      mobile: screenWidth * 0.9,
      tablet: screenWidth * 0.6,
      desktop: screenWidth * 0.4,
    );
  }

  // Get responsive list tile height
  static double getResponsiveListTileHeight(BuildContext context) {
    return getResponsiveValue(
      context: context,
      mobile: 56.0,
      tablet: 64.0,
      desktop: 72.0,
    );
  }
}

// Extension for easier access to responsive utilities
extension ResponsiveExtension on BuildContext {
  bool get isMobile => ResponsiveUtils.isMobile(this);
  bool get isTablet => ResponsiveUtils.isTablet(this);
  bool get isDesktop => ResponsiveUtils.isDesktop(this);
  bool get isLandscape => ResponsiveUtils.isLandscape(this);
  bool get isPortrait => ResponsiveUtils.isPortrait(this);

  EdgeInsets get responsivePadding =>
      ResponsiveUtils.getResponsivePadding(this);
  EdgeInsets get responsiveMargin => ResponsiveUtils.getResponsiveMargin(this);
  BorderRadius get responsiveBorderRadius =>
      ResponsiveUtils.getResponsiveBorderRadius(this);
  EdgeInsets get safeAreaPadding => ResponsiveUtils.getSafeAreaPadding(this);

  double responsiveFontSize(double baseSize) =>
      ResponsiveUtils.getResponsiveFontSize(this, baseSize);
  double responsiveIconSize(double baseSize) =>
      ResponsiveUtils.getResponsiveIconSize(this, baseSize);

  int get responsiveGridColumns =>
      ResponsiveUtils.getResponsiveGridColumns(this);
  double get responsiveCardWidth =>
      ResponsiveUtils.getResponsiveCardWidth(this);
  double get responsiveAppBarHeight =>
      ResponsiveUtils.getResponsiveAppBarHeight(this);
  double get responsiveBottomNavHeight =>
      ResponsiveUtils.getResponsiveBottomNavHeight(this);
  double get responsiveButtonHeight =>
      ResponsiveUtils.getResponsiveButtonHeight(this);
  double get responsiveDialogWidth =>
      ResponsiveUtils.getResponsiveDialogWidth(this);
  double get responsiveListTileHeight =>
      ResponsiveUtils.getResponsiveListTileHeight(this);

  T getResponsiveValue<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) =>
      ResponsiveUtils.getResponsiveValue(
        context: this,
        mobile: mobile,
        tablet: tablet,
        desktop: desktop,
      );
}

// Responsive breakpoint widget
class ResponsiveBuilder extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveUtils.getResponsiveValue(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
}

// Responsive layout widget
class ResponsiveLayout extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? maxWidth;

  const ResponsiveLayout({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? double.infinity,
      ),
      padding: padding ?? context.responsivePadding,
      margin: margin ?? context.responsiveMargin,
      child: child,
    );
  }
}
