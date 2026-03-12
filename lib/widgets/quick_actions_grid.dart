import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      QuickAction(
        icon: Icons.child_care,
        title: 'Kid Mission',
        subtitle: 'Children\'s ministry activities',
        color: Theme.of(context).brightness == Brightness.dark 
            ? Colors.pink.shade300 
            : Colors.pink,
        route: '/kid-mission',
      ),
      QuickAction(
        icon: Icons.trending_up,
        title: 'Discipleship',
        subtitle: 'Track spiritual growth',
        color: Theme.of(context).brightness == Brightness.dark 
            ? Colors.green.shade300 
            : Colors.green,
        route: '/discipleship-tracker',
      ),
      QuickAction(
        icon: Icons.quiz,
        title: 'Bible Quizzes',
        subtitle: 'Test your Bible knowledge',
        color: Theme.of(context).brightness == Brightness.dark 
            ? Colors.blue.shade300 
            : Colors.blue,
        route: '/bible-quizzes',
      ),
      QuickAction(
        icon: Icons.restaurant,
        title: 'Recipes',
        subtitle: 'Nutritious meal ideas',
        color: Theme.of(context).brightness == Brightness.dark 
            ? Colors.orange.shade300 
            : Colors.orange,
        route: '/healthy-recipes',
      ),
      QuickAction(
        icon: Icons.public,
        title: translate('missions'),
        subtitle: TextFormatter.formatActivityType('global_outreach'),
        color: Theme.of(context).brightness == Brightness.dark 
            ? Colors.cyan.shade300 
            : Colors.cyan,
        route: '/missions',
      ),
      QuickAction(
        icon: Icons.record_voice_over,
        title: 'Testimonies',
        subtitle: 'Share your story',
        color: Theme.of(context).brightness == Brightness.dark 
            ? Colors.amber.shade300 
            : Colors.amber,
        route: '/testimonies',
      ),
      QuickAction(
        icon: Icons.auto_stories,
        title: 'Kids Stories',
        subtitle: 'Bible stories for children',
        color: Theme.of(context).brightness == Brightness.dark 
            ? Colors.deepOrange.shade300 
            : Colors.deepOrange,
        route: '/kids-stories',
      ),
      QuickAction(
        icon: Icons.library_books,
        title: 'Library',
        subtitle: 'Books, articles & resources',
        color: Theme.of(context).brightness == Brightness.dark 
            ? Colors.teal.shade300 
            : Colors.teal,
        route: '/library',
      ),
      QuickAction(
        icon: Icons.podcasts,
        title: 'Podcasts',
        subtitle: 'Audio content & sermons',
        color: Theme.of(context).brightness == Brightness.dark 
            ? Colors.purple.shade300 
            : Colors.purple,
        route: '/podcasts',
      ),
      QuickAction(
        icon: Icons.school,
        title: 'Lessons',
        subtitle: 'Learn & grow in faith',
        color: Theme.of(context).brightness == Brightness.dark 
            ? Colors.indigo.shade300 
            : Colors.indigo,
        route: '/interactive-lessons',
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
                  fontWeight: FontWeight.bold,
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
              // Small mobile screens
              crossAxisCount = 2;
              childAspectRatio = 1.1;
              horizontalPadding = 16;
            } else if (constraints.maxWidth < 600) {
              // Medium mobile screens
              crossAxisCount = 2;
              childAspectRatio = 1.2;
              horizontalPadding = 20;
            } else if (constraints.maxWidth < 900) {
              // Tablet screens
              crossAxisCount = 3;
              childAspectRatio = 1.0;
              horizontalPadding = 24;
            } else {
              // Desktop screens
              crossAxisCount = 4;
              childAspectRatio = 1.0;
              horizontalPadding = 32;
            }
            
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: ResponsiveUtils.getResponsiveSpacing(context, 12),
                mainAxisSpacing: ResponsiveUtils.getResponsiveSpacing(context, 12),
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
            padding: const EdgeInsets.all(8), // Further reduced padding
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  action.color.withValues(alpha: 0.1),
                  action.color.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, // Prevent overflow
              children: [
                // Icon container with fixed size
                Container(
                  padding: const EdgeInsets.all(8), // Further reduced padding
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10), // Smaller radius
                  ),
                  child: Icon(
                    action.icon,
                    color: action.color,
                    size: 20, // Further reduced icon size
                  ),
                ),
                const SizedBox(height: 6), // Further reduced spacing
                // Title with flexible constraints
                Flexible(
                  child: LayoutFixUtils.responsiveText(
                    action.title,
                    context: context,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 11, // Further reduced font size
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2), // Minimal spacing
                // Subtitle with flexible constraints
                Flexible(
                  child: LayoutFixUtils.responsiveText(
                    action.subtitle,
                    context: context,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                          fontSize: 9, // Further reduced font size
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ),
    );
  }
}





