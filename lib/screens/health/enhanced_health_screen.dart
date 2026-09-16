import 'package:flutter/material.dart';
import '../../services/health_content_service.dart';
import '../../services/role_access_service.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/custom_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_constants.dart';

class EnhancedHealthScreen extends ConsumerStatefulWidget {
  const EnhancedHealthScreen({super.key});

  @override
  ConsumerState<EnhancedHealthScreen> createState() =>
      _EnhancedHealthScreenState();
}

class _EnhancedHealthScreenState extends ConsumerState<EnhancedHealthScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final HealthContentService _contentService = HealthContentService();

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // 3 tabs: Recipes, Remedies, Community Q&A
    _tabController = TabController(length: 3, vsync: this);
    _loadHealthData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHealthData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await _contentService.ensureInitialized();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPost = RoleAccessService.instance.canPostHealth();
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Health+',
        showDonationButton: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: theme.colorScheme.onPrimary,
          indicatorWeight: 3,
          labelColor: theme.colorScheme.onPrimary,
          unselectedLabelColor:
              theme.colorScheme.onPrimary.withValues(alpha: 0.72),
          tabs: const [
            Tab(icon: Icon(Icons.restaurant_menu), text: 'Recipes'),
            Tab(icon: Icon(Icons.spa), text: 'Remedies'),
            Tab(icon: Icon(Icons.forum), text: 'Community Q&A'),
          ],
        ),
      ),
      floatingActionButton: canPost
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppConstants.recipeSubmissionRoute),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRecipesTab(),
                    _buildRemediesTab(),
                    _buildCommunityTab(),
                  ],
                ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: context.responsiveIconSize(64), color: Theme.of(context).colorScheme.error),
          SizedBox(
              height: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 16.0, tablet: 18.0, desktop: 20.0)),
          Text(
            'Failed to load health data',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(
              height: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 8.0, tablet: 10.0, desktop: 12.0)),
          Text(
            _error ?? 'Unknown error occurred',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(
              height: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 16.0, tablet: 18.0, desktop: 20.0)),
          ElevatedButton(
            onPressed: _loadHealthData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ── Recipes Tab ──────────────────────────────────────────────────────
  Widget _buildRecipesTab() {
    final recipes = _contentService.recipes;
    return ListView(
      padding: context.responsivePadding,
      children: [
        _sectionHeader(
          'Plant-Based Nigerian Recipes',
          'Wholesome meals from the Health+ kitchen',
          Icons.restaurant_menu,
        ),
        const SizedBox(height: 12),
        if (recipes.isEmpty)
          _emptyCard('No recipes yet', 'Admins can publish the first recipe from the Admin Dashboard.')
        else
          ...recipes.map((recipe) => _buildHealthRecipeCard(recipe)),
      ],
    );
  }

  Widget _buildHealthRecipeCard(HealthRecipeItem recipe) {
    final theme = Theme.of(context);
    final commentCount = _contentService.getCommentsFor(recipe.id).length;
    return Card(
      margin: EdgeInsets.only(
          bottom: ResponsiveUtils.getResponsiveValue(
              context: context, mobile: 12, tablet: 16, desktop: 20)),
      child: Padding(
        padding: context.responsivePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    recipe.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.getResponsiveValue(
                          context: context, mobile: 8, tablet: 10, desktop: 12),
                      vertical: ResponsiveUtils.getResponsiveValue(
                          context: context, mobile: 4, tablet: 6, desktop: 8)),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: context.responsiveBorderRadius,
                  ),
                  child: Text(
                    recipe.category.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 8, tablet: 10, desktop: 12)),
            Text(
              recipe.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 12, tablet: 16, desktop: 20)),
            // Ingredients preview
            if (recipe.ingredients.isNotEmpty) ...[
              Text(
                'Key Ingredients:',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                recipe.ingredients.take(4).join(' • '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
            ],
            // Metadata row
            Row(
              children: [
                Icon(Icons.schedule,
                    size: context.responsiveIconSize(16),
                    color: theme.colorScheme.onSurfaceVariant),
                SizedBox(
                    width: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 4, tablet: 6, desktop: 8)),
                Text(
                  recipe.prepTime,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
                SizedBox(
                    width: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 16, tablet: 20, desktop: 24)),
                Icon(Icons.people,
                    size: context.responsiveIconSize(16),
                    color: theme.colorScheme.onSurfaceVariant),
                SizedBox(
                    width: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 4, tablet: 6, desktop: 8)),
                Text(
                  '${recipe.servings} servings',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
                const Spacer(),
                // Comment button
                TextButton.icon(
                  onPressed: () => _showCommentSheet(recipe.id, recipe.title),
                  icon: Icon(Icons.comment_outlined, size: 16, color: theme.colorScheme.primary),
                  label: Text(
                    commentCount > 0 ? '$commentCount' : 'Comment',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            if (recipe.healthPrinciples.isNotEmpty) ...[
              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 8, tablet: 10, desktop: 12)),
              Wrap(
                spacing: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 4, tablet: 6, desktop: 8),
                children: recipe.healthPrinciples
                    .take(3)
                    .map((principle) => Chip(
                          label: Text(
                            principle,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                          backgroundColor:
                              theme.colorScheme.secondaryContainer,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
            ],
            // Expandable detail
            ExpansionTile(
              title: Text(
                'View Full Recipe',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              children: [
                if (recipe.ingredients.isNotEmpty) ...[
                  _detailSection('Ingredients', recipe.ingredients),
                  const SizedBox(height: 8),
                ],
                if (recipe.instructions.isNotEmpty) ...[
                  _detailSection('Instructions', recipe.instructions, numbered: true),
                  const SizedBox(height: 8),
                ],
                if (recipe.benefits.isNotEmpty) ...[
                  Text(
                    'Health Benefits',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recipe.benefits,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.tertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailSection(String title, List<String> items, {bool numbered = false}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        ...items.asMap().entries.map((entry) {
          final prefix = numbered ? '${entry.key + 1}. ' : '• ';
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '$prefix${entry.value}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Remedies Tab ──────────────────────────────────────────────────────
  Widget _buildRemediesTab() {
    final remedies = _contentService.remedies;
    return ListView(
      padding: context.responsivePadding,
      children: [
        _sectionHeader(
          'Natural Remedies',
          'Time-tested remedies guided by divine health principles',
          Icons.spa,
        ),
        const SizedBox(height: 12),
        if (remedies.isEmpty)
          _emptyCard('No remedies yet', 'Admins can add natural remedies from the Admin Dashboard.')
        else
          ...remedies.map((remedy) => _buildHealthRemedyCard(remedy)),
      ],
    );
  }

  Widget _buildHealthRemedyCard(HealthRemedyItem remedy) {
    final theme = Theme.of(context);
    final commentCount = _contentService.getCommentsFor(remedy.id).length;
    return Card(
      margin: EdgeInsets.only(
          bottom: ResponsiveUtils.getResponsiveValue(
              context: context, mobile: 12, tablet: 16, desktop: 20)),
      child: Padding(
        padding: context.responsivePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.local_florist,
                      color: theme.colorScheme.tertiary,
                      size: context.responsiveIconSize(20)),
                ),
                SizedBox(
                    width: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 12, tablet: 16, desktop: 20)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        remedy.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          remedy.ailmentCategory,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 12, tablet: 16, desktop: 20)),
            Text(
              remedy.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            // Dosage & Usage
            if (remedy.dosageAndUsage.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.medication_outlined,
                        size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        remedy.dosageAndUsage,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Precautions
            if (remedy.precautions.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 18, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⚠️ ${remedy.precautions}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Biblical principle
            if (remedy.biblicalPrinciple.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: theme.colorScheme.tertiary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.menu_book,
                        color: theme.colorScheme.tertiary,
                        size: context.responsiveIconSize(16)),
                    SizedBox(
                        width: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 8,
                            tablet: 10,
                            desktop: 12)),
                    Expanded(
                      child: Text(
                        remedy.biblicalPrinciple,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Comment + expand row
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _showCommentSheet(remedy.id, remedy.title),
                  icon: Icon(Icons.comment_outlined, size: 16, color: theme.colorScheme.primary),
                  label: Text(
                    commentCount > 0 ? '$commentCount Comments' : 'Comment',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            // Expandable preparation steps
            if (remedy.preparationSteps.isNotEmpty || remedy.ingredients.isNotEmpty)
              ExpansionTile(
                title: Text(
                  'View Preparation Details',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                children: [
                  if (remedy.ingredients.isNotEmpty)
                    _detailSection('Ingredients', remedy.ingredients),
                  if (remedy.preparationSteps.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _detailSection('Preparation', remedy.preparationSteps, numbered: true),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ── Community Q&A Tab ────────────────────────────────────────────────
  Widget _buildCommunityTab() {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final communityComments = _contentService.getCommunityQnA();

    return ListView(
      padding: context.responsivePadding,
      children: [
        _sectionHeader(
          'Community Q&A',
          'Ask questions, share tips, and encourage one another',
          Icons.forum,
        ),
        const SizedBox(height: 16),
        // Sign In button for guests
        if (user == null) ...[
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.lock_outline,
                      size: 40,
                      color: theme.colorScheme.onPrimaryContainer),
                  const SizedBox(height: 12),
                  Text(
                    'Sign in to join the discussion',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share your health tips, ask questions, and connect with other members.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => context.push(AppConstants.authRoute),
                    icon: const Icon(Icons.login),
                    label: const Text('Sign In to Join Discussion'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ] else ...[
          // Post form for authenticated users
          _buildPostForm(user),
          const SizedBox(height: 16),
        ],
        // Existing community comments
        if (communityComments.isEmpty)
          _emptyCard(
            'No discussions yet',
            user != null
                ? 'Be the first to ask a health question!'
                : 'Sign in to start a discussion.',
          )
        else
          ...communityComments.map((comment) => _buildCommentCard(comment)),
      ],
    );
  }

  Widget _buildPostForm(AppUser user) {
    final theme = Theme.of(context);
    final controller = TextEditingController();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(
                    (user.displayName ?? user.email).isNotEmpty
                        ? (user.displayName ?? user.email)[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  user.displayName ?? user.email.split('@').first,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ask a health question or share a tip...',
                hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () async {
                  final text = controller.text.trim();
                  if (text.isEmpty) return;
                  await _contentService.addComment(
                    targetId: 'general',
                    authorName: user.displayName ?? user.email.split('@').first,
                    authorEmail: user.email,
                    content: text,
                  );
                  controller.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.send, size: 18),
                label: const Text('Post'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentCard(HealthCommentItem comment) {
    final theme = Theme.of(context);
    final timeAgo = _formatTimeAgo(comment.createdAt);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: Text(
                comment.authorName.isNotEmpty
                    ? comment.authorName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: theme.colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        comment.authorName,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeAgo,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment.content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Comment Bottom Sheet ─────────────────────────────────────────────
  void _showCommentSheet(String targetId, String targetTitle) {
    final user = ref.read(currentUserProvider);
    final theme = Theme.of(context);
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final comments = _contentService.getCommentsFor(targetId);
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              minChildSize: 0.3,
              builder: (_, scrollController) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom,
                  ),
                  child: Column(
                    children: [
                      // Handle bar
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Comments on "$targetTitle"',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: comments.isEmpty
                            ? Center(
                                child: Text(
                                  'No comments yet. Be the first!',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: comments.length,
                                itemBuilder: (_, i) =>
                                    _buildCommentCard(comments[i]),
                              ),
                      ),
                      // Input area
                      if (user != null) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: controller,
                                  decoration: InputDecoration(
                                    hintText: 'Write a comment...',
                                    hintStyle: TextStyle(
                                        color: theme.colorScheme.onSurfaceVariant),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                onPressed: () async {
                                  final text = controller.text.trim();
                                  if (text.isEmpty) return;
                                  await _contentService.addComment(
                                    targetId: targetId,
                                    authorName: user.displayName ??
                                        user.email.split('@').first,
                                    authorEmail: user.email,
                                    content: text,
                                  );
                                  controller.clear();
                                  setSheetState(() {});
                                  setState(() {}); // Update parent counts
                                },
                                icon: const Icon(Icons.send, size: 20),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              context.push(AppConstants.authRoute);
                            },
                            icon: const Icon(Icons.login),
                            label: const Text('Sign In to Comment'),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ── Shared Widgets ───────────────────────────────────────────────────
  Widget _sectionHeader(String title, String subtitle, IconData icon) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: theme.colorScheme.primary),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _emptyCard(String title, String subtitle) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surface,
      child: ListTile(
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
