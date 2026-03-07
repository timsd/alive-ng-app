import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/health_models.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';

class HealthData {
  final String id;
  final String userId;
  final DateTime date;
  final int waterIntake;
  final int exerciseMinutes;
  final int sunlightMinutes;
  final double sleepHours;
  final int nutritionScore;
  final int temperanceScore;
  final int freshAirScore;
  final int trustScore;
  final String? notes;
  final DateTime createdAt;

  const HealthData({
    required this.id,
    required this.userId,
    required this.date,
    required this.waterIntake,
    required this.exerciseMinutes,
    required this.sunlightMinutes,
    required this.sleepHours,
    required this.nutritionScore,
    required this.temperanceScore,
    required this.freshAirScore,
    required this.trustScore,
    this.notes,
    required this.createdAt,
  });

  factory HealthData.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.parse(val);
      if (val is DateTime) return val;
      return DateTime.now();
    }

    return HealthData(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      date: parseDate(json['date']),
      waterIntake: (json['water_intake'] as num).toInt(),
      exerciseMinutes: (json['exercise_minutes'] as num).toInt(),
      sunlightMinutes: (json['sunlight_minutes'] as num).toInt(),
      sleepHours: (json['sleep_hours'] as num).toDouble(),
      nutritionScore: (json['nutrition_score'] as num).toInt(),
      temperanceScore: (json['temperance_score'] as num).toInt(),
      freshAirScore: (json['fresh_air_score'] as num).toInt(),
      trustScore: (json['trust_score'] as num).toInt(),
      notes: json['notes'] as String?,
      createdAt: parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'date': Timestamp.fromDate(date),
      'water_intake': waterIntake,
      'exercise_minutes': exerciseMinutes,
      'sunlight_minutes': sunlightMinutes,
      'sleep_hours': sleepHours,
      'nutrition_score': nutritionScore,
      'temperance_score': temperanceScore,
      'fresh_air_score': freshAirScore,
      'trust_score': trustScore,
      'notes': notes,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  HealthData copyWith({
    String? id,
    String? userId,
    DateTime? date,
    int? waterIntake,
    int? exerciseMinutes,
    int? sunlightMinutes,
    double? sleepHours,
    int? nutritionScore,
    int? temperanceScore,
    int? freshAirScore,
    int? trustScore,
    String? notes,
    DateTime? createdAt,
  }) {
    return HealthData(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      waterIntake: waterIntake ?? this.waterIntake,
      exerciseMinutes: exerciseMinutes ?? this.exerciseMinutes,
      sunlightMinutes: sunlightMinutes ?? this.sunlightMinutes,
      sleepHours: sleepHours ?? this.sleepHours,
      nutritionScore: nutritionScore ?? this.nutritionScore,
      temperanceScore: temperanceScore ?? this.temperanceScore,
      freshAirScore: freshAirScore ?? this.freshAirScore,
      trustScore: trustScore ?? this.trustScore,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  final Uuid _uuid = const Uuid();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger('HealthService');

  // Fetch health data for the last 30 days
  Future<List<HealthData>> fetchHealthData(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('health_tracking')
          .where('user_id', isEqualTo: userId)
          .orderBy('date', descending: true)
          .limit(30)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return HealthData.fromJson(data);
      }).toList();
    } catch (e) {
      _logger.error('Failed to fetch health data: $e');
      throw DatabaseException('Failed to fetch health data', originalError: e);
    }
  }

  // Get today's health data
  Future<HealthData?> getTodayHealthData(String userId) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final snapshot = await _firestore
          .collection('health_tracking')
          .where('user_id', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final data = snapshot.docs.first.data();
      data['id'] = snapshot.docs.first.id;
      return HealthData.fromJson(data);
    } catch (e) {
      _logger.error('Failed to fetch today\'s health data: $e');
      throw DatabaseException('Failed to fetch today\'s health data',
          originalError: e);
    }
  }

  // Save or update health data
  Future<HealthData> saveHealthData(HealthData healthData) async {
    try {
      final docRef =
          _firestore.collection('health_tracking').doc(healthData.id);
      await docRef.set(healthData.toJson(), SetOptions(merge: true));
      return healthData;
    } catch (e) {
      _logger.error('Failed to save health data: $e');
      throw DatabaseException('Failed to save health data', originalError: e);
    }
  }

  // Delete health data
  Future<void> deleteHealthData(String id) async {
    try {
      await _firestore.collection('health_tracking').doc(id).delete();
    } catch (e) {
      _logger.error('Failed to delete health data: $e');
      throw DatabaseException('Failed to delete health data', originalError: e);
    }
  }

  // Calculate health score based on the 8 natural laws
  double calculateHealthScore(HealthData data) {
    final scores = [
      data.nutritionScore,
      data.exerciseMinutes > 0 ? 10 : 0,
      data.waterIntake >= 8 ? 10 : (data.waterIntake * 1.25).round(),
      data.sunlightMinutes >= 15 ? 10 : (data.sunlightMinutes * 0.67).round(),
      data.temperanceScore,
      data.freshAirScore,
      data.sleepHours >= 7 ? 10 : (data.sleepHours * 1.43).round(),
      data.trustScore,
    ];

    return scores.reduce((a, b) => a + b) / scores.length;
  }

  // === NIGERIAN MEAL PLANS ===

  // Fetch meal plans
  Future<List<NigerianMealPlan>> fetchMealPlans({
    NigerianRegion? region,
    DifficultyLevel? difficulty,
    int? durationDays,
  }) async {
    try {
      Query query = _firestore.collection('nigerian_meal_plans');

      if (region != null) {
        query = query.where('region', isEqualTo: region.name);
      }
      if (difficulty != null) {
        query = query.where('difficulty_level', isEqualTo: difficulty.name);
      }
      if (durationDays != null) {
        query = query.where('duration_days', isEqualTo: durationDays);
      }

      final snapshot =
          await query.orderBy('created_at', descending: true).get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return NigerianMealPlan.fromJson(data);
      }).toList();
    } catch (e) {
      _logger.error('Failed to fetch meal plans: $e');
      throw DatabaseException('Failed to fetch meal plans', originalError: e);
    }
  }

  // Get meal plan by ID
  Future<NigerianMealPlan?> getMealPlan(String id) async {
    try {
      final doc =
          await _firestore.collection('nigerian_meal_plans').doc(id).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return NigerianMealPlan.fromJson(data);
    } catch (e) {
      _logger.error('Failed to fetch meal plan: $e');
      throw DatabaseException('Failed to fetch meal plan', originalError: e);
    }
  }

  // Search meal plans and recipes
  Future<List<NigerianMealPlan>> searchMealPlans(String queryText) async {
    try {
      // Client-side filtering as Firestore lacks full-text search
      final snapshot = await _firestore
          .collection('nigerian_meal_plans')
          .orderBy('created_at', descending: true)
          .limit(50)
          .get();

      final allPlans = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return NigerianMealPlan.fromJson(data);
      }).toList();

      if (queryText.isEmpty) return allPlans;

      final lowerQuery = queryText.toLowerCase();
      return allPlans.where((plan) {
        return plan.title.toLowerCase().contains(lowerQuery) ||
            plan.description.toLowerCase().contains(lowerQuery);
      }).toList();
    } catch (e) {
      _logger.error('Failed to search meal plans: $e');
      throw DatabaseException('Failed to search meal plans', originalError: e);
    }
  }

  // Get featured meal plans
  Future<List<NigerianMealPlan>> getFeaturedMealPlans() async {
    try {
      final snapshot = await _firestore
          .collection('nigerian_meal_plans')
          .where('is_featured', isEqualTo: true)
          .orderBy('created_at', descending: true)
          .limit(10)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return NigerianMealPlan.fromJson(data);
      }).toList();
    } catch (e) {
      _logger.error('Failed to fetch featured meal plans: $e');
      throw DatabaseException('Failed to fetch featured meal plans',
          originalError: e);
    }
  }

  // === WHOLESOME LIVING TIPS ===

  Future<List<WholesomeLivingTip>> fetchWholesomeTips({
    String? category,
    int limit = 20,
  }) async {
    try {
      Query query = _firestore.collection('wholesome_living_tips');

      if (category != null) {
        query = query.where('category', isEqualTo: category);
      }

      final snapshot = await query
          .orderBy('created_at', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return WholesomeLivingTip.fromJson(data);
      }).toList();
    } catch (e) {
      _logger.error('Failed to fetch wholesome tips: $e');
      throw DatabaseException('Failed to fetch wholesome tips',
          originalError: e);
    }
  }

  Future<WholesomeLivingTip?> getDailyTip() async {
    try {
      final today = DateTime.now();
      final dayOfYear = today.difference(DateTime(today.year, 1, 1)).inDays + 1;

      final snapshot = await _firestore
          .collection('wholesome_living_tips')
          .where('day_of_year', isEqualTo: dayOfYear % 365 + 1)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final data = snapshot.docs.first.data();
      data['id'] = snapshot.docs.first.id;
      return WholesomeLivingTip.fromJson(data);
    } catch (e) {
      _logger.error('Failed to fetch daily tip: $e');
      throw DatabaseException('Failed to fetch daily tip', originalError: e);
    }
  }

  Future<List<WholesomeLivingTip>> searchTips(String queryText) async {
    try {
      final snapshot = await _firestore
          .collection('wholesome_living_tips')
          .orderBy('created_at', descending: true)
          .limit(50)
          .get();

      final allTips = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return WholesomeLivingTip.fromJson(data);
      }).toList();

      if (queryText.isEmpty) return allTips;

      final lowerQuery = queryText.toLowerCase();
      return allTips.where((tip) {
        return tip.title.toLowerCase().contains(lowerQuery) ||
            tip.content.toLowerCase().contains(lowerQuery) ||
            tip.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
      }).toList();
    } catch (e) {
      _logger.error('Failed to search tips: $e');
      throw DatabaseException('Failed to search tips', originalError: e);
    }
  }

  // === LIFESTYLE TRACKER ===

  Future<List<LifestyleTracker>> fetchLifestyleTrackers(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('lifestyle_trackers')
          .where('user_id', isEqualTo: userId)
          .orderBy('date', descending: true)
          .limit(30)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return LifestyleTracker.fromJson(data);
      }).toList();
    } catch (e) {
      _logger.error('Failed to fetch lifestyle trackers: $e');
      throw DatabaseException('Failed to fetch lifestyle trackers',
          originalError: e);
    }
  }

  Future<LifestyleTracker> saveLifestyleTracker(
      LifestyleTracker tracker) async {
    try {
      final docRef =
          _firestore.collection('lifestyle_trackers').doc(tracker.id);
      await docRef.set(tracker.toJson(), SetOptions(merge: true));
      return tracker;
    } catch (e) {
      _logger.error('Failed to save lifestyle tracker: $e');
      throw DatabaseException('Failed to save lifestyle tracker',
          originalError: e);
    }
  }

  Future<LifestyleTracker?> getTodayLifestyleTracker(String userId) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final snapshot = await _firestore
          .collection('lifestyle_trackers')
          .where('user_id', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final data = snapshot.docs.first.data();
      data['id'] = snapshot.docs.first.id;
      return LifestyleTracker.fromJson(data);
    } catch (e) {
      _logger.error('Failed to fetch today\'s lifestyle tracker: $e');
      throw DatabaseException('Failed to fetch today\'s lifestyle tracker',
          originalError: e);
    }
  }

  // === LIFESTYLE GOALS ===

  Future<List<LifestyleGoalSetting>> fetchLifestyleGoals(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('lifestyle_goals')
          .where('user_id', isEqualTo: userId)
          .where('is_active', isEqualTo: true)
          .orderBy('created_at', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return LifestyleGoalSetting.fromJson(data);
      }).toList();
    } catch (e) {
      _logger.error('Failed to fetch lifestyle goals: $e');
      throw DatabaseException('Failed to fetch lifestyle goals',
          originalError: e);
    }
  }

  Future<LifestyleGoalSetting> createLifestyleGoal(
      LifestyleGoalSetting goal) async {
    try {
      await _firestore
          .collection('lifestyle_goals')
          .doc(goal.id)
          .set(goal.toJson());
      return goal;
    } catch (e) {
      _logger.error('Failed to create lifestyle goal: $e');
      throw DatabaseException('Failed to create lifestyle goal',
          originalError: e);
    }
  }

  Future<LifestyleGoalSetting> updateLifestyleGoal(
      LifestyleGoalSetting goal) async {
    try {
      await _firestore
          .collection('lifestyle_goals')
          .doc(goal.id)
          .update(goal.toJson());
      return goal;
    } catch (e) {
      _logger.error('Failed to update lifestyle goal: $e');
      throw DatabaseException('Failed to update lifestyle goal',
          originalError: e);
    }
  }

  // === USER HEALTH PROFILE ===

  Future<UserHealthProfile?> getUserHealthProfile(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('user_health_profiles')
          .where('user_id', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final data = snapshot.docs.first.data();
      data['id'] = snapshot.docs.first.id;
      return UserHealthProfile.fromJson(data);
    } catch (e) {
      _logger.error('Failed to fetch user health profile: $e');
      throw DatabaseException('Failed to fetch user health profile',
          originalError: e);
    }
  }

  Future<UserHealthProfile> saveUserHealthProfile(
      UserHealthProfile profile) async {
    try {
      final docRef =
          _firestore.collection('user_health_profiles').doc(profile.userId);
      await docRef.set(
        {
          ...profile.toJson(),
          'user_id': profile.userId,
        },
        SetOptions(merge: true),
      );
      return profile;
    } catch (e) {
      _logger.error('Failed to save user health profile: $e');
      throw DatabaseException('Failed to save user health profile',
          originalError: e);
    }
  }

  // === HEALTH INSIGHTS ===

  Future<List<HealthInsight>> generateHealthInsights(String userId) async {
    try {
      final trackers = await fetchLifestyleTrackers(userId);
      List<HealthInsight> insights = [];

      if (trackers.isNotEmpty) {
        final recent = trackers.first;

        // Water
        final waterGlasses = (recent.metrics['water_glasses'] ?? 0).toDouble();
        final waterTarget = (HealthConstants
                .dailyTargets[NaturalRemedy.water]!['glasses'] as int)
            .toDouble();

        if (waterGlasses < waterTarget) {
          insights.add(HealthInsight(
            id: _uuid.v4(),
            userId: userId,
            title: 'Increase Water Intake',
            content:
                'You\'re drinking ${waterGlasses.toInt()} glasses of water. Aim for ${waterTarget.toInt()} glasses daily.',
            category: waterGlasses < 4 ? 'urgent' : 'moderate',
            recommendations: [
              'Start your day with a glass of water and keep a water bottle nearby.'
            ],
            data: {
              'type': 'water_intake',
              'bibleVerse': HealthConstants.healthBibleVerses['3 John 1:2'] ??
                  'Beloved, I wish above all things that thou mayest prosper and be in health, even as thy soul prospereth.',
              'priority': waterGlasses < 4 ? 'high' : 'medium',
            },
            generatedAt: DateTime.now(),
          ));
        }

        // Exercise
        final exerciseMinutes =
            (recent.metrics['exercise_minutes'] ?? 0).toDouble();
        final exerciseTarget = (HealthConstants
                .dailyTargets[NaturalRemedy.exercise]!['minutes'] as int)
            .toDouble();

        if (exerciseMinutes < exerciseTarget) {
          insights.add(HealthInsight(
            id: _uuid.v4(),
            userId: userId,
            title: 'More Physical Activity Needed',
            content:
                'You exercised for ${exerciseMinutes.toInt()} minutes. Aim for ${exerciseTarget.toInt()} minutes daily.',
            category: exerciseMinutes == 0 ? 'urgent' : 'moderate',
            recommendations: [
              'Try a 15-minute walk after meals or simple stretching exercises.'
            ],
            data: {
              'type': 'exercise',
              'bibleVerse': HealthConstants
                      .healthBibleVerses['Proverbs 31:17'] ??
                  'She girdeth her loins with strength, and strengtheneth her arms.',
              'priority': exerciseMinutes == 0 ? 'high' : 'medium',
            },
            generatedAt: DateTime.now(),
          ));
        }

        // Sleep
        final sleepHours = (recent.metrics['sleep_hours'] ?? 0).toDouble();
        final sleepTarget = (HealthConstants
                .dailyTargets[NaturalRemedy.rest]!['sleep_hours'] as int)
            .toDouble();

        if (sleepHours < sleepTarget) {
          insights.add(HealthInsight(
            id: _uuid.v4(),
            userId: userId,
            title: 'Improve Sleep Quality',
            content:
                'You slept for ${sleepHours.toInt()} hours. Aim for ${sleepTarget.toInt()} hours nightly.',
            category: sleepHours < 6 ? 'urgent' : 'moderate',
            recommendations: [
              'Establish a bedtime routine and avoid screens 1 hour before sleep.'
            ],
            data: {
              'type': 'rest',
              'bibleVerse': HealthConstants
                      .healthBibleVerses['Ecclesiastes 3:1'] ??
                  'To every thing there is a season, and a time to every purpose under the heaven.',
              'priority': sleepHours < 6 ? 'high' : 'medium',
            },
            generatedAt: DateTime.now(),
          ));
        }
      }
      return insights;
    } catch (e) {
      _logger.error('Failed to generate health insights: $e');
      throw DatabaseException('Failed to generate health insights',
          originalError: e);
    }
  }

  // === STATISTICS ===
  Future<Map<String, dynamic>> getHealthStatistics(String userId) async {
    try {
      final trackers = await fetchLifestyleTrackers(userId);

      if (trackers.isEmpty) {
        return {
          'totalDays': 0,
          'averageScore': 0.0,
          'streakDays': 0,
          'bestCategory': 'none',
          'improvementNeeded': 'none',
        };
      }

      final totalDays = trackers.length;
      double totalScore = 0;
      Map<String, double> categoryTotals = {
        'nutrition': 0,
        'exercise': 0,
        'water': 0,
        'sunlight': 0,
        'temperance': 0,
        'air': 0,
        'rest': 0,
        'trust': 0,
      };

      for (final tracker in trackers) {
        final overallScore = (tracker.metrics['overall_score'] ?? 0).toDouble();
        final nutritionScore =
            (tracker.metrics['nutrition_score'] ?? 0).toDouble();
        final exerciseMinutes =
            (tracker.metrics['exercise_minutes'] ?? 0).toDouble();
        final waterGlasses = (tracker.metrics['water_glasses'] ?? 0).toDouble();
        final sunlightMinutes =
            (tracker.metrics['sunlight_minutes'] ?? 0).toDouble();
        final temperanceScore =
            (tracker.metrics['temperance_score'] ?? 0).toDouble();
        final airQualityScore =
            (tracker.metrics['air_quality_score'] ?? 0).toDouble();
        final sleepHours = (tracker.metrics['sleep_hours'] ?? 0).toDouble();
        final trustScore = (tracker.metrics['trust_score'] ?? 0).toDouble();

        totalScore += overallScore;
        categoryTotals['nutrition'] =
            categoryTotals['nutrition']! + nutritionScore;
        categoryTotals['exercise'] = categoryTotals['exercise']! +
            (exerciseMinutes >= 30 ? 10 : exerciseMinutes / 3);
        categoryTotals['water'] = categoryTotals['water']! +
            (waterGlasses >= 8 ? 10 : waterGlasses * 1.25);
        categoryTotals['sunlight'] = categoryTotals['sunlight']! +
            (sunlightMinutes >= 15 ? 10 : sunlightMinutes * 0.67);
        categoryTotals['temperance'] =
            categoryTotals['temperance']! + temperanceScore;
        categoryTotals['air'] = categoryTotals['air']! + airQualityScore;
        categoryTotals['rest'] = categoryTotals['rest']! +
            (sleepHours >= 7 ? 10 : sleepHours * 1.43);
        categoryTotals['trust'] = categoryTotals['trust']! + trustScore;
      }

      final averageScore = totalScore / totalDays;
      final categoryAverages =
          categoryTotals.map((key, value) => MapEntry(key, value / totalDays));

      final sortedCategories = categoryAverages.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final bestCategory = sortedCategories.first.key;
      final improvementNeeded = sortedCategories.last.key;

      int streakDays = 0;
      for (final tracker in trackers) {
        final overallScore = (tracker.metrics['overall_score'] ?? 0).toDouble();
        if (overallScore >= 7.0) {
          streakDays++;
        } else {
          break;
        }
      }

      return {
        'totalDays': totalDays,
        'averageScore': averageScore,
        'streakDays': streakDays,
        'bestCategory': bestCategory,
        'improvementNeeded': improvementNeeded,
        'categoryAverages': categoryAverages,
      };
    } catch (e) {
      _logger.error('Failed to get health statistics: $e');
      throw DatabaseException('Failed to get health statistics',
          originalError: e);
    }
  }
}
