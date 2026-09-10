import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/localization_compat.dart';

class LocaleNotifier extends StateNotifier<Locale> {
  static Locale _initialLocale = const Locale('en');
  LocaleNotifier() : super(_initialLocale);

  static Future<void> loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(AppConstants.languageKey) ??
          prefs.getString('selected_language') ??
          'en';
      _initialLocale = Locale(
          AppConstants.supportedLanguages.containsKey(code) ? code : 'en');
    } catch (_) {
      _initialLocale = const Locale('en');
    }
  }

  Future<void> setLocale(String code) async {
    if (!AppConstants.supportedLanguages.containsKey(code)) return;
    state = Locale(code);
    _initialLocale = state;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.languageKey, code);
    } catch (error) {
      debugPrint('Could not save language preference: $error');
    }
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) => LocaleNotifier(),
);

final appLocalizationsProvider = Provider<AppLocalizations>((ref) {
  return lookupAppLocalizations(ref.watch(localeProvider));
});

// Compatibility for existing screens while their calls become typed getters.
final languageProvider = Provider<String Function(String)>((ref) {
  final messages = ref.watch(appLocalizationsProvider);
  return (key) => lookupLegacyMessage(messages, key);
});
final translationProvider = languageProvider;
