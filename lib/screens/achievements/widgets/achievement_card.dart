import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/achievement_model.dart';
import '../achievement_detail_screen.dart';

class AchievementCard extends StatelessWidget {
  const AchievementCard({
    super.key,
    required this.achievement,
    this.progress,
  });

  final Achievement achievement;
  final AchievementProgress? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEarned = progress?.isEarned ?? false;
    final progressPercent = progress != null && achievement.requiredCount > 0
        ? (progress!.currentCount / achievement.requiredCount).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isEarned ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isEarned
              ? achievement.tier.color.withValues(alpha: 0.8)
              : theme.colorScheme.outline.withValues(alpha: 0.2),
          width: isEarned ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AchievementDetailScreen(
                achievement: achievement,
                progress: progress,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildBadgeIcon(context, theme, isEarned),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDetails(
                    context, theme, isEarned, progressPercent),
              ),
              if (isEarned)
                IconButton(
                  icon: Icon(
                    Icons.share_rounded,
                    color: achievement.tier.color,
                    size: 20,
                  ),
                  tooltip: 'Share Achievement',
                  onPressed: () => _shareAchievement(context),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareAchievement(BuildContext context) {
    SharePlus.instance.share(
      ShareParams(
        text:
            '🏆 I unlocked the "${achievement.title}" badge (${achievement.tier.displayName} Tier) in ALIVE Nigeria!\n\n"${achievement.description}"\n\nJoin me in study and mission on ALIVE Nigeria: https://app.alivenigeria.org',
        subject: 'ALIVE Nigeria Achievement: ${achievement.title}',
      ),
    );
  }

  Widget _buildBadgeIcon(BuildContext context, ThemeData theme, bool isEarned) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: isEarned
            ? achievement.tier.color.withValues(alpha: 0.18)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isEarned
              ? achievement.tier.color
              : theme.colorScheme.outline.withValues(alpha: 0.3),
          width: isEarned ? 2.5 : 1.5,
        ),
        boxShadow: isEarned
            ? [
                BoxShadow(
                  color: achievement.tier.color.withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Icon(
        _getIconData(achievement.iconName),
        size: 30,
        color: isEarned
            ? achievement.tier.color
            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildDetails(BuildContext context, ThemeData theme, bool isEarned, double progressPercent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                achievement.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isEarned
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: achievement.tier.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                achievement.tier.displayName,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: achievement.tier.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          achievement.description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        if (!isEarned && progress != null) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progressPercent,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(achievement.tier.color),
            minHeight: 4,
          ),
          const SizedBox(height: 4),
          Text(
            '${progress!.currentCount} / ${achievement.requiredCount}',
            style: theme.textTheme.labelSmall,
          ),
        ],
        if (isEarned)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(Icons.verified_rounded, size: 14, color: achievement.tier.color),
                const SizedBox(width: 4),
                Text(
                  'Earned Badge',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: achievement.tier.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'menu_book':
        return Icons.menu_book;
      case 'auto_stories':
        return Icons.auto_stories;
      case 'school':
        return Icons.school;
      case 'military_tech':
        return Icons.military_tech;
      case 'volunteer_activism':
        return Icons.volunteer_activism;
      case 'favorite':
        return Icons.favorite;
      case 'stars':
        return Icons.stars;
      case 'emoji_events':
        return Icons.emoji_events;
      case 'card_giftcard':
        return Icons.card_giftcard;
      case 'handshake':
        return Icons.handshake;
      case 'calendar_month':
        return Icons.calendar_month;
      case 'share':
        return Icons.share;
      case 'person_add':
        return Icons.person_add;
      case 'record_voice_over':
        return Icons.record_voice_over;
      case 'quiz':
        return Icons.quiz;
      case 'trophy':
        return Icons.emoji_events;
      case 'workspace_premium':
        return Icons.workspace_premium;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'directions_walk':
        return Icons.directions_walk;
      case 'foundation':
        return Icons.foundation;
      case 'diversity_3':
        return Icons.diversity_3;
      case 'campaign':
        return Icons.campaign;
      case 'lightbulb':
        return Icons.lightbulb;
      case 'wb_sunny':
        return Icons.wb_sunny;
      case 'headphones':
        return Icons.headphones;
      case 'hearing':
        return Icons.hearing;
      default:
        return Icons.emoji_events;
    }
  }
}
