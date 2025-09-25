import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/custom_app_bar.dart';

class BooksTractsScreen extends ConsumerStatefulWidget {
  const BooksTractsScreen({super.key});

  @override
  ConsumerState<BooksTractsScreen> createState() => _BooksTractsScreenState();
}

class _BooksTractsScreenState extends ConsumerState<BooksTractsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _viewMode = 'grid'; // 'grid' or 'list'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        title: 'Books & Tracts',
        showBackButton: true,
        actions: [
          IconButton(
            icon: Icon(_viewMode == 'grid' ? Icons.view_list : Icons.grid_view),
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == 'grid' ? 'list' : 'grid';
              });
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.book), text: 'Books'),
            Tab(icon: Icon(Icons.article), text: 'Tracts'),
            Tab(icon: Icon(Icons.download), text: 'Downloaded'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search books and tracts...',
                    prefixIcon: const Icon(Icons.search),
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
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Categories')),
                    DropdownMenuItem(value: 'Doctrine', child: Text('Doctrine')),
                    DropdownMenuItem(value: 'Prophecy', child: Text('Prophecy')),
                    DropdownMenuItem(value: 'Health', child: Text('Health')),
                    DropdownMenuItem(value: 'Youth', child: Text('Youth')),
                    DropdownMenuItem(value: 'Family', child: Text('Family')),
                    DropdownMenuItem(value: 'Evangelism', child: Text('Evangelism')),
                    DropdownMenuItem(value: 'Sabbath', child: Text('Sabbath')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                    });
                    _applyCategoryFilter(value!);
                  },
                ),
              ],
            ),
          ),
          
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBooksTab(),
                _buildTractsTab(),
                _buildDownloadedTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBooksTab() {
    if (_viewMode == 'grid') {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 20, // Using sample data - replace with Supabase query
        itemBuilder: (context, index) {
          return _buildBookGridItem(context, index, true);
        },
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 20, // Using sample data - replace with Supabase query
        itemBuilder: (context, index) {
          return _buildBookListItem(context, index, true);
        },
      );
    }
  }

  Widget _buildTractsTab() {
    if (_viewMode == 'grid') {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.8,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 15, // Using sample data - replace with Supabase query
        itemBuilder: (context, index) {
          return _buildBookGridItem(context, index, false);
        },
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 15, // Using sample data - replace with Supabase query
        itemBuilder: (context, index) {
          return _buildBookListItem(context, index, false);
        },
      );
    }
  }

  Widget _buildDownloadedTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8, // Using sample data - replace with Supabase query
      itemBuilder: (context, index) {
        return _buildDownloadedItem(context, index);
      },
    );
  }

  Widget _buildBookGridItem(BuildContext context, int index, bool isBook) {
    final bookTitles = [
      'Steps to Christ',
      'The Great Controversy',
      'Desire of Ages',
      'Patriarchs and Prophets',
      'Acts of the Apostles',
      'Prophets and Kings',
      'The Ministry of Healing',
      'Education',
      'Christ\'s Object Lessons',
      'Thoughts from the Mount of Blessing',
      'Early Writings',
      'Gospel Workers',
      'Counsels to Parents, Teachers, and Students',
      'The Adventist Home',
      'Testimonies for the Church Vol. 1',
      'Christian Service',
      'Evangelism',
      'Medical Ministry',
      'Colporteur Ministry',
      'Country Living',
    ];

    final tractTitles = [
      'The Sabbath Truth',
      'What Happens When You Die?',
      'The Second Coming of Christ',
      'Health and Temperance',
      'Bible Prophecy Made Simple',
      'The State of the Dead',
      'The Millennium',
      'The Sanctuary',
      'The Law of God',
      'Baptism by Immersion',
      'The Gift of Prophecy',
      'Tithing and Offerings',
      'Christian Standards',
      'The Three Angels\' Messages',
      'Daniel\'s Prophecies',
    ];

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
      'Various Authors',
      'Various Authors',
      'Church Ministry',
      'Bible Study Guide',
      'Prophecy Study',
    ];

    final titles = isBook ? bookTitles : tractTitles;
    final title = titles[index % titles.length];
    final author = authors[index % authors.length];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          _openReader(context, title, isBook);
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isBook ? Icons.menu_book : Icons.article,
                      size: 40,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(height: 8),
                    if (!isBook)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'TRACT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
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
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      author,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.amber,
                        ),
                        Text(
                          '4.${7 + index % 3}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        IconButton(
                          icon: const Icon(Icons.download, size: 20),
                          onPressed: () {
                            _downloadItem('Sample Book ${index + 1}', 'Book');
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
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

  Widget _buildBookListItem(BuildContext context, int index, bool isBook) {
    final bookTitles = [
      'Steps to Christ',
      'The Great Controversy',
      'Desire of Ages',
      'Patriarchs and Prophets',
      'Acts of the Apostles',
    ];

    final descriptions = [
      'A guide to finding Jesus and growing in faith',
      'The cosmic conflict between good and evil',
      'The life and ministry of Jesus Christ',
      'Stories from Creation to King David',
      'The early Christian church and its mission',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 56,
          height: 80,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isBook ? Icons.menu_book : Icons.article,
                color: Theme.of(context).primaryColor,
              ),
              if (!isBook)
                const Text(
                  'TRACT',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        title: Text(
          bookTitles[index % bookTitles.length],
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              descriptions[index % descriptions.length],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.star,
                  size: 16,
                  color: Colors.amber,
                ),
                const SizedBox(width: 4),
                Text(
                  '4.${7 + index % 3}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 16),
                Text(
                  '${isBook ? 200 + index * 50 : 8 + index * 2} pages',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () {
                _downloadItem(bookTitles[index % bookTitles.length], isBook ? 'Book' : 'Tract');
              },
            ),
          ],
        ),
        onTap: () {
          _openReader(context, bookTitles[index % bookTitles.length], isBook);
        },
      ),
    );
  }

  Widget _buildDownloadedItem(BuildContext context, int index) {
    final titles = [
      'Steps to Christ',
      'The Sabbath Truth',
      'The Great Controversy',
      'What Happens When You Die?',
      'Desire of Ages',
      'The Second Coming of Christ',
      'Patriarchs and Prophets',
      'Health and Temperance',
    ];

    final isBook = index % 2 == 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isBook ? Icons.menu_book : Icons.article,
                color: Colors.green,
              ),
              Icon(
                Icons.download_done,
                size: 16,
                color: Colors.green,
              ),
            ],
          ),
        ),
        title: Text(
          titles[index % titles.length],
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isBook ? 'Book • Downloaded' : 'Tract • Downloaded',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Downloaded on ${DateTime.now().subtract(Duration(days: index + 1)).day}/${DateTime.now().month}/${DateTime.now().year}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                _shareDownloadedItem(titles[index % titles.length]);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                _deleteDownloadedItem(titles[index % titles.length]);
              },
            ),
          ],
        ),
        onTap: () {
          _openReader(context, titles[index % titles.length], isBook);
        },
      ),
    );
  }

  void _openReader(BuildContext context, String title, bool isBook) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Open ${isBook ? 'Book' : 'Tract'}'),
        content: Text(
          'Opening "$title" in the reader. This will provide a full reading experience with bookmarks, notes, and highlighting.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToReader(context, title);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Opening "$title" in reader...'),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }

  void _applyCategoryFilter(String category) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Filtering by category: $category'),
        duration: const Duration(seconds: 2),
      ),
    );
    // In a real app, this would filter the displayed items
  }

  void _downloadItem(String title, String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Download $type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Do you want to download "$title"?'),
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Preparing download...'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('"$title" downloaded successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  void _shareDownloadedItem(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sharing "$title"...'),
        action: SnackBarAction(
          label: 'Share',
          onPressed: () {
            // Implement actual sharing logic
          },
        ),
      ),
    );
  }

  void _deleteDownloadedItem(String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('"$title" deleted successfully!'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Navigation Methods
  void _navigateToReader(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open Reader'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Opening "$title" in the digital reader...'),
            const SizedBox(height: 16),
            const Text('Features available:'),
            const SizedBox(height: 8),
            const Text('• Adjustable font size'),
            const Text('• Night mode'),
            const Text('• Bookmarks'),
            const Text('• Search functionality'),
            const Text('• Offline reading'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Reader opened for: $title'),
                  action: SnackBarAction(
                    label: 'Settings',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Opening reader settings...')),
                      );
                    },
                  ),
                ),
              );
            },
            child: const Text('Open Reader'),
          ),
        ],
      ),
    );
  }
}