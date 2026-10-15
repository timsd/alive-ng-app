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

  // If profile couldn't be loaded, fail open to avoid trapping users in a loop
  if (storedProfile == null) return false;
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
  if (profile == null) return false;

  // Guest users are not required to complete member profile setup
  if (profile.role == 'guest') return false;

  // If the profile already has phone number, church, chapter, or commitment,
  // they already entered their details during registration (email signup).
  // Never redirect them to profile completion.
  final hasPhone =
      profile.phoneNumber != null && profile.phoneNumber!.trim().isNotEmpty;
  final hasChurch =
      profile.localChurch != null && profile.localChurch!.trim().isNotEmpty;
  final hasChapter =
      profile.localChapter != null && profile.localChapter!.trim().isNotEmpty;
  final hasCommitment = profile.commitmentType != null &&
      profile.commitmentType!.trim().isNotEmpty &&
      profile.commitmentType != 'none';

  if (hasPhone || hasChurch || hasChapter || hasCommitment) {
    return false;
  }

  // Only newly created OAuth/Google accounts with zero contact/church info need setup
  return true;
}
