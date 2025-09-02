import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

// Language/Locale Provider
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en', 'US')) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString(AppConstants.languageKey);

      if (languageCode != null &&
          AppConstants.supportedLanguages.containsKey(languageCode)) {
        switch (languageCode) {
          case 'en':
            state = const Locale('en', 'US');
            break;
          case 'yo':
            state = const Locale('yo', 'NG');
            break;
          case 'ig':
            state = const Locale('ig', 'NG');
            break;
          case 'ha':
            state = const Locale('ha', 'NG');
            break;
          default:
            state = const Locale('en', 'US');
        }
      }
    } catch (e) {
      // If there's an error loading the locale, default to English
      state = const Locale('en', 'US');
    }
  }

  Future<void> setLocale(String languageCode) async {
    if (!AppConstants.supportedLanguages.containsKey(languageCode)) {
      return;
    }

    Locale newLocale;
    switch (languageCode) {
      case 'en':
        newLocale = const Locale('en', 'US');
        break;
      case 'yo':
        newLocale = const Locale('yo', 'NG');
        break;
      case 'ig':
        newLocale = const Locale('ig', 'NG');
        break;
      case 'ha':
        newLocale = const Locale('ha', 'NG');
        break;
      default:
        newLocale = const Locale('en', 'US');
    }

    state = newLocale;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.languageKey, languageCode);
    } catch (e) {
      debugPrint('Error saving language preference: $e');
    }
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) => LocaleNotifier(),
);

