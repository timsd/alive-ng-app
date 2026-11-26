import 'package:flutter/material.dart';
import '../../widgets/modern_dropdown.dart';
import '../../utils/error_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/responsive_utils.dart';
import '../../services/appwrite_library_service.dart';
import '../../widgets/in_app_pdf_viewer.dart';
import '../../widgets/standard_video_player_modal.dart';
import '../../widgets/custom_image.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'all';
  String _selectedLanguage = 'all';
  final AppwriteLibraryService _libraryService =
      AppwriteLibraryService.instance;

  final List<Map<String, dynamic>> _allBooks = [];
  final List<Map<String, dynamic>> _allArticles = [];
  final List<Map<String, dynamic>> _allVideos = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLibraryContent();
  }

  Future<void> _loadLibraryContent() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final results = await Future.wait([
        _libraryService.listBooks(throwOnError: true),
        _libraryService.listArticles(throwOnError: true),
        _libraryService.listVideos(throwOnError: true),
      ]);
      if (!mounted) return;
      setState(() {
        _allBooks
          ..clear()
          ..addAll(results[0]);
        _allArticles
          ..clear()
          ..addAll(results[1]);
        _allVideos
          ..clear()
          ..addAll(results[2]);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = ErrorHandler.getUserFriendlyMessage(e);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Digital Library',
        showBackButton: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.library_books), text: 'Books'),
            Tab(icon: Icon(Icons.article), text: 'Articles'),
            Tab(icon: Icon(Icons.video_library), text: 'Videos'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
                context: context, mobile: 16, tablet: 20, desktop: 24)),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search library...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _showFilterDialog,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                      ResponsiveUtils.getResponsiveValue(
                          context: context,
                          mobile: 12,
                          tablet: 14,
                          desktop: 16)),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Tab Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null &&
                        _allBooks.isEmpty &&
                        _allArticles.isEmpty &&
                        _allVideos.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cloud_off_rounded,
                                size: 48,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _loadError!,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _loadLibraryContent,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildBooksTab(),
                          _buildArticlesTab(),
                          _buildVideosTab(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildBooksTab() {
    final filteredBooks = _getFilteredContent(_allBooks);

    return Padding(
      padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
          context: context, mobile: 16, tablet: 20, desktop: 24)),
      child: filteredBooks.isEmpty
          ? Center(
              child: Text(
                'No books found matching your search criteria',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            )
          : GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 1, tablet: 2, desktop: 3),
                childAspectRatio: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 2.5, tablet: 2.8, desktop: 3.0),
                crossAxisSpacing: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 12, tablet: 16, desktop: 20),
                mainAxisSpacing: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 12, tablet: 16, desktop: 20),
              ),
              itemCount: filteredBooks.length,
              itemBuilder: (context, index) =>
                  _buildBookCard(context, filteredBooks[index]),
            ),
    );
  }

  Widget _buildArticlesTab() {
    final filteredArticles = _getFilteredContent(_allArticles);

    return Padding(
      padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
          context: context, mobile: 16, tablet: 20, desktop: 24)),
      child: filteredArticles.isEmpty
          ? Center(
              child: Text(
                'No articles found matching your search criteria',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            )
          : ListView.builder(
              itemCount: filteredArticles.length,
              itemBuilder: (context, index) {
                return _buildArticleCard(context, filteredArticles[index]);
              },
            ),
    );
  }

  Widget _buildVideosTab() {
    final filteredVideos = _getFilteredContent(_allVideos);

    return Padding(
      padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
          context: context, mobile: 16, tablet: 20, desktop: 24)),
      child: filteredVideos.isEmpty
          ? Center(
              child: Text(
                'No videos found matching your search criteria',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            )
          : ListView.separated(
              itemCount: filteredVideos.length,
              separatorBuilder: (_, __) => SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 16, tablet: 20, desktop: 24),
              ),
              itemBuilder: (context, index) {
                return _buildVideoCard(context, filteredVideos[index]);
              },
            ),
    );
  }

  // Helper method to filter content based on search and category
  List<Map<String, dynamic>> _getFilteredContent(
      List<Map<String, dynamic>> content) {
    return content.where((item) {
      // Exclude hidden/inactive content from user view!
      final rawActive = item['is_active'] ?? item['isActive'];
      final isItemActive = rawActive == null ? true : (rawActive == true || rawActive == 1 || rawActive.toString().toLowerCase() == 'true');
      if (!isItemActive) return false;

      final title = (item['title'] ?? '').toString().toLowerCase();
      final author = (item['author'] ?? '').toString().toLowerCase();
      final category = (item['category'] ?? '').toString().toLowerCase();
      final language = (item['language'] ?? 'en').toString().toLowerCase();

      final matchesSearch = _searchQuery.isEmpty ||
          title.contains(_searchQuery) ||
          author.contains(_searchQuery);

      final matchesCategory = _selectedCategory == 'all' ||
          category == _selectedCategory.toLowerCase() ||
          category.contains(_selectedCategory.toLowerCase());
      final matchesLanguage = _selectedLanguage == 'all' ||
          language == _selectedLanguage.toLowerCase();

      return matchesSearch && matchesCategory && matchesLanguage;
    }).toList();
  }

  Widget _buildBookCard(BuildContext context, Map<String, dynamic> book) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToBookReader((book['id'] ?? book['title']).toString()),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Book icon with theme-aware styling
              Container(
                width: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 60, tablet: 70, desktop: 80),
                height: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 80, tablet: 90, desktop: 100),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        Theme.of(context).primaryColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.menu_book,
                  size: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 32, tablet: 36, desktop: 40),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (book['title'] ?? 'Untitled Book').toString(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'By ${(book['author'] ?? 'ALIVE Nigeria').toString()}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (book['category'] ?? 'General').toString(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: ResponsiveUtils.getResponsiveValue(
                                context: context,
                                mobile: 12,
                                tablet: 13,
                                desktop: 14),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArticleCard(BuildContext context, Map<String, dynamic> article) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(
          bottom: ResponsiveUtils.getResponsiveValue(
              context: context, mobile: 8, tablet: 10, desktop: 12)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToArticle((article['id'] ?? article['title']).toString()),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (article['title'] ?? 'Untitled Article').toString(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveUtils.getResponsiveValue(
                          context: context,
                          mobile: 16,
                          tablet: 18,
                          desktop: 20),
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'By ${(article['author'] ?? 'ALIVE Nigeria').toString()}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 0.7),
                      fontSize: ResponsiveUtils.getResponsiveValue(
                          context: context,
                          mobile: 14,
                          tablet: 15,
                          desktop: 16),
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      (article['category'] ?? 'General').toString(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                          ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCard(BuildContext context, Map<String, dynamic> video) {
    final thumbnailUrl =
        (video['thumbnail_url'] ?? video['thumbnailUrl'])?.toString();

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _playVideo((video['id'] ?? video['title']).toString()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 16:9 Thumbnail
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (thumbnailUrl != null && thumbnailUrl.trim().isNotEmpty)
                    CustomImage(
                      imageUrl: thumbnailUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    )
                  else
                    Container(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      child: Icon(
                        Icons.video_library,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  // Center play icon
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  // Duration badge
                  if (video['duration'] != null &&
                      video['duration'].toString().isNotEmpty)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          video['duration'].toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Video Info
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video['title'] ?? '',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'By ${video['author'] ?? 'ALIVE Media'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                  if (video['category'] != null &&
                      video['category'].toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        video['category'].toString(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 11,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    String tempCategory = _selectedCategory;
    String tempLanguage = _selectedLanguage;
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Text('Filter Library'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Category Filter
              ModernDropdownFormField<String>(
                initialValue: tempCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Categories')),
                  DropdownMenuItem(value: 'bible', child: Text('Bible Study')),
                  DropdownMenuItem(
                      value: 'devotional', child: Text('Devotional')),
                  DropdownMenuItem(value: 'health', child: Text('Health')),
                  DropdownMenuItem(value: 'youth', child: Text('Youth')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => tempCategory = value);
                  }
                },
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                      context: dialogCtx, mobile: 12, tablet: 14, desktop: 16)),

              // Language Filter
              ModernDropdownFormField<String>(
                initialValue: tempLanguage,
                decoration: const InputDecoration(
                  labelText: 'Language',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Languages')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'yo', child: Text('Yoruba')),
                  DropdownMenuItem(value: 'ig', child: Text('Igbo')),
                  DropdownMenuItem(value: 'ha', child: Text('Hausa')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => tempLanguage = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(
                'Cancel',
                style: Theme.of(dialogCtx).textTheme.labelLarge?.copyWith(
                      fontSize: ResponsiveUtils.getResponsiveValue(
                          context: dialogCtx, mobile: 14, tablet: 15, desktop: 16),
                    ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedCategory = tempCategory;
                  _selectedLanguage = tempLanguage;
                });
                Navigator.of(dialogCtx).pop();
              },
              child: Text(
                'Apply',
                style: Theme.of(dialogCtx).textTheme.labelLarge?.copyWith(
                      fontSize: ResponsiveUtils.getResponsiveValue(
                          context: dialogCtx, mobile: 14, tablet: 15, desktop: 16),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDocumentOrReader(Map<String, dynamic> doc, {required String kind}) {
    final title = (doc['title'] ?? 'Untitled $kind').toString();
    final pdfUrl = (doc['pdf_url'] ?? doc['file_url'] ?? doc['url'] ?? '').toString().trim();
    if (pdfUrl.isNotEmpty &&
        (pdfUrl.toLowerCase().contains('.pdf') || pdfUrl.contains('/storage/buckets/'))) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InAppPdfViewerScreen(title: title, pdfUrl: pdfUrl),
        ),
      );
      return;
    }

    final author = (doc['author'] ?? 'ALIVE Nigeria').toString();
    final category = (doc['category'] ?? 'General').toString();
    final body = (doc['content'] ?? doc['body'] ?? doc['description'] ?? doc['summary'] ?? '')
        .toString()
        .trim();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: ListView(
            controller: scrollCtrl,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(sheetCtx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                  ),
                ],
              ),
              Text(
                'By $author • $category',
                style: Theme.of(sheetCtx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(sheetCtx).colorScheme.onSurfaceVariant,
                    ),
              ),
              const Divider(height: 24),
              Text(
                body.isNotEmpty
                    ? body
                    : 'Full content for "$title" will appear here once published by the ALIVE Nigeria content team.',
                style: Theme.of(sheetCtx).textTheme.bodyLarge?.copyWith(height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Navigation methods
  void _navigateToBookReader(String bookId) async {
    try {
      final doc = await _libraryService.getBook(bookId) ??
          _allBooks.firstWhere(
            (b) => (b['id'] ?? b['title']).toString() == bookId,
            orElse: () => {'title': bookId},
          );
      if (mounted) {
        _openDocumentOrReader(doc, kind: 'Book');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening book: ${ErrorHandler.getUserFriendlyMessage(e)}')),
        );
      }
    }
  }

  void _navigateToArticle(String articleId) async {
    try {
      final doc = await _libraryService.getArticle(articleId) ??
          _allArticles.firstWhere(
            (a) => (a['id'] ?? a['title']).toString() == articleId,
            orElse: () => {'title': articleId},
          );
      if (mounted) {
        _openDocumentOrReader(doc, kind: 'Article');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening article: ${ErrorHandler.getUserFriendlyMessage(e)}')),
        );
      }
    }
  }

  // Video methods
  void _playVideo(String videoId) async {
    debugPrint('Playing video for video ID: $videoId');
    try {
      final doc = await _libraryService.getVideo(videoId);
      final videoData = doc ??
          _allVideos.firstWhere(
            (v) => (v['id'] ?? v['title']).toString() == videoId,
            orElse: () => {
              'title': 'Bible Study Methods',
              'author': 'ALIVE Media',
              'category': 'Bible Study',
              'duration': '18:30',
            },
          );
      if (mounted) {
        StandardVideoPlayerModal.show(context, videoData: videoData);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing video: ${ErrorHandler.getUserFriendlyMessage(e)}')),
        );
      }
    }
  }

}
