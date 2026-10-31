import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/appwrite_auth_provider.dart';

import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../utils/text_formatter.dart';
import '../utils/layout_fix_utils.dart';
import '../constants/app_constants.dart';
import 'custom_image.dart';

/// Clean, human-centered Greeting Header for ALIVE Nigeria.
/// Grounded in ministry brand colors, warm editorial typography,
/// and accessible layout without artificial decorative AI orbs.
class GreetingHeader extends ConsumerWidget {
  const GreetingHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final userProfile = ref.watch(currentUserProfileProvider).value;
    final avatarOverride = ref.watch(uploadedAvatarUrlProvider);
    final avatarUrl = avatarOverride != null
        ? (avatarOverride.trim().isEmpty ? null : avatarOverride.trim())
        : ((userProfile?.avatarUrl != null &&
                userProfile!.avatarUrl!.trim().isNotEmpty)
            ? userProfile.avatarUrl!.trim()
            : ((userProfile?.photoUrl != null &&
                    userProfile!.photoUrl!.trim().isNotEmpty)
                ? userProfile.photoUrl!.trim()
                : ((currentUser?.photoUrl != null &&
                        currentUser!.photoUrl!.trim().isNotEmpty)
                    ? currentUser.photoUrl!.trim()
                    : null)));
    final translate = ref.watch(translationProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hour = DateTime.now().hour;
    final greeting = _getGreeting(hour);
    final timeIcon = _getTimeIcon(hour);
    final userName = (userProfile?.fullName != null &&
            userProfile!.fullName!.trim().isNotEmpty)
        ? userProfile.fullName!.trim()
        : (currentUser?.displayName ??
            (currentUser?.email.split('@').first ?? ''));
    final initialLetter =
        userName.isNotEmpty ? userName[0].toUpperCase() : 'M';
    final formattedDate =
        DateFormat('EEEE, MMMM d').format(DateTime.now());

    // Authentic ALIVE brand colors
    final cardBg = isDark
        ? const Color(0xFF141F2D) // Deep elevated slate
        : Colors.white; // Clean warm white for light mode
    final onCard = isDark ? Colors.white : const Color(0xFF17263B);
    final secondaryText = isDark
        ? Colors.white.withValues(alpha: 0.75)
        : const Color(0xFF5B6B82);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE7E0D1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Date + Sign In (if guest)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      timeIcon,
                      size: 14,
                      color: const Color(0xFFD49B28), // Warm Gold
                    ),
                    const SizedBox(width: 6),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                if (currentUser == null)
                  InkWell(
                    onTap: () => context.push(AppConstants.authRoute),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.login_rounded,
                            size: 13,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Sign In",
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),

            // Middle row: Greeting & Name on left; Profile Avatar on right (Blue Circle position)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        greeting,
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentUser != null && userName.isNotEmpty
                            ? userName
                            : 'Welcome to ALIVE Nigeria',
                        style: TextStyle(
                          color: onCard,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (currentUser != null) ...[
                  const SizedBox(width: 16),
                  // User avatar placed in the middle-right area without pill container
                  InkWell(
                    onTap: () => context.push(AppConstants.profileRoute),
                    borderRadius: BorderRadius.circular(32),
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD49B28),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                                alpha: isDark ? 0.35 : 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFFD49B28),
                        child: avatarUrl != null
                            ? ClipOval(
                                child: CustomImage(
                                  key: ValueKey(avatarUrl),
                                  imageUrl: avatarUrl,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  backgroundColor: const Color(0xFFD49B28),
                                  placeholder: Center(
                                    child: Text(
                                      initialLetter,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Text(
                                initialLetter,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // Bottom row: Subtitle
            Text(
              translate('continue_spiritual_journey'),
              style: TextStyle(
                color: secondaryText,
                fontSize: 13,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Guest call-to-action
            if (currentUser == null) ...[
              const SizedBox(height: 14),
              InkWell(
                onTap: () => context.go(AppConstants.authRoute),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5B94D), // Warm gold button
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LayoutFixUtils.responsiveText(
                        TextFormatter.formatText('join_us_in_spiritual_growth'),
                        context: context,
                        style: const TextStyle(
                          color: Color(0xFF1B365D),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: Color(0xFF1B365D),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getGreeting(int hour) {
    if (hour >= 5 && hour < 12) {
      return TextFormatter.formatText('good_morning');
    } else if (hour >= 12 && hour < 17) {
      return TextFormatter.formatText('good_afternoon');
    } else {
      return TextFormatter.formatText('good_evening');
    }
  }

  IconData _getTimeIcon(int hour) {
    if (hour >= 5 && hour < 12) {
      return Icons.wb_sunny_outlined;
    } else if (hour >= 12 && hour < 17) {
      return Icons.wb_sunny_rounded;
    } else {
      return Icons.nights_stay_outlined;
    }
  }
}
