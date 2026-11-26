import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/appwrite_client.dart';
import '../models/app_models.dart';
import '../services/appwrite_profile_service.dart';

/// In-memory cache of user IDs confirmed to have completed profile setup.
/// Prevents GoRouter.redirect from awaiting network calls on every navigation,
/// which would otherwise stall or freeze routing when mobile network blips
/// (e.g. during incoming phone calls).
class ProfileSetupCache {
  static final Set<String> _completedUsers = {};

  static bool isCompleted(String userId) => _completedUsers.contains(userId);
  static void markCompleted(String userId) => _completedUsers.add(userId);
  static void clear() => _completedUsers.clear();
}

/// Whether a signed-in user still has to go through the profile setup flow.
///
/// The `profile_setup_completed` account preference is the source of truth so
/// that users who finish or skip setup are not redirected back into it on every
/// navigation. When the preference is unavailable (new session or a failed
/// request) we fall back to inspecting the stored profile.
final profileSetupRequiredProvider =
    FutureProvider.family<bool, String>((ref, userId) async {
  if (ProfileSetupCache.isCompleted(userId)) {
    return false;
  }

  UserProfile? storedProfile;
  final profileService = ref.read(appwriteProfileServiceProvider);
  try {
    storedProfile = await profileService
        .getUserProfileModel(userId)
        .timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('Profile setup: could not load profile data: $e');
  }

  // Prefer the explicit `profile_setup_completed` preference (set by
  // completeProfileSetup / the email signup path). When it is explicitly true
  // the setup flow is authoritative and we skip the redirect.
  try {
    final prefs = await Account(appwriteClient)
        .getPrefs()
        .timeout(const Duration(seconds: 3));
    final completed = prefs.data['profile_setup_completed'];
    if (completed is bool && completed) {
      ProfileSetupCache.markCompleted(userId);
      return false;
    }
  } catch (e) {
    debugPrint('Profile setup preference unavailable; using profile data: $e');
  }

  // If profile couldn't be loaded (e.g. offline/timeout), fail open to avoid
  // trapping or freezing users during navigation.
  if (storedProfile == null) return false;
  final needed = needsProfileSetup(storedProfile);
  if (!needed) {
    ProfileSetupCache.markCompleted(userId);
  }
  return needed;
});

Future<void> completeProfileSetup() async {
  final account = Account(appwriteClient);
  try {
    final user = await account.get().timeout(const Duration(seconds: 3));
    ProfileSetupCache.markCompleted(user.$id);
  } catch (_) {}
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
