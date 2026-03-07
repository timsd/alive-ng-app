import 'package:flutter/material.dart';

/// Utility class for color operations
class ColorUtils {
  /// Creates a color with the specified opacity
  /// Uses Color.withValues(alpha: ...) to avoid precision loss
  static Color withOpacity(Color color, double opacity) {
    final alpha = (opacity * 255).clamp(0, 255).round();
    return color.withValues(alpha: alpha / 255.0);
  }

  /// Creates a color with alpha value (0-255)
  static Color withAlpha(Color color, int alpha) {
    return color.withValues(alpha: alpha / 255.0);
  }

  /// Converts opacity (0.0-1.0) to alpha (0-255)
  static int opacityToAlpha(double opacity) {
    return (opacity * 255).round().clamp(0, 255);
  }

  /// Converts alpha (0-255) to opacity (0.0-1.0)
  static double alphaToOpacity(int alpha) {
    return (alpha / 255.0).clamp(0.0, 1.0);
  }

  /// Creates a semi-transparent version of a color
  static Color transparent(Color color, [double opacity = 0.5]) {
    return color.withValues(alpha: opacity);
  }

  /// Creates a lighter version of a color
  static Color lighten(Color color, [double amount = 0.1]) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  /// Creates a darker version of a color
  static Color darken(Color color, [double amount = 0.1]) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }
}
