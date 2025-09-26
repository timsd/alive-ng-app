import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/language_provider.dart';
import '../utils/text_formatter.dart';

class QuickActionsGrid extends ConsumerWidget {
  const QuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translate = ref.watch(translationProvider);

    final actions = [
      QuickAction(
        icon: Icons.menu_book,
        title: translate('study'),
        subtitle: TextFormatter.formatActivityType('bible_study'),
        color: Theme.of(context).colorScheme.primary,
        route: '/study',
      ),
      QuickAction(
        icon: Icons.favorite,
        title: translate('prayer'),
        subtitle: TextFormatter.formatActivityType('prayer_requests'),
        color: Theme.of(context).colorScheme.secondary,
        route: '/prayer',
      ),
      QuickAction(
        icon: Icons.health_and_safety,
        title: translate('health'),
        subtitle: TextFormatter.formatActivityType('wellness_tracking'),
        color: Theme.of(context).colorScheme.tertiary,
        route: '/health',
      ),
      QuickAction(
        icon: Icons.public,
        title: translate('missions'),
        subtitle: TextFormatter.formatActivityType('global_outreach'),
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
        route: '/missions',
      ),
      QuickAction(
        icon: Icons.auto_stories,
        title: 'Kids Stories',
        subtitle: 'Bible stories for children',
        color: Colors.orange,
        route: '/kids-stories',
      ),
      QuickAction(
        icon: Icons.library_books,
        title: 'Library',
        subtitle: 'Books, articles & resources',
        color: Colors.teal,
        route: '/library',
      ),
      QuickAction(
        icon: Icons.podcasts,
        title: 'Podcasts',
        subtitle: 'Audio content & sermons',
        color: Colors.purple,
        route: '/podcasts',
      ),
      QuickAction(
        icon: Icons.school,
        title: 'Interactive Lessons',
        subtitle: 'Learn & grow in faith',
        color: Colors.indigo,
        route: '/interactive-lessons',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            TextFormatter.formatText('quick_actions'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
            final childAspectRatio = constraints.maxWidth > 600 ? 1.0 : 1.2;
            
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
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
          padding: const EdgeInsets.all(16),
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
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  action.icon,
                  color: action.color,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                action.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: action.color,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                action.subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}




