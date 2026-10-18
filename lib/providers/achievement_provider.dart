import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// Provider for achievement badge visibility on home screen.
class AchievementBadgeNotifier extends StateNotifier<bool> {
  AchievementBadgeNotifier() : super(true) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(AppConstants.showAchievementBadgeKey) ?? true;
    } catch (e) {
      state = true;
    }
  }

  Future<void> setShowBadge(bool show) async {
    state = show;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.showAchievementBadgeKey, show);
    } catch (e) {
      debugPrint('Error saving achievement badge preference: $e');
    }
  }

  Future<void> toggle() async {
    await setShowBadge(!state);
  }
}

/// Provider for the achievement badge visibility toggle.
final showAchievementBadgeProvider =
    StateNotifierProvider<AchievementBadgeNotifier, bool>((ref) {
  return AchievementBadgeNotifier();
});
