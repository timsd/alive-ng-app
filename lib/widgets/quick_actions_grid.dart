import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_constants.dart';
import '../providers/language_provider.dart';
import '../utils/text_formatter.dart';
import '../utils/layout_fix_utils.dart';
import '../utils/responsive_utils.dart';

class QuickActionsGrid extends ConsumerWidget {
  const QuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translate = ref.watch(translationProvider);

    final actions = [
      const QuickAction(
        icon: Icons.child_care_rounded,
        title: 'Kid Mission',
        subtitle: 'Children\'s ministry',
        color: Color(0xFFF43F5E), // Rose 500
        route: '/kid-mission',
      ),
      const QuickAction(
        icon: Icons.trending_up_rounded,
        title: 'Discipleship',
        subtitle: 'Track growth',
        color: Color(0xFF10B981), // Emerald 500
        route: '/discipleship-tracker',
      ),
      const QuickAction(
        icon: Icons.sports_esports_rounded,
        title: 'Bible Game',
        subtitle: 'Faith on demand',
        color: Color(0xFF2563EB), // Blue 600
        route: AppConstants.bibleGameRoute,
      ),
      const QuickAction(
        icon: Icons.restaurant_menu_rounded,
        title: 'Recipes',
        subtitle: 'Healthy meals',
        color: Color(0xFFF59E0B), // Amber 500
        route: '/healthy-recipes',
      ),
      QuickAction(
        icon: Icons.public_rounded,
        title: translate('missions'),
        subtitle: 'Global outreach',
        color: const Color(0xFF0EA5E9), // Sky 500
        route: '/missions',
      ),
      const QuickAction(
        icon: Icons.record_voice_over_rounded,
        title: 'Testimonies',
        subtitle: 'Share story',
        color: Color(0xFF8B5CF6), // Violet 500
        route: '/testimonies',
      ),
      const QuickAction(
        icon: Icons.auto_stories_rounded,
        title: 'Kids Stories',
        subtitle: 'Bible stories',
        color: Color(0xFFF97316), // Orange 500
        route: '/kids-stories',
      ),
      const QuickAction(
        icon: Icons.local_library_rounded,
        title: 'Library',
        subtitle: 'Resources',
        color: Color(0xFF14B8A6), // Teal 500
        route: '/library',
      ),
      const QuickAction(
        icon: Icons.podcasts_rounded,
        title: 'Podcasts',
        subtitle: 'Audio content',
        color: Color(0xFFD946EF), // Fuchsia 500
        route: '/podcasts',
      ),
      const QuickAction(
        icon: Icons.menu_book_rounded,
        title: 'Bible',
        subtitle: 'Read scripture',
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
            TextFormatter.formatText('quick_actions'),
            context: context,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            // Improved responsive breakpoints for better mobile experience
            int crossAxisCount;
            double childAspectRatio;
            double horizontalPadding;

            if (constraints.maxWidth < 400) {
              // Small mobile screens — 3 compact columns
              crossAxisCount = 3;
              childAspectRatio = 1.05;
              horizontalPadding = 12;
            } else if (constraints.maxWidth < 600) {
              // Medium mobile screens — 3 columns with breathing room
              crossAxisCount = 3;
              childAspectRatio = 1.1;
              horizontalPadding = 16;
            } else if (constraints.maxWidth < 900) {
              // Tablet screens — 4 columns
              crossAxisCount = 4;
              childAspectRatio = 1.15;
              horizontalPadding = 24;
            } else {
              // Desktop screens — 5 columns
              crossAxisCount = 5;
              childAspectRatio = 1.2;
              horizontalPadding = 32;
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing:
                    ResponsiveUtils.getResponsiveSpacing(context, 12),
                mainAxisSpacing:
                    ResponsiveUtils.getResponsiveSpacing(context, 12),
                childAspectRatio: childAspectRatio,
              ),
              itemCount: actions.length,
              itemBuilder: (context, index) {
                final action = actions[index];
                return QuickActionCard(
                  action: action,
                  onTap: () => context.go(action.route),
                );
              },
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
  final String subtitle;
  final Color color;
  final String route;

  const QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.route,
  });
}

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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon container with responsive size
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  action.icon,
                  color: action.color,
                  size: 22,
                ),
              ),
              const SizedBox(height: 8),
              // Title - auto-scaling with FittedBox
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    action.title,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
