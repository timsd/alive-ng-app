import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/responsive_utils.dart';
import '../../services/firebase_database_service.dart';
import 'package:just_audio/just_audio.dart';

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
  final String _selectedCategory = 'all';
  final String _selectedLanguage = 'all';

  // Sample data with categories for proper indexing
  final List<Map<String, dynamic>> _allBooks = [
    {
      'title': 'The Great Controversy',
      'author': 'Ellen G. White',
      'category': 'bible',
      'language': 'en'
    },
    {
      'title': 'Steps to Christ',
      'author': 'Ellen G. White',
      'category': 'devotional',
      'language': 'en'
    },
    {
      'title': 'The Desire of Ages',
      'author': 'Ellen G. White',
      'category': 'bible',
      'language': 'en'
    },
    {
      'title': 'Patriarchs and Prophets',
      'author': 'Ellen G. White',
      'category': 'bible',
      'language': 'en'
    },
    {
      'title': 'The Acts of the Apostles',
      'author': 'Ellen G. White',
      'category': 'bible',
      'language': 'en'
    },
    {
      'title': 'Prophets and Kings',
      'author': 'Ellen G. White',
      'category': 'bible',
      'language': 'en'
    },
    {
      'title': 'Education',
      'author': 'Ellen G. White',
      'category': 'youth',
      'language': 'en'
    },
    {
      'title': 'Ministry of Healing',
      'author': 'Ellen G. White',
      'category': 'health',
      'language': 'en'
    },
  ];

  final List<Map<String, dynamic>> _allArticles = [
    {
      'title': 'Understanding Bible Prophecy',
      'author': 'John Doe',
      'category': 'bible',
      'language': 'en'
    },
    {
      'title': 'Health and Wellness Tips',
      'author': 'Jane Smith',
      'category': 'health',
      'language': 'en'
    },
    {
      'title': 'Youth Ministry Guidelines',
      'author': 'David Johnson',
      'category': 'youth',
      'language': 'en'
    },
  ];

  final List<Map<String, dynamic>> _allAudio = [
    {
      'title': 'Daily Devotional Podcast',
      'author': 'Speaker One',
      'category': 'devotional',
      'language': 'en'
    },
    {
      'title': 'Bible Study Series',
      'author': 'Speaker Two',
      'category': 'bible',
      'language': 'en'
    },
  ];

  final List<Map<String, dynamic>> _allVideos = [
    {
      'title': 'Bible Study Methods',
      'author': 'Teacher One',
      'category': 'bible',
      'language': 'en'
    },
    {
      'title': 'Health Cooking Series',
      'author': 'Chef Two',
      'category': 'health',
      'language': 'en'
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
            Tab(icon: Icon(Icons.headphones), text: 'Audio'),
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
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBooksTab(),
                _buildArticlesTab(),
                _buildAudioTab(),
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
          ? const Center(
              child: Text(
                'No books found matching your search criteria',
                style: TextStyle(fontSize: 16, color: Colors.grey),
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
          ? const Center(
              child: Text(
                'No articles found matching your search criteria',
                style: TextStyle(fontSize: 16, color: Colors.grey),
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

  Widget _buildAudioTab() {
    final filteredAudio = _getFilteredContent(_allAudio);

    return Padding(
      padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
          context: context, mobile: 16, tablet: 20, desktop: 24)),
      child: filteredAudio.isEmpty
          ? const Center(
              child: Text(
                'No audio content found matching your search criteria',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: filteredAudio.length,
              itemBuilder: (context, index) {
                return _buildAudioCard(context, filteredAudio[index]);
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
          ? const Center(
              child: Text(
                'No videos found matching your search criteria',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 1, tablet: 2, desktop: 3),
                crossAxisSpacing: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 16, tablet: 20, desktop: 24),
                mainAxisSpacing: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 16, tablet: 20, desktop: 24),
                childAspectRatio: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 16 / 9,
                    tablet: 16 / 9,
                    desktop: 16 / 9),
              ),
              itemCount: filteredVideos.length,
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
      final matchesSearch = _searchQuery.isEmpty ||
          item['title'].toString().toLowerCase().contains(_searchQuery) ||
          item['author'].toString().toLowerCase().contains(_searchQuery);

      final matchesCategory =
          _selectedCategory == 'all' || item['category'] == _selectedCategory;
      final matchesLanguage =
          _selectedLanguage == 'all' || item['language'] == _selectedLanguage;

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
        onTap: () => _navigateToBookReader(book['title']),
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
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
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
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book['title'],
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
                      'By ${book['author']}',
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
                    const SizedBox(height: 4),
                    Text(
                      book['category'],
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).primaryColor,
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
        onTap: () => _navigateToArticle(article['title']),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                article['title'],
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
                'By ${article['author']}',
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
                      color:
                          Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      article['category'],
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).primaryColor,
                            fontSize: 12,
                          ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioCard(BuildContext context, Map<String, dynamic> audio) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(
          bottom: ResponsiveUtils.getResponsiveValue(
              context: context, mobile: 8, tablet: 10, desktop: 12)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _playAudio(audio['title']),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color:
                        Theme.of(context).primaryColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.play_arrow,
                  size: 32,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      audio['title'],
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
                    const SizedBox(height: 4),
                    Text(
                      'By ${audio['author']}',
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
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _downloadAudio(audio['title']),
                icon: const Icon(Icons.download),
                color: Colors.grey[600],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCard(BuildContext context, Map<String, dynamic> video) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _playVideo(video['title']),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Thumbnail
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 12, tablet: 14, desktop: 16)),
                  ),
                  border: Border.all(
                    color:
                        Theme.of(context).primaryColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.video_library,
                      size: ResponsiveUtils.getResponsiveValue(
                          context: context,
                          mobile: 48,
                          tablet: 56,
                          desktop: 64),
                      color: Colors.grey[600],
                    ),
                    Container(
                      padding: EdgeInsets.all(
                          ResponsiveUtils.getResponsiveValue(
                              context: context,
                              mobile: 8,
                              tablet: 10,
                              desktop: 12)),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 24,
                            tablet: 28,
                            desktop: 32),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Video Info
            Padding(
              padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 8, tablet: 10, desktop: 12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video['title'],
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
                  SizedBox(
                      height: ResponsiveUtils.getResponsiveValue(
                          context: context, mobile: 4, tablet: 5, desktop: 6)),
                  Text(
                    'By ${video['author']}',
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
                  SizedBox(
                      height: ResponsiveUtils.getResponsiveValue(
                          context: context, mobile: 4, tablet: 5, desktop: 6)),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .primaryColor
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          video['category'],
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).primaryColor,
                                    fontSize: 12,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Library'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Category Filter
            DropdownButtonFormField<String>(
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
                _applyCategoryFilter(value!);
              },
            ),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 12, tablet: 14, desktop: 16)),

            // Language Filter
            DropdownButtonFormField<String>(
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
                _applyLanguageFilter(value!);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 14, tablet: 15, desktop: 16),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _applyFilters();
              Navigator.of(context).pop();
            },
            child: Text(
              'Apply',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 14, tablet: 15, desktop: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Navigation methods
  void _navigateToBookReader(String bookId) async {
    debugPrint('Navigating to book reader for book ID: $bookId');
    try {
      final doc =
          await FirebaseDatabaseService.instance.getDocument('books', bookId);
      if (doc != null && mounted) {
        // Navigate to actual reader screen (assuming BooksTractsScreen or similar)
        // For now, we'll just show the success message as the reader might need specific arguments
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening book: ${doc['title']}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening book: $e')),
        );
      }
    }
  }

  void _navigateToArticle(String articleId) async {
    debugPrint('Navigating to article for article ID: $articleId');
    try {
      final doc = await FirebaseDatabaseService.instance
          .getDocument('articles', articleId);
      if (doc != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening article: ${doc['title']}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening article: $e')),
        );
      }
    }
  }

  // Audio methods
  // Audio player instance
  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> _playAudio(String audioId) async {
    debugPrint('Playing audio for audio ID: $audioId');
    final messenger = ScaffoldMessenger.of(context);
    try {
      // In a real implementation, you would fetch the audio URL from Firebase
      // based on the audioId. Here we're assuming the audioId is stored in
      // the 'podcast_episodes' collection
      final firebaseService = FirebaseDatabaseService.instance;
      final episodeData =
          await firebaseService.getDocument('podcast_episodes', audioId);

      if (episodeData == null ||
          episodeData['audioUrl'] == null ||
          episodeData['audioUrl'].isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No audio available for this episode')),
        );
        return;
      }

      final audioUrl = episodeData['audioUrl'];

      // Show loading indicator
      messenger.showSnackBar(
        const SnackBar(content: Text('Loading audio...')),
      );

      // Play the audio
      await _audioPlayer.setUrl(audioUrl);
      await _audioPlayer.play();

      // Show now playing notification
      messenger.showSnackBar(
        SnackBar(
          content: Text('Playing audio: ${episodeData['title'] ?? audioId}'),
          action: SnackBarAction(
            label: 'Pause',
            onPressed: () {
              _audioPlayer.pause();
              messenger.showSnackBar(
                const SnackBar(content: Text('Audio paused')),
              );
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error playing audio: $e')),
      );
    }
  }

  Future<void> _downloadAudio(String audioId) async {
    debugPrint('Downloading audio for audio ID: $audioId');
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Show downloading notification
      messenger.showSnackBar(
        SnackBar(
          content: Text('Downloading audio: $audioId'),
          duration: const Duration(seconds: 2),
        ),
      );

      // In a real implementation, you would fetch the audio URL from Firebase
      // based on the audioId
      final firebaseService = FirebaseDatabaseService.instance;
      final episodeData =
          await firebaseService.getDocument('podcast_episodes', audioId);

      if (episodeData == null ||
          episodeData['audioUrl'] == null ||
          episodeData['audioUrl'].isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No audio available for this episode')),
        );
        return;
      }

      final audioUrl = episodeData['audioUrl'];

      // Download the file
      final audioData = await firebaseService.downloadFile(
        Uri.parse(audioUrl).pathSegments.last,
      );

      if (audioData == null) {
        throw Exception('Failed to download audio file');
      }

      // In a real app, you would save the file to local storage here
      // and update a local database to track downloaded episodes

      messenger.showSnackBar(
        SnackBar(
          content: Text('Downloaded: ${episodeData['title'] ?? audioId}'),
          action: SnackBarAction(
            label: 'Play',
            onPressed: () {
              _playAudio(audioId);
            },
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error downloading audio: $e')),
      );
    }
  }

  // Video methods
  void _playVideo(String videoId) async {
    debugPrint('Playing video for video ID: $videoId');
    try {
      final doc =
          await FirebaseDatabaseService.instance.getDocument('videos', videoId);
      if (doc != null && mounted) {
        // In a real app, launch video player
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playing video: ${doc['title']}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing video: $e')),
        );
      }
    }
  }

  // Filter Methods
  void _applyCategoryFilter(String category) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Applied category filter: $category')),
    );
  }

  void _applyLanguageFilter(String language) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Applied language filter: $language')),
    );
  }

  void _applyFilters() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Filters applied successfully')),
    );
  }
}
