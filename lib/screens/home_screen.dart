import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/guest_provider.dart';
import '../constants/app_constants.dart';
import '../widgets/daily_verse_card.dart';
import '../widgets/quick_actions_grid.dart';
import '../widgets/greeting_header.dart';
import '../services/role_access_service.dart';
import 'health_screen.dart';
import 'daily_screen.dart';

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
              icon: const Icon(Icons.person),
              onPressed: () => context.go('/profile'),
            ),
        ],
      ),
      body: currentUser == null
          ? _buildUnauthenticatedView(context, ref)
          : _buildAuthenticatedView(context, ref, translate),
    );
  }

  Widget _buildUnauthenticatedView(BuildContext context, WidgetRef ref) {
    final translate = ref.watch(translationProvider);
    final isGuest = ref.watch(isGuestModeProvider);

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth > 600;
          final horizontalPadding = isTablet ? 32.0 : 16.0;
          
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                // Welcome Header
                GreetingHeader(),
                const SizedBox(height: 24),
                
                // Daily Verse Card
                Consumer(
                  builder: (context, ref, child) {
                    final dailyVerseAsync = ref.watch(dailyVerseProvider);
                    return dailyVerseAsync.when(
                      data: (verse) => DailyVerseCard(
                        verse: verse,
                        isLoading: false,
                      ),
                      loading: () => const DailyVerseCard(
                        verse: null,
                        isLoading: true,
                      ),
                      error: (error, stack) => const DailyVerseCard(
                        verse: null,
                        isLoading: false,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                
                // Quick Actions for Guests
                Text(
                  translate('explore'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildGuestQuickActions(context, ref),
                const SizedBox(height: 24),
                
                // Sign In Prompt
                if (!isGuest) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.person_add,
                          size: 48,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          translate('sign_in_to_continue'),
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => context.go(AppConstants.authRoute),
                                child: Text(translate('sign_in')),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => context.go(AppConstants.authRoute),
                                child: Text(translate('sign_up')),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGuestQuickActions(BuildContext context, WidgetRef ref) {
    final translate = ref.watch(translationProvider);
    
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildQuickActionCard(
          context,
          icon: Icons.book,
          title: translate('bible'),
          subtitle: translate('read_bible'),
          onTap: () => context.go('/bible'),
        ),
        _buildQuickActionCard(
          context,
          icon: Icons.auto_stories,
          title: translate('study'),
          subtitle: translate('bible_study'),
          onTap: () => context.go('/study'),
        ),
        _buildQuickActionCard(
          context,
          icon: Icons.favorite,
          title: translate('prayer'),
          subtitle: translate('prayer_requests'),
          onTap: () => context.go('/prayer'),
        ),
        _buildQuickActionCard(
          context,
          icon: Icons.calendar_today,
          title: translate('daily'),
          subtitle: translate('daily_devotion'),
          onTap: () => context.go('/daily'),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
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

  Widget _buildAuthenticatedView(BuildContext context, WidgetRef ref, String Function(String) translate) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth > 600;
          final horizontalPadding = isTablet ? 32.0 : 16.0;
          
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentUserProvider);
              ref.invalidate(healthTrackingProvider);
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GreetingHeader(),
                  const SizedBox(height: 24),
                  
                  // Admin Approval Status Notification
                  Builder(
                    builder: (context) {
                      final isApproved = RoleAccessService.instance.isUserApproved();
                      if (!isApproved) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.orange.shade200,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.hourglass_empty,
                                color: Colors.orange.shade700,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Account Pending Approval',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade800,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Your account is currently under review by our administrators. You\'ll have full access once approved.',
                                      style: TextStyle(
                                        color: Colors.orange.shade700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  
                  Consumer(
                    builder: (context, ref, child) {
                      final dailyVerseAsync = ref.watch(dailyVerseProvider);
                      return dailyVerseAsync.when(
                        data: (verse) => DailyVerseCard(
                          verse: verse,
                          isLoading: false,
                        ),
                        loading: () => const DailyVerseCard(
                          verse: null,
                          isLoading: true,
                        ),
                        error: (error, stack) => const DailyVerseCard(
                          verse: null,
                          isLoading: false,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const QuickActionsGrid(),
                  const SizedBox(height: 24),
                  _buildFeaturedTodaySection(context, ref),
                  const SizedBox(height: 24),
                  _buildRecentActivitySection(context, ref, translate),
                  const SizedBox(height: 24),
                  _buildStatsSection(context, ref, translate),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedTodaySection(BuildContext context, WidgetRef ref) {
    final translate = ref.watch(translationProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          translate('featured_today'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: [
            _buildFeaturedCard(
              context,
              ref,
              title: translate('health_message'),
              description: translate('health_message_desc'),
              icon: Icons.health_and_safety,
              color: Colors.green,
              onTap: () => context.go('/health'),
            ),
            const SizedBox(height: 12),
            _buildFeaturedCard(
              context,
              ref,
              title: translate('mission_spotlight'),
              description: translate('mission_spotlight_desc'),
              icon: Icons.public,
              color: Colors.blue,
              onTap: () => context.go('/missions'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeaturedCard(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.1),
                color.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: color,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection(BuildContext context, WidgetRef ref, String Function(String) translate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          translate('recent_activity'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              _buildActivityItem(
                context,
                ref,
                icon: Icons.book,
                title: 'bible_study_completed',
                subtitle: '2 hours_ago',
                color: Colors.blue,
              ),
              _buildActivityItem(
                context,
                ref,
                icon: Icons.favorite,
                title: 'prayer_request_submitted',
                subtitle: '5 hours_ago',
                color: Colors.red,
              ),
              _buildActivityItem(
                context,
                ref,
                icon: Icons.group,
                title: 'joined_small_group',
                subtitle: '1 day_ago',
                color: Colors.green,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final translate = ref.watch(translationProvider);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(icon, color: color),
      ),
      title: Text(translate(title)),
      subtitle: Text(translate(subtitle)),
      trailing: const Icon(Icons.chevron_right),
    );
  }

  Widget _buildStatsSection(BuildContext context, WidgetRef ref, String Function(String) translate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          translate('your_progress'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                ref,
                icon: Icons.book,
                title: 'studies',
                value: '12',
                subtitle: 'completed',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                context,
                ref,
                icon: Icons.favorite,
                title: 'prayers',
                value: '45',
                subtitle: 'this_month',
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
                ref,
                icon: Icons.group,
                title: 'groups',
                value: '3',
                subtitle: 'active',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                context,
                ref,
                icon: Icons.star,
                title: 'streak',
                value: '7',
                subtitle: 'days',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    final translate = ref.watch(translationProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              translate(title),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              translate(subtitle),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
