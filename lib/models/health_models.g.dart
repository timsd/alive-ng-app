// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NigerianMealPlan _$NigerianMealPlanFromJson(Map<String, dynamic> json) =>
    NigerianMealPlan(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      region: $enumDecode(_$NigerianRegionEnumMap, json['region']),
      availableIngredients: (json['availableIngredients'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      days: (json['days'] as List<dynamic>)
          .map((e) => MealPlanDay.fromJson(e as Map<String, dynamic>))
          .toList(),
      healthPrinciples: (json['healthPrinciples'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      bibleVerses: (json['bibleVerses'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      nutritionistNotes: json['nutritionistNotes'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isActive: json['isActive'] as bool? ?? true,
    );

Map<String, dynamic> _$NigerianMealPlanToJson(NigerianMealPlan instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'region': _$NigerianRegionEnumMap[instance.region]!,
      'availableIngredients': instance.availableIngredients,
      'days': instance.days,
      'healthPrinciples': instance.healthPrinciples,
      'bibleVerses': instance.bibleVerses,
      'nutritionistNotes': instance.nutritionistNotes,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'isActive': instance.isActive,
    };

const _$NigerianRegionEnumMap = {
  NigerianRegion.north: 'north',
  NigerianRegion.east: 'east',
  NigerianRegion.west: 'west',
};

MealPlanDay _$MealPlanDayFromJson(Map<String, dynamic> json) => MealPlanDay(
      dayNumber: (json['dayNumber'] as num).toInt(),
      dayName: json['dayName'] as String,
      meals: (json['meals'] as List<dynamic>)
          .map((e) => MealPlanMeal.fromJson(e as Map<String, dynamic>))
          .toList(),
      dailyTip: json['dailyTip'] as String,
      bibleVerse: json['bibleVerse'] as String?,
      estimatedCalories: (json['estimatedCalories'] as num).toDouble(),
      macronutrients: (json['macronutrients'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ),
    );

Map<String, dynamic> _$MealPlanDayToJson(MealPlanDay instance) =>
    <String, dynamic>{
      'dayNumber': instance.dayNumber,
      'dayName': instance.dayName,
      'meals': instance.meals,
      'dailyTip': instance.dailyTip,
      'bibleVerse': instance.bibleVerse,
      'estimatedCalories': instance.estimatedCalories,
      'macronutrients': instance.macronutrients,
    };

MealPlanMeal _$MealPlanMealFromJson(Map<String, dynamic> json) => MealPlanMeal(
      id: json['id'] as String,
      type: $enumDecode(_$MealTypeEnumMap, json['type']),
      name: json['name'] as String,
      description: json['description'] as String,
      ingredients: (json['ingredients'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      instructions: (json['instructions'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      prepTimeMinutes: (json['prepTimeMinutes'] as num).toInt(),
      cookTimeMinutes: (json['cookTimeMinutes'] as num).toInt(),
      servings: (json['servings'] as num).toInt(),
      estimatedCalories: (json['estimatedCalories'] as num).toDouble(),
      tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
      imageUrl: json['imageUrl'] as String?,
      healthBenefits: (json['healthBenefits'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$MealPlanMealToJson(MealPlanMeal instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$MealTypeEnumMap[instance.type]!,
      'name': instance.name,
      'description': instance.description,
      'ingredients': instance.ingredients,
      'instructions': instance.instructions,
      'prepTimeMinutes': instance.prepTimeMinutes,
      'cookTimeMinutes': instance.cookTimeMinutes,
      'servings': instance.servings,
      'estimatedCalories': instance.estimatedCalories,
      'tags': instance.tags,
      'imageUrl': instance.imageUrl,
      'healthBenefits': instance.healthBenefits,
    };

const _$MealTypeEnumMap = {
  MealType.breakfast: 'breakfast',
  MealType.lunch: 'lunch',
  MealType.dinner: 'dinner',
  MealType.snack: 'snack',
};

WholesomeLivingTip _$WholesomeLivingTipFromJson(Map<String, dynamic> json) =>
    WholesomeLivingTip(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      category: json['category'] as String,
      tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
      bibleVerse: json['bibleVerse'] as String?,
      bibleReference: json['bibleReference'] as String?,
      difficulty: $enumDecode(_$DifficultyLevelEnumMap, json['difficulty']),
      estimatedTimeMinutes: (json['estimatedTimeMinutes'] as num).toInt(),
      benefits:
          (json['benefits'] as List<dynamic>).map((e) => e as String).toList(),
      imageUrl: json['imageUrl'] as String?,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      shares: (json['shares'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isActive: json['isActive'] as bool? ?? true,
    );

Map<String, dynamic> _$WholesomeLivingTipToJson(WholesomeLivingTip instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'content': instance.content,
      'category': instance.category,
      'tags': instance.tags,
      'bibleVerse': instance.bibleVerse,
      'bibleReference': instance.bibleReference,
      'difficulty': _$DifficultyLevelEnumMap[instance.difficulty]!,
      'estimatedTimeMinutes': instance.estimatedTimeMinutes,
      'benefits': instance.benefits,
      'imageUrl': instance.imageUrl,
      'likes': instance.likes,
      'shares': instance.shares,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'isActive': instance.isActive,
    };

const _$DifficultyLevelEnumMap = {
  DifficultyLevel.easy: 'easy',
  DifficultyLevel.medium: 'medium',
  DifficultyLevel.hard: 'hard',
};

LifestyleTracker _$LifestyleTrackerFromJson(Map<String, dynamic> json) =>
    LifestyleTracker(
      id: json['id'] as String,
      userId: json['userId'] as String,
      date: DateTime.parse(json['date'] as String),
      naturalRemedies: Map<String, bool>.from(json['naturalRemedies'] as Map),
      metrics: (json['metrics'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ),
      meals: (json['meals'] as List<dynamic>).map((e) => e as String).toList(),
      notes: json['notes'] as String?,
      mood: json['mood'] as String?,
      energyLevel: (json['energyLevel'] as num?)?.toInt(),
      achievements: (json['achievements'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$LifestyleTrackerToJson(LifestyleTracker instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'date': instance.date.toIso8601String(),
      'naturalRemedies': instance.naturalRemedies,
      'metrics': instance.metrics,
      'meals': instance.meals,
      'notes': instance.notes,
      'mood': instance.mood,
      'energyLevel': instance.energyLevel,
      'achievements': instance.achievements,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

LifestyleGoalSetting _$LifestyleGoalSettingFromJson(
        Map<String, dynamic> json) =>
    LifestyleGoalSetting(
      id: json['id'] as String,
      userId: json['userId'] as String,
      goal: $enumDecode(_$LifestyleGoalEnumMap, json['goal']),
      title: json['title'] as String,
      description: json['description'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      targetDate: DateTime.parse(json['targetDate'] as String),
      targetMetrics: json['targetMetrics'] as Map<String, dynamic>,
      milestones: (json['milestones'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      completedMilestones: (json['completedMilestones'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$LifestyleGoalSettingToJson(
        LifestyleGoalSetting instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'goal': _$LifestyleGoalEnumMap[instance.goal]!,
      'title': instance.title,
      'description': instance.description,
      'startDate': instance.startDate.toIso8601String(),
      'targetDate': instance.targetDate.toIso8601String(),
      'targetMetrics': instance.targetMetrics,
      'milestones': instance.milestones,
      'completedMilestones': instance.completedMilestones,
      'isActive': instance.isActive,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

const _$LifestyleGoalEnumMap = {
  LifestyleGoal.weightLoss: 'weightLoss',
  LifestyleGoal.weightGain: 'weightGain',
  LifestyleGoal.muscleBuilding: 'muscleBuilding',
  LifestyleGoal.generalHealth: 'generalHealth',
  LifestyleGoal.spiritualGrowth: 'spiritualGrowth',
  LifestyleGoal.stressReduction: 'stressReduction',
};

HealthInsight _$HealthInsightFromJson(Map<String, dynamic> json) =>
    HealthInsight(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      category: json['category'] as String,
      recommendations: (json['recommendations'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      data: json['data'] as Map<String, dynamic>,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
    );

Map<String, dynamic> _$HealthInsightToJson(HealthInsight instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'title': instance.title,
      'content': instance.content,
      'category': instance.category,
      'recommendations': instance.recommendations,
      'data': instance.data,
      'generatedAt': instance.generatedAt.toIso8601String(),
      'isRead': instance.isRead,
    };

UserHealthProfile _$UserHealthProfileFromJson(Map<String, dynamic> json) =>
    UserHealthProfile(
      userId: json['userId'] as String,
      preferredRegion:
          $enumDecode(_$NigerianRegionEnumMap, json['preferredRegion']),
      dietaryRestrictions: (json['dietaryRestrictions'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      allergies:
          (json['allergies'] as List<dynamic>).map((e) => e as String).toList(),
      currentGoals: (json['currentGoals'] as List<dynamic>)
          .map((e) => $enumDecode(_$LifestyleGoalEnumMap, e))
          .toList(),
      healthConditions: Map<String, bool>.from(json['healthConditions'] as Map),
      height: (json['height'] as num?)?.toDouble(),
      weight: (json['weight'] as num?)?.toDouble(),
      age: (json['age'] as num?)?.toInt(),
      activityLevel: json['activityLevel'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$UserHealthProfileToJson(UserHealthProfile instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'preferredRegion': _$NigerianRegionEnumMap[instance.preferredRegion]!,
      'dietaryRestrictions': instance.dietaryRestrictions,
      'allergies': instance.allergies,
      'currentGoals':
          instance.currentGoals.map((e) => _$LifestyleGoalEnumMap[e]!).toList(),
      'healthConditions': instance.healthConditions,
      'height': instance.height,
      'weight': instance.weight,
      'age': instance.age,
      'activityLevel': instance.activityLevel,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

HealthData _$HealthDataFromJson(Map<String, dynamic> json) => HealthData(
      id: json['id'] as String,
      userId: json['userId'] as String,
      date: DateTime.parse(json['date'] as String),
      waterIntake: (json['waterIntake'] as num?)?.toDouble() ?? 0,
      exerciseMinutes: (json['exerciseMinutes'] as num?)?.toInt() ?? 0,
      sunlightMinutes: (json['sunlightMinutes'] as num?)?.toInt() ?? 0,
      sleepHours: (json['sleepHours'] as num?)?.toDouble() ?? 0,
      nutritionScore: (json['nutritionScore'] as num?)?.toInt() ?? 0,
      temperanceScore: (json['temperanceScore'] as num?)?.toInt() ?? 0,
      airQualityScore: (json['airQualityScore'] as num?)?.toInt() ?? 0,
      restScore: (json['restScore'] as num?)?.toInt() ?? 0,
      trustInGodScore: (json['trustInGodScore'] as num?)?.toInt() ?? 0,
      additionalMetrics: json['additionalMetrics'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$HealthDataToJson(HealthData instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'date': instance.date.toIso8601String(),
      'waterIntake': instance.waterIntake,
      'exerciseMinutes': instance.exerciseMinutes,
      'sunlightMinutes': instance.sunlightMinutes,
      'sleepHours': instance.sleepHours,
      'nutritionScore': instance.nutritionScore,
      'temperanceScore': instance.temperanceScore,
      'airQualityScore': instance.airQualityScore,
      'restScore': instance.restScore,
      'trustInGodScore': instance.trustInGodScore,
      'additionalMetrics': instance.additionalMetrics,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
