import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:uuid/uuid.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
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
    return HealthData(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      date: HealthService._parseDate(json['date']),
      waterIntake: HealthService._int(json['water_intake']),
      exerciseMinutes: HealthService._int(json['exercise_minutes']),
      sunlightMinutes: HealthService._int(json['sunlight_minutes']),
      sleepHours: HealthService._double(json['sleep_hours']),
      nutritionScore: HealthService._int(json['nutrition_score']),
      temperanceScore: HealthService._int(json['temperance_score']),
      freshAirScore: HealthService._int(json['fresh_air_score']),
      trustScore:
          HealthService._int(json['trust_score'] ?? json['trust_in_god_score']),
      notes: json['notes'] as String?,
      createdAt: HealthService._parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'date': date.toUtc().toIso8601String(),
      'water_intake': waterIntake,
      'exercise_minutes': exerciseMinutes,
      'sunlight_minutes': sunlightMinutes,
      'sleep_hours': sleepHours,
      'nutrition_score': nutritionScore,
      'temperance_score': temperanceScore,
      'fresh_air_score': freshAirScore,
      'trust_score': trustScore,
      'trust_in_god_score': trustScore,
      'notes': notes,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
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
  final TablesDB _tables = TablesDB(appwriteClient);
  final Logger _logger = Logger('HealthService');

  Future<List<HealthData>> fetchHealthData(String userId) async {
    try {
      final docs = await _list(
        AppwriteBackendConfig.healthTrackingCollectionId,
        queries: [
          Query.equal('user_id', userId),
          Query.orderDesc('date'),
          Query.limit(30),
        ],
      );
      return docs.map(HealthData.fromJson).toList();
    } catch (e) {
      _logger.error('Failed to fetch health data', e);
      throw DatabaseException('Failed to fetch health data', originalError: e);
    }
  }

  Future<HealthData?> getTodayHealthData(String userId) async {
    try {
      final range = _todayRange();
      final docs = await _list(
        AppwriteBackendConfig.healthTrackingCollectionId,
        queries: [
          Query.equal('user_id', userId),
          Query.greaterThanEqual('date', range.$1),
          Query.lessThanEqual('date', range.$2),
          Query.limit(1),
        ],
      );
      return docs.isEmpty ? null : HealthData.fromJson(docs.first);
    } catch (e) {
      _logger.error('Failed to fetch today health data', e);
      throw DatabaseException('Failed to fetch today health data',
          originalError: e);
    }
  }

  Future<HealthData> saveHealthData(HealthData healthData) async {
    try {
      await _upsert(
        AppwriteBackendConfig.healthTrackingCollectionId,
        healthData.id,
        healthData.toJson(),
      );
      return healthData;
    } catch (e) {
      _logger.error('Failed to save health data', e);
      throw DatabaseException('Failed to save health data', originalError: e);
    }
  }

  Future<void> deleteHealthData(String id) async {
    try {
      await _tables.deleteRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.healthTrackingCollectionId,
        rowId: id,
      );
    } catch (e) {
      _logger.error('Failed to delete health data', e);
      throw DatabaseException('Failed to delete health data', originalError: e);
    }
  }

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

  Future<List<NigerianMealPlan>> fetchMealPlans({
    NigerianRegion? region,
    DifficultyLevel? difficulty,
    int? durationDays,
  }) async {
    try {
      final docs = await _list(
        'nigerian_meal_plans',
        queries: [
          if (region != null) Query.equal('region', region.name),
          Query.orderDesc('created_at'),
          Query.limit(100),
        ],
      );
      return docs
          .where((doc) =>
              difficulty == null ||
              doc['difficulty_level'] == difficulty.name ||
              doc['difficulty'] == difficulty.name)
          .where((doc) =>
              durationDays == null ||
              _int(doc['duration_days']) == durationDays)
          .map((doc) => NigerianMealPlan.fromJson(_mealPlanJson(doc)))
          .toList();
    } catch (e) {
      _logger.error('Failed to fetch meal plans', e);
      throw DatabaseException('Failed to fetch meal plans', originalError: e);
    }
  }

  Future<NigerianMealPlan?> getMealPlan(String id) async {
    try {
      final row = await _tables.getRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: 'nigerian_meal_plans',
        rowId: id,
      );
      return NigerianMealPlan.fromJson(_mealPlanJson(_rowData(row)));
    } on AppwriteException catch (e) {
      if (e.code == 404) return null;
      rethrow;
    } catch (e) {
      _logger.error('Failed to fetch meal plan', e);
      throw DatabaseException('Failed to fetch meal plan', originalError: e);
    }
  }

  Future<List<NigerianMealPlan>> searchMealPlans(String queryText) async {
    try {
      final plans = await fetchMealPlans();
      if (queryText.isEmpty) return plans;

      final lowerQuery = queryText.toLowerCase();
      return plans.where((plan) {
        return plan.title.toLowerCase().contains(lowerQuery) ||
            plan.description.toLowerCase().contains(lowerQuery);
      }).toList();
    } catch (e) {
      _logger.error('Failed to search meal plans', e);
      throw DatabaseException('Failed to search meal plans', originalError: e);
    }
  }

  Future<List<NigerianMealPlan>> getFeaturedMealPlans() async {
    try {
      final docs = await _list(
        'nigerian_meal_plans',
        queries: [
          Query.orderDesc('created_at'),
          Query.limit(50),
        ],
      );
      final featured = docs.where((doc) => doc['is_featured'] == true).toList();
      return (featured.isEmpty ? docs.take(10) : featured.take(10))
          .map((doc) => NigerianMealPlan.fromJson(_mealPlanJson(doc)))
          .toList();
    } catch (e) {
      _logger.error('Failed to fetch featured meal plans', e);
      throw DatabaseException('Failed to fetch featured meal plans',
          originalError: e);
    }
  }

  Future<List<WholesomeLivingTip>> fetchWholesomeTips({
    String? category,
    int limit = 20,
  }) async {
    try {
      final docs = await _list(
        'wholesome_living_tips',
        queries: [
          if (category != null) Query.equal('category', category),
          Query.orderDesc('created_at'),
          Query.limit(limit),
        ],
      );
      return docs
          .map((doc) => WholesomeLivingTip.fromJson(_tipJson(doc)))
          .toList();
    } catch (e) {
      _logger.error('Failed to fetch wholesome tips', e);
      throw DatabaseException('Failed to fetch wholesome tips',
          originalError: e);
    }
  }

  Future<WholesomeLivingTip?> getDailyTip() async {
    try {
      final docs = await _list(
        'wholesome_living_tips',
        queries: [
          Query.orderDesc('created_at'),
          Query.limit(30),
        ],
      );
      if (docs.isEmpty) return null;
      final dayOfYear =
          DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
      final doc = docs[dayOfYear % docs.length];
      return WholesomeLivingTip.fromJson(_tipJson(doc));
    } catch (e) {
      _logger.error('Failed to fetch daily tip', e);
      throw DatabaseException('Failed to fetch daily tip', originalError: e);
    }
  }

  Future<List<WholesomeLivingTip>> searchTips(String queryText) async {
    try {
      final tips = await fetchWholesomeTips(limit: 50);
      if (queryText.isEmpty) return tips;

      final lowerQuery = queryText.toLowerCase();
      return tips.where((tip) {
        return tip.title.toLowerCase().contains(lowerQuery) ||
            tip.content.toLowerCase().contains(lowerQuery) ||
            tip.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
      }).toList();
    } catch (e) {
      _logger.error('Failed to search tips', e);
      throw DatabaseException('Failed to search tips', originalError: e);
    }
  }

  Future<List<LifestyleTracker>> fetchLifestyleTrackers(String userId) async {
    try {
      final docs = await _list(
        'lifestyle_trackers',
        queries: [
          Query.equal('user_id', userId),
          Query.orderDesc('date'),
          Query.limit(30),
        ],
      );
      return docs
          .map((doc) => LifestyleTracker.fromJson(_lifestyleTrackerJson(doc)))
          .toList();
    } catch (e) {
      _logger.error('Failed to fetch lifestyle trackers', e);
      throw DatabaseException('Failed to fetch lifestyle trackers',
          originalError: e);
    }
  }

  Future<LifestyleTracker> saveLifestyleTracker(
      LifestyleTracker tracker) async {
    try {
      await _upsert(
          'lifestyle_trackers', tracker.id, _lifestyleTrackerWrite(tracker));
      return tracker;
    } catch (e) {
      _logger.error('Failed to save lifestyle tracker', e);
      throw DatabaseException('Failed to save lifestyle tracker',
          originalError: e);
    }
  }

  Future<LifestyleTracker?> getTodayLifestyleTracker(String userId) async {
    try {
      final range = _todayRange();
      final docs = await _list(
        'lifestyle_trackers',
        queries: [
          Query.equal('user_id', userId),
          Query.greaterThanEqual('date', range.$1),
          Query.lessThanEqual('date', range.$2),
          Query.limit(1),
        ],
      );
      return docs.isEmpty
          ? null
          : LifestyleTracker.fromJson(_lifestyleTrackerJson(docs.first));
    } catch (e) {
      _logger.error('Failed to fetch today lifestyle tracker', e);
      throw DatabaseException('Failed to fetch today lifestyle tracker',
          originalError: e);
    }
  }

  Future<List<LifestyleGoalSetting>> fetchLifestyleGoals(String userId) async {
    try {
      final docs = await _list(
        'lifestyle_goals',
        queries: [
          Query.equal('user_id', userId),
          Query.equal('is_active', true),
          Query.orderDesc('created_at'),
        ],
      );
      return docs
          .map((doc) => LifestyleGoalSetting.fromJson(_goalJson(doc)))
          .toList();
    } catch (e) {
      _logger.error('Failed to fetch lifestyle goals', e);
      throw DatabaseException('Failed to fetch lifestyle goals',
          originalError: e);
    }
  }

  Future<LifestyleGoalSetting> createLifestyleGoal(
      LifestyleGoalSetting goal) async {
    try {
      await _upsert('lifestyle_goals', goal.id, _goalWrite(goal));
      return goal;
    } catch (e) {
      _logger.error('Failed to create lifestyle goal', e);
      throw DatabaseException('Failed to create lifestyle goal',
          originalError: e);
    }
  }

  Future<LifestyleGoalSetting> updateLifestyleGoal(
      LifestyleGoalSetting goal) async {
    try {
      await _upsert('lifestyle_goals', goal.id, _goalWrite(goal));
      return goal;
    } catch (e) {
      _logger.error('Failed to update lifestyle goal', e);
      throw DatabaseException('Failed to update lifestyle goal',
          originalError: e);
    }
  }

  Future<UserHealthProfile?> getUserHealthProfile(String userId) async {
    try {
      final docs = await _list(
        'user_health_profiles',
        queries: [
          Query.equal('user_id', userId),
          Query.limit(1),
        ],
      );
      return docs.isEmpty
          ? null
          : UserHealthProfile.fromJson(_profileJson(docs.first));
    } catch (e) {
      _logger.error('Failed to fetch user health profile', e);
      throw DatabaseException('Failed to fetch user health profile',
          originalError: e);
    }
  }

  Future<UserHealthProfile> saveUserHealthProfile(
      UserHealthProfile profile) async {
    try {
      await _upsert(
        'user_health_profiles',
        profile.userId,
        _profileWrite(profile),
      );
      return profile;
    } catch (e) {
      _logger.error('Failed to save user health profile', e);
      throw DatabaseException('Failed to save user health profile',
          originalError: e);
    }
  }

  Future<List<HealthInsight>> generateHealthInsights(String userId) async {
    try {
      final trackers = await fetchLifestyleTrackers(userId);
      final insights = <HealthInsight>[];

      if (trackers.isNotEmpty) {
        final recent = trackers.first;
        final waterGlasses = (recent.metrics['water_glasses'] ?? 0).toDouble();
        final waterTarget = (HealthConstants
                .dailyTargets[NaturalRemedy.water]!['glasses'] as int)
            .toDouble();

        if (waterGlasses < waterTarget) {
          insights.add(_insight(
            userId: userId,
            title: 'Increase Water Intake',
            content:
                'You are drinking ${waterGlasses.toInt()} glasses of water. Aim for ${waterTarget.toInt()} glasses daily.',
            category: waterGlasses < 4 ? 'urgent' : 'moderate',
            recommendation:
                'Start your day with a glass of water and keep a water bottle nearby.',
            type: 'water_intake',
            priority: waterGlasses < 4 ? 'high' : 'medium',
          ));
        }

        final exerciseMinutes =
            (recent.metrics['exercise_minutes'] ?? 0).toDouble();
        final exerciseTarget = (HealthConstants
                .dailyTargets[NaturalRemedy.exercise]!['minutes'] as int)
            .toDouble();

        if (exerciseMinutes < exerciseTarget) {
          insights.add(_insight(
            userId: userId,
            title: 'More Physical Activity Needed',
            content:
                'You exercised for ${exerciseMinutes.toInt()} minutes. Aim for ${exerciseTarget.toInt()} minutes daily.',
            category: exerciseMinutes == 0 ? 'urgent' : 'moderate',
            recommendation:
                'Try a 15-minute walk after meals or simple stretching exercises.',
            type: 'exercise',
            priority: exerciseMinutes == 0 ? 'high' : 'medium',
          ));
        }

        final sleepHours = (recent.metrics['sleep_hours'] ?? 0).toDouble();
        final sleepTarget = (HealthConstants
                .dailyTargets[NaturalRemedy.rest]!['sleep_hours'] as int)
            .toDouble();

        if (sleepHours < sleepTarget) {
          insights.add(_insight(
            userId: userId,
            title: 'Improve Sleep Quality',
            content:
                'You slept for ${sleepHours.toInt()} hours. Aim for ${sleepTarget.toInt()} hours nightly.',
            category: sleepHours < 6 ? 'urgent' : 'moderate',
            recommendation:
                'Establish a bedtime routine and avoid screens 1 hour before sleep.',
            type: 'rest',
            priority: sleepHours < 6 ? 'high' : 'medium',
          ));
        }
      }
      return insights;
    } catch (e) {
      _logger.error('Failed to generate health insights', e);
      throw DatabaseException('Failed to generate health insights',
          originalError: e);
    }
  }

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

      final categoryTotals = <String, double>{
        'nutrition': 0,
        'exercise': 0,
        'water': 0,
        'sunlight': 0,
        'temperance': 0,
        'air': 0,
        'rest': 0,
        'trust': 0,
      };
      var totalScore = 0.0;

      for (final tracker in trackers) {
        final metrics = tracker.metrics;
        final overallScore = (metrics['overall_score'] ?? 0).toDouble();
        totalScore += overallScore;
        categoryTotals['nutrition'] = categoryTotals['nutrition']! +
            (metrics['nutrition_score'] ?? 0).toDouble();
        categoryTotals['exercise'] = categoryTotals['exercise']! +
            ((metrics['exercise_minutes'] ?? 0).toDouble() >= 30
                ? 10
                : (metrics['exercise_minutes'] ?? 0).toDouble() / 3);
        categoryTotals['water'] = categoryTotals['water']! +
            ((metrics['water_glasses'] ?? 0).toDouble() >= 8
                ? 10
                : (metrics['water_glasses'] ?? 0).toDouble() * 1.25);
        categoryTotals['sunlight'] = categoryTotals['sunlight']! +
            ((metrics['sunlight_minutes'] ?? 0).toDouble() >= 15
                ? 10
                : (metrics['sunlight_minutes'] ?? 0).toDouble() * 0.67);
        categoryTotals['temperance'] = categoryTotals['temperance']! +
            (metrics['temperance_score'] ?? 0).toDouble();
        categoryTotals['air'] = categoryTotals['air']! +
            (metrics['air_quality_score'] ?? 0).toDouble();
        categoryTotals['rest'] = categoryTotals['rest']! +
            ((metrics['sleep_hours'] ?? 0).toDouble() >= 7
                ? 10
                : (metrics['sleep_hours'] ?? 0).toDouble() * 1.43);
        categoryTotals['trust'] =
            categoryTotals['trust']! + (metrics['trust_score'] ?? 0).toDouble();
      }

      final totalDays = trackers.length;
      final categoryAverages =
          categoryTotals.map((key, value) => MapEntry(key, value / totalDays));
      final sortedCategories = categoryAverages.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      var streakDays = 0;
      for (final tracker in trackers) {
        if ((tracker.metrics['overall_score'] ?? 0).toDouble() >= 7.0) {
          streakDays++;
        } else {
          break;
        }
      }

      return {
        'totalDays': totalDays,
        'averageScore': totalScore / totalDays,
        'streakDays': streakDays,
        'bestCategory': sortedCategories.first.key,
        'improvementNeeded': sortedCategories.last.key,
        'categoryAverages': categoryAverages,
      };
    } catch (e) {
      _logger.error('Failed to get health statistics', e);
      throw DatabaseException('Failed to get health statistics',
          originalError: e);
    }
  }

  Future<List<Map<String, dynamic>>> _list(
    String collectionId, {
    List<String> queries = const [],
  }) async {
    final response = await _tables.listRows(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: collectionId,
      queries: queries,
    );
    return response.rows.map(_rowData).toList();
  }

  Map<String, dynamic> _rowData(models.Row row) {
    return {
      ...Map<String, dynamic>.from(row.data),
      'id': row.$id,
    };
  }

  Future<void> _upsert(
    String collectionId,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    final payload = Map<String, dynamic>.from(data)
      ..remove('id')
      ..removeWhere((key, _) => key.startsWith(r'$'));
    await _tables.upsertRow(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: collectionId,
      rowId: documentId,
      data: payload,
    );
  }

  static (String, String) _todayRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return (start.toUtc().toIso8601String(), end.toUtc().toIso8601String());
  }

  static DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    final dynamic timestampLike = value;
    final toDate = timestampLike?.toDate;
    if (toDate is Function) {
      final parsed = toDate();
      if (parsed is DateTime) return parsed;
    }
    return DateTime.now();
  }

  static int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _double(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) return value.map((item) => item.toString()).toList();
    if (value is String && value.trim().isNotEmpty) {
      final decoded = _json(value);
      if (decoded is List) {
        return decoded.map((item) => item.toString()).toList();
      }
      return [value];
    }
    return [];
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    final decoded = value is String ? _json(value) : value;
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return [];
  }

  static Map<String, dynamic> _map(dynamic value) {
    final decoded = value is String ? _json(value) : value;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {};
  }

  static dynamic _json(String value) {
    try {
      return jsonDecode(value);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _mealPlanJson(Map<String, dynamic> data) {
    return {
      ...data,
      'availableIngredients': _stringList(
          data['available_ingredients'] ?? data['availableIngredients']),
      'days': _mapList(data['days']),
      'healthPrinciples':
          _stringList(data['health_principles'] ?? data['healthPrinciples']),
      'bibleVerses': _stringList(data['bible_verses'] ?? data['bibleVerses']),
      'nutritionistNotes':
          data['nutritionist_notes'] ?? data['nutritionistNotes'] ?? '',
      'createdAt': data['created_at'] ?? data['createdAt'],
      'updatedAt': data['updated_at'] ?? data['updatedAt'],
      'isActive': data['is_active'] ?? data['isActive'] ?? true,
    };
  }

  static Map<String, dynamic> _tipJson(Map<String, dynamic> data) {
    return {
      ...data,
      'tags': _stringList(data['tags']),
      'bibleVerse': data['bible_verse'] ?? data['bibleVerse'],
      'bibleReference': data['bible_reference'] ?? data['bibleReference'],
      'estimatedTimeMinutes':
          _int(data['estimated_time_minutes'] ?? data['estimatedTimeMinutes']),
      'benefits': _stringList(data['benefits']),
      'imageUrl': data['image_url'] ?? data['imageUrl'],
      'likes': _int(data['likes']),
      'shares': _int(data['shares']),
      'createdAt': data['created_at'] ?? data['createdAt'],
      'updatedAt': data['updated_at'] ?? data['updatedAt'],
      'isActive': data['is_active'] ?? data['isActive'] ?? true,
    };
  }

  static Map<String, dynamic> _lifestyleTrackerJson(Map<String, dynamic> data) {
    return {
      ...data,
      'userId': data['user_id'] ?? data['userId'],
      'naturalRemedies':
          _map(data['natural_remedies'] ?? data['naturalRemedies'])
              .map((key, value) => MapEntry(key, value == true)),
      'metrics': _map(data['metrics']),
      'meals': _stringList(data['meals']),
      'energyLevel': data['energy_level'] ?? data['energyLevel'],
      'achievements': _stringList(data['achievements']),
      'createdAt': data['created_at'] ?? data['createdAt'],
      'updatedAt': data['updated_at'] ?? data['updatedAt'],
    };
  }

  static Map<String, dynamic> _goalJson(Map<String, dynamic> data) {
    return {
      ...data,
      'userId': data['user_id'] ?? data['userId'],
      'startDate': data['start_date'] ?? data['startDate'],
      'targetDate': data['target_date'] ?? data['targetDate'],
      'targetMetrics': _map(data['target_metrics'] ?? data['targetMetrics']),
      'completedMilestones': _stringList(
          data['completed_milestones'] ?? data['completedMilestones']),
      'isActive': data['is_active'] ?? data['isActive'] ?? true,
      'createdAt': data['created_at'] ?? data['createdAt'],
      'updatedAt': data['updated_at'] ?? data['updatedAt'],
    };
  }

  static Map<String, dynamic> _profileJson(Map<String, dynamic> data) {
    return {
      ...data,
      'userId': data['user_id'] ?? data['userId'],
      'preferredRegion':
          data['preferred_region'] ?? data['preferredRegion'] ?? 'west',
      'dietaryRestrictions': _stringList(
          data['dietary_restrictions'] ?? data['dietaryRestrictions']),
      'currentGoals':
          _stringList(data['current_goals'] ?? data['currentGoals']),
      'healthConditions':
          _map(data['health_conditions'] ?? data['healthConditions']),
      'createdAt': data['created_at'] ?? data['createdAt'],
      'updatedAt': data['updated_at'] ?? data['updatedAt'],
    };
  }

  static Map<String, dynamic> _lifestyleTrackerWrite(LifestyleTracker tracker) {
    return {
      'user_id': tracker.userId,
      'date': tracker.date.toUtc().toIso8601String(),
      'natural_remedies': jsonEncode(tracker.naturalRemedies),
      'metrics': jsonEncode(tracker.metrics),
      'meals': tracker.meals,
      'notes': tracker.notes,
      'mood': tracker.mood,
      'energy_level': tracker.energyLevel,
      'achievements': tracker.achievements,
      'created_at': tracker.createdAt.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  static Map<String, dynamic> _goalWrite(LifestyleGoalSetting goal) {
    return {
      'user_id': goal.userId,
      'goal': goal.goal.name,
      'title': goal.title,
      'description': goal.description,
      'start_date': goal.startDate.toUtc().toIso8601String(),
      'target_date': goal.targetDate.toUtc().toIso8601String(),
      'target_metrics': jsonEncode(goal.targetMetrics),
      'milestones': goal.milestones,
      'completed_milestones': goal.completedMilestones,
      'is_active': goal.isActive,
      'created_at': goal.createdAt.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  static Map<String, dynamic> _profileWrite(UserHealthProfile profile) {
    return {
      'user_id': profile.userId,
      'preferred_region': profile.preferredRegion.name,
      'dietary_restrictions': profile.dietaryRestrictions,
      'allergies': profile.allergies,
      'current_goals': profile.currentGoals.map((goal) => goal.name).toList(),
      'health_conditions': jsonEncode(profile.healthConditions),
      'height': profile.height,
      'weight': profile.weight,
      'age': profile.age,
      'activity_level': profile.activityLevel,
      'created_at': profile.createdAt.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  HealthInsight _insight({
    required String userId,
    required String title,
    required String content,
    required String category,
    required String recommendation,
    required String type,
    required String priority,
  }) {
    return HealthInsight(
      id: _uuid.v4(),
      userId: userId,
      title: title,
      content: content,
      category: category,
      recommendations: [recommendation],
      data: {
        'type': type,
        'bibleVerse': HealthConstants.healthBibleVerses['3 John 1:2'] ??
            'Beloved, I wish above all things that thou mayest prosper and be in health, even as thy soul prospereth.',
        'priority': priority,
      },
      generatedAt: DateTime.now(),
    );
  }
}
