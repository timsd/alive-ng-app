import 'package:flutter/foundation.dart';

import '../models/achievement_model.dart';
import 'user_statistics_service.dart';

/// Service for managing user achievements.
class AchievementService {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  static AchievementService get instance => _instance;

  static const List<Achievement> _defaultAchievements = [
    Achievement(
      id: 'study_first',
      title: 'First Steps',
      description: 'Complete your first study session',
      category: AchievementCategory.study,
      tier: AchievementTier.bronze,
      iconName: 'menu_book',
      requiredCount: 1,
    ),
    Achievement(
      id: 'study_five',
      title: 'Seeking Knowledge',
      description: 'Complete 5 study sessions',
      category: AchievementCategory.study,
      tier: AchievementTier.bronze,
      iconName: 'auto_stories',
      requiredCount: 5,
    ),
    Achievement(
      id: 'study_twenty',
      title: 'Dedicated Scholar',
      description: 'Complete 20 study sessions',
      category: AchievementCategory.study,
      tier: AchievementTier.silver,
      iconName: 'school',
      requiredCount: 20,
    ),
    Achievement(
      id: 'study_fifty',
      title: 'Bible Master',
      description: 'Complete 50 study sessions',
      category: AchievementCategory.study,
      tier: AchievementTier.gold,
      iconName: 'military_tech',
      requiredCount: 50,
    ),
    Achievement(
      id: 'prayer_first',
      title: 'Prayer Warrior Initiate',
      description: 'Log your first prayer',
      category: AchievementCategory.prayer,
      tier: AchievementTier.bronze,
      iconName: 'volunteer_activism',
      requiredCount: 1,
    ),
    Achievement(
      id: 'prayer_ten',
      title: 'Faithful Intercessor',
      description: 'Log 10 prayers',
      category: AchievementCategory.prayer,
      tier: AchievementTier.bronze,
      iconName: 'favorite',
      requiredCount: 10,
    ),
    Achievement(
      id: 'prayer_fifty',
      title: 'Prayer Champion',
      description: 'Log 50 prayers',
      category: AchievementCategory.prayer,
      tier: AchievementTier.silver,
      iconName: 'stars',
      requiredCount: 50,
    ),
    Achievement(
      id: 'prayer_hundred',
      title: 'Prayer Giant',
      description: 'Log 100 prayers',
      category: AchievementCategory.prayer,
      tier: AchievementTier.gold,
      iconName: 'emoji_events',
      requiredCount: 100,
    ),
    Achievement(
      id: 'giving_first',
      title: 'First Fruit',
      description: 'Make your first donation',
      category: AchievementCategory.giving,
      tier: AchievementTier.bronze,
      iconName: 'card_giftcard',
      requiredCount: 1,
    ),
    Achievement(
      id: 'giving_five',
      title: 'Generous Heart',
      description: 'Make 5 donations',
      category: AchievementCategory.giving,
      tier: AchievementTier.silver,
      iconName: 'handshake',
      requiredCount: 5,
    ),
    Achievement(
      id: 'giving_monthly',
      title: 'Faithful Giver',
      description: 'Set up a monthly donation',
      category: AchievementCategory.giving,
      tier: AchievementTier.gold,
      iconName: 'calendar_month',
      requiredCount: 1,
    ),
    Achievement(
      id: 'outreach_share',
      title: 'Spread the Word',
      description: 'Share content 5 times',
      category: AchievementCategory.outreach,
      tier: AchievementTier.bronze,
      iconName: 'share',
      requiredCount: 5,
    ),
    Achievement(
      id: 'outreach_invite',
      title: 'Invite a Friend',
      description: 'Invite someone to join ALIVE',
      category: AchievementCategory.outreach,
      tier: AchievementTier.silver,
      iconName: 'person_add',
      requiredCount: 1,
    ),
    Achievement(
      id: 'outreach_testimony',
      title: 'Share Your Story',
      description: 'Submit a testimony',
      category: AchievementCategory.outreach,
      tier: AchievementTier.gold,
      iconName: 'record_voice_over',
      requiredCount: 1,
    ),
    Achievement(
      id: 'game_first',
      title: 'Quiz Rookie',
      description: 'Complete your first quiz',
      category: AchievementCategory.game,
      tier: AchievementTier.bronze,
      iconName: 'quiz',
      requiredCount: 1,
    ),
    Achievement(
      id: 'game_perfect',
      title: 'Perfect Score',
      description: 'Get a perfect score on a quiz',
      category: AchievementCategory.game,
      tier: AchievementTier.silver,
      iconName: 'trophy',
      requiredCount: 1,
    ),
    Achievement(
      id: 'game_ten',
      title: 'Bible Trivia Master',
      description: 'Complete 10 quizzes',
      category: AchievementCategory.game,
      tier: AchievementTier.gold,
      iconName: 'workspace_premium',
      requiredCount: 10,
    ),

    // Streak/Consistency Achievements
    Achievement(
      id: 'streak_3',
      title: '3-Day Spark',
      description: 'Maintain a 3-day activity streak',
      category: AchievementCategory.streak,
      tier: AchievementTier.bronze,
      iconName: 'local_fire_department',
      requiredCount: 3,
    ),
    Achievement(
      id: 'streak_7',
      title: '7-Day Walker',
      description: 'Maintain a 7-day activity streak',
      category: AchievementCategory.streak,
      tier: AchievementTier.bronze,
      iconName: 'directions_walk',
      requiredCount: 7,
    ),
    Achievement(
      id: 'streak_30',
      title: '30-Day Unshakable',
      description: 'Maintain a 30-day activity streak',
      category: AchievementCategory.streak,
      tier: AchievementTier.silver,
      iconName: 'emoji_events',
      requiredCount: 30,
    ),
    Achievement(
      id: 'streak_100',
      title: '100-Day Century Club',
      description: 'Maintain a 100-day activity streak',
      category: AchievementCategory.streak,
      tier: AchievementTier.gold,
      iconName: 'military_tech',
      requiredCount: 100,
    ),

    // Discipleship Achievements
    Achievement(
      id: 'discipleship_eager',
      title: 'Eager Disciple',
      description: 'Complete 5 discipleship study sessions',
      category: AchievementCategory.discipleship,
      tier: AchievementTier.bronze,
      iconName: 'school',
      requiredCount: 5,
    ),
    Achievement(
      id: 'discipleship_foundation',
      title: 'Foundation Builder',
      description: 'Complete 20 discipleship study sessions',
      category: AchievementCategory.discipleship,
      tier: AchievementTier.silver,
      iconName: 'foundation',
      requiredCount: 20,
    ),
    Achievement(
      id: 'discipleship_mentor',
      title: 'Kingdom Mentor',
      description: 'Complete 50 discipleship study sessions',
      category: AchievementCategory.discipleship,
      tier: AchievementTier.gold,
      iconName: 'diversity_3',
      requiredCount: 50,
    ),

    // Testimonies Achievements
    Achievement(
      id: 'testimony_praise',
      title: 'Praise Bearer',
      description: 'Submit your first testimony',
      category: AchievementCategory.testimonies,
      tier: AchievementTier.bronze,
      iconName: 'campaign',
      requiredCount: 1,
    ),
    Achievement(
      id: 'testimony_light',
      title: 'Light Shiner',
      description: 'Submit 3 testimonies',
      category: AchievementCategory.testimonies,
      tier: AchievementTier.silver,
      iconName: 'lightbulb',
      requiredCount: 3,
    ),
    Achievement(
      id: 'testimony_beacon',
      title: 'Beacon of Hope',
      description: 'Submit 10 testimonies',
      category: AchievementCategory.testimonies,
      tier: AchievementTier.gold,
      iconName: 'wb_sunny',
      requiredCount: 10,
    ),

    // Tracts & Books Achievements
    Achievement(
      id: 'tracts_distributor',
      title: 'Tract Distributor',
      description: 'Download or share 5 tracts',
      category: AchievementCategory.tracts,
      tier: AchievementTier.bronze,
      iconName: 'share',
      requiredCount: 5,
    ),
    Achievement(
      id: 'tracts_reader',
      title: 'Avid Reader',
      description: 'Read 10 books or tracts',
      category: AchievementCategory.tracts,
      tier: AchievementTier.silver,
      iconName: 'auto_stories',
      requiredCount: 10,
    ),
    Achievement(
      id: 'tracts_ambassador',
      title: 'Truth Ambassador',
      description: 'Read 25 books or tracts',
      category: AchievementCategory.tracts,
      tier: AchievementTier.gold,
      iconName: 'menu_book',
      requiredCount: 25,
    ),

    // Media/Audio Achievements
    Achievement(
      id: 'media_listener',
      title: 'Listener of the Word',
      description: 'Listen to 5 audio messages',
      category: AchievementCategory.media,
      tier: AchievementTier.bronze,
      iconName: 'headphones',
      requiredCount: 5,
    ),
    Achievement(
      id: 'media_deep',
      title: 'Deep Listener',
      description: 'Listen to 20 audio messages',
      category: AchievementCategory.media,
      tier: AchievementTier.silver,
      iconName: 'hearing',
      requiredCount: 20,
    ),
    Achievement(
      id: 'media_scholar',
      title: 'Sermon Scholar',
      description: 'Listen to 50 audio messages',
      category: AchievementCategory.media,
      tier: AchievementTier.gold,
      iconName: 'record_voice_over',
      requiredCount: 50,
    ),
  ];

