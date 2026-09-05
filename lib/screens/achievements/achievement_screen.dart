import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/achievement_model.dart';
import '../../providers/appwrite_auth_provider.dart';
import '../../services/achievement_service.dart';
import '../../widgets/custom_app_bar.dart';
import 'widgets/achievement_card.dart';

/// Provider for user achievements.
final achievementsProvider = FutureProvider<List<AchievementProgress>>((ref) async {
  final user = ref.watch(appwriteUserStreamProvider).value;
  if (user == null) return [];
  return AchievementService.instance.getUserProgress(user.uid);
});

/// Provider for achievement summary.
final achievementSummaryProvider = FutureProvider<AchievementSummary>((ref) async {
  final user = ref.watch(appwriteUserStreamProvider).value;
  if (user == null) {
    return const AchievementSummary(
      totalEarned: 0,
      totalAvailable: 0,
      recentAchievements: [],
    );
  }
  return AchievementService.instance.getAchievementSummary(user.uid);
});

class AchievementScreen extends ConsumerStatefulWidget {
  const AchievementScreen({super.key});

  @override
  ConsumerState<AchievementScreen> createState() => _AchievementScreenState();
}

class _AchievementScreenState extends ConsumerState<AchievementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: AchievementCategory.values.length + 1,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final achievementsAsync = ref.watch(achievementsProvider);
    final summaryAsync = ref.watch(achievementSummaryProvider);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Achievements',
        showBackButton: true,
      ),
      body: Column(
        children: [
          summaryAsync.when(
            data: (summary) => _buildSummaryCard(context, theme, summary),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: [
              const Tab(text: 'All'),
              ...AchievementCategory.values.map(
                (cat) => Tab(text: cat.displayName),
              ),
            ],
          ),
          Expanded(
            child: achievementsAsync.when(
              data: (progressList) => TabBarView(
                controller: _tabController,
                children: [
                  _buildAchievementList(context, theme, null, progressList),
                  ...AchievementCategory.values.map(
                    (cat) => _buildAchievementList(context, theme, cat, progressList),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('Failed to load achievements'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    ThemeData theme,
    AchievementSummary summary,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Progress',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${summary.totalEarned} of ${summary.totalAvailable} earned',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: summary.completionPercentage / 100,
                  backgroundColor: theme.colorScheme.onPrimary.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation(theme.colorScheme.onPrimary),
                  minHeight: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Icon(Icons.emoji_events, size: 48, color: theme.colorScheme.onPrimary),
        ],
      ),
    );
  }

  Widget _buildAchievementList(
    BuildContext context,
    ThemeData theme,
    AchievementCategory? category,
    List<AchievementProgress> progressList,
  ) {
    final allAchievements = AchievementService.instance.getAllAchievements();
    final filteredAchievements = category == null
        ? allAchievements
        : allAchievements.where((a) => a.category == category).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredAchievements.length,
      itemBuilder: (context, index) {
        final achievement = filteredAchievements[index];
        final progress = progressList.where(
          (p) => p.achievementId == achievement.id,
        ).firstOrNull;

        return AchievementCard(achievement: achievement, progress: progress);
      },
    );
  }
}
