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
  UserProfile? storedProfile;
  final profileService = ref.read(appwriteProfileServiceProvider);
  try {
    storedProfile = await profileService.getUserProfileModel(userId);
  } catch (e) {
    debugPrint('Profile setup: could not load profile data: $e');
  }

  // Prefer the explicit `profile_setup_completed` preference (set by
  // completeProfileSetup / the email signup path). When it is explicitly true
  // the setup flow is authoritative and we skip the redirect.
  try {
    final prefs = await Account(appwriteClient).getPrefs();
    final completed = prefs.data['profile_setup_completed'];
    if (completed is bool && completed) {
      return false;
    }
  } catch (e) {
    debugPrint('Profile setup preference unavailable; using profile data: $e');
  }

  // Otherwise fall back to inspecting the stored profile. If the profile is
  // already populated (or couldn't be loaded), don't redirect — otherwise the
  // user is sent to the setup flow.
  if (storedProfile == null) return true;
  return needsProfileSetup(storedProfile);
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
