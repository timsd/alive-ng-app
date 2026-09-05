import 'package:flutter/material.dart';

/// Domain model representing a user achievement badge.
///
/// SDK-agnostic — MUST NOT import any third-party packages.
/// This model is used across UI, providers, and services.

/// Categories of achievements.
enum AchievementCategory {
  study('Study', Icons.menu_book),
  prayer('Prayer', Icons.volunteer_activism),
  giving('Giving', Icons.card_giftcard),
  outreach('Outreach', Icons.people_outline),
  game('Game', Icons.sports_esports),
  streak('Streak', Icons.local_fire_department),
  discipleship('Discipleship', Icons.school),
  testimonies('Testimonies', Icons.record_voice_over),
  tracts('Tracts & Books', Icons.menu_book),
  media('Media/Audio', Icons.headphones);

  final String displayName;
  final IconData icon;

  const AchievementCategory(this.displayName, this.icon);
}

/// Difficulty/rarity levels for achievements.
enum AchievementTier {
  bronze('Bronze', Color(0xFFCD7F32)),
  silver('Silver', Color(0xFFC0C0C0)),
  gold('Gold', Color(0xFFFFD700)),
  platinum('Platinum', Color(0xFFE5E4E2));

  final String displayName;
  final Color color;

  const AchievementTier(this.displayName, this.color);
}

/// A single achievement that can be earned by the user.
class Achievement {
  final String id;
  final String title;
  final String description;
  final AchievementCategory category;
  final AchievementTier tier;
  final String iconName;
  final int requiredCount;
  final bool isSecret;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.tier,
    required this.iconName,
    required this.requiredCount,
    this.isSecret = false,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: AchievementCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => AchievementCategory.study,
      ),
      tier: AchievementTier.values.firstWhere(
        (e) => e.name == json['tier'],
        orElse: () => AchievementTier.bronze,
      ),
      iconName: json['icon_name'] as String,
      requiredCount: (json['required_count'] as num).toInt(),
      isSecret: json['is_secret'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category.name,
      'tier': tier.name,
      'icon_name': iconName,
      'required_count': requiredCount,
      'is_secret': isSecret,
    };
  }
}

/// Tracks a user's progress toward a specific achievement.
class AchievementProgress {
  final String achievementId;
  final int currentCount;
  final DateTime? earnedAt;
  final bool isNew;

  const AchievementProgress({
    required this.achievementId,
    required this.currentCount,
    this.earnedAt,
    this.isNew = false,
  });

  bool get isEarned => earnedAt != null;

  double get progressPercentage {
    // Will be calculated against the achievement's requiredCount
    return currentCount.toDouble();
  }

  factory AchievementProgress.fromJson(Map<String, dynamic> json) {
    return AchievementProgress(
      achievementId: json['achievement_id'] as String,
      currentCount: (json['current_count'] as num).toInt(),
      earnedAt: json['earned_at'] != null
          ? DateTime.parse(json['earned_at'] as String)
          : null,
      isNew: json['is_new'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'achievement_id': achievementId,
      'current_count': currentCount,
      'earned_at': earnedAt?.toIso8601String(),
      'is_new': isNew,
    };
  }
}

/// Aggregated achievement data for display.
class AchievementSummary {
  final int totalEarned;
  final int totalAvailable;
  final List<AchievementProgress> recentAchievements;
  final AchievementCategory? lastEarnedCategory;

  const AchievementSummary({
    required this.totalEarned,
    required this.totalAvailable,
    required this.recentAchievements,
    this.lastEarnedCategory,
  });

  double get completionPercentage =>
      totalAvailable > 0 ? (totalEarned / totalAvailable * 100) : 0;
}
