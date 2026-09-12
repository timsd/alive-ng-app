import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/appwrite_facade.dart';
import '../../config/appwrite_backend_config.dart';
import '../../main.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/layout_fix_utils.dart';
import '../../models/kids_models.dart';
import '../../utils/error_handler.dart';
import '../../utils/search_utils.dart';

class KidsStoriesScreen extends ConsumerStatefulWidget {
  const KidsStoriesScreen({super.key});

  @override
  ConsumerState<KidsStoriesScreen> createState() => _KidsStoriesScreenState();
}

class _KidsStoriesScreenState extends ConsumerState<KidsStoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedAgeGroup = 'All';
  String _selectedCategory = 'All';
  final Set<String> _favoriteStories = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  void _openStoryReader(BuildContext context, BibleStory story) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(story.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (story.illustrationUrl != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      story.illustrationUrl!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 150,
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        child: Icon(Icons.broken_image,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ),
              Text(
                story.description,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),
              if (story.content != null && story.content!.isNotEmpty) ...[
                Text('Content:',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(story.content!,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
              ],
              Text('Moral Lesson:',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(story.moralLesson,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              Text('Bible Reference:',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(story.bibleReference,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Appwrite-backed stream wrapper for StreamBuilder compatibility.
  Stream<List<BibleStory>> _getStoriesStream() {
    return Stream.fromFuture(TablesDB(appwriteClient).listRows(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: AppwriteBackendConfig.kidsStoriesCollectionId,
      queries: [Query.equal('is_active', true), Query.limit(100)],
    ).then((snapshot) {
      return snapshot.rows
          .map((row) {
            final data = _mapStoryDocument(row);

            try {
              return BibleStory.fromJson(data);
            } catch (e) {
              return null; // Ignore corrupted mappings locally while migrating
            }
          })
          .whereType<BibleStory>()
          .toList();
    }));
  }

  Map<String, dynamic> _mapStoryDocument(dynamic row) {
    final data = Map<String, dynamic>.from(row.data);
    final categories = _stringList(data['categories']);
    final category = (data['category'] as String?) ??
        (categories.isNotEmpty ? categories.first : 'oldTestament');

    return {
      'id': row.$id,
      'title': data['title'] ?? 'Untitled Story',
      'subtitle': data['subtitle'] ?? '',
      'ageGroup': _storyAgeGroup(data['age_group']),
      'duration': data['duration'] ?? 10,
      'description': data['description'] ?? '',
      'content': data['content'],
      'moralLesson': data['moral_lesson'] ?? data['moralLesson'] ?? '',
      'bibleReference':
          data['bible_reference'] ?? data['bibleReference'] ?? '',
      'audioUrl': data['audio_url'] ?? data['audioUrl'],
      'illustrationUrl':
          data['illustration_url'] ?? data['image_url'] ?? data['illustrationUrl'],
      'mediaUrl': data['media_url'] ?? data['mediaUrl'],
      'completed': data['completed'] ?? false,
      'favorite': data['favorite'] ?? false,
      'category': _storyCategory(category),
      'tags': _stringList(data['tags']),
    };
  }

  List<String> _stringList(dynamic value) {
    if (value is List) return value.map((item) => item.toString()).toList();
    if (value is String && value.isNotEmpty) return [value];
    return const [];
  }

  String _storyAgeGroup(dynamic value) {
    final normalized = value?.toString().toLowerCase().replaceAll('_', '-') ?? '';
    if (normalized.contains('11')) return 'age-11-14';
    if (normalized.contains('7')) return 'age-7-10';
    return 'age-3-6';
  }

  String _storyCategory(dynamic value) {
    final normalized = value?.toString().toLowerCase().replaceAll('_', '-') ?? '';
    if (normalized.contains('new')) return 'newTestament';
    if (normalized.contains('parable')) return 'parables';
    if (normalized.contains('miracle')) return 'miracles';
    if (normalized.contains('doctrine')) return 'sdaDoctrines';
    if (normalized.contains('value')) return 'sdaValues';
    return 'oldTestament';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Kids Stories',
        showBackButton: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.auto_stories), text: 'Stories'),
            Tab(icon: Icon(Icons.favorite), text: 'Favorites'),
            Tab(icon: Icon(Icons.history), text: 'Recently Read'),
            Tab(icon: Icon(Icons.download), text: 'Downloaded'),
          ],
        ),
      ),
      body: StreamBuilder<List<BibleStory>>(
          stream: _getStoriesStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _buildLoadStateCard(
                context,
                title: 'Unable to load kids stories',
                message: ErrorHandler.getUserFriendlyMessage(snapshot.error),
                icon: Icons.cloud_off_rounded,
              );
            }

            final stories = snapshot.data ?? [];

            return Column(
              children: [
                // Search and Filter Bar
                Container(
                  padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 12.0,
                      tablet: 16.0,
                      desktop: 20.0)),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search stories...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                                ResponsiveUtils.getResponsiveValue(
                                    context: context,
                                    mobile: 10.0,
                                    tablet: 12.0,
                                    desktop: 14.0)),
                          ),
                        ),
                        onChanged: (value) => setState(() {}),
                      ),
                      SizedBox(
                          height: ResponsiveUtils.getResponsiveValue(
                              context: context,
                              mobile: 10.0,
                              tablet: 12.0,
                              desktop: 14.0)),
                      LayoutFixUtils.safeRow(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _selectedAgeGroup,
                              decoration: InputDecoration(
                                labelText: 'Age Group',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        ResponsiveUtils.getResponsiveValue(
                                            context: context,
                                            mobile: 6,
                                            tablet: 8,
                                            desktop: 10))),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal:
                                      ResponsiveUtils.getResponsiveValue(
                                          context: context,
                                          mobile: 10,
                                          tablet: 12,
                                          desktop: 14),
                                  vertical: ResponsiveUtils.getResponsiveValue(
                                      context: context,
                                      mobile: 6,
                                      tablet: 8,
                                      desktop: 10),
                                ),
                              ),
                              items: [
                                const DropdownMenuItem(
                                    value: 'All', child: Text('All Ages')),
                                ...AgeGroup.values.map((age) =>
                                    DropdownMenuItem(
                                        value: age.displayName,
                                        child: Text(age.displayName))),
                              ],
                              onChanged: (value) =>
                                  setState(() => _selectedAgeGroup = value!),
                            ),
                          ),
                          SizedBox(
                              width: ResponsiveUtils.getResponsiveValue(
                                  context: context,
                                  mobile: 10.0,
                                  tablet: 12.0,
                                  desktop: 14.0)),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _selectedCategory,
                              decoration: InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        ResponsiveUtils.getResponsiveValue(
                                            context: context,
                                            mobile: 6,
                                            tablet: 8,
                                            desktop: 10))),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal:
                                      ResponsiveUtils.getResponsiveValue(
                                          context: context,
                                          mobile: 10,
                                          tablet: 12,
                                          desktop: 14),
                                  vertical: ResponsiveUtils.getResponsiveValue(
                                      context: context,
                                      mobile: 6,
                                      tablet: 8,
                                      desktop: 10),
                                ),
                              ),
                              items: [
                                const DropdownMenuItem(
                                    value: 'All', child: Text('All Stories')),
                                ...StoryCategory.values.map((cat) =>
                                    DropdownMenuItem(
                                        value: cat.displayName,
                                        child: Text(cat.displayName))),
                              ],
                              onChanged: (value) =>
                                  setState(() => _selectedCategory = value!),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBibleStoriesTab(stories),
                      _buildFavoritesTab(stories),
                      _buildRecentlyReadTab(stories),
                      _buildDownloadedTab(stories),
                    ],
                  ),
                ),
              ],
            );
          }),
    );
  }

  Widget _buildLoadStateCard(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBibleStoriesTab(List<BibleStory> stories) {
    if (stories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_stories,
                size: 56,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No Stories Available',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Check back later for new stories',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    // Filter (search standard: exact phrase, then ALL words, then ANY word).
    final preFiltered = stories.where((story) {
      final matchesAge = _selectedAgeGroup == 'All' ||
          story.ageGroup.displayName == _selectedAgeGroup;
      final matchesCategory = _selectedCategory == 'All' ||
          story.category.displayName == _selectedCategory;
      return matchesAge && matchesCategory;
    }).toList();
    final filteredStories = SearchUtils.rankFilter(
      preFiltered,
      _searchController.text,
      (story) => [story.title, story.description],
    );

    if (filteredStories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off,
                size: 56,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No stories match your filters',
                style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
          context: context, mobile: 12, tablet: 16, desktop: 20)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: ResponsiveUtils.getResponsiveValue(
            context: context, mobile: 12, tablet: 16, desktop: 20),
        mainAxisSpacing: ResponsiveUtils.getResponsiveValue(
            context: context, mobile: 12, tablet: 16, desktop: 20),
      ),
      itemCount: filteredStories.length,
      itemBuilder: (context, index) {
        final story = filteredStories[index];
        return _buildStoryCardFromData(
            context, story, _favoriteStories.contains(story.id), false);
      },
    );
  }

  Widget _buildFavoritesTab(List<BibleStory> stories) {
    final favoriteStories =
        stories.where((story) => _favoriteStories.contains(story.id)).toList();

    if (favoriteStories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border,
                size: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 56, tablet: 64, desktop: 72),
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 14, tablet: 16, desktop: 18)),
            Text('No favorite stories yet',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 6, tablet: 8, desktop: 10)),
            Text('Tap the heart icon on any story to add it to your favorites',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.8)),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
          context: context, mobile: 12, tablet: 16, desktop: 20)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: ResponsiveUtils.getResponsiveValue(
            context: context, mobile: 12, tablet: 16, desktop: 20),
        mainAxisSpacing: ResponsiveUtils.getResponsiveValue(
            context: context, mobile: 12, tablet: 16, desktop: 20),
      ),
      itemCount: favoriteStories.length,
      itemBuilder: (context, index) {
        return _buildStoryCardFromData(
            context, favoriteStories[index], true, false);
      },
    );
  }

  Widget _buildRecentlyReadTab(List<BibleStory> stories) {
    // Mocked out temporarily until progress tracking is fully implemented in Appwrite.
    // Showing top 5 as "recently read" for UI continuity
    final recent = stories.take(5).toList();
    if (recent.isEmpty) {
      return const Center(child: Text("Read stories to track them here"));
    }

    return ListView.builder(
      padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
          context: context, mobile: 12, tablet: 16, desktop: 20)),
      itemCount: recent.length,
      itemBuilder: (context, index) {
        return _buildRecentStoryItem(context, recent[index]);
      },
    );
  }

  Widget _buildDownloadedTab(List<BibleStory> stories) {
    // Only display stories where audio/image URL exists indicating media readiness
    final downloaded = stories
        .where((s) => s.audioUrl != null || s.illustrationUrl != null)
        .toList();

    if (downloaded.isEmpty) {
      return const Center(child: Text("No items fully cashed on device"));
    }

    return GridView.builder(
      padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
          context: context, mobile: 12, tablet: 16, desktop: 20)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: ResponsiveUtils.getResponsiveValue(
            context: context, mobile: 12, tablet: 16, desktop: 20),
        mainAxisSpacing: ResponsiveUtils.getResponsiveValue(
            context: context, mobile: 12, tablet: 16, desktop: 20),
      ),
      itemCount: downloaded.length,
      itemBuilder: (context, index) {
        return _buildStoryCardFromData(context, downloaded[index],
            _favoriteStories.contains(downloaded[index].id), true);
      },
    );
  }

  Widget _buildStoryCardFromData(BuildContext context, BibleStory story,
      bool isFavorite, bool isDownloaded) {
    final categoryColors = {
      StoryCategory.oldTestament: Theme.of(context).colorScheme.primary,
      StoryCategory.newTestament: Theme.of(context).colorScheme.tertiary,
      StoryCategory.parables: Theme.of(context).colorScheme.secondary,
      StoryCategory.miracles: Theme.of(context).colorScheme.secondary,
      StoryCategory.sdaDoctrines: Theme.of(context).colorScheme.tertiary,
      StoryCategory.sdaValues: Theme.of(context).colorScheme.primary,
    };
    final color =
        categoryColors[story.category] ?? Theme.of(context).colorScheme.primary;

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(
            context: context, mobile: 14, tablet: 16, desktop: 18)),
        side: BorderSide(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.4)),
      ),
      child: InkWell(
        onTap: () => _openStoryReader(context, story),
        borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(
            context: context, mobile: 14, tablet: 16, desktop: 18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Story Image/Icon
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  image: story.illustrationUrl != null
                      ? DecorationImage(
                          image: NetworkImage(story.illustrationUrl!),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                              Theme.of(context)
                                  .colorScheme
                                  .shadow
                                  .withValues(alpha: 0.3),
                              BlendMode.darken))
                      : null,
                  gradient: story.illustrationUrl == null
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withValues(alpha: 0.8),
                            color.withValues(alpha: 0.6),
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 14, tablet: 16, desktop: 18)),
                  ),
                ),
                child: Stack(
                  children: [
                    if (story.illustrationUrl == null)
                      Center(
                        child: Icon(
                          Icons.auto_stories,
                          size: ResponsiveUtils.getResponsiveValue(
                              context: context,
                              mobile: 42,
                              tablet: 48,
                              desktop: 54),
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    Positioned(
                      top: ResponsiveUtils.getResponsiveValue(
                          context: context, mobile: 6, tablet: 8, desktop: 10),
                      right: ResponsiveUtils.getResponsiveValue(
                          context: context, mobile: 6, tablet: 8, desktop: 10),
                      child: IconButton(
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.onPrimary,
                        ),
                        onPressed: () {
                          setState(() {
                            if (_favoriteStories.contains(story.id)) {
                              _favoriteStories.remove(story.id);
                            } else {
                              _favoriteStories.add(story.id);
                            }
                          });
                        },
                      ),
                    ),
                    if (isDownloaded)
                      Positioned(
                        top: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 6,
                            tablet: 8,
                            desktop: 10),
                        left: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 6,
                            tablet: 8,
                            desktop: 10),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.tertiary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.download_done,
                            size: 14,
                            color: Theme.of(context).colorScheme.onTertiary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Story Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 10, tablet: 12, desktop: 14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(
                        height: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 3,
                            tablet: 4,
                            desktop: 5)),
                    Text(
                      story.category.displayName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const Spacer(),
                    LayoutFixUtils.safeRow(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveUtils.getResponsiveValue(
                                context: context,
                                mobile: 5,
                                tablet: 6,
                                desktop: 7),
                            vertical: ResponsiveUtils.getResponsiveValue(
                                context: context,
                                mobile: 1,
                                tablet: 2,
                                desktop: 3),
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(
                                ResponsiveUtils.getResponsiveValue(
                                    context: context,
                                    mobile: 6,
                                    tablet: 8,
                                    desktop: 10)),
                          ),
                          child: Text(
                            story.ageGroup.displayName,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  fontSize: ResponsiveUtils.getResponsiveValue(
                                      context: context,
                                      mobile: 9,
                                      tablet: 10,
                                      desktop: 11),
                                ),
                          ),
                        ),
                        LayoutFixUtils.safeRow(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: ResponsiveUtils.getResponsiveValue(
                                  context: context,
                                  mobile: 10,
                                  tablet: 12,
                                  desktop: 14),
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                            SizedBox(
                                width: ResponsiveUtils.getResponsiveValue(
                                    context: context,
                                    mobile: 1,
                                    tablet: 2,
                                    desktop: 3)),
                            LayoutFixUtils.safeText(
                              '${story.duration} min',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    fontSize:
                                        ResponsiveUtils.getResponsiveValue(
                                            context: context,
                                            mobile: 9,
                                            tablet: 10,
                                            desktop: 11),
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentStoryItem(BuildContext context, BibleStory story) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      margin: EdgeInsets.only(
          bottom: ResponsiveUtils.getResponsiveValue(
              context: context, mobile: 10, tablet: 12, desktop: 14)),
      child: ListTile(
        leading: Container(
          width: ResponsiveUtils.getResponsiveValue(
              context: context, mobile: 50, tablet: 56, desktop: 62),
          height: ResponsiveUtils.getResponsiveValue(
              context: context, mobile: 50, tablet: 56, desktop: 62),
          decoration: BoxDecoration(
            image: story.illustrationUrl != null
                ? DecorationImage(
                    image: NetworkImage(story.illustrationUrl!),
                    fit: BoxFit.cover)
                : null,
            gradient: story.illustrationUrl == null
                ? LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor.withValues(alpha: 0.8),
                      Theme.of(context).primaryColor.withValues(alpha: 0.6),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(
                ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 6, tablet: 8, desktop: 10)),
          ),
          child: story.illustrationUrl == null
              ? Icon(
                  Icons.auto_stories,
                  color: Theme.of(context).colorScheme.onPrimary,
                )
              : null,
        ),
        title: Text(
          story.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Interactive Story Content Available',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 3, tablet: 4, desktop: 5)),
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 14, tablet: 16, desktop: 18),
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                SizedBox(
                    width: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 3, tablet: 4, desktop: 5)),
                Text(
                  'Added recently',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.tertiary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.play_arrow),
          onPressed: () {
            _openStoryReader(context, story);
          },
        ),
        onTap: () {
          _openStoryReader(context, story);
        },
      ),
    );
  }
}
