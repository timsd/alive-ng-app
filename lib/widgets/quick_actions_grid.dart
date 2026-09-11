import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_constants.dart';
import '../providers/language_provider.dart';
import '../utils/layout_fix_utils.dart';

/// Quick Actions Grid - styled to match the "More" feature display
/// Uses the same grid layout and card design with colored icons
class QuickActionsGrid extends ConsumerWidget {
  const QuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translate = ref.watch(translationProvider);

    final actions = [
      const QuickAction(
        icon: Icons.child_care_rounded,
        title: 'Kid Mission',
        color: Color(0xFFF43F5E), // Rose 500
        route: '/kid-mission',
      ),
      const QuickAction(
        icon: Icons.trending_up_rounded,
        title: 'Discipleship',
        color: Color(0xFF10B981), // Emerald 500
        route: '/discipleship-tracker',
      ),
      const QuickAction(
        icon: Icons.sports_esports_rounded,
        title: 'Bible Game',
        color: Color(0xFF2563EB), // Blue 600
        route: AppConstants.bibleGameRoute,
      ),
      const QuickAction(
        icon: Icons.restaurant_menu_rounded,
        title: 'Recipes',
        color: Color(0xFFF59E0B), // Amber 500
        route: '/healthy-recipes',
      ),
      QuickAction(
        icon: Icons.public_rounded,
        title: translate('missions'),
        color: const Color(0xFF0EA5E9), // Sky 500
        route: '/missions',
      ),
      const QuickAction(
        icon: Icons.record_voice_over_rounded,
        title: 'Testimonies',
        color: Color(0xFF8B5CF6), // Violet 500
        route: '/testimonies',
      ),
      const QuickAction(
        icon: Icons.auto_stories_rounded,
        title: 'Kids Stories',
        color: Color(0xFFF97316), // Orange 500
        route: '/kids-stories',
      ),
      const QuickAction(
        icon: Icons.local_library_rounded,
        title: 'Library',
        color: Color(0xFF14B8A6), // Teal 500
        route: '/library',
      ),
      const QuickAction(
        icon: Icons.podcasts_rounded,
        title: 'Podcasts',
        color: Color(0xFFD946EF), // Fuchsia 500
        route: '/podcasts',
      ),
      const QuickAction(
        icon: Icons.menu_book_rounded,
        title: 'Bible',
        color: Color(0xFF6366F1), // Indigo 500
        route: AppConstants.bibleRoute,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: LayoutFixUtils.responsiveText(
            ref.watch(appLocalizationsProvider).quick_actions,
            context: context,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(height: 16),
        // Using the same grid layout as "More" feature
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 8,
            childAspectRatio: 0.88,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return QuickActionCard(
              action: action,
              onTap: () => context.go(action.route),
            );
          },
        ),
      ],
    );
  }
}

class QuickAction {
  final IconData icon;
  final String title;
  final Color color;
  final String route;

  const QuickAction({
    required this.icon,
    required this.title,
    required this.color,
    required this.route,
  });
}

/// Quick Action Card - matches the "More" feature item style
/// (no square container behind the item, just the circular colored icon)
class QuickActionCard extends StatelessWidget {
  final QuickAction action;
  final VoidCallback onTap;

  const QuickActionCard({
    super.key,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? action.color.withValues(alpha: 0.20)
                  : action.color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              action.icon,
              size: 24,
              color: action.color,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              action.title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
