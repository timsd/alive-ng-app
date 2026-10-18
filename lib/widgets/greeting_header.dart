import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../utils/text_formatter.dart';
import '../utils/layout_fix_utils.dart';
import '../constants/app_constants.dart';

/// Clean, human-centered Greeting Header for ALIVE Nigeria.
/// Grounded in ministry brand colors, warm editorial typography,
/// and accessible layout without artificial decorative AI orbs.
class GreetingHeader extends ConsumerWidget {
  const GreetingHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final translate = ref.watch(translationProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hour = DateTime.now().hour;
    final greeting = _getGreeting(hour);
    final timeIcon = _getTimeIcon(hour);
    final userName = currentUser?.displayName ??
        (currentUser?.email.split('@').first ?? '');
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
            // Top row: Date + Member badge
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
                if (currentUser != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : const Color(0xFFF1EDE4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          size: 13,
                          color: Color(0xFFD49B28),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Member',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.9)
                                : const Color(0xFF233E5F),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),

            // Greeting + Name
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

            const SizedBox(height: 10),

            // Subtitle
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
