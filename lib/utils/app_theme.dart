import 'package:flutter/material.dart';

/// ALIVE-NG Design System - Spiritual, warm colors reflecting faith and Nigerian culture
class AppTheme {
  // Legacy color getters for backward compatibility
  static const Color primaryColor = lightPrimary;
  static const Color primaryVariant = lightPrimaryGlow;
  static const Color secondaryColor = lightEmerald;
  static const Color secondaryVariant = Color(0xFF059669);
  static const Color backgroundColor = lightBackground;
  static const Color surfaceColor = lightCard;
  static const Color errorColor = lightDestructive;
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color successColor = lightEmerald;
  
  // Dark Theme Colors
  static const Color darkBackgroundColor = darkBackground;
  static const Color darkSurfaceColor = darkCard;
  static const Color darkOnSurfaceColor = darkCardForeground;
  
  // Text Colors
  static const Color textPrimary = lightForeground;
  static const Color textSecondary = lightMutedForeground;
  static const Color textTertiary = Color(0xFF94A3B8);
  
  // Dark Text Colors
  static const Color darkTextPrimary = darkForeground;
  static const Color darkTextSecondary = darkMutedForeground;
  static const Color darkTextTertiary = Color(0xFF94A3B8);
  
  // Border Colors
  static const Color borderColor = lightBorder;
  static const Color darkBorderColor = darkBorder;
  
  // Core spiritual palette - Light Theme
  static const Color lightBackground = Color(0xFFF8FAFC); // Crisp, cool white
  static const Color lightForeground = Color(0xFF0F172A); // Deep slate black
  
  static const Color lightCard = Color(0xFFFFFFFF); // Pure white
  static const Color lightCardForeground = Color(0xFF0F172A); 
  
  // Primary - Deep spiritual blue
  static const Color lightPrimary = Color(0xFFF8FAFC); // Crisp, cool white (Requested)
  static const Color lightPrimaryForeground = Color(0xFF0F172A); // Deep slate black for contrast
  static const Color lightPrimaryGlow = Color(0xFFE2E8F0); 
  
  // Secondary - Warm divine gold
  static const Color lightSecondary = Color(0xFFFEF08A); 
  static const Color lightSecondaryForeground = Color(0xFF1E3A8A); 
  static const Color lightGold = Color(0xFFEAB308); // Brilliant gold
  static const Color lightGoldForeground = Color(0xFFFFFFFF); 
  
  // Accent - Life/growth green
  static const Color lightAccent = Color(0xFFDCFCE7); 
  static const Color lightAccentForeground = Color(0xFF14532D); 
  static const Color lightEmerald = Color(0xFF10B981); // Vibrant emerald
  static const Color lightEmeraldForeground = Color(0xFFFFFFFF); 
  
  static const Color lightMuted = Color(0xFFF1F5F9); 
  static const Color lightMutedForeground = Color(0xFF64748B); // Slate 500
  
  static const Color lightDestructive = Color(0xFFEF4444); 
  static const Color lightDestructiveForeground = Color(0xFFFFFFFF); 
  
  static const Color lightBorder = Color(0xFFE2E8F0); 
  static const Color lightInput = Color(0xFFE2E8F0); 
  static const Color lightRing = Color(0xFF1E3A8A); 
  
  // Dark mode - peaceful night theme (High contrast, OLED friendly)
  static const Color darkBackground = Color(0xFF0B0F19); // Rich, deep OLED blue-black
  static const Color darkForeground = Color(0xFFF8FAFC); // Brilliant white
  
  static const Color darkCard = Color(0xFF151D2F); // Elevated dark surface
  static const Color darkCardForeground = Color(0xFFF8FAFC); 
  
  static const Color darkPrimary = Color(0xFF151D2F); // Elevated dark surface (Requested)
  static const Color darkPrimaryForeground = Color(0xFFF8FAFC); // Brilliant white for contrast
  static const Color darkPrimaryGlow = Color(0xFF1E293B); 
  
  static const Color darkSecondary = Color(0xFF1E293B); 
  static const Color darkSecondaryForeground = Color(0xFFF1F5F9); 
  static const Color darkGold = Color(0xFFFDE047); // Brilliant gold
  static const Color darkGoldForeground = Color(0xFF0B0F19); 
  
  static const Color darkAccent = Color(0xFF1E293B); 
  static const Color darkAccentForeground = Color(0xFFF8FAFC); 
  static const Color darkEmerald = Color(0xFF10B981); 
  static const Color darkEmeraldForeground = Color(0xFFFFFFFF); 
  
