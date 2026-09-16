import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HealthRecipeItem {
  final String id;
  final String title;
  final String description;
  final String category; // Breakfast, Lunch, Dinner, Drink, Snack
  final String region; // West, East, North, General
  final List<String> ingredients;
  final List<String> instructions;
  final List<String> healthPrinciples; // Nutrition, Water, Temperance, etc.
  final String prepTime;
  final int servings;
  final String benefits;
  final bool isSample;

  const HealthRecipeItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.region,
    required this.ingredients,
    required this.instructions,
    required this.healthPrinciples,
    required this.prepTime,
    required this.servings,
    required this.benefits,
    this.isSample = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'region': region,
        'ingredients': ingredients,
        'instructions': instructions,
        'healthPrinciples': healthPrinciples,
        'prepTime': prepTime,
        'servings': servings,
        'benefits': benefits,
        'isSample': isSample,
      };

  factory HealthRecipeItem.fromJson(Map<String, dynamic> json) =>
      HealthRecipeItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Untitled Recipe',
        description: json['description'] as String? ?? '',
        category: json['category'] as String? ?? 'Meal',
        region: json['region'] as String? ?? 'General',
        ingredients: (json['ingredients'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        instructions: (json['instructions'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        healthPrinciples: (json['healthPrinciples'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        prepTime: json['prepTime'] as String? ?? '30 mins',
        servings: (json['servings'] as num?)?.toInt() ?? 4,
        benefits: json['benefits'] as String? ?? '',
        isSample: json['isSample'] as bool? ?? false,
      );

  HealthRecipeItem copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? region,
    List<String>? ingredients,
    List<String>? instructions,
    List<String>? healthPrinciples,
    String? prepTime,
    int? servings,
    String? benefits,
    bool? isSample,
  }) {
    return HealthRecipeItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      region: region ?? this.region,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      healthPrinciples: healthPrinciples ?? this.healthPrinciples,
      prepTime: prepTime ?? this.prepTime,
      servings: servings ?? this.servings,
      benefits: benefits ?? this.benefits,
      isSample: isSample ?? this.isSample,
    );
  }
}

class HealthRemedyItem {
  final String id;
  final String title;
  final String description;
  final String ailmentCategory; // Cold/Flu, Digestion, Immunity, First Aid
  final List<String> ingredients;
  final List<String> preparationSteps;
  final String dosageAndUsage;
  final String precautions;
  final String biblicalPrinciple;
  final bool isSample;

  const HealthRemedyItem({
    required this.id,
    required this.title,
    required this.description,
    required this.ailmentCategory,
    required this.ingredients,
    required this.preparationSteps,
    required this.dosageAndUsage,
    required this.precautions,
    required this.biblicalPrinciple,
    this.isSample = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'ailmentCategory': ailmentCategory,
        'ingredients': ingredients,
        'preparationSteps': preparationSteps,
        'dosageAndUsage': dosageAndUsage,
        'precautions': precautions,
        'biblicalPrinciple': biblicalPrinciple,
        'isSample': isSample,
      };

  factory HealthRemedyItem.fromJson(Map<String, dynamic> json) =>
      HealthRemedyItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Untitled Remedy',
        description: json['description'] as String? ?? '',
        ailmentCategory: json['ailmentCategory'] as String? ?? 'General Health',
        ingredients: (json['ingredients'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        preparationSteps: (json['preparationSteps'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        dosageAndUsage: json['dosageAndUsage'] as String? ?? '',
        precautions: json['precautions'] as String? ?? '',
        biblicalPrinciple: json['biblicalPrinciple'] as String? ?? '',
        isSample: json['isSample'] as bool? ?? false,
      );

  HealthRemedyItem copyWith({
    String? id,
    String? title,
    String? description,
    String? ailmentCategory,
    List<String>? ingredients,
    List<String>? preparationSteps,
    String? dosageAndUsage,
    String? precautions,
    String? biblicalPrinciple,
    bool? isSample,
  }) {
    return HealthRemedyItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      ailmentCategory: ailmentCategory ?? this.ailmentCategory,
      ingredients: ingredients ?? this.ingredients,
      preparationSteps: preparationSteps ?? this.preparationSteps,
      dosageAndUsage: dosageAndUsage ?? this.dosageAndUsage,
      precautions: precautions ?? this.precautions,
      biblicalPrinciple: biblicalPrinciple ?? this.biblicalPrinciple,
      isSample: isSample ?? this.isSample,
    );
  }
}

class HealthCommentItem {
  final String id;
  final String targetId; // recipe or remedy id, or 'general'
  final String authorName;
  final String authorEmail;
  final String content;
  final DateTime createdAt;

  const HealthCommentItem({
    required this.id,
    required this.targetId,
    required this.authorName,
    required this.authorEmail,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'targetId': targetId,
        'authorName': authorName,
        'authorEmail': authorEmail,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
      };

  factory HealthCommentItem.fromJson(Map<String, dynamic> json) =>
      HealthCommentItem(
        id: json['id'] as String? ?? '',
        targetId: json['targetId'] as String? ?? 'general',
        authorName: json['authorName'] as String? ?? 'Member',
        authorEmail: json['authorEmail'] as String? ?? '',
        content: json['content'] as String? ?? '',
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}

/// Service managing Health+ items (Recipes & Natural Remedies)
/// Allows Admins to Add, Edit, Delete and users to view and comment.
class HealthContentService extends ChangeNotifier {
  static final HealthContentService instance = HealthContentService._internal();
  factory HealthContentService() => instance;
  HealthContentService._internal();

  static const String _recipesKey = 'health_plus_custom_recipes';
  static const String _remediesKey = 'health_plus_custom_remedies';
  static const String _commentsKey = 'health_plus_comments';

  List<HealthRecipeItem> _recipes = [];
  List<HealthRemedyItem> _remedies = [];
  List<HealthCommentItem> _comments = [];
  bool _initialized = false;

  List<HealthRecipeItem> get recipes => List.unmodifiable(_recipes);
  List<HealthRemedyItem> get remedies => List.unmodifiable(_remedies);

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();

    // 1. Load recipes (seed + custom)
    final savedRecipes = prefs.getStringList(_recipesKey);
    if (savedRecipes != null && savedRecipes.isNotEmpty) {
      _recipes = savedRecipes
          .map((s) => HealthRecipeItem.fromJson(jsonDecode(s)))
          .toList();
    } else {
      _recipes = List.from(_defaultRecipes);
      await _saveRecipes();
    }

    // 2. Load remedies (seed + custom)
    final savedRemedies = prefs.getStringList(_remediesKey);
    if (savedRemedies != null && savedRemedies.isNotEmpty) {
      _remedies = savedRemedies
          .map((s) => HealthRemedyItem.fromJson(jsonDecode(s)))
          .toList();
    } else {
      _remedies = List.from(_defaultRemedies);
      await _saveRemedies();
    }

    // 3. Load comments
    final savedComments = prefs.getStringList(_commentsKey);
    if (savedComments != null && savedComments.isNotEmpty) {
      _comments = savedComments
          .map((s) => HealthCommentItem.fromJson(jsonDecode(s)))
          .toList();
    } else {
      _comments = List.from(_defaultComments);
      await _saveComments();
    }

    _initialized = true;
    notifyListeners();
  }

  // --- Recipe Operations (Admin & App) ---
  Future<void> addRecipe(HealthRecipeItem recipe) async {
    _recipes.insert(0, recipe);
    await _saveRecipes();
    notifyListeners();
  }

  Future<void> updateRecipe(HealthRecipeItem recipe) async {
    final idx = _recipes.indexWhere((r) => r.id == recipe.id);
    if (idx != -1) {
      _recipes[idx] = recipe;
      await _saveRecipes();
      notifyListeners();
    }
  }

  Future<void> deleteRecipe(String id) async {
    _recipes.removeWhere((r) => r.id == id);
    await _saveRecipes();
    notifyListeners();
  }

  // --- Remedy Operations (Admin & App) ---
  Future<void> addRemedy(HealthRemedyItem remedy) async {
    _remedies.insert(0, remedy);
    await _saveRemedies();
    notifyListeners();
  }

  Future<void> updateRemedy(HealthRemedyItem remedy) async {
    final idx = _remedies.indexWhere((r) => r.id == remedy.id);
    if (idx != -1) {
      _remedies[idx] = remedy;
      await _saveRemedies();
      notifyListeners();
    }
  }

  Future<void> deleteRemedy(String id) async {
    _remedies.removeWhere((r) => r.id == id);
    await _saveRemedies();
    notifyListeners();
  }

  // --- Comments & Community Q&A ---
  List<HealthCommentItem> getCommentsFor(String targetId) {
    return _comments.where((c) => c.targetId == targetId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<HealthCommentItem> getCommunityQnA() {
    return _comments.where((c) => c.targetId == 'general').toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> addComment({
    required String targetId,
    required String authorName,
    required String authorEmail,
    required String content,
  }) async {
    final comment = HealthCommentItem(
      id: 'comm_${DateTime.now().millisecondsSinceEpoch}',
      targetId: targetId,
      authorName: authorName.trim().isEmpty ? 'Member' : authorName.trim(),
      authorEmail: authorEmail,
      content: content.trim(),
      createdAt: DateTime.now(),
    );
    _comments.insert(0, comment);
    await _saveComments();
    notifyListeners();
  }

  Future<void> _saveRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _recipes.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_recipesKey, list);
  }

  Future<void> _saveRemedies() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _remedies.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_remediesKey, list);
  }

  Future<void> _saveComments() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _comments.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(_commentsKey, list);
  }

  // Pre-populated Curated Nigerian SDA Plant-based Recipes
  static final List<HealthRecipeItem> _defaultRecipes = [
    const HealthRecipeItem(
      id: 'rec_brown_rice_veggie_stew',
      title: 'Ofada Brown Rice & Vibrant Vegetable Stew',
      description:
          'Wholesome unpolished local brown rice paired with rich tomato, sweet bell pepper, and pumpkin leaves (Ugu) stew with golden baked tofu cubes.',
      category: 'Lunch',
      region: 'West',
      prepTime: '45 mins',
      servings: 4,
      benefits:
          'High in dietary fiber, low glycemic index, promotes steady energy, rich in plant iron and antioxidants.',
      ingredients: [
        '2 cups unpolished Ofada/Abakaliki brown rice',
        '300g firm organic tofu, cubed & oven-baked',
        '4 large ripe plum tomatoes & 2 bell peppers (Tatashe)',
        '1 bunch fresh pumpkin leaves (Ugu), shredded',
        '2 tablespoons cold-pressed coconut oil or olive oil',
        '1 medium red onion, diced',
        '1 teaspoon ground ginger, garlic, and dried thyme',
        'Sea salt to taste',
      ],
      instructions: [
        'Rinse brown rice thoroughly and parboil with 4 cups of clean water until tender and fluffy.',
        'Blend tomatoes, bell peppers, ginger, and garlic into a coarse purée.',
        'Sauté diced onions lightly in cold-pressed oil, pour in the blended sauce, and simmer until reduced.',
        'Fold in the baked tofu cubes and allow to absorb the rich flavors for 5 minutes.',
        'Stir in shredded Ugu leaves and turn off heat immediately to retain vital vitamins.',
        'Serve warm with the steaming brown rice.',
      ],
      healthPrinciples: ['Nutrition', 'Temperance', 'Water'],
      isSample: true,
    ),
    const HealthRecipeItem(
      id: 'rec_plantain_bean_pottage',
      title: 'Ripe Plantain & Honey Bean (Oloyin) Pottage',
      description:
          'Slow-cooked sweet honey beans infused with naturally sweet plantains, roasted ground seeds, and rich green scent leaves (Efirin).',
      category: 'Dinner',
      region: 'West',
      prepTime: '50 mins',
      servings: 5,
      benefits:
          'Packed with clean plant protein, potassium, and resistant starch that nourishes healthy gut bacteria.',
      ingredients: [
        '3 cups brown honey beans (Ewa Oloyin), rinsed',
        '2 semi-ripe plantains, diced into bite sizes',
        '1 cup shredded scent leaves (Efirin) or spinach',
        '1 large red onion, sliced',
        '2 tablespoons virgin olive oil',
        '1 teaspoon ground dry pepper (Cameroon or scotch bonnet)',
        'A pinch of sea salt and mineral seasoning',
      ],
      instructions: [
        'Boil beans in fresh water until tender and soft to digest.',
        'Add diced plantains, chopped onions, and seasoning to the pot.',
        'Simmer together on low heat until plantains soften and bean broth thickens naturally.',
        'Stir in aromatic scent leaves just before serving.',
      ],
      healthPrinciples: ['Nutrition', 'Rest', 'Temperance'],
      isSample: true,
    ),
    const HealthRecipeItem(
      id: 'rec_tigernut_coconut_milk',
      title: 'Creamy Tiger Nut & Coconut Milk (Kunun Aya)',
      description:
          '100% natural, dairy-free refreshing milk made from sweet tiger nuts, fresh coconut flesh, and dates with a hint of warm ginger.',
      category: 'Drink',
      region: 'North',
      prepTime: '20 mins',
      servings: 4,
      benefits:
          'Rich in magnesium, prebiotic fiber, natural electrolytes, and vitamins E & C. Excellent dairy alternative.',
      ingredients: [
        '2 cups dry tiger nuts, soaked overnight in pure water',
        '1 fresh coconut, flesh diced',
        '10 pitted sweet dates (Dabino) for natural sweetness',
        '1 thumb fresh ginger root, peeled',
        '4 cups cold purified water',
      ],
      instructions: [
        'Drain the soaked tiger nuts and combine in high-speed blender with coconut, dates, and ginger.',
        'Add cold water and blend thoroughly until completely smooth.',
        'Strain through a fine cheesecloth or nut-milk bag, squeezing out every drop of pure creamy milk.',
        'Chill in glass pitcher and serve cool.',
      ],
      healthPrinciples: ['Water', 'Nutrition', 'Fresh Air'],
      isSample: true,
    ),
    const HealthRecipeItem(
      id: 'rec_healthy_oatmeal_seeds',
      title: 'Hearty Whole Oat Porridge with Groundnuts',
      description:
          'Sustaining morning porridge made with rolled oats, ground roasted groundnuts, flaxseed meal, and naturally sweetened with sliced bananas.',
      category: 'Breakfast',
      region: 'General',
      prepTime: '15 mins',
      servings: 2,
      benefits:
          'High in beta-glucan soluble fiber that naturally lowers LDL cholesterol and stabilizes blood sugar.',
      ingredients: [
        '1.5 cups whole rolled oats',
        '3 cups almond or tiger nut milk',
        '2 tablespoons roasted unsalted groundnuts, lightly crushed',
        '1 tablespoon flaxseed or chia seeds',
        '1 ripe banana or fresh berries for garnish',
        'Half teaspoon ground cinnamon',
      ],
      instructions: [
        'Bring milk to a gentle simmer in a saucepan.',
        'Stir in rolled oats and cinnamon, cooking on medium-low for 7–10 minutes.',
        'Pour into bowls, sprinkle with crushed groundnuts and flaxseed.',
        'Top with sliced banana and enjoy warm.',
      ],
      healthPrinciples: ['Nutrition', 'Sunlight', 'Temperance'],
      isSample: true,
    ),
  ];

  // Pre-populated Curated Natural Remedies
  static final List<HealthRemedyItem> _defaultRemedies = [
    const HealthRemedyItem(
      id: 'rem_ginger_garlic_lemon',
      title: 'Ginger, Garlic & Lemon Immune Infusion',
      description:
          'Potent natural antimicrobial infusion for relieving early symptoms of colds, flu, sore throat, and congestion.',
      ailmentCategory: 'Cold & Flu',
      ingredients: [
        '1 large thumb fresh ginger root, crushed',
        '2 cloves garlic, crushed & exposed to air for 10 mins (activates allicin)',
        '1 fresh lemon or lime, freshly juiced',
        '1 tablespoon pure raw honey',
        '2 cups boiling purified water',
      ],
      preparationSteps: [
        'Place crushed ginger and garlic in a mug or heat-resistant teapot.',
        'Pour freshly boiled water over them and cover with a lid to trap essential oils.',
        'Steep for 10 to 15 minutes.',
        'Strain liquid, stir in fresh lemon juice and raw honey once slightly cooled.',
      ],
      dosageAndUsage:
          'Drink 1 cup warm morning and evening at the first onset of cold or throat tickle.',
      precautions:
          'Avoid very high doses of garlic if taking prescription blood-thinning medications.',
      biblicalPrinciple:
          '"And the leaves of the tree were for the healing of the nations." - Revelation 22:2',
      isSample: true,
    ),
    const HealthRemedyItem(
      id: 'rem_activated_charcoal',
      title: 'Activated Charcoal Emergency Remedy',
      description:
          'Highly effective natural adsorbent for sudden food poisoning, acute diarrhea, indigestion, and toxic ingestion.',
      ailmentCategory: 'Digestion',
      ingredients: [
        '1 to 2 tablespoons pharmaceutical-grade activated charcoal powder',
        '1 large glass (300ml) room-temperature pure water',
      ],
      preparationSteps: [
        'Slowly stir charcoal powder into the glass of water to avoid powder dispersing in air.',
        'Mix thoroughly until evenly suspended.',
      ],
      dosageAndUsage:
          'Drink immediately upon noticing gastrointestinal distress. Follow with a second glass of plain water within 30 minutes.',
      precautions:
          'Do not take within 2 hours of essential medications or meals as it binds indiscriminately.',
      biblicalPrinciple:
          '"He that is of a merry heart hath a continual feast." - Proverbs 15:15',
      isSample: true,
    ),
    const HealthRemedyItem(
      id: 'rem_steam_inhalation',
      title: 'Eucalyptus Steam Inhalation for Nasal & Sinus Relief',
      description:
          'Natural moist-heat therapy for clearing congested nasal passages, opening bronchial airways, and easing sinus headaches.',
      ailmentCategory: 'Respiratory',
      ingredients: [
        '4 cups boiling water in a wide bowl',
        '3–5 drops pure eucalyptus oil (or handful of fresh eucalyptus/menthol leaves)',
        '1 clean bath towel',
      ],
      preparationSteps: [
        'Pour steaming hot water into a sturdy bowl on a stable table.',
        'Add eucalyptus drops or bruised fresh leaves.',
        'Drape towel over head and bowl to create a comfortable steam tent.',
      ],
      dosageAndUsage:
          'Inhale steam deeply through nostrils for 10 minutes, with eyes closed. Repeat 2–3 times daily during congestion.',
      precautions:
          'Keep eyes closed. Ensure safe distance from hot bowl to prevent burns.',
      biblicalPrinciple:
          '"A merry heart doeth good like a medicine." - Proverbs 17:22',
      isSample: true,
    ),
    const HealthRemedyItem(
      id: 'rem_salt_water_gargle',
      title: 'Warm Salt Water Throat Gargle',
      description:
          'Gentle hypertonic saline rinse that draws out fluid from inflamed throat tissues and inhibits bacterial growth.',
      ailmentCategory: 'Throat & Mouth',
      ingredients: [
        'Half teaspoon fine sea salt or unrefined salt',
        '1 cup comfortably warm purified water',
      ],
      preparationSteps: [
        'Dissolve salt completely in the warm water.',
      ],
      dosageAndUsage:
          'Take a mouthful, tilt head back, and gargle thoroughly for 30 seconds before spitting out. Repeat with entire cup 3 times a day.',
      precautions:
          'Spit out after gargling; do not swallow the salty liquid.',
      biblicalPrinciple:
          '"Salt is good: but if the salt have lost his saltness, wherewith will ye season it?" - Mark 9:50',
      isSample: true,
    ),
  ];

  static final List<HealthCommentItem> _defaultComments = [
    HealthCommentItem(
      id: 'comm_1',
      targetId: 'general',
      authorName: 'Sister Grace O.',
      authorEmail: 'grace@example.com',
      content:
          'The plant-based switch has tremendously improved my energy levels and blood pressure. Blessed to have local Nigerian Adventist recipes here!',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    HealthCommentItem(
      id: 'comm_2',
      targetId: 'rec_brown_rice_veggie_stew',
      authorName: 'Brother Emmanuel',
      authorEmail: 'emmanuel@example.com',
      content:
          'Tasted wonderful! Adding the scent leaf right at the end made the whole house smell amazing.',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];
}
