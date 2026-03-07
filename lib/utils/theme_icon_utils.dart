import 'package:flutter/material.dart';
import 'responsive_utils.dart';

/// Utility class for theme-aware icons that adapt to light/dark modes
class ThemeIconUtils {
  /// Get theme-aware icon color
  static Color getIconColor(BuildContext context, {
    Color? lightColor,
    Color? darkColor,
    double opacity = 1.0,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark 
        ? (darkColor ?? Colors.white)
        : (lightColor ?? Colors.black87);
    return baseColor.withValues(alpha: opacity);
  }

  /// Get adaptive icon based on theme
  static IconData getAdaptiveIcon({
    required IconData lightIcon,
    required IconData darkIcon,
    required BuildContext context,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkIcon : lightIcon;
  }

  /// Create theme-aware icon widget
  static Widget createThemeIcon({
    required BuildContext context,
    required IconData icon,
    double? size,
    Color? lightColor,
    Color? darkColor,
    double opacity = 1.0,
    String? semanticLabel,
  }) {
    final iconSize = size ?? ResponsiveUtils.getResponsiveIconSize(context, 24.0);
    final iconColor = getIconColor(
      context,
      lightColor: lightColor,
      darkColor: darkColor,
      opacity: opacity,
    );

    return Icon(
      icon,
      size: iconSize,
      color: iconColor,
      semanticLabel: semanticLabel,
    );
  }

  /// Create theme-aware icon button
  static Widget createThemeIconButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onPressed,
    double? size,
    Color? lightColor,
    Color? darkColor,
    Color? backgroundColor,
    double opacity = 1.0,
    String? tooltip,
    EdgeInsets? padding,
  }) {
    final iconSize = size ?? ResponsiveUtils.getResponsiveIconSize(context, 24.0);
    final iconColor = getIconColor(
      context,
      lightColor: lightColor,
      darkColor: darkColor,
      opacity: opacity,
    );

    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: iconSize,
        color: iconColor,
      ),
      tooltip: tooltip,
      padding: padding ?? const EdgeInsets.all(8.0),
      style: backgroundColor != null
          ? IconButton.styleFrom(
              backgroundColor: backgroundColor,
              shape: const CircleBorder(),
            )
          : null,
    );
  }

  /// Create floating action button with theme-aware icon
  static Widget createThemeFAB({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onPressed,
    Color? lightBackgroundColor,
    Color? darkBackgroundColor,
    Color? lightIconColor,
    Color? darkIconColor,
    String? tooltip,
    String? heroTag,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? (darkBackgroundColor ?? Theme.of(context).colorScheme.secondary)
        : (lightBackgroundColor ?? Theme.of(context).colorScheme.primary);
    
    final iconColor = isDark
        ? (darkIconColor ?? Colors.white)
        : (lightIconColor ?? Colors.white);

    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: backgroundColor,
      tooltip: tooltip,
      heroTag: heroTag,
      child: Icon(
        icon,
        color: iconColor,
        size: ResponsiveUtils.getResponsiveIconSize(context, 24.0),
      ),
    );
  }

  /// Get theme-aware card color
  static Color getCardColor(BuildContext context, {double elevation = 1.0}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return Theme.of(context).colorScheme.surface;
    } else {
      return Colors.white;
    }
  }

  /// Get theme-aware text color
  static Color getTextColor(BuildContext context, {
    TextColorType type = TextColorType.primary,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (type) {
      case TextColorType.primary:
        return colorScheme.onSurface;
      case TextColorType.secondary:
        return colorScheme.onSurface.withValues(alpha: 0.7);
      case TextColorType.disabled:
        return colorScheme.onSurface.withValues(alpha: 0.38);
      case TextColorType.error:
        return colorScheme.error;
      case TextColorType.success:
        return Colors.green;
      case TextColorType.warning:
        return Colors.orange;
    }
  }

  /// Get theme-aware border color
  static Color getBorderColor(BuildContext context, {double opacity = 0.12}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? Colors.white.withValues(alpha: opacity)
        : Colors.black.withValues(alpha: opacity);
  }

  /// Get theme-aware shadow color
  static Color getShadowColor(BuildContext context, {double opacity = 0.1}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? Colors.black.withValues(alpha: opacity * 2)
        : Colors.black.withValues(alpha: opacity);
  }

  /// Create theme-aware container
  static Widget createThemeContainer({
    required BuildContext context,
    required Widget child,
    Color? lightBackgroundColor,
    Color? darkBackgroundColor,
    double? elevation,
    BorderRadius? borderRadius,
    EdgeInsets? padding,
    EdgeInsets? margin,
    Border? border,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? (darkBackgroundColor ?? Theme.of(context).colorScheme.surface)
        : (lightBackgroundColor ?? Colors.white);

    return Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius ?? BorderRadius.circular(ResponsiveUtils.getResponsiveBorderRadiusValue(context, 8)),
        border: border,
        boxShadow: elevation != null
            ? [
                BoxShadow(
                  color: getShadowColor(context),
                  blurRadius: elevation * 2,
                  offset: Offset(0, elevation),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }

  /// Create theme-aware divider
  static Widget createThemeDivider(BuildContext context, {
    double? height,
    double? thickness,
    double? indent,
    double? endIndent,
  }) {
    return Divider(
      height: height,
      thickness: thickness ?? 1.0,
      indent: indent,
      endIndent: endIndent,
      color: getBorderColor(context),
    );
  }

  /// Get theme-aware app bar colors
  static AppBarTheme getAppBarTheme(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    
    return AppBarTheme(
      backgroundColor: isDark ? colorScheme.surface : colorScheme.primary,
      foregroundColor: isDark ? colorScheme.onSurface : colorScheme.onPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: isDark ? colorScheme.onSurface : colorScheme.onPrimary,
        fontSize: ResponsiveUtils.getResponsiveFontSize(context, 20.0),
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(
        color: isDark ? colorScheme.onSurface : colorScheme.onPrimary,
        size: ResponsiveUtils.getResponsiveIconSize(context, 24.0),
      ),
    );
  }

  /// Create theme-aware chip
  static Widget createThemeChip({
    required BuildContext context,
    required String label,
    IconData? icon,
    VoidCallback? onTap,
    bool selected = false,
    Color? selectedColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected
              ? (isDark ? Colors.black : Colors.white)
              : getTextColor(context),
          fontSize: ResponsiveUtils.getResponsiveFontSize(context, 14.0),
        ),
      ),
      avatar: icon != null
          ? Icon(
              icon,
              size: ResponsiveUtils.getResponsiveIconSize(context, 18.0),
              color: selected
                  ? (isDark ? Colors.black : Colors.white)
                  : getIconColor(context),
            )
          : null,
      selected: selected,
      onSelected: onTap != null ? (_) => onTap() : null,
      backgroundColor: isDark ? colorScheme.surface : Colors.grey[100],
      selectedColor: selectedColor ?? colorScheme.primary,
      checkmarkColor: isDark ? Colors.black : Colors.white,
      side: BorderSide(
        color: getBorderColor(context),
        width: 1.0,
      ),
    );
  }
}

/// Text color types for theme-aware text
enum TextColorType {
  primary,
  secondary,
  disabled,
  error,
  success,
  warning,
}