// Translation Provider
class TranslationService {
  static const Map<String, Map<String, String>> _translations = {
    'en': {
      'home': 'Home',
      'study': 'Study',
      'daily': 'Daily',
      'prayer': 'Prayer',
      'profile': 'Profile',
      'health': 'Health',
      'missions': 'Missions',
      'welcome': 'Welcome',
      'good_morning': 'Good Morning',
      'good_afternoon': 'Good Afternoon',
      'good_evening': 'Good Evening',
      'daily_verse': 'Daily Verse',
      'quick_actions': 'Quick Actions',
      'study_programs': 'Study Programs',
      'prayer_requests': 'Prayer Requests',
      'health_tracking': 'Health Tracking',
      'mission_updates': 'Mission Updates',
      'sign_in': 'Sign In',
      'sign_up': 'Sign Up',
      'sign_out': 'Sign Out',
      'email': 'Email',
      'password': 'Password',
      'submit': 'Submit',
      'cancel': 'Cancel',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'add': 'Add',
      'settings': 'Settings',
      'theme': 'Theme',
      'language': 'Language',
      'notifications': 'Notifications',
      'about': 'About',
      'version': 'Version',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'try_again': 'Try Again',
      'no_data': 'No data available',
    },
    'yo': {
      'home': 'Ile',
      'study': 'Eko',
      'daily': 'Ojoojumo',
      'prayer': 'Adura',
      'profile': 'Profaili',
      'health': 'Ilera',
      'missions': 'Iṣẹ Ihinrere',
      'welcome': 'Kaabo',
      'good_morning': 'E kaaro',
      'good_afternoon': 'E kaasan',
      'good_evening': 'E kaale',
      'daily_verse': 'Ọrọ Ojoojumo',
      'quick_actions': 'Awọn Iṣe Kiakia',
      'study_programs': 'Awọn Eto Eko',
      'prayer_requests': 'Awọn Ibeere Adura',
      'health_tracking': 'Itọpinpin Ilera',
      'mission_updates': 'Awọn Imudojuiwọn Iṣẹ',
      'sign_in': 'Wọle',
      'sign_up': 'Forukọsilẹ',
      'sign_out': 'Jade',
      'email': 'Imeeli',
      'password': 'Ọrọ Igbaniwọle',
      'submit': 'Fi silẹ',
      'cancel': 'Fagilee',
      'save': 'Tọju',
      'delete': 'Paarẹ',
      'edit': 'Ṣatunkọ',
      'add': 'Fi kun',
      'settings': 'Awọn Eto',
      'theme': 'Aṣa',
      'language': 'Ede',
      'notifications': 'Awọn Iwifunni',
      'about': 'Nipa',
      'version': 'Ẹya',
      'loading': 'N gbe...',
      'error': 'Aṣiṣe',
      'success': 'Aṣeyọri',
      'try_again': 'Gbiyanju lẹẹkansi',
      'no_data': 'Ko si data',
    },
    'ig': {
      'home': 'Ụlọ',
      'study': 'Ọmụmụ',
      'daily': 'Kwa Ụbọchị',
      'prayer': 'Ekpere',
      'profile': 'Profaịlụ',
      'health': 'Ahụ Ike',
      'missions': 'Ozi Ọma',
      'welcome': 'Nnọọ',
      'good_morning': 'Ụtụtụ Ọma',
      'good_afternoon': 'Ehihie Ọma',
      'good_evening': 'Mgbede Ọma',
      'daily_verse': 'Okwu Kwa Ụbọchị',
      'quick_actions': 'Omume Ngwa Ngwa',
      'study_programs': 'Mmemme Ọmụmụ',
      'prayer_requests': 'Arịrịọ Ekpere',
      'health_tracking': 'Nlekọta Ahụ Ike',
      'mission_updates': 'Mmelite Ozi',
      'sign_in': 'Banye',
      'sign_up': 'Debanye Aha',
      'sign_out': 'Pụọ',
      'email': 'Ozi Eletrọnịkị',
      'password': 'Okwu Nzuzo',
      'submit': 'Ziga',
      'cancel': 'Kagbuo',
      'save': 'Chekwaa',
      'delete': 'Hichapụ',
      'edit': 'Dezie',
      'add': 'Tinye',
      'settings': 'Ntọala',
      'theme': 'Ụdịdị',
      'language': 'Asụsụ',
      'notifications': 'Ọkwa',
      'about': 'Banyere',
      'version': 'Ụdị',
      'loading': 'Na-ebu...',
      'error': 'Njehie',
      'success': 'Ihe Ịga Nke Ọma',
      'try_again': 'Nwaa Ọzọ',
      'no_data': 'Enweghị data',
    },
    'ha': {
      'home': 'Gida',
      'study': 'Karatu',
      'daily': 'Kullum',
      'prayer': 'Addu\'a',
      'profile': 'Bayani',
      'health': 'Lafiya',
      'missions': 'Ayyukan Bishara',
      'welcome': 'Maraba',
      'good_morning': 'Barka da Safe',
      'good_afternoon': 'Barka da Rana',
      'good_evening': 'Barka da Yamma',
      'daily_verse': 'Aya ta Kullum',
      'quick_actions': 'Ayyuka masu Sauri',
      'study_programs': 'Shirye-shiryen Karatu',
      'prayer_requests': 'Bukatar Addu\'a',
      'health_tracking': 'Bin Lafiya',
      'mission_updates': 'Sabuntawar Ayyuka',
      'sign_in': 'Shiga',
      'sign_up': 'Yi Rajista',
      'sign_out': 'Fita',
      'email': 'Imel',
      'password': 'Kalmar Sirri',
      'submit': 'Aika',
      'cancel': 'Soke',
      'save': 'Ajiye',
      'delete': 'Share',
      'edit': 'Gyara',
      'add': 'Kara',
      'settings': 'Saitunan',
      'theme': 'Kayan Ado',
      'language': 'Harshe',
      'notifications': 'Sanarwa',
      'about': 'Game da',
      'version': 'Sigar',
      'loading': 'Ana Loda...',
      'error': 'Kuskure',
      'success': 'Nasara',
      'try_again': 'Sake Gwadawa',
      'no_data': 'Babu bayanai',
    },
  };

  static String translate(String key, String languageCode) {
    final translations = _translations[languageCode];
    if (translations != null && translations.containsKey(key)) {
      return translations[key]!;
    }

    // Fallback to English if translation not found
    final englishTranslations = _translations['en'];
    if (englishTranslations != null && englishTranslations.containsKey(key)) {
      return englishTranslations[key]!;
    }

    // Return the key itself if no translation found
    return key;
  }
}

final translationProvider = Provider<String Function(String)>((ref) {
  final locale = ref.watch(localeProvider);
  return (String key) => TranslationService.translate(key, locale.languageCode);
});
