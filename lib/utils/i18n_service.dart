import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported languages in the app
enum SupportedLanguage {
  english('en', 'English'),
  yoruba('yo', 'Yorùbá'),
  igbo('ig', 'Igbo'),
  hausa('ha', 'Hausa');

  const SupportedLanguage(this.code, this.name);
  final String code;
  final String name;

  static SupportedLanguage fromCode(String code) {
    return SupportedLanguage.values.firstWhere(
      (lang) => lang.code == code,
      orElse: () => SupportedLanguage.english,
    );
  }
}

/// Internationalization service for the app
class I18nService extends ChangeNotifier {
  static final I18nService _instance = I18nService._internal();
  factory I18nService() => _instance;
  I18nService._internal();

  SupportedLanguage _currentLanguage = SupportedLanguage.english;
  Map<String, Map<String, String>> _translations = {};
  bool _isInitialized = false;

  SupportedLanguage get currentLanguage => _currentLanguage;
  bool get isInitialized => _isInitialized;

  /// Initialize the i18n service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Load saved language preference
    await _loadSavedLanguage();

    // Load translations
    await _loadTranslations();

    _isInitialized = true;
    notifyListeners();
  }

  /// Load saved language from SharedPreferences
  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguageCode = prefs.getString('selected_language');

      if (savedLanguageCode != null) {
        _currentLanguage = SupportedLanguage.fromCode(savedLanguageCode);
      }
    } catch (e) {
      debugPrint('Error loading saved language: $e');
    }
  }

  /// Load translations from assets or define them inline
  Future<void> _loadTranslations() async {
    _translations = {
      'en': {
        // Navigation
        'home': 'Home',
        'study': 'Study',
        'daily': 'Daily',
        'prayer': 'Prayer',
        'profile': 'Profile',

        // Common
        'welcome': 'Welcome',
        'loading': 'Loading...',
        'save': 'Save',
        'cancel': 'Cancel',
        'delete': 'Delete',
        'edit': 'Edit',
        'share': 'Share',
        'error': 'Error',
        'success': 'Success',
        'retry': 'Retry',
        'ok': 'OK',
        'yes': 'Yes',
        'no': 'No',

        // Prayer
        'prayerWall': 'Prayer Wall',
        'sharePrayerRequest': 'Share a Prayer Request',
        'prayFor': 'Pray For',
        'prayerRequests': 'Prayer Requests',
        'myPrayers': 'My Prayers',
        'addPrayer': 'Add Prayer',

        // Study
        'bibleStudy': 'Bible Study',
        'continueLesson': 'Continue Lesson',
        'startProgram': 'Start Program',
        'studyProgress': 'Study Progress',
        'completedLessons': 'Completed Lessons',

        // Health
        'healthyLiving': 'Healthy Living',
        'todaysScore': 'Today\'s Wellness Score',
        'logWater': 'Log Water Intake',
        'waterIntake': 'Water Intake',
        'exercise': 'Exercise',
        'sleep': 'Sleep',
        'nutrition': 'Nutrition',

        // Missions
        'missionStories': 'Mission Stories',
        'supportMission': 'Support This Mission',
        'missions': 'Missions',
        'donate': 'Donate',
        'volunteer': 'Volunteer',

        // Settings
        'settings': 'Settings',
        'language': 'Language',
        'notifications': 'Notifications',
        'theme': 'Theme',
        'account': 'Account',
        'privacy': 'Privacy',
        'about': 'About',

        // Auth
        'signIn': 'Sign In',
        'signUp': 'Sign Up',
        'signOut': 'Sign Out',
        'email': 'Email',
        'password': 'Password',
        'confirmPassword': 'Confirm Password',
        'forgotPassword': 'Forgot Password?',
        'createAccount': 'Create Account',
        'alreadyHaveAccount': 'Already have an account?',
        'dontHaveAccount': 'Don\'t have an account?',
      },
      'yo': {
        // Navigation
        'home': 'Ile',
        'study': 'Eko',
        'daily': 'Ojoojumo',
        'prayer': 'Adura',
        'profile': 'Ifihan',

        // Common
        'welcome': 'Kaabo',
        'loading': 'N gbogun...',
        'save': 'Fi Pamosi',
        'cancel': 'Fagile',
        'delete': 'Pa nu',
        'edit': 'Tun se',
        'share': 'Pin',
        'error': 'Aṣiṣe',
        'success': 'Aṣeyọri',
        'retry': 'Tun gbiyanju',
        'ok': 'O dara',
        'yes': 'Beeni',
        'no': 'Rara',

        // Prayer
        'prayerWall': 'Ogiri Adura',
        'sharePrayerRequest': 'Pin Ibeere Adura',
        'prayFor': 'Gbadura Fun',
        'prayerRequests': 'Awon Ibeere Adura',
        'myPrayers': 'Awon Adura Mi',
        'addPrayer': 'Fi Adura Kun',

        // Study
        'bibleStudy': 'Eko Bibeli',
        'continueLesson': 'Tesiwaju Eko',
        'startProgram': 'Bere Eto',
        'studyProgress': 'Ilọsiwaju Eko',
        'completedLessons': 'Awon Eko Ti O Ti Pari',

        // Health
        'healthyLiving': 'Igbesi Aye Ilera',
        'todaysScore': 'Ami Ilera Oni',
        'logWater': 'Fi Omi Ti O Mu Sinu',
        'waterIntake': 'Mimu Omi',
        'exercise': 'Ere Idaraya',
        'sleep': 'Oorun',
        'nutrition': 'Ounjẹ Ilera',

        // Missions
        'missionStories': 'Awon Itan Ijose',
        'supportMission': 'Ati Ijose Yi',
        'missions': 'Awon Ijose',
        'donate': 'Fun ni',
        'volunteer': 'Ṣe atilẹyin',

        // Settings
        'settings': 'Awon Eto',
        'language': 'Ede',
        'notifications': 'Awon Iwifun',
        'theme': 'Koko-oro',
        'account': 'Akọọlẹ',
        'privacy': 'Aṣiri',
        'about': 'Nipa',

        // Auth
        'signIn': 'Wọle',
        'signUp': 'Forukọsilẹ',
        'signOut': 'Jade',
        'email': 'Imeeli',
        'password': 'Ọrọ igbaniwọle',
        'confirmPassword': 'Jẹrisi Ọrọ igbaniwọle',
        'forgotPassword': 'Gbagbe Ọrọ igbaniwọle?',
        'createAccount': 'Ṣẹda Akọọlẹ',
        'alreadyHaveAccount': 'Ni akọọlẹ tẹlẹ?',
        'dontHaveAccount': 'Ko ni akọọlẹ?',
      },
      'ig': {
        // Navigation
        'home': 'Ulo',
        'study': 'Omenala',
        'daily': 'Kwa Ubochi',
        'prayer': 'Ekpere',
        'profile': 'Nkowa',

        // Common
        'welcome': 'Nnoo',
        'loading': 'Ana-eme...',
        'save': 'Chekwaa',
        'cancel': 'Kagbuo',
        'delete': 'Hichaa',
        'edit': 'Dezie',
        'share': 'Kekoria',
        'error': 'Njehie',
        'success': 'Ihe oma',
        'retry': 'Nwaa ọzọ',
        'ok': 'O di mma',
        'yes': 'Ee',
        'no': 'Mba',

        // Prayer
        'prayerWall': 'Mgbidi Ekpere',
        'sharePrayerRequest': 'Kekoria Ekpere',
        'prayFor': 'Kpere Maka',
        'prayerRequests': 'Arịrịọ Ekpere',
        'myPrayers': 'Ekpere M',
        'addPrayer': 'Tinye Ekpere',

        // Study
        'bibleStudy': 'Ihe Omuma Bible',
        'continueLesson': 'Gaa n\'ihu',
        'startProgram': 'Malite Mmemme',
        'studyProgress': 'Ọganihu Ọmụmụ',
        'completedLessons': 'Nkuzi Emechara',

        // Health
        'healthyLiving': 'Ndu Ahụike',
        'todaysScore': 'Akara Ahụike Taa',
        'logWater': 'Dekoo Mmiri',
        'waterIntake': 'Ịṅụ Mmiri',
        'exercise': 'Mgbatị Ahụ',
        'sleep': 'Ụra',
        'nutrition': 'Nri Ahụike',

        // Missions
        'missionStories': 'Akuko Ozi Oma',
        'supportMission': 'Kwado Ozi A',
        'missions': 'Ozi Oma',
        'donate': 'Nye onyinye',
        'volunteer': 'Bụrụ onye enyemaka',

        // Settings
        'settings': 'Ntọala',
        'language': 'Asụsụ',
        'notifications': 'Ọkwa',
        'theme': 'Isiokwu',
        'account': 'Akaụntụ',
        'privacy': 'Nzuzo',
        'about': 'Banyere',

        // Auth
        'signIn': 'Banye',
        'signUp': 'Debanye aha',
        'signOut': 'Pụọ',
        'email': 'Email',
        'password': 'Okwu nzuzo',
        'confirmPassword': 'Kwenye Okwu nzuzo',
        'forgotPassword': 'Chefuru Okwu nzuzo?',
        'createAccount': 'Mepụta Akaụntụ',
        'alreadyHaveAccount': 'Ị nwere akaụntụ?',
        'dontHaveAccount': 'Ị nweghị akaụntụ?',
      },
      'ha': {
        // Navigation
        'home': 'Gida',
        'study': 'Karatu',
        'daily': 'Yau da Yau',
        'prayer': 'Addu\'a',
        'profile': 'Bayanin Kai',

        // Common
        'welcome': 'Maraba',
        'loading': 'Ana Lodi...',
        'save': 'Ajiye',
        'cancel': 'Soke',
        'delete': 'Share',
        'edit': 'Gyara',
        'share': 'Raba',
        'error': 'Kuskure',
        'success': 'Nasara',
        'retry': 'Sake gwadawa',
        'ok': 'To',
        'yes': 'I',
        'no': 'A\'a',

        // Prayer
        'prayerWall': 'Bangon Addu\'a',
        'sharePrayerRequest': 'Raba Bukatar Addu\'a',
        'prayFor': 'Yi Addu\'a',
        'prayerRequests': 'Bukatar Addu\'a',
        'myPrayers': 'Addu\'o\'ina',
        'addPrayer': 'Kara Addu\'a',

        // Study
        'bibleStudy': 'Karatun Littafi Mai Tsarki',
        'continueLesson': 'Ci Gaba da Darasi',
        'startProgram': 'Fara Shirin',
        'studyProgress': 'Ci Gaban Karatu',
        'completedLessons': 'Darussan Da Aka Gama',

        // Health
        'healthyLiving': 'Rayuwar Lafiya',
        'todaysScore': 'Maki Lafiya na Yau',
        'logWater': 'Rubuta Ruwan Da Ka Sha',
        'waterIntake': 'Shan Ruwa',
        'exercise': 'Motsa Jiki',
        'sleep': 'Barci',
        'nutrition': 'Abinci Mai Gina Jiki',

        // Missions
        'missionStories': 'Labarun Aiki',
        'supportMission': 'Goyi Bayan Wannan Aiki',
        'missions': 'Ayyuka',
        'donate': 'Ba da gudummawa',
        'volunteer': 'Zama mai ba da gudummawa',

        // Settings
        'settings': 'Saitunan',
        'language': 'Harshe',
        'notifications': 'Sanarwa',
        'theme': 'Jigo',
        'account': 'Asusun',
        'privacy': 'Sirri',
        'about': 'Game da',

        // Auth
        'signIn': 'Shiga',
        'signUp': 'Yi Rajista',
        'signOut': 'Fita',
        'email': 'Imel',
        'password': 'Kalmar sirri',
        'confirmPassword': 'Tabbatar da Kalmar sirri',
        'forgotPassword': 'Ka manta da Kalmar sirri?',
        'createAccount': 'Kirkiro Asusun',
        'alreadyHaveAccount': 'Kana da asusun?',
        'dontHaveAccount': 'Ba ka da asusun?',
      },
    };
  }

  /// Change the current language
  Future<void> changeLanguage(SupportedLanguage language) async {
    if (_currentLanguage == language) return;

    _currentLanguage = language;

    // Save to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_language', language.code);
    } catch (e) {
      debugPrint('Error saving language preference: $e');
    }

    notifyListeners();
  }

  /// Get translated text for a key
  String translate(String key, {Map<String, String>? params}) {
    final languageTranslations =
        _translations[_currentLanguage.code] ?? _translations['en']!;
    String translation = languageTranslations[key] ?? key;

    // Replace parameters if provided
    if (params != null) {
      params.forEach((paramKey, paramValue) {
        translation = translation.replaceAll('{{$paramKey}}', paramValue);
      });
    }

    return translation;
  }

  /// Get all available languages
  List<SupportedLanguage> get availableLanguages => SupportedLanguage.values;

  /// Check if a translation exists for a key
  bool hasTranslation(String key) {
    final languageTranslations =
        _translations[_currentLanguage.code] ?? _translations['en']!;
    return languageTranslations.containsKey(key);
  }

  /// Get current language name
  String get currentLanguageName => _currentLanguage.name;

  /// Get current language code
  String get currentLanguageCode => _currentLanguage.code;

  /// Check if current language is RTL (Right-to-Left)
  bool get isRTL {
    // Add RTL languages here if needed
    return false;
  }
}

/// Extension to make translation easier in widgets
extension BuildContextI18n on BuildContext {
  /// Get the I18nService instance
  I18nService get i18n => I18nService();

  /// Translate a key
  String tr(String key, {Map<String, String>? params}) {
    return I18nService().translate(key, params: params);
  }
}

/// Global instance for easy access
final i18nService = I18nService();




