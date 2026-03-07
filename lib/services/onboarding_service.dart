import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class OnboardingService {
  static bool _initialized = false;
  static bool _completed = false;

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _completed = prefs.getBool(AppConstants.onboardingKey) ?? false;
    _initialized = true;
  }

  static bool get isInitialized => _initialized;

  static bool get isCompleted => _completed;

  static Future<bool> shouldShowOnboarding() async {
    if (!_initialized) await initialize();
    return !_completed;
  }

  static Future<void> complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.onboardingKey, true);
    _completed = true;
  }
}

