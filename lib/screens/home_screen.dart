import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../constants/app_constants.dart';
import '../widgets/daily_verse_card.dart';
import '../widgets/quick_actions_grid.dart';
import '../widgets/greeting_header.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final translate = ref.watch(translationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(translate('home')),
        actions: [
          if (currentUser != null)
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {
                // TODO: Navigate to notifications
              },
            ),
        ],
      ),
      body: currentUser == null
          ? _buildUnauthenticatedView(context, ref)
          : _buildAuthenticatedView(context, ref),
    );
  }

  Widget _buildUnauthenticatedView(BuildContext context, WidgetRef ref) {
    final translate = ref.watch(translationProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.church,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              translate('welcome'),
              style: Theme.of(context).textTheme.displayMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Grow in faith with daily verses, prayer, and spiritual study',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go(AppConstants.authRoute),
                child: Text(translate('sign_in')),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go(AppConstants.authRoute),
              child: Text(translate('sign_up')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthenticatedView(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        // TODO: Refresh data
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting Header
            const GreetingHeader(),
            const SizedBox(height: 24),

            // Daily Verse Card
            const DailyVerseCard(),
            const SizedBox(height: 24),

            // Quick Actions
            const QuickActionsGrid(),
            const SizedBox(height: 24),

            // Recent Activity Section
            _buildRecentActivitySection(context, ref),
            const SizedBox(height: 24),

            // Stats Section
            _buildStatsSection(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection(BuildContext context, WidgetRef ref) {
    final translate = ref.watch(translationProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildActivityItem(
                  context,
                  icon: Icons.book,
                  title: 'Completed "Faith Foundations" Lesson 3',
                  subtitle: '2 hours ago',
                  color: Theme.of(context).colorScheme.primary,
                ),
                const Divider(),
                _buildActivityItem(
                  context,
                  icon: Icons.favorite,
                  title: 'Prayed for 5 requests',
                  subtitle: '1 day ago',
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const Divider(),
                _buildActivityItem(
                  context,
                  icon: Icons.health_and_safety,
                  title: 'Logged daily health tracking',
                  subtitle: '2 days ago',
                  color: Colors.orange,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Progress',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.book,
                title: 'Study Programs',
                value: '3',
                subtitle: 'Active',
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.favorite,
                title: 'Prayers',
                value: '47',
                subtitle: 'This month',
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.calendar_today,
                title: 'Streak',
                value: '12',
                subtitle: 'Days',
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.star,
                title: 'Points',
                value: '1,250',
                subtitle: 'Total earned',
                color: Colors.amber,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
