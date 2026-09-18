import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart';
import '../models/app_models.dart';
import '../services/appwrite_profile_service.dart';

/// Whether a signed-in user still has to go through the profile setup flow.
///
/// The `profile_setup_completed` account preference is the source of truth so
/// that users who finish or skip setup are not redirected back into it on every
/// navigation. When the preference is unavailable (new session or a failed
/// request) we fall back to inspecting the stored profile.
final profileSetupRequiredProvider =
    FutureProvider.family<bool, String>((ref, userId) async {
  try {
    final prefs = await Account(appwriteClient).getPrefs();
    final completed = prefs.data['profile_setup_completed'];
    if (completed is bool) return !completed;
  } catch (e) {
    debugPrint('Profile setup preference unavailable; using profile data: $e');
  }

  final profile =
      await ref.read(appwriteProfileServiceProvider).getUserProfileModel(userId);
  return needsProfileSetup(profile);
});

Future<void> completeProfileSetup() async {
  final account = Account(appwriteClient);
  final prefs = await account.getPrefs();
  await account.updatePrefs(prefs: {
    ...prefs.data,
    'profile_setup_completed': true,
  });
}

bool needsProfileSetup(UserProfile? profile) {
  if (profile == null) return true;
  return [
    profile.phoneNumber,
    profile.location,
    profile.localChurch,
    profile.occupation,
  ].any((value) => value == null || value.trim().isEmpty);
}