  static const Color darkMuted = Color(0xFF1E293B); // Slate 800
  static const Color darkMutedForeground = Color(0xFF94A3B8); // Brilliant slate 400
  
  static const Color darkDestructive = Color(0xFFEF4444); 
  static const Color darkDestructiveForeground = Color(0xFFFFFFFF); 
  
  static const Color darkBorder = Color(0xFF334155); // Sharper borders
  static const Color darkInput = Color(0xFF1E293B); 
  static const Color darkRing = Color(0xFFFDE047); 
  
  // Spiritual gradients
  static const LinearGradient gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lightPrimary, lightPrimaryGlow],
  );
  
  static const LinearGradient gradientDivine = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lightGold, Color(0xFFF0C814)], // Enhanced gold
  );
  
  static const LinearGradient gradientPeaceful = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [lightBackground, Color(0xFFF5F1E8)],
  );
  
  static const LinearGradient gradientGrowth = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lightEmerald, Color(0xFF4FD1C7)],
  );
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      
      // Color Scheme
      colorScheme: const ColorScheme.light(
        brightness: Brightness.light,
        primary: lightPrimary,
        onPrimary: lightPrimaryForeground,
        primaryContainer: Color(0xFF4A5568),
        onPrimaryContainer: lightPrimaryForeground,
        secondary: lightGold,
        onSecondary: lightGoldForeground,
        secondaryContainer: lightSecondary,
        onSecondaryContainer: lightSecondaryForeground,
        tertiary: lightEmerald,
        onTertiary: lightEmeraldForeground,
        tertiaryContainer: lightAccent,
        onTertiaryContainer: lightAccentForeground,
        error: lightDestructive,
        onError: lightDestructiveForeground,
        errorContainer: Color(0xFFFFEBEE),
        onErrorContainer: Color(0xFFB71C1C),
        surface: lightCard,
        onSurface: lightCardForeground,
        surfaceContainerHighest: lightMuted,
        onSurfaceVariant: lightMutedForeground,
        outline: lightBorder,
        outlineVariant: Color(0xFFE8DDD1),
        shadow: Color(0xFF000000),
        scrim: Color(0xFF000000),
        inverseSurface: darkCard,
        onInverseSurface: darkCardForeground,
        inversePrimary: darkPrimary,
        surfaceTint: lightPrimary,
      ),
      
      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: lightCard,
        foregroundColor: lightCardForeground,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: lightCardForeground,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(
          color: lightCardForeground,
        ),
      ),
      
      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightCard,
        selectedItemColor: lightPrimary,
        unselectedItemColor: lightMutedForeground,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 2,
        shadowColor: lightPrimary.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(8),
      ),
      
      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: lightPrimaryForeground,
          elevation: 2,
          shadowColor: lightPrimary.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lightPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      
      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightPrimary,
          side: const BorderSide(color: lightBorder, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightDestructive, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightDestructive, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(
          color: lightMutedForeground,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          color: lightMutedForeground,
          fontWeight: FontWeight.w500,
        ),
      ),
      
      
      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: lightSecondary,
        labelStyle: const TextStyle(
          color: lightSecondaryForeground,
          fontWeight: FontWeight.w500,
        ),
        side: const BorderSide(color: lightBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      
      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 1,
        space: 1,
      ),
      
      fontFamily: 'Inter',

      // Standard Text Hierarchy — visible in light mode (dark text on light bg)
      textTheme: const TextTheme(
        // Display — hero banners & splash screens
        displayLarge:   TextStyle(fontSize: 57, fontWeight: FontWeight.w700, letterSpacing: -0.25, color: lightCardForeground),
        displayMedium:  TextStyle(fontSize: 45, fontWeight: FontWeight.w700, color: lightCardForeground),
        displaySmall:   TextStyle(fontSize: 36, fontWeight: FontWeight.w600, color: lightCardForeground),
        // Headline — screen/section titles
        headlineLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: lightCardForeground),
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: lightCardForeground),
        headlineSmall:  TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: lightCardForeground),
        // Title — card headers, dialog titles
        titleLarge:     TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: lightCardForeground),
        titleMedium:    TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.15, color: lightCardForeground),
        titleSmall:     TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1, color: lightCardForeground),
        // Body — main content
        bodyLarge:      TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5, height: 1.5, color: lightCardForeground),
        bodyMedium:     TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25, height: 1.4, color: lightCardForeground),
        bodySmall:      TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4, height: 1.4, color: lightMutedForeground),
        // Label — buttons, chips, tabs, captions
        labelLarge:     TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: lightCardForeground),
        labelMedium:    TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5, color: lightMutedForeground),
        labelSmall:     TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5, color: lightMutedForeground),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      
      // Color Scheme
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: darkPrimary,
        onPrimary: darkPrimaryForeground,
        primaryContainer: Color(0xFF4A5568),
        onPrimaryContainer: darkForeground,
        secondary: darkGold,
        onSecondary: darkGoldForeground,
        secondaryContainer: darkSecondary,
        onSecondaryContainer: darkSecondaryForeground,
        tertiary: darkEmerald,
        onTertiary: darkEmeraldForeground,
        tertiaryContainer: darkAccent,
        onTertiaryContainer: darkAccentForeground,
        error: darkDestructive,
        onError: darkDestructiveForeground,
        errorContainer: Color(0xFF5D1A1A),
        onErrorContainer: Color(0xFFFFCDD2),
        surface: darkCard,
        onSurface: darkCardForeground,
        surfaceContainerHighest: darkMuted,
        onSurfaceVariant: darkMutedForeground,
        outline: darkBorder,
        outlineVariant: Color(0xFF3A3F4A),
        shadow: Color(0xFF000000),
        scrim: Color(0xFF000000),
        inverseSurface: lightCard,
        onInverseSurface: lightCardForeground,
        inversePrimary: lightPrimary,
        surfaceTint: darkPrimary,
      ),
      
      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: darkCard,
        foregroundColor: darkCardForeground,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkCardForeground,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(
          color: darkCardForeground,
        ),
      ),
      
      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkCard,
        selectedItemColor: darkPrimary,
        unselectedItemColor: darkMutedForeground,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(8),
      ),
      
      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: darkPrimaryForeground,
          elevation: 4,
          shadowColor: darkPrimary.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      
      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkPrimary,
          side: const BorderSide(color: darkBorder, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkDestructive, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkDestructive, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(
          color: darkMutedForeground,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          color: darkMutedForeground,
          fontWeight: FontWeight.w500,
        ),
      ),
      
      
      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: darkSecondary,
        labelStyle: const TextStyle(
          color: darkSecondaryForeground,
          fontWeight: FontWeight.w500,
        ),
        side: const BorderSide(color: darkBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      
      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
      
      fontFamily: 'Inter',

      // Standard Text Hierarchy — visible in dark mode (light text on dark bg)
      textTheme: const TextTheme(
        displayLarge:   TextStyle(fontSize: 57, fontWeight: FontWeight.w700, letterSpacing: -0.25, color: darkCardForeground),
        displayMedium:  TextStyle(fontSize: 45, fontWeight: FontWeight.w700, color: darkCardForeground),
        displaySmall:   TextStyle(fontSize: 36, fontWeight: FontWeight.w600, color: darkCardForeground),
        headlineLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: darkCardForeground),
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: darkCardForeground),
        headlineSmall:  TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: darkCardForeground),
        titleLarge:     TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: darkCardForeground),
        titleMedium:    TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.15, color: darkCardForeground),
        titleSmall:     TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1, color: darkCardForeground),
        bodyLarge:      TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5, height: 1.5, color: darkCardForeground),
        bodyMedium:     TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25, height: 1.4, color: darkCardForeground),
        bodySmall:      TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4, height: 1.4, color: darkMutedForeground),
        labelLarge:     TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: darkCardForeground),
        labelMedium:    TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5, color: darkMutedForeground),
        labelSmall:     TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5, color: darkMutedForeground),
      ),
    );
  }

  // Utility methods for accessing theme colors
  static Color getPrimaryColor(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }
  
  static Color getSecondaryColor(BuildContext context) {
    return Theme.of(context).colorScheme.secondary;
  }
  
  static Color getSurfaceColor(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }
  
  static Color getOnSurfaceColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }
  
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }
  
  // Spiritual gradient utilities
  static LinearGradient getDivineGradient(BuildContext context) {
    final isDark = isDarkMode(context);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark 
        ? [darkGold, const Color(0xFFF0C814)]
        : [lightGold, const Color(0xFFF0C814)],
    );
  }
  
  static LinearGradient getPrimaryGradient(BuildContext context) {
    final isDark = isDarkMode(context);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark 
        ? [darkPrimary, darkPrimaryGlow]
        : [lightPrimary, lightPrimaryGlow],
    );
  }
  
  static LinearGradient getGrowthGradient(BuildContext context) {
    final isDark = isDarkMode(context);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark 
        ? [darkEmerald, const Color(0xFF4FD1C7)]
        : [lightEmerald, const Color(0xFF4FD1C7)],
    );
  }
}