  List<Achievement> getAllAchievements() => _defaultAchievements;

  List<Achievement> getAchievementsByCategory(AchievementCategory category) {
    return _defaultAchievements.where((a) => a.category == category).toList();
  }

  Future<List<AchievementProgress>> getUserProgress(String userId) async {
    try {
      final stats = await UserStatisticsService.instance.getUserStatistics(userId);
      final prayersOffered = stats['prayers_offered'] ?? 0;
      final studySessions = stats['study_sessions_completed'] ?? 0;

      final progressList = <AchievementProgress>[];

      for (final achievement in _defaultAchievements) {
        int currentCount = 0;
        bool isEarned = false;

        switch (achievement.category) {
          case AchievementCategory.study:
            currentCount = studySessions;
            isEarned = studySessions >= achievement.requiredCount;
            break;
          case AchievementCategory.prayer:
            currentCount = prayersOffered;
            isEarned = prayersOffered >= achievement.requiredCount;
            break;
          case AchievementCategory.streak:
            currentCount = stats['current_streak'] ?? 0;
            isEarned = currentCount >= achievement.requiredCount;
            break;
          case AchievementCategory.discipleship:
            currentCount = stats['discipleship_sessions'] ?? 0;
            isEarned = currentCount >= achievement.requiredCount;
            break;
          case AchievementCategory.testimonies:
            currentCount = stats['testimonies_submitted'] ?? 0;
            isEarned = currentCount >= achievement.requiredCount;
            break;
          case AchievementCategory.tracts:
            currentCount = stats['tracts_read'] ?? 0;
            isEarned = currentCount >= achievement.requiredCount;
            break;
          case AchievementCategory.media:
            currentCount = stats['audio_listened'] ?? 0;
            isEarned = currentCount >= achievement.requiredCount;
            break;
          case AchievementCategory.giving:
            currentCount = stats['donations_count'] ?? 0;
            isEarned = currentCount >= achievement.requiredCount;
            break;
          case AchievementCategory.outreach:
            currentCount = stats['shares_count'] ?? 0;
            isEarned = currentCount >= achievement.requiredCount;
            break;
          case AchievementCategory.game:
            currentCount = stats['quizzes_completed'] ?? 0;
            isEarned = currentCount >= achievement.requiredCount;
            break;
        }

        progressList.add(AchievementProgress(
          achievementId: achievement.id,
          currentCount: currentCount,
          earnedAt: isEarned ? DateTime.now() : null,
          isNew: false,
        ));
      }

      return progressList;
    } catch (e) {
      debugPrint('Error getting achievement progress: $e');
      return [];
    }
  }

  Future<AchievementSummary> getAchievementSummary(String userId) async {
    final progressList = await getUserProgress(userId);
    final earned = progressList.where((p) => p.isEarned).toList();
    final recent = progressList.where((p) => p.isNew).toList();

    return AchievementSummary(
      totalEarned: earned.length,
      totalAvailable: _defaultAchievements.length,
      recentAchievements: recent,
      lastEarnedCategory: earned.isNotEmpty ? _defaultAchievements.firstWhere(
        (a) => a.id == earned.last.achievementId,
      ).category : null,
    );
  }
}
