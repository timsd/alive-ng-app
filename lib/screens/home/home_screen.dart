import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/guest_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/achievement_provider.dart';
import '../../widgets/greeting_header.dart';
import '../../widgets/quick_actions_grid.dart';
import '../../widgets/daily_verse_card.dart';
import '../../widgets/role_guard.dart';
import '../../utils/responsive_utils.dart';
import '../../screens/daily/daily_screen.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/error_widget.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final isGuest = ref.watch(isGuestModeProvider);
    final translate = ref.watch(translationProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const CustomAppBar(
        title: 'Home',
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.08),
              theme.scaffoldBackgroundColor,
              theme.colorScheme.secondary.withValues(alpha: 0.04),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: authState.when(
          data: (user) =>
              _buildHomeContent(context, ref, user, isGuest, translate),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => AppErrorWidget(
            title: 'Home is unavailable',
            message:
                'We could not load your home screen. Check your connection and try again.',
            actionText: 'Retry',
            onAction: () => ref.invalidate(authStateProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeContent(BuildContext context, WidgetRef ref, user,
      bool isGuest, Function translate) {
    final dailyVerseAsync = ref.watch(dailyVerseProvider);

    return SingleChildScrollView(
      padding: ResponsiveUtils.getResponsivePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GreetingHeader(),
          SizedBox(height: context.isMobile ? 12 : 16),
          // Achievement Badge (opt-in)
          Consumer(
            builder: (context, ref, _) {
              final showBadge = ref.watch(showAchievementBadgeProvider);
              if (!showBadge) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AchievementBadge(
                  onTap: () => context.push('/achievements'),
                ),
              );
            },
          ),
          Text(
            translate('daily_verse'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          SizedBox(height: context.isMobile ? 12 : 16),
          dailyVerseAsync.when(
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
          ),
          SizedBox(height: context.isMobile ? 20 : 28),
          if (user != null && !isGuest) ...[
            const RoleVisibility(
              allowedRoles: ['member', 'admin', 'leader'],
              child: QuickActionsGrid(),
            ),
          ] else ...[
            Consumer(
              builder: (context, ref, _) {
                return const QuickActionsGrid();
              },
            ),
            SizedBox(height: context.isMobile ? 16 : 24),
          ],
        ],
      ),
    );
  }
}

/// Compact achievement badge widget for the home screen.
class _AchievementBadge extends StatelessWidget {
  const _AchievementBadge({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.1),
              theme.colorScheme.secondary.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.emoji_events,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Achievements',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Track your progress',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
