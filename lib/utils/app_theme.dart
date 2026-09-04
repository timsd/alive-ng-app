import 'package:flutter/material.dart';

/// ALIVE-NG Design System - Spiritual, warm colors reflecting faith and Nigerian culture
///
/// Design tokens derived from the Lovable reference design system (shadcn/ui).
/// These tokens are the single source of truth for visual consistency
/// across both web and Flutter implementations.
class AppTheme {
  // ─── Spacing tokens ───
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacingLg = 16.0;
  static const double spacingXl = 24.0;
  static const double spacingXxl = 32.0;

  // ─── Radius tokens (matching shadcn --radius: 0.75rem) ───
  static const double radiusSm = 8.0;   // calc(var(--radius) - 4px)
  static const double radiusMd = 10.0;  // calc(var(--radius) - 2px)  — buttons, inputs
  static const double radiusLg = 12.0;  // var(--radius)              — cards
  static const double radiusXl = 16.0;  // dialogs
  static const double radiusFull = 9999.0; // badges, chips

  // ─── Component height tokens ───
  static const double buttonHeightSm = 36.0;   // h-9
  static const double buttonHeightMd = 44.0;   // h-11
  static const double buttonHeightLg = 48.0;   // h-12
  static const double buttonHeightXl = 56.0;   // h-14
  static const double inputHeight = 40.0;       // h-10
  static const double iconButtonSize = 40.0;    // h-10 w-10

  // ─── Container width tokens ───
  static const double containerMaxMobile = 448.0; // max-w-md
  static const double containerMax2xl = 1400.0;   // 2xl container

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
  static const Color lightBackground = Color(0xFFFCFAF5); // Lighter background (Slate 50/100)
  static const Color lightForeground = Color(0xFF17263B); // Deep slate black

  static const Color lightCard = Color(0xFFFDFCF9); // Pure white
  static const Color lightCardForeground = Color(0xFF17263B);

  // Primary - Deep spiritual slate
  static const Color lightPrimary = Color(0xFF233E5F); // Slate 800 (Rich, professional)
  static const Color lightPrimaryForeground = Color(0xFFF7F4EC);
  static const Color lightPrimaryGlow = Color(0xFF2E5B93);

  // Secondary - Warm divine gold
  static const Color lightSecondary = Color(0xFFF4E1B8);
  static const Color lightSecondaryForeground = Color(0xFF233E5F);
  static const Color lightGold = Color(0xFFE5B94D); // Classic ALIVE Gold
  static const Color lightGoldForeground = Color(0xFF17263B);

  // Accent - Life/growth green
  static const Color lightAccent = Color(0xFFDCEBD9);
  static const Color lightAccentForeground = Color(0xFF1F4C35);
  static const Color lightEmerald = Color(0xFF2FAD72); // Professional emerald
  static const Color lightEmeraldForeground = Color(0xFFF7F4EC);

  static const Color lightMuted = Color(0xFFF6F2E9);
  static const Color lightMutedForeground = Color(0xFF687586); // Slate 500

  static const Color lightDestructive = Color(0xFFEF4444);
  static const Color lightDestructiveForeground = Color(0xFFFFFFFF);

  static const Color lightBorder = Color(0xFFE7E0D1);
  static const Color lightInput = Color(0xFFE7E0D1);
  static const Color lightRing = Color(0xFF233E5F);

  // Dark mode - peaceful night theme (High contrast, OLED friendly)
  static const Color darkBackground = Color(0xFF0D1520); // Rich, deep OLED blue-black
  static const Color darkForeground = Color(0xFFEAE5D9); // Brilliant white

  static const Color darkCard = Color(0xFF141F2D); // Elevated dark surface
  static const Color darkCardForeground = Color(0xFFEAE5D9);

  static const Color darkPrimary = Color(0xFFE7D39B); // Warm gold for stronger contrast
  static const Color darkPrimaryForeground = Color(0xFF0D1520); // Deep background for contrast
  static const Color darkPrimaryGlow = Color(0xFFF2DFAC);

  static const Color darkSecondary = Color(0xFF1B2A3D);
  static const Color darkSecondaryForeground = Color(0xFFEAE5D9);
  static const Color darkGold = Color(0xFFF0C969); // Brilliant gold
  static const Color darkGoldForeground = Color(0xFF0D1520);

  static const Color darkAccent = Color(0xFF1B2A3D);
  static const Color darkAccentForeground = Color(0xFFEAE5D9);
  static const Color darkEmerald = Color(0xFF52C38B);
  static const Color darkEmeraldForeground = Color(0xFF0D1520);

  static const Color darkMuted = Color(0xFF1B2A3D); // Slate 800
  static const Color darkMutedForeground = Color(0xFFAAB4C0); // Brilliant slate 400

