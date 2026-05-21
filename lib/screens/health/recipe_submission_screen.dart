// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:appwrite/appwrite.dart';

import '../../config/appwrite_backend_config.dart';
import '../../main.dart';
import '../../providers/auth_provider.dart';
import '../../utils/i18n_service.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/guest_access_indicator.dart';

/// Screen for authenticated users to submit meal and natural remedy recipes
class RecipeSubmissionScreen extends ConsumerStatefulWidget {
  const RecipeSubmissionScreen({super.key});

  @override
  ConsumerState<RecipeSubmissionScreen> createState() =>
      _RecipeSubmissionScreenState();
}

class _RecipeSubmissionScreenState extends ConsumerState<RecipeSubmissionScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormBuilderState>();
  late final Databases _databases = Databases(appwriteClient);
  late TabController _tabController;
  bool _isSubmitting = false;

  // Recipe categories
  final List<String> _mealCategories = [
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snacks',
    'Beverages',
    'Traditional Nigerian',
    'Vegetarian',
    'Vegan',
    'Diabetic-Friendly',
    'Heart-Healthy',
  ];

  final List<String> _remedyCategories = [
    'Digestive Health',
    'Respiratory Health',
    'Immune Support',
    'Pain Relief',
    'Skin Care',
    'Mental Wellness',
    'Heart Health',
    'Blood Sugar',
    'Traditional Nigerian',
    'Herbal Teas',
  ];

  final List<String> _difficultyLevels = ['Easy', 'Medium', 'Hard'];
  final List<String> _preparationTimes = [
    '5-15 minutes',
    '15-30 minutes',
    '30-60 minutes',
    '1-2 hours',
    '2+ hours'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final translate = I18nService().translate;

    return authState.when(
      data: (user) {
        if (user == null) {
          return _buildUnauthenticatedView(context, translate);
        }
        return _buildAuthenticatedView(context, translate, user);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  Widget _buildUnauthenticatedView(
      BuildContext context, String Function(String) translate) {
    return Scaffold(
      appBar: AppBar(
        title: Text(translate('recipe_submission')),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(context: context, mobile: 16, tablet: 20, desktop: 24)),
          child: const GuestAccessIndicator(
            featureName: 'Recipe Sharing',
            description:
                'Create an account to share your healthy recipes and natural remedies with the community!',
            showAsCard: true,
          ),
        ),
      ),
    );
  }

  Widget _buildAuthenticatedView(
      BuildContext context, String Function(String) translate, user) {
    return Scaffold(
      appBar: AppBar(
        title: Text(translate('submit_recipe')),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.restaurant),
              text: translate('meal_recipe'),
            ),
            Tab(
              icon: const Icon(Icons.healing),
              text: translate('natural_remedy'),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMealRecipeForm(context, translate),
          _buildRemedyRecipeForm(context, translate),
        ],
      ),
    );
  }

  Widget _buildMealRecipeForm(
      BuildContext context, String Function(String) translate) {
    return SingleChildScrollView(
      padding: context.responsivePadding,
      child: FormBuilder(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe Name
            FormBuilderTextField(
              name: 'name',
              decoration: InputDecoration(
                labelText: translate('recipe_name'),
                hintText: translate('enter_recipe_name'),
                border: OutlineInputBorder(
                  borderRadius: context.responsiveBorderRadius,
                ),
              ),
              validator: FormBuilderValidators.compose([
                FormBuilderValidators.required(),
                FormBuilderValidators.minLength(3),
                FormBuilderValidators.maxLength(100),
              ]),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),

            // Category
            FormBuilderDropdown<String>(
              name: 'category',
              decoration: InputDecoration(
                labelText: translate('category'),
                border: OutlineInputBorder(
                  borderRadius: context.responsiveBorderRadius,
                ),
              ),
              validator: FormBuilderValidators.required(),
              items: _mealCategories
                  .map((category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ))
                  .toList(),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),

            // Difficulty Level
            FormBuilderDropdown<String>(
              name: 'difficulty',
              decoration: InputDecoration(
                labelText: translate('difficulty_level'),
                border: OutlineInputBorder(
                  borderRadius: context.responsiveBorderRadius,
                ),
              ),
              validator: FormBuilderValidators.required(),
              items: _difficultyLevels
                  .map((level) => DropdownMenuItem(
                        value: level,
                        child: Text(level),
                      ))
                  .toList(),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),

            // Preparation Time
            FormBuilderDropdown<String>(
              name: 'prep_time',
              decoration: InputDecoration(
                labelText: translate('preparation_time'),
                border: OutlineInputBorder(
                  borderRadius: context.responsiveBorderRadius,
                ),
              ),
              validator: FormBuilderValidators.required(),
              items: _preparationTimes
                  .map((time) => DropdownMenuItem(
                        value: time,
                        child: Text(time),
                      ))
                  .toList(),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),

            // Servings
            FormBuilderTextField(
              name: 'servings',
              decoration: InputDecoration(
                labelText: translate('servings'),
                hintText: translate('number_of_servings'),
                border: OutlineInputBorder(
                  borderRadius: context.responsiveBorderRadius,
                ),
              ),
              keyboardType: TextInputType.number,
              validator: FormBuilderValidators.compose([
                FormBuilderValidators.required(),
                FormBuilderValidators.integer(),
                FormBuilderValidators.min(1),
                FormBuilderValidators.max(50),
              ]),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),

            // Ingredients
            FormBuilderTextField(
              name: 'ingredients',
              decoration: InputDecoration(
                labelText: translate('ingredients'),
                hintText: translate('list_ingredients_separated_by_lines'),
                border: OutlineInputBorder(
                  borderRadius: context.responsiveBorderRadius,
                ),
              ),
              maxLines: 8,
              validator: FormBuilderValidators.compose([
                FormBuilderValidators.required(),
                FormBuilderValidators.minLength(10),
              ]),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),

            // Instructions
            FormBuilderTextField(
              name: 'instructions',
              decoration: InputDecoration(
                labelText: translate('cooking_instructions'),
                hintText: translate('step_by_step_instructions'),
                border: OutlineInputBorder(
                  borderRadius: context.responsiveBorderRadius,
                ),
              ),
              maxLines: 10,
              validator: FormBuilderValidators.compose([
                FormBuilderValidators.required(),
                FormBuilderValidators.minLength(20),
              ]),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),

            // Nutritional Benefits
            FormBuilderTextField(
              name: 'nutritional_benefits',
              decoration: InputDecoration(
                labelText: translate('nutritional_benefits'),
                hintText: translate('describe_health_benefits'),
                border: OutlineInputBorder(
                  borderRadius: context.responsiveBorderRadius,
                ),
              ),
              maxLines: 4,
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),

            // Cultural Significance
            FormBuilderTextField(
              name: 'cultural_significance',
              decoration: InputDecoration(
                labelText: translate('cultural_significance'),
                hintText: translate('cultural_or_traditional_importance'),
                border: OutlineInputBorder(
                  borderRadius: context.responsiveBorderRadius,
                ),
              ),
              maxLines: 3,
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 20, tablet: 24, desktop: 28)),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting
                    ? null
                    : () => _submitMealRecipe(context, translate),
                child: _isSubmitting
                    ? const CircularProgressIndicator()
                    : Text(translate('submit_recipe')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemedyRecipeForm(
      BuildContext context, String Function(String) translate) {
    return SingleChildScrollView(
      padding: context.responsivePadding,
      child: FormBuilder(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Remedy Name
            FormBuilderTextField(
              name: 'name',
              decoration: InputDecoration(
                labelText: translate('remedy_name'),
                hintText: translate('enter_remedy_name'),
                border: OutlineInputBorder(
                  borderRadius: context.responsiveBorderRadius,
                ),
              ),
              validator: FormBuilderValidators.compose([
                FormBuilderValidators.required(),
                FormBuilderValidators.minLength(3),
                FormBuilderValidators.maxLength(100),
              ]),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),

            // Category
            FormBuilderDropdown<String>(
              name: 'category',
              decoration: InputDecoration(
                labelText: translate('health_category'),
                border: OutlineInputBorder(
                  borderRadius: context.responsiveBorderRadius,
                ),
              ),
              validator: FormBuilderValidators.required(),
              items: _remedyCategories
                  .map((category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ))
                  .toList(),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),

            // Difficulty Level
            FormBuilderDropdown<String>(
              name: 'difficulty',
              decoration: InputDecoration(
                labelText: translate('difficulty_level'),
                border: OutlineInputBorder(
                  borderRadius: context.responsiveBorderRadius,
                ),
              ),
              validator: FormBuilderValidators.required(),
              items: _difficultyLevels
                  .map((level) => DropdownMenuItem(
                        value: level,
                        child: Text(level),
                      ))
                  .toList(),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),

            // Preparation Time
            FormBuilderDropdown<String>(
              name: 'prep_time',
              decoration: InputDecoration(
                labelText: translate('preparation_time'),
                border: OutlineInputBorder(
                  borderRadius: context.responsiveBorderRadius,
                ),
              ),
              validator: FormBuilderValidators.required(),
              items: _preparationTimes
                  .map((time) => DropdownMenuItem(
                        value: time,
                        child: Text(time),
                      ))
                  .toList(),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),

            // Ingredients/Materials
            FormBuilderTextField(
              name: 'ingredients',
              decoration: InputDecoration(
                labelText: translate('ingredients_materials'),
                hintText: translate('list_natural_ingredients'),
                border: OutlineInputBorder(
                  borderRadius: context.responsiveBorderRadius,
                ),
              ),
              maxLines: 6,
              validator: FormBuilderValidators.compose([
                FormBuilderValidators.required(),
                FormBuilderValidators.minLength(10),
              ]),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),

            // Preparation Instructions
            FormBuilderTextField(
              name: 'instructions',
              decoration: InputDecoration(
                labelText: translate('preparation_instructions'),
                hintText: translate('step_by_step_preparation'),
                border: OutlineInputBorder(
                  borderRadius: context.responsiveBorderRadius,
                ),
              ),
              maxLines: 8,
              validator: FormBuilderValidators.compose([
                FormBuilderValidators.required(),
                FormBuilderValidators.minLength(20),
              ]),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),

            // Usage Instructions
            FormBuilderTextField(
              name: 'usage_instructions',
              decoration: InputDecoration(
                labelText: translate('usage_instructions'),
                hintText: translate('how_to_use_remedy'),
                border: OutlineInputBorder(
                  borderRadius: context.responsiveBorderRadius,
                ),
              ),
              maxLines: 4,
              validator: FormBuilderValidators.required(),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),

            // Health Benefits
            FormBuilderTextField(
              name: 'health_benefits',
              decoration: InputDecoration(
                labelText: translate('health_benefits'),
                hintText: translate('describe_health_benefits'),
                border: OutlineInputBorder(
                  borderRadius: context.responsiveBorderRadius,
                ),
              ),
              maxLines: 4,
              validator: FormBuilderValidators.required(),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),

            // Precautions
            FormBuilderTextField(
              name: 'precautions',
              decoration: InputDecoration(
                labelText: translate('precautions_warnings'),
                hintText: translate('safety_precautions'),
                border: OutlineInputBorder(
                  borderRadius: context.responsiveBorderRadius,
                ),
              ),
              maxLines: 3,
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),

            // Traditional Source
            FormBuilderTextField(
              name: 'traditional_source',
              decoration: InputDecoration(
                labelText: translate('traditional_source'),
                hintText: translate('cultural_or_family_source'),
                border: OutlineInputBorder(
                  borderRadius: context.responsiveBorderRadius,
                ),
              ),
              maxLines: 2,
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 18, tablet: 24, desktop: 30)),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting
                    ? null
                    : () => _submitRemedyRecipe(context, translate),
                child: _isSubmitting
                    ? const CircularProgressIndicator()
                    : Text(translate('submit_remedy')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitMealRecipe(
      BuildContext context, String Function(String) translate) async {
    if (!_formKey.currentState!.saveAndValidate()) return;

    setState(() {
      _isSubmitting = true;
    });

    // Capture all translations and context-dependent objects before async operations
    final successMessage = translate('recipe_submitted_successfully');
    final errorMessage = translate('error_submitting_recipe');
    final messenger = ScaffoldMessenger.of(context);

    try {
      final formData = _formKey.currentState!.value;
      final authService = ref.read(authServiceProvider);
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Create meal recipe data
      final recipeData = {
        'name': formData['name'],
        'type': 'meal',
        'category': formData['category'],
        'difficulty': formData['difficulty'],
        'prep_time': formData['prep_time'],
        'servings': int.parse(formData['servings'].toString()),
        'ingredients': formData['ingredients'],
        'instructions': formData['instructions'],
        'nutritional_benefits': formData['nutritional_benefits'],
        'cultural_significance': formData['cultural_significance'],
        'submitted_by': currentUser.uid,
        'submitted_by_email': currentUser.email,
        'status': 'pending_review',
        'created_at': DateTime.now().toIso8601String(),
      };

      await _databases.createDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.userSubmittedRecipesCollectionId,
        documentId: ID.unique(),
        data: recipeData,
      );

      if (!mounted) return;
      
      messenger.showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: Colors.green,
        ),
      );

      // Reset form
      _formKey.currentState!.reset();
    } catch (e) {
      if (!mounted) return;
      
      messenger.showSnackBar(
        SnackBar(
          content: Text('$errorMessage: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _submitRemedyRecipe(
      BuildContext context, String Function(String) translate) async {
    if (!_formKey.currentState!.saveAndValidate()) return;

    setState(() {
      _isSubmitting = true;
    });

    // Capture all translations and context-dependent objects before async operations
    final successMessage = translate('remedy_submitted_successfully');
    final errorMessage = translate('error_submitting_remedy');
    final messenger = ScaffoldMessenger.of(context);

    try {
      final formData = _formKey.currentState!.value;
      final authService = ref.read(authServiceProvider);
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Create remedy recipe data
      final recipeData = {
        'name': formData['name'],
        'type': 'natural_remedy',
        'category': formData['category'],
        'difficulty': formData['difficulty'],
        'prep_time': formData['prep_time'],
        'ingredients': formData['ingredients'],
        'instructions': formData['instructions'],
        'usage_instructions': formData['usage_instructions'],
        'health_benefits': formData['health_benefits'],
        'precautions': formData['precautions'],
        'traditional_source': formData['traditional_source'],
        'submitted_by': currentUser.uid,
        'submitted_by_email': currentUser.email,
        'status': 'pending_review',
        'created_at': DateTime.now().toIso8601String(),
      };

      await _databases.createDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId:
            AppwriteBackendConfig.userSubmittedHealthTipsCollectionId,
        documentId: ID.unique(),
        data: recipeData,
      );

      if (!mounted) return;
      
      messenger.showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: Colors.green,
        ),
      );

      // Reset form
      _formKey.currentState!.reset();
    } catch (e) {
      if (!mounted) return;
      
      messenger.showSnackBar(
        SnackBar(
          content: Text('$errorMessage: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}




