import 'package:json_annotation/json_annotation.dart';

part 'health_models.g.dart';

// Enums for health-related features
enum MealType {
  breakfast,
  lunch,
  dinner,
  snack,
}

enum NigerianRegion {
  north,
  east,
  west,
}

enum DifficultyLevel {
  easy,
  medium,
  hard,
}

enum NaturalRemedy {
  nutrition,
  exercise,
  water,
  sunlight,
  temperance,
  air,
  rest,
  trustInGod,
}

enum LifestyleGoal {
  weightLoss,
  weightGain,
  muscleBuilding,
  generalHealth,
  spiritualGrowth,
  stressReduction,
}

// Nigerian Meal Plan Models
@JsonSerializable()
class NigerianMealPlan {
  final String id;
  final String title;
  final String description;
  final NigerianRegion region;
  final List<String> availableIngredients;
  final List<MealPlanDay> days;
  final List<String> healthPrinciples;
  final List<String> bibleVerses;
  final String nutritionistNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  const NigerianMealPlan({
    required this.id,
    required this.title,
    required this.description,
    required this.region,
    required this.availableIngredients,
    required this.days,
    required this.healthPrinciples,
    required this.bibleVerses,
    required this.nutritionistNotes,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  factory NigerianMealPlan.fromJson(Map<String, dynamic> json) =>
      _$NigerianMealPlanFromJson(json);
  Map<String, dynamic> toJson() => _$NigerianMealPlanToJson(this);
}

@JsonSerializable()
class MealPlanDay {
  final int dayNumber;
  final String dayName;
  final List<MealPlanMeal> meals;
  final String dailyTip;
  final String? bibleVerse;
  final double estimatedCalories;
  final Map<String, double> macronutrients; // protein, carbs, fats, fiber

  const MealPlanDay({
    required this.dayNumber,
    required this.dayName,
    required this.meals,
    required this.dailyTip,
    this.bibleVerse,
    required this.estimatedCalories,
    required this.macronutrients,
  });

  factory MealPlanDay.fromJson(Map<String, dynamic> json) =>
      _$MealPlanDayFromJson(json);
  Map<String, dynamic> toJson() => _$MealPlanDayToJson(this);
}

@JsonSerializable()
class MealPlanMeal {
  final String id;
  final MealType type;
  final String name;
  final String description;
  final List<String> ingredients;
  final List<String> instructions;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final int servings;
  final double estimatedCalories;
  final List<String> tags; // vegetarian, vegan, gluten-free, etc.
  final String? imageUrl;
  final List<String> healthBenefits;

  const MealPlanMeal({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.ingredients,
    required this.instructions,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.servings,
    required this.estimatedCalories,
    required this.tags,
    this.imageUrl,
    required this.healthBenefits,
  });

  factory MealPlanMeal.fromJson(Map<String, dynamic> json) =>
      _$MealPlanMealFromJson(json);
  Map<String, dynamic> toJson() => _$MealPlanMealToJson(this);

  String get totalTimeText {
    final total = prepTimeMinutes + cookTimeMinutes;
    if (total < 60) {
      return '${total}min';
    } else {
      final hours = total ~/ 60;
      final minutes = total % 60;
      return minutes > 0 ? '${hours}h ${minutes}min' : '${hours}h';
    }
  }
}

// Wholesome Living Tips Models
@JsonSerializable()
class WholesomeLivingTip {
  final String id;
  final String title;
  final String content;
  final String category; // exercise, rest, time_management, family_worship
  final List<String> tags;
  final String? bibleVerse;
  final String? bibleReference;
  final DifficultyLevel difficulty;
  final int estimatedTimeMinutes;
  final List<String> benefits;
  final String? imageUrl;
  final int likes;
  final int shares;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  const WholesomeLivingTip({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.tags,
    this.bibleVerse,
    this.bibleReference,
    required this.difficulty,
    required this.estimatedTimeMinutes,
    required this.benefits,
    this.imageUrl,
    this.likes = 0,
    this.shares = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  factory WholesomeLivingTip.fromJson(Map<String, dynamic> json) =>
      _$WholesomeLivingTipFromJson(json);
  Map<String, dynamic> toJson() => _$WholesomeLivingTipToJson(this);

  String get difficultyText {
    switch (difficulty) {
      case DifficultyLevel.easy:
        return 'Easy';
      case DifficultyLevel.medium:
        return 'Medium';
      case DifficultyLevel.hard:
        return 'Challenging';
    }
  }

  String get estimatedTimeText {
    if (estimatedTimeMinutes < 60) {
      return '${estimatedTimeMinutes}min';
    } else {
      final hours = estimatedTimeMinutes ~/ 60;
      final minutes = estimatedTimeMinutes % 60;
      return minutes > 0 ? '${hours}h ${minutes}min' : '${hours}h';
    }
  }
}

// Healthy Lifestyle Tracker Models
@JsonSerializable()
class LifestyleTracker {
  final String id;
  final String userId;
  final DateTime date;
  final Map<String, bool> naturalRemedies; // NaturalRemedy.name -> completed
  final Map<String, double>
      metrics; // water_glasses, exercise_minutes, sleep_hours, etc.
  final List<String> meals;
  final String? notes;
  final String? mood;
  final int? energyLevel; // 1-10 scale
  final List<String> achievements;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LifestyleTracker({
    required this.id,
    required this.userId,
    required this.date,
    required this.naturalRemedies,
    required this.metrics,
    required this.meals,
    this.notes,
    this.mood,
    this.energyLevel,
    required this.achievements,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LifestyleTracker.fromJson(Map<String, dynamic> json) =>
      _$LifestyleTrackerFromJson(json);
  Map<String, dynamic> toJson() => _$LifestyleTrackerToJson(this);

  int get completedRemediesCount {
    return naturalRemedies.values.where((completed) => completed).length;
  }

  double get completionPercentage {
    if (naturalRemedies.isEmpty) return 0.0;
    return (completedRemediesCount / naturalRemedies.length) * 100;
  }

  bool get isFullyCompleted => completedRemediesCount == 8;
}

@JsonSerializable()
class LifestyleGoalSetting {
  final String id;
  final String userId;
  final LifestyleGoal goal;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime targetDate;
  final Map<String, dynamic> targetMetrics; // goal-specific metrics
  final List<String> milestones;
  final List<String> completedMilestones;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LifestyleGoalSetting({
    required this.id,
    required this.userId,
    required this.goal,
    required this.title,
    required this.description,
    required this.startDate,
    required this.targetDate,
    required this.targetMetrics,
    required this.milestones,
    required this.completedMilestones,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LifestyleGoalSetting.fromJson(Map<String, dynamic> json) =>
      _$LifestyleGoalSettingFromJson(json);
  Map<String, dynamic> toJson() => _$LifestyleGoalSettingToJson(this);

  double get progressPercentage {
    if (milestones.isEmpty) return 0.0;
    return (completedMilestones.length / milestones.length) * 100;
  }

  int get daysRemaining {
    final now = DateTime.now();
    if (targetDate.isBefore(now)) return 0;
    return targetDate.difference(now).inDays;
  }

  bool get isCompleted => completedMilestones.length == milestones.length;
  bool get isOverdue => DateTime.now().isAfter(targetDate) && !isCompleted;
}

@JsonSerializable()
class HealthInsight {
  final String id;
  final String userId;
  final String title;
  final String content;
  final String category;
  final List<String> recommendations;
  final Map<String, dynamic> data; // supporting data/charts
  final DateTime generatedAt;
  final bool isRead;

  const HealthInsight({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.category,
    required this.recommendations,
    required this.data,
    required this.generatedAt,
    this.isRead = false,
  });

  factory HealthInsight.fromJson(Map<String, dynamic> json) =>
      _$HealthInsightFromJson(json);
  Map<String, dynamic> toJson() => _$HealthInsightToJson(this);
}

// User Health Profile
@JsonSerializable()
class UserHealthProfile {
  final String userId;
  final NigerianRegion preferredRegion;
  final List<String> dietaryRestrictions;
  final List<String> allergies;
  final List<LifestyleGoal> currentGoals;
  final Map<String, bool> healthConditions;
  final double? height; // in cm
  final double? weight; // in kg
  final int? age;
  final String?
      activityLevel; // sedentary, light, moderate, active, very_active
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserHealthProfile({
    required this.userId,
    required this.preferredRegion,
    required this.dietaryRestrictions,
    required this.allergies,
    required this.currentGoals,
    required this.healthConditions,
    this.height,
    this.weight,
    this.age,
    this.activityLevel,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserHealthProfile.fromJson(Map<String, dynamic> json) =>
      _$UserHealthProfileFromJson(json);
  Map<String, dynamic> toJson() => _$UserHealthProfileToJson(this);

  double? get bmi {
    if (height == null || weight == null) return null;
    final heightInMeters = height! / 100;
    return weight! / (heightInMeters * heightInMeters);
  }

  String? get bmiCategory {
    final bmiValue = bmi;
    if (bmiValue == null) return null;

    if (bmiValue < 18.5) return 'Underweight';
    if (bmiValue < 25) return 'Normal weight';
    if (bmiValue < 30) return 'Overweight';
    return 'Obese';
  }
}

// Health Data Model for tracking daily wellness metrics
@JsonSerializable()
class HealthData {
  final String id;
  final String userId;
  final DateTime date;
  final double waterIntake; // glasses of water
  final int exerciseMinutes;
  final int sunlightMinutes;
  final double sleepHours;
  final int nutritionScore; // 0-100
  final int temperanceScore; // 0-100
  final int airQualityScore; // 0-100
  final int restScore; // 0-100
  final int trustInGodScore; // 0-100
  final Map<String, dynamic>? additionalMetrics;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HealthData({
    required this.id,
    required this.userId,
    required this.date,
    this.waterIntake = 0,
    this.exerciseMinutes = 0,
    this.sunlightMinutes = 0,
    this.sleepHours = 0,
    this.nutritionScore = 0,
    this.temperanceScore = 0,
    this.airQualityScore = 0,
    this.restScore = 0,
    this.trustInGodScore = 0,
    this.additionalMetrics,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HealthData.fromJson(Map<String, dynamic> json) => _$HealthDataFromJson(json);
  Map<String, dynamic> toJson() => _$HealthDataToJson(this);

  HealthData copyWith({
    String? id,
    String? userId,
    DateTime? date,
    double? waterIntake,
    int? exerciseMinutes,
    int? sunlightMinutes,
    double? sleepHours,
    int? nutritionScore,
    int? temperanceScore,
    int? airQualityScore,
    int? restScore,
    int? trustInGodScore,
    Map<String, dynamic>? additionalMetrics,
    DateTime? createdAt,
    DateTime? updatedAt,
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
      airQualityScore: airQualityScore ?? this.airQualityScore,
      restScore: restScore ?? this.restScore,
      trustInGodScore: trustInGodScore ?? this.trustInGodScore,
      additionalMetrics: additionalMetrics ?? this.additionalMetrics,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Constants for health features
class HealthConstants {
  // Nigerian regional ingredients
  static const Map<NigerianRegion, List<String>> regionalIngredients = {
    NigerianRegion.north: [
      'Millet',
      'Sorghum',
      'Groundnuts',
      'Cowpeas',
      'Onions',
      'Tomatoes',
      'Ginger',
      'Garlic',
      'Moringa leaves',
      'Baobab leaves',
      'Dates',
      'Watermelon',
      'Cucumber',
      'Carrots',
      'Cabbage',
      'Spinach'
    ],
    NigerianRegion.east: [
      'Cassava',
      'Yam',
      'Cocoyam',
      'Plantain',
      'Palm oil',
      'Bitter leaf',
      'Ugu (fluted pumpkin)',
      'Okra',
      'Garden egg',
      'Pepper',
      'Ginger',
      'Turmeric',
      'Avocado',
      'Pawpaw',
      'Pineapple',
      'Orange',
      'Banana'
    ],
    NigerianRegion.west: [
      'Rice',
      'Beans',
      'Plantain',
      'Sweet potato',
      'Cassava',
      'Ewedu',
      'Gbure (waterleaf)',
      'Tomatoes',
      'Pepper',
      'Onions',
      'Okra',
      'Coconut',
      'Mango',
      'Cashew',
      'Guava',
      'Soursop',
      'African star apple'
    ],
  };

  // Adventist health principles
  static const List<String> healthPrinciples = [
    'Eat a plant-based diet rich in whole foods',
    'Drink plenty of clean water',
    'Get regular physical exercise',
    'Enjoy adequate rest and sleep',
    'Get fresh air and sunlight daily',
    'Practice temperance in all things',
    'Maintain trust in God and spiritual wellness',
    'Avoid harmful substances like alcohol and tobacco',
  ];

  // Natural remedies descriptions
  static const Map<NaturalRemedy, String> naturalRemedyDescriptions = {
    NaturalRemedy.nutrition: 'Eat nutritious, plant-based whole foods',
    NaturalRemedy.exercise: 'Engage in regular physical activity',
    NaturalRemedy.water: 'Drink adequate clean water daily',
    NaturalRemedy.sunlight: 'Get appropriate sunlight exposure',
    NaturalRemedy.temperance: 'Practice moderation in all things',
    NaturalRemedy.air: 'Breathe fresh, clean air',
    NaturalRemedy.rest: 'Get adequate sleep and rest',
    NaturalRemedy.trustInGod: 'Maintain spiritual wellness and trust in God',
  };

  // Daily targets for natural remedies
  static const Map<NaturalRemedy, Map<String, dynamic>> dailyTargets = {
    NaturalRemedy.nutrition: {'meals': 3, 'fruits_vegetables': 5},
    NaturalRemedy.exercise: {'minutes': 30, 'steps': 8000},
    NaturalRemedy.water: {'glasses': 8, 'liters': 2.0},
    NaturalRemedy.sunlight: {'minutes': 15},
    NaturalRemedy.temperance: {'check': true},
    NaturalRemedy.air: {'outdoor_time_minutes': 30},
    NaturalRemedy.rest: {'sleep_hours': 8, 'rest_periods': 1},
    NaturalRemedy.trustInGod: {'prayer_minutes': 15, 'bible_reading': true},
  };

  // Health tip categories
  static const List<String> tipCategories = [
    'Exercise',
    'Rest & Sleep',
    'Time Management',
    'Family Worship',
    'Nutrition',
    'Mental Health',
    'Spiritual Wellness',
    'Stress Management',
  ];

  // Bible verses for health
  static const Map<String, String> healthBibleVerses = {
    '3 John 1:2':
        'Beloved, I wish above all things that thou mayest prosper and be in health, even as thy soul prospereth.',
    '1 Corinthians 6:19-20':
        'What? know ye not that your body is the temple of the Holy Ghost which is in you, which ye have of God, and ye are not your own? For ye are bought with a price: therefore glorify God in your body, and in your spirit, which are God\'s.',
    'Daniel 1:8':
        'But Daniel purposed in his heart that he would not defile himself with the portion of the king\'s meat, nor with the wine which he drank.',
    'Proverbs 31:17':
        'She girdeth her loins with strength, and strengtheneth her arms.',
    'Ecclesiastes 3:1':
        'To every thing there is a season, and a time to every purpose under the heaven.',
  };
}




