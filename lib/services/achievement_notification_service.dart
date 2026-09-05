import 'package:flutter/material.dart';

import '../models/achievement_model.dart';

/// Service for showing achievement earned notifications.
class AchievementNotificationService {
  static final AchievementNotificationService _instance = AchievementNotificationService._internal();
  factory AchievementNotificationService() => _instance;
  AchievementNotificationService._internal();

  static AchievementNotificationService get instance => _instance;

  /// Show a snackbar notification when an achievement is earned.
  void showAchievementEarned(BuildContext context, Achievement achievement) {
    final theme = Theme.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: achievement.tier.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getIconData(achievement.iconName),
                color: achievement.tier.color,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Achievement Earned!',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onInverseSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    achievement.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onInverseSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.inverseSurface,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'menu_book': return Icons.menu_book;
      case 'auto_stories': return Icons.auto_stories;
      case 'school': return Icons.school;
      case 'military_tech': return Icons.military_tech;
      case 'volunteer_activism': return Icons.volunteer_activism;
      case 'favorite': return Icons.favorite;
      case 'stars': return Icons.stars;
      case 'emoji_events': return Icons.emoji_events;
      case 'card_giftcard': return Icons.card_giftcard;
      case 'handshake': return Icons.handshake;
      case 'calendar_month': return Icons.calendar_month;
      case 'share': return Icons.share;
      case 'person_add': return Icons.person_add;
      case 'record_voice_over': return Icons.record_voice_over;
      case 'quiz': return Icons.quiz;
      case 'workspace_premium': return Icons.workspace_premium;
      case 'local_fire_department': return Icons.local_fire_department;
      case 'directions_walk': return Icons.directions_walk;
      case 'foundation': return Icons.foundation;
      case 'diversity_3': return Icons.diversity_3;
      case 'campaign': return Icons.campaign;
      case 'lightbulb': return Icons.lightbulb;
      case 'wb_sunny': return Icons.wb_sunny;
      case 'headphones': return Icons.headphones;
      case 'hearing': return Icons.hearing;
      default: return Icons.emoji_events;
    }
  }
}
