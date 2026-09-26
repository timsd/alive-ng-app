import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/health_content_service.dart';
import '../../services/role_access_service.dart';
import '../../widgets/custom_app_bar.dart';

class AdminHealthContentScreen extends ConsumerStatefulWidget {
  const AdminHealthContentScreen({super.key});

  @override
  ConsumerState<AdminHealthContentScreen> createState() =>
      _AdminHealthContentScreenState();
}

class _AdminHealthContentScreenState
    extends ConsumerState<AdminHealthContentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final HealthContentService _service = HealthContentService.instance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initData();
  }

  Future<void> _initData() async {
    await _service.ensureInitialized();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleService = RoleAccessService.instance;

    // `canManageHealthContent` (not `canAccessAdmin`) so a narrow
    // `dietist` can add recipes/remedies without being a full admin.
    if (!roleService.canManageHealthContent()) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Access Restricted'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Health+ content privileges are required to manage recipes and remedies.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Health+ Content Admin',
        showDonationButton: false,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          tabs: const [
            Tab(icon: Icon(Icons.restaurant_menu), text: 'Recipes'),
            Tab(icon: Icon(Icons.spa), text: 'Remedies'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _showRecipeDialog(context);
          } else {
            _showRemedyDialog(context);
          }
        },
        icon: const Icon(Icons.add),
        label: Text(_tabController.index == 0 ? 'Add Recipe' : 'Add Remedy'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : AnimatedBuilder(
              animation: _service,
              builder: (context, _) {
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRecipesList(theme),
                    _buildRemediesList(theme),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildRecipesList(ThemeData theme) {
    final recipes = _service.recipes;
    if (recipes.isEmpty) {
      return Center(
        child: Text('No recipes found. Tap "Add Recipe" to create one.',
            style: theme.textTheme.bodyMedium),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final r = recipes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
              child: Icon(Icons.restaurant, color: theme.colorScheme.primary),
            ),
            title: Text(
              r.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${r.category} • ${r.region} Region • ${r.prepTime}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  r.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') {
                  _showRecipeDialog(context, recipe: r);
                } else if (val == 'delete') {
                  _confirmDelete(context, r.title, () => _service.deleteRecipe(r.id));
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRemediesList(ThemeData theme) {
    final remedies = _service.remedies;
    if (remedies.isEmpty) {
      return Center(
        child: Text('No remedies found. Tap "Add Remedy" to create one.',
            style: theme.textTheme.bodyMedium),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: remedies.length,
      itemBuilder: (context, index) {
        final rem = remedies[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.15),
              child: Icon(Icons.spa, color: theme.colorScheme.secondary),
            ),
            title: Text(
              rem.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Category: ${rem.ailmentCategory}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rem.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') {
                  _showRemedyDialog(context, remedy: rem);
                } else if (val == 'delete') {
                  _confirmDelete(context, rem.title, () => _service.deleteRemedy(rem.id));
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRecipeDialog(BuildContext context, {HealthRecipeItem? recipe}) {
    final titleCtrl = TextEditingController(text: recipe?.title ?? '');
    final descCtrl = TextEditingController(text: recipe?.description ?? '');
    final categoryCtrl = TextEditingController(text: recipe?.category ?? 'Lunch');
    final regionCtrl = TextEditingController(text: recipe?.region ?? 'General');
    final prepTimeCtrl = TextEditingController(text: recipe?.prepTime ?? '30 mins');
    final ingredientsCtrl =
        TextEditingController(text: recipe?.ingredients.join('\n') ?? '');
    final instructionsCtrl =
        TextEditingController(text: recipe?.instructions.join('\n') ?? '');
    final benefitsCtrl = TextEditingController(text: recipe?.benefits ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(recipe == null ? 'Add Plant-Based Recipe' : 'Edit Recipe'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Recipe Title*'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Short Description*'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: categoryCtrl,
                      decoration: const InputDecoration(labelText: 'Category (e.g. Lunch)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: regionCtrl,
                      decoration: const InputDecoration(labelText: 'Region (e.g. West)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: prepTimeCtrl,
                decoration: const InputDecoration(labelText: 'Prep Time (e.g. 45 mins)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ingredientsCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Ingredients (one per line)*',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: instructionsCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Instructions (one step per line)*',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: benefitsCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Nutritional / Health Benefits'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty) {
                return;
              }
              final ingList = ingredientsCtrl.text
                  .split('\n')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
              final insList = instructionsCtrl.text
                  .split('\n')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();

              final newItem = HealthRecipeItem(
                id: recipe?.id ?? 'rec_${DateTime.now().millisecondsSinceEpoch}',
                title: titleCtrl.text.trim(),
                description: descCtrl.text.trim(),
                category: categoryCtrl.text.trim().isEmpty ? 'Meal' : categoryCtrl.text.trim(),
                region: regionCtrl.text.trim().isEmpty ? 'General' : regionCtrl.text.trim(),
                prepTime: prepTimeCtrl.text.trim().isEmpty ? '30 mins' : prepTimeCtrl.text.trim(),
                servings: 4,
                ingredients: ingList,
                instructions: insList,
                healthPrinciples: ['Nutrition', 'Temperance'],
                benefits: benefitsCtrl.text.trim(),
              );

              if (recipe == null) {
                _service.addRecipe(newItem);
              } else {
                _service.updateRecipe(newItem);
              }
              Navigator.pop(ctx);
            },
            child: Text(recipe == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _showRemedyDialog(BuildContext context, {HealthRemedyItem? remedy}) {
    final titleCtrl = TextEditingController(text: remedy?.title ?? '');
    final descCtrl = TextEditingController(text: remedy?.description ?? '');
    final categoryCtrl =
        TextEditingController(text: remedy?.ailmentCategory ?? 'Cold & Flu');
    final ingredientsCtrl =
        TextEditingController(text: remedy?.ingredients.join('\n') ?? '');
    final stepsCtrl =
        TextEditingController(text: remedy?.preparationSteps.join('\n') ?? '');
    final dosageCtrl =
        TextEditingController(text: remedy?.dosageAndUsage ?? '');
    final precautionsCtrl =
        TextEditingController(text: remedy?.precautions ?? '');
    final verseCtrl =
        TextEditingController(text: remedy?.biblicalPrinciple ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(remedy == null ? 'Add Natural Remedy' : 'Edit Remedy'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Remedy Title*'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description*'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: categoryCtrl,
                decoration: const InputDecoration(labelText: 'Ailment Category (e.g. Digestion)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ingredientsCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Ingredients (one per line)*',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: stepsCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Preparation Steps (one per line)*',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: dosageCtrl,
                decoration: const InputDecoration(labelText: 'Dosage & Usage Instructions*'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: precautionsCtrl,
                decoration: const InputDecoration(labelText: 'Precautions / Contraindications'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: verseCtrl,
                decoration: const InputDecoration(labelText: 'Scripture Reference / Principle'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty) {
                return;
              }
              final ingList = ingredientsCtrl.text
                  .split('\n')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
              final stepList = stepsCtrl.text
                  .split('\n')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();

              final newItem = HealthRemedyItem(
                id: remedy?.id ?? 'rem_${DateTime.now().millisecondsSinceEpoch}',
                title: titleCtrl.text.trim(),
                description: descCtrl.text.trim(),
                ailmentCategory: categoryCtrl.text.trim().isEmpty
                    ? 'General Health'
                    : categoryCtrl.text.trim(),
                ingredients: ingList,
                preparationSteps: stepList,
                dosageAndUsage: dosageCtrl.text.trim(),
                precautions: precautionsCtrl.text.trim(),
                biblicalPrinciple: verseCtrl.text.trim(),
              );

              if (remedy == null) {
                _service.addRemedy(newItem);
              } else {
                _service.updateRemedy(newItem);
              }
              Navigator.pop(ctx);
            },
            child: Text(remedy == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String title, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              onConfirm();
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
