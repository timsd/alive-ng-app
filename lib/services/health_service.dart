import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/health_models.dart';
import 'package:uuid/uuid.dart';

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
    return HealthData(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      date: DateTime.parse(json['date'] as String),
      waterIntake: json['water_intake'] as int,
      exerciseMinutes: json['exercise_minutes'] as int,
      sunlightMinutes: json['sunlight_minutes'] as int,
      sleepHours: (json['sleep_hours'] as num).toDouble(),
      nutritionScore: json['nutrition_score'] as int,
      temperanceScore: json['temperance_score'] as int,
      freshAirScore: json['fresh_air_score'] as int,
      trustScore: json['trust_score'] as int,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'date': date.toIso8601String().split('T')[0],
      'water_intake': waterIntake,
      'exercise_minutes': exerciseMinutes,
      'sunlight_minutes': sunlightMinutes,
      'sleep_hours': sleepHours,
      'nutrition_score': nutritionScore,
      'temperance_score': temperanceScore,
      'fresh_air_score': freshAirScore,
      'trust_score': trustScore,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
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

  final SupabaseClient _supabase = Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  // Fetch health data for the last 30 days
  Future<List<HealthData>> fetchHealthData(String userId) async {
    try {
      final response = await _supabase
          .from('health_tracking')
          .select('*')
          .eq('user_id', userId)
          .order('date', ascending: false)
          .limit(30);

      return (response as List)
          .map((json) => HealthData.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch health data: $e');
    }
  }

  // Get today's health data
  Future<HealthData?> getTodayHealthData(String userId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final response = await _supabase
          .from('health_tracking')
          .select('*')
          .eq('user_id', userId)
          .eq('date', today)
          .maybeSingle();

      return response != null ? HealthData.fromJson(response) : null;
    } catch (e) {
      throw Exception('Failed to fetch today\'s health data: $e');
    }
  }

  // Save or update health data
  Future<HealthData> saveHealthData(HealthData healthData) async {
    try {
      final response = await _supabase
          .from('health_tracking')
          .upsert(healthData.toJson())
          .select()
          .single();

      return HealthData.fromJson(response);
    } catch (e) {
      throw Exception('Failed to save health data: $e');
    }
  }

  // Delete health data
  Future<void> deleteHealthData(String id) async {
    try {
      await _supabase.from('health_tracking').delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete health data: $e');
    }
  }

  // Calculate health score based on the 8 natural laws
  double calculateHealthScore(HealthData data) {
    final scores = [
      data.nutritionScore,
      data.exerciseMinutes > 0 ? 10 : 0, // Exercise score
      data.waterIntake >= 8
          ? 10
          : (data.waterIntake * 1.25).round(), // Water score
      data.sunlightMinutes >= 15
          ? 10
          : (data.sunlightMinutes * 0.67).round(), // Sunlight score
      data.temperanceScore,
      data.freshAirScore,
      data.sleepHours >= 7
          ? 10
          : (data.sleepHours * 1.43).round(), // Rest score
      data.trustScore,
    ];

    return scores.reduce((a, b) => a + b) / scores.length;
  }

  // === NIGERIAN MEAL PLANS ===

  // Fetch meal plans by region and dietary preferences
  Future<List<NigerianMealPlan>> fetchMealPlans({
    NigerianRegion? region,
    DifficultyLevel? difficulty,
    int? durationDays,
  }) async {
    try {
      dynamic query = _supabase.from('nigerian_meal_plans').select('*');

      if (region != null) {
        query = query.eq('region', region.name);
      }
      if (difficulty != null) {
        query = query.eq('difficulty_level', difficulty.name);
      }
      if (durationDays != null) {
        query = query.eq('duration_days', durationDays);
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map((json) => NigerianMealPlan.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch meal plans: $e');
    }
  }

  // Get meal plan by ID
  Future<NigerianMealPlan?> getMealPlan(String id) async {
    try {
      final response = await _supabase
          .from('nigerian_meal_plans')
          .select('*')
          .eq('id', id)
          .maybeSingle();

      return response != null ? NigerianMealPlan.fromJson(response) : null;
    } catch (e) {
      throw Exception('Failed to fetch meal plan: $e');
    }
  }

  // Search meal plans and recipes
  Future<List<NigerianMealPlan>> searchMealPlans(String query) async {
    try {
      final response = await _supabase
          .from('nigerian_meal_plans')
          .select('*')
          .or('title.ilike.%$query%,description.ilike.%$query%')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => NigerianMealPlan.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to search meal plans: $e');
    }
  }

  // Get featured meal plans
  Future<List<NigerianMealPlan>> getFeaturedMealPlans() async {
    try {
      final response = await _supabase
          .from('nigerian_meal_plans')
          .select('*')
          .eq('is_featured', true)
          .order('created_at', ascending: false)
          .limit(10);

      return (response as List)
          .map((json) => NigerianMealPlan.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch featured meal plans: $e');
    }
  }

  // === WHOLESOME LIVING TIPS ===

  // Fetch wholesome living tips
  Future<List<WholesomeLivingTip>> fetchWholesomeTips({
    String? category,
    int limit = 20,
  }) async {
    try {
      dynamic query = _supabase.from('wholesome_living_tips').select('*');

      if (category != null) {
        query = query.eq('category', category);
      }

      final response =
          await query.order('created_at', ascending: false).limit(limit);

      return (response as List)
          .map((json) => WholesomeLivingTip.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch wholesome tips: $e');
    }
  }

  // Get daily tip
  Future<WholesomeLivingTip?> getDailyTip() async {
    try {
      final today = DateTime.now();
      final dayOfYear = today.difference(DateTime(today.year, 1, 1)).inDays + 1;

      final response = await _supabase
          .from('wholesome_living_tips')
          .select('*')
          .eq('day_of_year', dayOfYear % 365 + 1)
          .maybeSingle();

      return response != null ? WholesomeLivingTip.fromJson(response) : null;
    } catch (e) {
      throw Exception('Failed to fetch daily tip: $e');
    }
  }

  // Search tips
  Future<List<WholesomeLivingTip>> searchTips(String query) async {
    try {
      final response = await _supabase
          .from('wholesome_living_tips')
          .select('*')
          .or('title.ilike.%$query%,content.ilike.%$query%,tags.cs.{"$query"}')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => WholesomeLivingTip.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to search tips: $e');
    }
  }

  // === LIFESTYLE TRACKER ===

  // Fetch user's lifestyle trackers
  Future<List<LifestyleTracker>> fetchLifestyleTrackers(String userId) async {
    try {
      final response = await _supabase
          .from('lifestyle_trackers')
          .select('*')
          .eq('user_id', userId)
          .order('date', ascending: false)
          .limit(30);

      return (response as List)
          .map((json) => LifestyleTracker.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch lifestyle trackers: $e');
    }
  }

  // Save lifestyle tracker data
  Future<LifestyleTracker> saveLifestyleTracker(
      LifestyleTracker tracker) async {
    try {
      final response = await _supabase
          .from('lifestyle_trackers')
          .upsert(tracker.toJson())
          .select()
          .single();

      return LifestyleTracker.fromJson(response);
    } catch (e) {
      throw Exception('Failed to save lifestyle tracker: $e');
    }
  }

  // Get today's lifestyle tracker
  Future<LifestyleTracker?> getTodayLifestyleTracker(String userId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final response = await _supabase
          .from('lifestyle_trackers')
          .select('*')
          .eq('user_id', userId)
          .eq('date', today)
          .maybeSingle();

      return response != null ? LifestyleTracker.fromJson(response) : null;
    } catch (e) {
      throw Exception('Failed to fetch today\'s lifestyle tracker: $e');
    }
  }

  // === LIFESTYLE GOALS ===

  // Fetch user's lifestyle goals
  Future<List<LifestyleGoalSetting>> fetchLifestyleGoals(String userId) async {
    try {
      final response = await _supabase
          .from('lifestyle_goals')
          .select('*')
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => LifestyleGoalSetting.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch lifestyle goals: $e');
    }
  }

  // Create lifestyle goal
  Future<LifestyleGoalSetting> createLifestyleGoal(
      LifestyleGoalSetting goal) async {
    try {
      final response = await _supabase
          .from('lifestyle_goals')
          .insert(goal.toJson())
          .select()
          .single();

      return LifestyleGoalSetting.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create lifestyle goal: $e');
    }
  }

  // Update lifestyle goal
  Future<LifestyleGoalSetting> updateLifestyleGoal(
      LifestyleGoalSetting goal) async {
    try {
      final response = await _supabase
          .from('lifestyle_goals')
          .update(goal.toJson())
          .eq('id', goal.id)
          .select()
          .single();

      return LifestyleGoalSetting.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update lifestyle goal: $e');
    }
  }

  // === USER HEALTH PROFILE ===

  // Get user health profile
  Future<UserHealthProfile?> getUserHealthProfile(String userId) async {
    try {
      final response = await _supabase
          .from('user_health_profiles')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      return response != null ? UserHealthProfile.fromJson(response) : null;
    } catch (e) {
      throw Exception('Failed to fetch user health profile: $e');
    }
  }

  // Save user health profile
  Future<UserHealthProfile> saveUserHealthProfile(
      UserHealthProfile profile) async {
    try {
      final response = await _supabase
          .from('user_health_profiles')
          .upsert(profile.toJson())
          .select()
          .single();

      return UserHealthProfile.fromJson(response);
    } catch (e) {
      throw Exception('Failed to save user health profile: $e');
    }
  }

  // === HEALTH INSIGHTS ===

  // Generate health insights for user
  Future<List<HealthInsight>> generateHealthInsights(String userId) async {
    try {
      // Get recent lifestyle data
      final trackers = await fetchLifestyleTrackers(userId);

      List<HealthInsight> insights = [];

      if (trackers.isNotEmpty) {
        final recent = trackers.first;

        // Water intake insight
        final waterGlasses = recent.metrics['water_glasses'] ?? 0.0;
        final waterTarget = HealthConstants.dailyTargets[NaturalRemedy.water]!['glasses'] as int;
        if (waterGlasses < waterTarget) {
          insights.add(HealthInsight(
            id: _uuid.v4(),
            userId: userId,
            title: 'Increase Water Intake',
            content:
                'You\'re drinking ${waterGlasses.toInt()} glasses of water. Aim for $waterTarget glasses daily.',
            category: waterGlasses < 4 ? 'urgent' : 'moderate',
            recommendations: ['Start your day with a glass of water and keep a water bottle nearby.'],
            data: {
              'type': 'water_intake',
              'bibleVerse': HealthConstants.healthBibleVerses['3 John 1:2'] ?? 'Beloved, I wish above all things that thou mayest prosper and be in health, even as thy soul prospereth.',
              'priority': waterGlasses < 4 ? 'high' : 'medium',
            },
            generatedAt: DateTime.now(),
          ));
        }

        // Exercise insight
        final exerciseMinutes = recent.metrics['exercise_minutes'] ?? 0.0;
        final exerciseTarget = HealthConstants.dailyTargets[NaturalRemedy.exercise]!['minutes'] as int;
        if (exerciseMinutes < exerciseTarget) {
          insights.add(HealthInsight(
            id: _uuid.v4(),
            userId: userId,
            title: 'More Physical Activity Needed',
            content:
                'You exercised for ${exerciseMinutes.toInt()} minutes. Aim for $exerciseTarget minutes daily.',
            category: exerciseMinutes == 0 ? 'urgent' : 'moderate',
            recommendations: ['Try a 15-minute walk after meals or simple stretching exercises.'],
            data: {
              'type': 'exercise',
              'bibleVerse': HealthConstants.healthBibleVerses['Proverbs 31:17'] ?? 'She girdeth her loins with strength, and strengtheneth her arms.',
              'priority': exerciseMinutes == 0 ? 'high' : 'medium',
            },
            generatedAt: DateTime.now(),
          ));
        }

        // Sleep insight
        final sleepHours = recent.metrics['sleep_hours'] ?? 0.0;
        final sleepTarget = HealthConstants.dailyTargets[NaturalRemedy.rest]!['sleep_hours'] as int;
        if (sleepHours < sleepTarget) {
          insights.add(HealthInsight(
            id: _uuid.v4(),
            userId: userId,
            title: 'Improve Sleep Quality',
            content:
                'You slept for ${sleepHours.toInt()} hours. Aim for $sleepTarget hours nightly.',
            category: sleepHours < 6 ? 'urgent' : 'moderate',
            recommendations: ['Establish a bedtime routine and avoid screens 1 hour before sleep.'],
            data: {
              'type': 'rest',
              'bibleVerse': HealthConstants.healthBibleVerses['Ecclesiastes 3:1'] ?? 'To every thing there is a season, and a time to every purpose under the heaven.',
              'priority': sleepHours < 6 ? 'high' : 'medium',
            },
            generatedAt: DateTime.now(),
          ));
        }
      }

      return insights;
    } catch (e) {
      throw Exception('Failed to generate health insights: $e');
    }
  }

  // Get health statistics for user
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

      // Calculate averages
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
        final nutritionScore = (tracker.metrics['nutrition_score'] ?? 0).toDouble();
        final exerciseMinutes = (tracker.metrics['exercise_minutes'] ?? 0).toDouble();
        final waterGlasses = (tracker.metrics['water_glasses'] ?? 0).toDouble();
        final sunlightMinutes = (tracker.metrics['sunlight_minutes'] ?? 0).toDouble();
        final temperanceScore = (tracker.metrics['temperance_score'] ?? 0).toDouble();
        final airQualityScore = (tracker.metrics['air_quality_score'] ?? 0).toDouble();
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
            (sunlightMinutes >= 15
                ? 10
                : sunlightMinutes * 0.67);
        categoryTotals['temperance'] =
            categoryTotals['temperance']! + temperanceScore;
        categoryTotals['air'] =
            categoryTotals['air']! + airQualityScore;
        categoryTotals['rest'] = categoryTotals['rest']! +
            (sleepHours >= 7 ? 10 : sleepHours * 1.43);
        categoryTotals['trust'] = categoryTotals['trust']! + trustScore;
      }

      // Calculate averages
      final averageScore = totalScore / totalDays;
      final categoryAverages =
          categoryTotals.map((key, value) => MapEntry(key, value / totalDays));

      // Find best and worst categories
      final sortedCategories = categoryAverages.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final bestCategory = sortedCategories.first.key;
      final improvementNeeded = sortedCategories.last.key;

      // Calculate streak
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
      throw Exception('Failed to get health statistics: $e');
    }
  }
}