  static const Color darkDestructive = Color(0xFFEF4444);
  static const Color darkDestructiveForeground = Color(0xFFFFFFFF);

  static const Color darkBorder = Color(0xFF33445A); // Sharper borders
  static const Color darkInput = Color(0xFF1B2A3D);
  static const Color darkRing = Color(0xFFF0C969);

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
      scaffoldBackgroundColor: lightBackground,
      canvasColor: lightBackground,

      // Color Scheme
      colorScheme: const ColorScheme.light(
        brightness: Brightness.light,
        primary: lightPrimary,
        onPrimary: lightPrimaryForeground,
        primaryContainer: Color(0xFFF1F5F9),
        onPrimaryContainer: lightPrimary,
        secondary: lightGold,
        onSecondary: lightGoldForeground,
        secondaryContainer: lightSecondary,
        onSecondaryContainer: Color(0xFF1E3A8A),
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
        surfaceDim: Color(0xFFF4EFE6),
        surfaceBright: Color(0xFFFFFFFF),
        surfaceContainerLowest: Color(0xFFFFFFFF),
        surfaceContainerLow: Color(0xFFFCFAF5),
        surfaceContainer: Color(0xFFF7F2E7),
        surfaceContainerHigh: Color(0xFFF0EADB),
        surfaceContainerHighest: Color(0xFFE8E0CE),
        onSurfaceVariant: Color(0xFF475569), // Slate 600
        outline: Color(0xFFE2E8F0), // Slate 200
        outlineVariant: Color(0xFFCBD5E1), // Slate 300
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
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: lightCardForeground,
          letterSpacing: 0,
        ),
        iconTheme: IconThemeData(
          color: lightCardForeground,
        ),
      ),
      iconTheme: const IconThemeData(
        color: lightCardForeground,
      ),
      primaryIconTheme: const IconThemeData(
        color: lightPrimaryForeground,
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
          side: const BorderSide(
            color: lightBorder,
            width: 1,
          ),
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          minimumSize: const Size(48, buttonHeightMd),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          side: const BorderSide(
            color: lightBorder,
            width: 1,
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lightPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(48, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightPrimary,
          side: const BorderSide(color: lightBorder, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          minimumSize: const Size(48, buttonHeightMd),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: lightBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: lightBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: lightPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: lightDestructive, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: lightDestructive, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      listTileTheme: const ListTileThemeData(
        iconColor: lightCardForeground,
        textColor: lightCardForeground,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightCard,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          side: const BorderSide(
            color: lightBorder,
            width: 1,
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightCard,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: lightCard,
        showDragHandle: true,
        constraints: BoxConstraints(maxWidth: 860),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(
            color: lightBorder,
            width: 1,
          ),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          side: BorderSide(
            color: lightBorder,
            width: 1,
          ),
        ),
      ),

      fontFamily: 'Inter',

      // Standard Text Hierarchy — visible in light mode (dark text on light bg)
      textTheme: const TextTheme(
        // Display — hero banners & splash screens
        displayLarge:   TextStyle(fontSize: 57, fontWeight: FontWeight.w700, letterSpacing: -0.25, height: 1.12, color: lightCardForeground, fontFamily: 'Inter'),
        displayMedium:  TextStyle(fontSize: 45, fontWeight: FontWeight.w700, letterSpacing: 0, height: 1.16, color: lightCardForeground, fontFamily: 'Inter'),
        displaySmall:   TextStyle(fontSize: 36, fontWeight: FontWeight.w600, letterSpacing: 0, height: 1.22, color: lightCardForeground, fontFamily: 'Inter'),
        // Headline — screen/section titles (Lovable h1 = 24 / 700)
        headlineLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: 0, height: 1.25, color: lightCardForeground, fontFamily: 'Inter'),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 0, height: 1.25, color: lightCardForeground, fontFamily: 'Inter'),
        headlineSmall:  TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0, height: 1.28, color: lightCardForeground, fontFamily: 'Inter'),
        // Title — section headers, card titles (Lovable h2 = 18 / 600, cardTitle = 16-18 / 600)
        titleLarge:     TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0, height: 1.3, color: lightCardForeground, fontFamily: 'Inter'),
        titleMedium:    TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.1, height: 1.35, color: lightCardForeground, fontFamily: 'Inter'),
        titleSmall:     TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1, height: 1.4, color: lightCardForeground, fontFamily: 'Inter'),
        // Body — main content (Lovable text-sm = 14 / 400, text-xs = 12 / 400)
        bodyLarge:      TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.15, height: 1.5, color: lightCardForeground, fontFamily: 'Inter'),
        bodyMedium:     TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25, height: 1.45, color: lightCardForeground, fontFamily: 'Inter'),
        bodySmall:      TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4, height: 1.4, color: lightMutedForeground, fontFamily: 'Inter'),
        // Label — buttons, chips, tabs, navigation, captions
        labelLarge:     TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1, height: 1.3, color: lightCardForeground, fontFamily: 'Inter'),
        labelMedium:    TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5, height: 1.3, color: lightMutedForeground, fontFamily: 'Inter'),
        labelSmall:     TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5, height: 1.3, color: lightMutedForeground, fontFamily: 'Inter'),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      canvasColor: darkBackground,

      // Color Scheme
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: darkPrimary,
        onPrimary: darkPrimaryForeground,
        primaryContainer: Color(0xFF423617),
        onPrimaryContainer: darkForeground,
        secondary: darkSecondary,
        onSecondary: darkSecondaryForeground,
        secondaryContainer: Color(0xFF22354D),
        onSecondaryContainer: darkForeground,
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
        surfaceDim: Color(0xFF090E17),
        surfaceBright: Color(0xFF1A283B),
        surfaceContainerLowest: Color(0xFF070B12),
        surfaceContainerLow: Color(0xFF0D1520),
        surfaceContainer: Color(0xFF141F2D),
        surfaceContainerHigh: Color(0xFF1B2A3D),
        surfaceContainerHighest: Color(0xFF23354C),
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
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkCardForeground,
          letterSpacing: 0,
        ),
        iconTheme: IconThemeData(
          color: darkCardForeground,
        ),
      ),
      iconTheme: const IconThemeData(
        color: darkCardForeground,
      ),
      primaryIconTheme: const IconThemeData(
        color: darkPrimaryForeground,
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
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(
            color: darkBorder,
            width: 1,
          ),
        ),
        margin: const EdgeInsets.all(8),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: darkPrimaryForeground,
          elevation: 3,
          shadowColor: darkPrimary.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          minimumSize: const Size(48, buttonHeightMd),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          side: const BorderSide(
            color: darkBorder,
            width: 1,
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(48, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkPrimary,
          side: const BorderSide(color: darkPrimary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          minimumSize: const Size(48, buttonHeightMd),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: darkBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: darkBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: darkPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: darkDestructive, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: darkDestructive, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      listTileTheme: const ListTileThemeData(
        iconColor: darkCardForeground,
        textColor: darkCardForeground,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkCard,
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          side: const BorderSide(
            color: darkBorder,
            width: 1,
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkCard,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: darkCard,
        showDragHandle: true,
        constraints: BoxConstraints(maxWidth: 860),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(
            color: darkBorder,
            width: 1,
          ),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          side: BorderSide(
            color: darkBorder,
            width: 1,
          ),
        ),
      ),

      fontFamily: 'Inter',

      // Standard Text Hierarchy — visible in dark mode (light text on dark bg)
      textTheme: const TextTheme(
        displayLarge:   TextStyle(fontSize: 57, fontWeight: FontWeight.w700, letterSpacing: -0.25, height: 1.12, color: darkCardForeground, fontFamily: 'Inter'),
        displayMedium:  TextStyle(fontSize: 45, fontWeight: FontWeight.w700, letterSpacing: 0, height: 1.16, color: darkCardForeground, fontFamily: 'Inter'),
        displaySmall:   TextStyle(fontSize: 36, fontWeight: FontWeight.w600, letterSpacing: 0, height: 1.22, color: darkCardForeground, fontFamily: 'Inter'),
        headlineLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: 0, height: 1.25, color: darkCardForeground, fontFamily: 'Inter'),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 0, height: 1.25, color: darkCardForeground, fontFamily: 'Inter'),
        headlineSmall:  TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0, height: 1.28, color: darkCardForeground, fontFamily: 'Inter'),
        titleLarge:     TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0, height: 1.3, color: darkCardForeground, fontFamily: 'Inter'),
        titleMedium:    TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.1, height: 1.35, color: darkCardForeground, fontFamily: 'Inter'),
        titleSmall:     TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1, height: 1.4, color: darkCardForeground, fontFamily: 'Inter'),
        bodyLarge:      TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.15, height: 1.5, color: darkCardForeground, fontFamily: 'Inter'),
        bodyMedium:     TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25, height: 1.45, color: darkCardForeground, fontFamily: 'Inter'),
        bodySmall:      TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4, height: 1.4, color: darkMutedForeground, fontFamily: 'Inter'),
        labelLarge:     TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1, height: 1.3, color: darkCardForeground, fontFamily: 'Inter'),
        labelMedium:    TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5, height: 1.3, color: darkMutedForeground, fontFamily: 'Inter'),
        labelSmall:     TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5, height: 1.3, color: darkMutedForeground, fontFamily: 'Inter'),
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




