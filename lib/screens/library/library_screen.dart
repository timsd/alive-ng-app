import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/custom_app_bar.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
            padding: const EdgeInsets.all(16),
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
                  borderRadius: BorderRadius.circular(12),
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
    final books = [
      'Steps to Christ',
      'The Great Controversy',
      'Desire of Ages',
      'Patriarchs and Prophets',
      'The Acts of the Apostles',
      'Prophets and Kings',
      'Education',
      'Ministry of Healing',
      'Christ\'s Object Lessons',
      'Thoughts from the Mount of Blessing',
      'The Sanctified Life',
      'Early Writings',
    ];

    final filteredBooks = _searchQuery.isEmpty
        ? books
        : books.where((book) => book.toLowerCase().contains(_searchQuery)).toList();

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.7,
      ),
      itemCount: filteredBooks.length,
      itemBuilder: (context, index) {
        return _buildBookCard(context, index, filteredBooks);
      },
    );
  }

  Widget _buildArticlesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 10, // Using sample data - replace with Supabase query
      itemBuilder: (context, index) {
        return _buildArticleCard(context, index);
      },
    );
  }

  Widget _buildAudioTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8, // Using sample data - replace with Supabase query
      itemBuilder: (context, index) {
        return _buildAudioCard(context, index);
      },
    );
  }

  Widget _buildVideosTab() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 16 / 9,
      ),
      itemCount: 6, // Using sample data - replace with Supabase query
      itemBuilder: (context, index) {
        return _buildVideoCard(context, index);
      },
    );
  }

  Widget _buildBookCard(BuildContext context, int index, List<String> books) {
    final authors = [
      'Ellen G. White',
      'Ellen G. White',
      'Ellen G. White',
      'Ellen G. White',
      'Ellen G. White',
      'Ellen G. White',
      'Ellen G. White',
      'Ellen G. White',
      'Ellen G. White',
      'Ellen G. White',
      'Ellen G. White',
      'Ellen G. White',
    ];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          _navigateToBookReader(context, books[index]);
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book Cover
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Icon(
                  Icons.menu_book,
                  size: 64,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            
            // Book Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      books[index],
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      authors[index % authors.length],
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '4.${8 + index % 2}',
                          style: Theme.of(context).textTheme.bodySmall,
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

  Widget _buildArticleCard(BuildContext context, int index) {
    final articles = [
      'Understanding Bible Prophecy',
      'The Sabbath: A Day of Rest',
      'Christian Living in Modern Times',
      'Prayer and Meditation',
      'Health and Wellness',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          child: Icon(
            Icons.article,
            color: Theme.of(context).primaryColor,
          ),
        ),
        title: Text(
          articles[index % articles.length],
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Published ${index + 1} days ago',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${5 + index} min read',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          _navigateToArticle(context, articles[index % articles.length]);
        },
      ),
    );
  }

  Widget _buildAudioCard(BuildContext context, int index) {
    final audioTitles = [
      'Daily Devotional Reading',
      'Bible Study Commentary',
      'Inspirational Messages',
      'Worship Songs',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          child: Icon(
            Icons.headphones,
            color: Theme.of(context).primaryColor,
          ),
        ),
        title: Text(
          audioTitles[index % audioTitles.length],
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${15 + index * 5} minutes',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () {
                _playAudio(context, audioTitles[index % audioTitles.length]);
              },
            ),
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () {
                _downloadAudio(context, audioTitles[index % audioTitles.length]);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard(BuildContext context, int index) {
    final videoTitles = [
      'Bible Study Series - Episode ${index + 1}',
      'Worship Service Highlights',
      'Youth Ministry Activities',
      'Health and Wellness Tips',
    ];

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video Thumbnail
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.video_library,
                    size: 64,
                    color: Colors.grey[600],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Video Info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  videoTitles[index % videoTitles.length],
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${20 + index * 10} minutes • ${100 + index * 50} views',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
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
                DropdownMenuItem(value: 'devotional', child: Text('Devotional')),
                DropdownMenuItem(value: 'health', child: Text('Health')),
                DropdownMenuItem(value: 'youth', child: Text('Youth')),
              ],
              onChanged: (value) {
                _applyCategoryFilter(value!);
              },
            ),
            const SizedBox(height: 16),
            
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _applyFilters();
              Navigator.of(context).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  // Navigation Methods
  void _navigateToBookReader(BuildContext context, String bookTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Open Book'),
        content: Text('Opening "$bookTitle" in reader...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Opening $bookTitle...')),
              );
            },
            child: const Text('Read'),
          ),
        ],
      ),
    );
  }

  void _navigateToArticle(BuildContext context, String articleTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Open Article'),
        content: Text('Opening "$articleTitle"...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Opening $articleTitle...')),
              );
            },
            child: const Text('Read'),
          ),
        ],
      ),
    );
  }

  // Audio Methods
  void _playAudio(BuildContext context, String audioTitle) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Playing: $audioTitle'),
        action: SnackBarAction(
          label: 'Stop',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Audio stopped')),
            );
          },
        ),
      ),
    );
  }

  void _downloadAudio(BuildContext context, String audioTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Audio'),
        content: Text('Download "$audioTitle" for offline listening?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Downloading $audioTitle...')),
              );
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
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



