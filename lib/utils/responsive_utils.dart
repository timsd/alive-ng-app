import 'package:flutter/material.dart';


/// Screen type enumeration
enum ScreenType {
  mobile,
  tablet,
  desktop,
}

class ResponsiveUtils {
  static const double mobileBreakpoint = 768.0;
  static const double tabletBreakpoint = 1024.0;
  static const double desktopBreakpoint = 1200.0;

  // Add screen type helper for APIs that depend on discrete categories
  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return ScreenType.mobile;
    } else if (width < tabletBreakpoint) {
      return ScreenType.tablet;
    } else {
      return ScreenType.desktop;
    }
  }

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
  // Generic responsive value helper for any type
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

  // Provide a double-only variant for radius values to support call sites that use BorderRadius.circular(value)
  static double getResponsiveRadiusValue(
    BuildContext context,
    double baseRadius, {
    double? mobileRadius,
    double? tabletRadius,
    double? desktopRadius,
  }) {
    return getResponsiveValue<double>(
      context: context,
      mobile: mobileRadius ?? baseRadius,
      tablet: tabletRadius ?? (baseRadius * 1.1),
      desktop: desktopRadius ?? (baseRadius * 1.2),
    );
  }

  // Get responsive border radius value (double)
  static double getResponsiveBorderRadiusValue(BuildContext context, double baseRadius) {
    return getResponsiveValue(
      context: context,
      mobile: baseRadius,
      tablet: baseRadius * 1.2,
      desktop: baseRadius * 1.5,
    );
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

  // Get responsive padding with a custom base value
  static EdgeInsets getResponsivePaddingWithBase(
      BuildContext context, double base) {
    return EdgeInsets.all(
      getResponsiveValue<double>(
        context: context,
        mobile: base,
        tablet: base * 1.5,
        desktop: base * 2.0,
      ),
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
      mobile: 2,
      tablet: 3,
      desktop: 4,
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

  // Get responsive icon size
  static double getResponsiveIconSize(BuildContext context, double baseSize) {
    return getResponsiveValue(
      context: context,
      mobile: baseSize,
      tablet: baseSize * 1.2,
      desktop: baseSize * 1.5,
    );
  }

  // Get responsive spacing based on screen size
  static double getResponsiveSpacing(
    BuildContext context,
    double baseSpacing, {
    double? mobileSpacing,
    double? tabletSpacing,
    double? desktopSpacing,
  }) {
    return getResponsiveValue<double>(
      context: context,
      mobile: mobileSpacing ?? baseSpacing,
      tablet: tabletSpacing ?? (baseSpacing * 1.2),
      desktop: desktopSpacing ?? (baseSpacing * 1.5),
    );
  }

  // Get responsive horizontal padding based on screen size
  static EdgeInsets getResponsiveHorizontalPadding(BuildContext context) {
    return getResponsiveValue<EdgeInsets>(
      context: context,
      mobile: const EdgeInsets.symmetric(horizontal: 16.0),
      tablet: const EdgeInsets.symmetric(horizontal: 24.0),
      desktop: const EdgeInsets.symmetric(horizontal: 32.0),
    );
  }

  // Get responsive padding value as double
  static double getResponsivePaddingValue(BuildContext context) {
    return getResponsiveValue<double>(
      context: context,
      mobile: 16.0,
      tablet: 24.0,
      desktop: 32.0,
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




