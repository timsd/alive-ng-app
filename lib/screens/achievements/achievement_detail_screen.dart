import 'package:flutter/material.dart';
import '../../models/achievement_model.dart';
import '../../widgets/custom_app_bar.dart';

class AchievementDetailScreen extends StatelessWidget {
  const AchievementDetailScreen({super.key, required this.achievement, this.progress});
  final Achievement achievement;
  final AchievementProgress? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEarned = progress?.isEarned ?? false;
    return Scaffold(
      appBar: CustomAppBar(title: 'Achievement Details', showBackButton: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: isEarned ? achievement.tier.color.withValues(alpha: 0.2) : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isEarned ? achievement.tier.color : theme.colorScheme.outline, width: 2),
              ),
              child: Icon(_getIcon(achievement.iconName), size: 48, color: isEarned ? achievement.tier.color : theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(achievement.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(achievement.description, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            if (isEarned)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check_circle, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Earned!', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                ]),
              ),
            const SizedBox(height: 24),
            Text('Tips to Earn:', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._getTips(achievement).map((tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [Icon(Icons.lightbulb_outline, size: 18, color: theme.colorScheme.primary), const SizedBox(width: 8), Expanded(child: Text(tip, style: theme.textTheme.bodyMedium))]),
            )),
          ],
        ),
      ),
    );
  }

  List<String> _getTips(Achievement a) {
    switch (a.category) {
      case AchievementCategory.study: return ['Complete daily Bible study sessions', 'Read chapters from Study Guides', 'Set daily reminders'];
      case AchievementCategory.prayer: return ['Log prayers in Prayer section', 'Use Prayer Wall to share requests', 'Set prayer reminders'];
      case AchievementCategory.giving: return ['Make a donation', 'Set up monthly donations', 'Share donation page'];
      case AchievementCategory.outreach: return ['Share app content', 'Invite others to join ALIVE', 'Use share button'];
      case AchievementCategory.game: return ['Take Bible quizzes', 'Answer correctly to earn points', 'Try different levels'];
      case AchievementCategory.streak: return ['Use app every day', 'Complete one activity daily', 'Set reminders'];
      case AchievementCategory.discipleship: return ['Complete study sessions', 'Track contacts', 'Study with others'];
      case AchievementCategory.testimonies: return ['Share your testimony', 'Tell others your story', 'Be encouraging'];
      case AchievementCategory.tracts: return ['Download tracts', 'Read recommended books', 'Share materials'];
      case AchievementCategory.media: return ['Listen to podcasts', 'Complete full sessions', 'Explore different series'];
    }
  }

  IconData _getIcon(String name) {
    const icons = {
      'menu_book': Icons.menu_book, 'school': Icons.school, 'emoji_events': Icons.emoji_events,
      'volunteer_activism': Icons.volunteer_activism, 'favorite': Icons.favorite, 'stars': Icons.stars,
      'card_giftcard': Icons.card_giftcard, 'share': Icons.share, 'record_voice_over': Icons.record_voice_over,
      'local_fire_department': Icons.local_fire_department, 'directions_walk': Icons.directions_walk,
      'headphones': Icons.headphones, 'hearing': Icons.hearing, 'campaign': Icons.campaign,
    };
    return icons[name] ?? Icons.emoji_events;
  }
}
