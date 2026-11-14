import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

// Theme Mode Provider
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static ThemeMode _initialThemeMode = ThemeMode.system;
  bool _hasUserUpdated = false;

  ThemeModeNotifier() : super(_initialThemeMode) {
    _loadThemeMode();
  }

  static ThemeMode _parseThemeMode(String? themeString) {
    switch (themeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  /// Preload saved theme preference before runApp() so the first frame uses
  /// the user's persisted theme (or system theme if none was selected).
  static Future<void> loadSavedThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _initialThemeMode = _parseThemeMode(prefs.getString(AppConstants.themeKey));
    } catch (_) {
      _initialThemeMode = ThemeMode.system;
    }
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_hasUserUpdated) return;
      final loaded = _parseThemeMode(prefs.getString(AppConstants.themeKey));
      _initialThemeMode = loaded;
      state = loaded;
    } catch (e) {
      if (!_hasUserUpdated) {
        state = ThemeMode.system;
      }
    }
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    _hasUserUpdated = true;
    _initialThemeMode = themeMode;
    state = themeMode;

    try {
      final prefs = await SharedPreferences.getInstance();
      String themeString;

      switch (themeMode) {
        case ThemeMode.light:
          themeString = 'light';
          break;
        case ThemeMode.dark:
          themeString = 'dark';
          break;
        case ThemeMode.system:
          themeString = 'system';
          break;
      }

      await prefs.setString(AppConstants.themeKey, themeString);
    } catch (e) {
      // Handle error saving theme preference
      debugPrint('Error saving theme preference: $e');
    }
  }

  Future<void> toggleTheme() async {
    ThemeMode newTheme;
    
    switch (state) {
      case ThemeMode.system:
        newTheme = ThemeMode.light;
        break;
      case ThemeMode.light:
        newTheme = ThemeMode.dark;
        break;
      case ThemeMode.dark:
        newTheme = ThemeMode.system;
        break;
    }
    
    await setThemeMode(newTheme);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);




