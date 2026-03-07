import 'package:flutter/material.dart';

/// Utility class to help prevent and fix common Flutter layout overflow issues
class LayoutFixUtils {
  
  /// Wraps a widget with SingleChildScrollView to prevent overflow
  static Widget preventOverflow({
    required Widget child,
    Axis scrollDirection = Axis.vertical,
    EdgeInsetsGeometry? padding,
    ScrollPhysics? physics,
  }) {
    return SingleChildScrollView(
      scrollDirection: scrollDirection,
      padding: padding,
      physics: physics ?? const ClampingScrollPhysics(),
      child: child,
    );
  }

  /// Creates a safe Column that prevents overflow by wrapping in SingleChildScrollView
  static Widget safeColumn({
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    MainAxisSize mainAxisSize = MainAxisSize.max,
    EdgeInsetsGeometry? padding,
    ScrollPhysics? physics,
  }) {
    return SingleChildScrollView(
      padding: padding,
      physics: physics ?? const ClampingScrollPhysics(),
      child: Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: children,
      ),
    );
  }

  /// Creates a safe Row that prevents overflow by using Flexible/Expanded widgets
  static Widget safeRow({
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    MainAxisSize mainAxisSize = MainAxisSize.max,
  }) {
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: children.map((child) {
        // Wrap each child in Flexible to prevent overflow
        return Flexible(child: child);
      }).toList(),
    );
  }

  /// Creates a text widget that handles overflow gracefully
  static Widget safeText(
    String text, {
    TextStyle? style,
    int? maxLines,
    TextOverflow overflow = TextOverflow.ellipsis,
    TextAlign textAlign = TextAlign.start,
  }) {
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }

  /// Wraps a widget with Expanded to fill available space
  static Widget expanded({
    required Widget child,
    int flex = 1,
  }) {
    return Expanded(
      flex: flex,
      child: child,
    );
  }

  /// Wraps a widget with Flexible to allow it to shrink
  static Widget flexible({
    required Widget child,
    int flex = 1,
    FlexFit fit = FlexFit.loose,
  }) {
    return Flexible(
      flex: flex,
      fit: fit,
      child: child,
    );
  }

  /// Creates a constrained container to prevent unbounded height/width
  static Widget constrainedContainer({
    required Widget child,
    double? maxWidth,
    double? maxHeight,
    double? minWidth,
    double? minHeight,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Decoration? decoration,
  }) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? double.infinity,
        maxHeight: maxHeight ?? double.infinity,
        minWidth: minWidth ?? 0,
        minHeight: minHeight ?? 0,
      ),
      padding: padding,
      margin: margin,
      decoration: decoration,
      child: child,
    );
  }

  /// Creates a responsive grid that adapts to screen size
  static Widget responsiveGrid({
    required List<Widget> children,
    required int crossAxisCount,
    double crossAxisSpacing = 8.0,
    double mainAxisSpacing = 8.0,
    EdgeInsetsGeometry? padding,
    bool shrinkWrap = true,
    ScrollPhysics? physics,
  }) {
    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics ?? const NeverScrollableScrollPhysics(),
      children: children,
    );
  }

  /// Creates a wrap widget that handles overflow by wrapping to next line
  static Widget safeWrap({
    required List<Widget> children,
    Axis direction = Axis.horizontal,
    WrapAlignment alignment = WrapAlignment.start,
    double spacing = 0.0,
    WrapAlignment runAlignment = WrapAlignment.start,
    double runSpacing = 0.0,
    WrapCrossAlignment crossAxisAlignment = WrapCrossAlignment.start,
  }) {
    return Wrap(
      direction: direction,
      alignment: alignment,
      spacing: spacing,
      runAlignment: runAlignment,
      runSpacing: runSpacing,
      crossAxisAlignment: crossAxisAlignment,
      children: children,
    );
  }

  /// Creates a list view that handles dynamic content safely
  static Widget safeListView({
    required List<Widget> children,
    bool shrinkWrap = true,
    ScrollPhysics? physics,
    EdgeInsetsGeometry? padding,
    Axis scrollDirection = Axis.vertical,
  }) {
    return ListView(
      shrinkWrap: shrinkWrap,
      physics: physics ?? const ClampingScrollPhysics(),
      padding: padding,
      scrollDirection: scrollDirection,
      children: children,
    );
  }

  /// Fixes common bottom overflow issues in dialogs and bottom sheets
  static Widget fixBottomOverflow({
    required Widget child,
    EdgeInsetsGeometry? padding,
    double? maxHeight,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxHeight ?? 600,
      ),
      child: SingleChildScrollView(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  /// Creates a safe card widget that prevents content overflow
  static Widget safeCard({
    required Widget child,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
    Color? color,
    double? elevation,
    ShapeBorder? shape,
  }) {
    return Card(
      margin: margin,
      color: color,
      elevation: elevation,
      shape: shape,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  /// Debugging helper to identify overflow issues
  static Widget debugOverflow({
    required Widget child,
    Color? color,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: color ?? Colors.red,
          width: 2,
        ),
      ),
      child: child,
    );
  }

  /// Creates a safe container that prevents content overflow with proper constraints
  static Widget safeContainer({
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? color,
    Decoration? decoration,
    double? width,
    double? height,
    BoxConstraints? constraints,
  }) {
    return Container(
      padding: padding,
      margin: margin,
      color: color,
      decoration: decoration,
      constraints: constraints ?? const BoxConstraints(
        maxWidth: double.infinity,
      ),
      width: width,
      height: height,
      child: child,
    );
  }

  /// Creates a safe GridView that prevents overflow
  static Widget safeGridView({
    required List<Widget> children,
    required SliverGridDelegate gridDelegate,
    ScrollPhysics? physics,
    EdgeInsetsGeometry? padding,
    bool shrinkWrap = true,
  }) {
    return GridView(
      physics: physics ?? const ClampingScrollPhysics(),
      padding: padding,
      shrinkWrap: shrinkWrap,
      gridDelegate: gridDelegate,
      children: children,
    );
  }

  /// Creates a safe dialog content that prevents overflow
  static Widget safeDialogContent({
    required Widget child,
    double? maxHeight,
    double? maxWidth,
    EdgeInsetsGeometry? padding,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxHeight ?? MediaQuery.of(child as BuildContext).size.height * 0.8,
        maxWidth: maxWidth ?? MediaQuery.of(child as BuildContext).size.width * 0.9,
      ),
      child: SingleChildScrollView(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  /// Creates a safe bottom sheet content that prevents overflow
  static Widget safeBottomSheetContent({
    required Widget child,
    double? maxHeight,
    EdgeInsetsGeometry? padding,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxHeight ?? 600,
      ),
      child: SingleChildScrollView(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  /// Creates a safe form field that handles overflow in labels and hints
  static Widget safeFormField({
    required Widget child,
    String? label,
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: safeText(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        child,
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: safeText(
              hint,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  /// Creates a responsive layout that adapts to screen size
  static Widget responsiveLayout({
    required BuildContext context,
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth >= 1200 && desktop != null) {
      return desktop;
    } else if (screenWidth >= 768 && tablet != null) {
      return tablet;
    } else {
      return mobile;
    }
  }

  /// Creates a safe app bar that handles overflow in titles and actions
  static PreferredSizeWidget safeAppBar({
    required BuildContext context,
    Widget? title,
    List<Widget>? actions,
    Widget? leading,
    Color? backgroundColor,
    Color? foregroundColor,
    double? elevation,
    bool automaticallyImplyLeading = true,
  }) {
    return AppBar(
      title: title != null 
          ? flexible(child: title)
          : null,
      actions: actions?.map((action) => flexible(child: action)).toList(),
      leading: leading,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: elevation,
      automaticallyImplyLeading: automaticallyImplyLeading,
    );
  }

  /// Gets responsive icon size based on screen size
  static double getResponsiveIconSize(BuildContext context, {double baseSize = 24.0}) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth < 360) {
      // Very small screens (old phones)
      return baseSize * 0.8;
    } else if (screenWidth < 600) {
      // Mobile phones
      return baseSize;
    } else if (screenWidth < 900) {
      // Tablets
      return baseSize * 1.2;
    } else {
      // Desktop/large screens
      return baseSize * 1.4;
    }
  }

  /// Gets responsive font size based on screen size
  static double getResponsiveFontSize(BuildContext context, {double baseSize = 14.0}) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth < 360) {
      // Very small screens (old phones)
      return baseSize * 0.9;
    } else if (screenWidth < 600) {
      // Mobile phones
      return baseSize;
    } else if (screenWidth < 900) {
      // Tablets
      return baseSize * 1.1;
    } else {
      // Desktop/large screens
      return baseSize * 1.2;
    }
  }

  /// Creates a responsive icon that adapts to screen size
  static Widget responsiveIcon(
    IconData? iconData, {
    required BuildContext context,
    double baseSize = 24.0,
    Color? color,
    String? semanticLabel,
    TextDirection? textDirection,
  }) {
    if (iconData == null) {
      return SizedBox(
        width: getResponsiveIconSize(context, baseSize: baseSize),
        height: getResponsiveIconSize(context, baseSize: baseSize),
      );
    }
    return Icon(
      iconData,
      size: getResponsiveIconSize(context, baseSize: baseSize),
      color: color,
      semanticLabel: semanticLabel,
      textDirection: textDirection,
    );
  }

  /// Creates a responsive text widget that adapts to screen size
  static Widget responsiveText(
    String text, {
    required BuildContext context,
    double baseFontSize = 14.0,
    TextStyle? style,
    int? maxLines,
    TextOverflow overflow = TextOverflow.ellipsis,
    TextAlign textAlign = TextAlign.start,
    FontWeight? fontWeight,
    Color? color,
  }) {
    final responsiveFontSize = getResponsiveFontSize(context, baseSize: baseFontSize);
    
    return Text(
      text,
      style: (style ?? const TextStyle()).copyWith(
        fontSize: responsiveFontSize,
        fontWeight: fontWeight,
        color: color,
      ),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }

  /// Creates a responsive text style that adapts to screen size
  static TextStyle responsiveTextStyle(
    BuildContext context, {
    double baseFontSize = 14.0,
    FontWeight? fontWeight,
    Color? color,
    TextDecoration? decoration,
    double? letterSpacing,
    double? wordSpacing,
    double? height,
  }) {
    return TextStyle(
      fontSize: getResponsiveFontSize(context, baseSize: baseFontSize),
      fontWeight: fontWeight,
      color: color,
      decoration: decoration,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      height: height,
    );
  }

  /// Creates responsive padding based on screen size
  static EdgeInsetsGeometry getResponsivePadding(BuildContext context, {double basePadding = 16.0}) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth < 360) {
      return EdgeInsets.all(basePadding * 0.75);
    } else if (screenWidth < 600) {
      return EdgeInsets.all(basePadding);
    } else if (screenWidth < 900) {
      return EdgeInsets.all(basePadding * 1.25);
    } else {
      return EdgeInsets.all(basePadding * 1.5);
    }
  }

  /// Creates responsive margin based on screen size
  static EdgeInsetsGeometry getResponsiveMargin(BuildContext context, {double baseMargin = 8.0}) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth < 360) {
      return EdgeInsets.all(baseMargin * 0.75);
    } else if (screenWidth < 600) {
      return EdgeInsets.all(baseMargin);
    } else if (screenWidth < 900) {
      return EdgeInsets.all(baseMargin * 1.25);
    } else {
      return EdgeInsets.all(baseMargin * 1.5);
    }
  }
}
