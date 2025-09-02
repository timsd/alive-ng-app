import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/bible_verses.dart';

class BibleReaderScreen extends StatefulWidget {
  final String? initialReference;

  const BibleReaderScreen({
    super.key,
    this.initialReference,
  });

  @override
  State<BibleReaderScreen> createState() => _BibleReaderScreenState();
}

class _BibleReaderScreenState extends State<BibleReaderScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedVersion = 'KJV';
  String? _currentReference;
  BibleVerse? _currentVerse;
  bool _isLoading = false;
  List<BibleVerse> _searchResults = [];
  final bool _showEGWContent = false;

  final List<String> _bibleVersions = ['KJV', 'NKJV', 'NIV'];
  final List<String> _bibleBooks = [
    // Old Testament
    'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
    'Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel',
    '1 Kings', '2 Kings', '1 Chronicles', '2 Chronicles',
    'Ezra', 'Nehemiah', 'Esther', 'Job', 'Psalms', 'Proverbs',
    'Ecclesiastes', 'Song of Songs', 'Isaiah', 'Jeremiah',
    'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel',
    'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk',
    'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
    // New Testament
    'Matthew', 'Mark', 'Luke', 'John', 'Acts', 'Romans',
    '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
    'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
    '1 Timothy', '2 Timothy', 'Titus', 'Philemon', 'Hebrews',
    'James', '1 Peter', '2 Peter', '1 John', '2 John', '3 John',
    'Jude', 'Revelation'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    if (widget.initialReference != null) {
      _currentReference = widget.initialReference;
      _searchController.text = widget.initialReference!;
      _loadVerse(widget.initialReference!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVerse(String reference) async {
    setState(() => _isLoading = true);

    try {
      // First check local data
      final verse = _findVerseInLocalData(reference);

      if (verse != null) {
        setState(() {
          _currentVerse = verse;
          _currentReference = reference;
        });
      } else {
        // TODO: Implement API call to Bible service
        await Future.delayed(const Duration(milliseconds: 500));

        // Mock verse for demonstration
        final mockVerse = BibleVerse(
          reference: reference,
          text: {
            'KJV': 'This verse would be loaded from a Bible API service.',
            'NKJV': 'This verse would be loaded from a Bible API service.',
            'NIV': 'This verse would be loaded from a Bible API service.',
          },
        );

        setState(() {
          _currentVerse = mockVerse;
          _currentReference = reference;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading verse: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  BibleVerse? _findVerseInLocalData(String reference) {
    final cleanRef = reference.trim();

    for (final verse in dailyVerses) {
      if (verse.reference.toLowerCase() == cleanRef.toLowerCase()) {
        return verse;
      }
    }

    return null;
  }

  void _searchVerses(String query) {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() {
      _searchResults = dailyVerses.where((verse) {
        final searchLower = query.toLowerCase();
        return verse.reference.toLowerCase().contains(searchLower) ||
            verse.text.values
                .any((text) => text.toLowerCase().contains(searchLower));
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bible Reader'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.menu_book), text: 'Reader'),
            Tab(icon: Icon(Icons.search), text: 'Search'),
            Tab(icon: Icon(Icons.library_books), text: 'E.G. White'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.translate),
            onSelected: (version) {
              setState(() => _selectedVersion = version);
            },
            itemBuilder: (context) => _bibleVersions.map((version) {
              return PopupMenuItem(
                value: version,
                child: Row(
                  children: [
                    if (_selectedVersion == version)
                      const Icon(Icons.check, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(version),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReaderTab(),
          _buildSearchTab(),
          _buildEGWhiteTab(),
        ],
      ),
    );
  }

  Widget _buildReaderTab() {
    return Column(
      children: [
        // Reference Input
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Enter Bible Reference (e.g., John 3:16)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.menu_book),
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      _loadVerse(value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  if (_searchController.text.isNotEmpty) {
                    _loadVerse(_searchController.text);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Go', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.green),
                )
              : _currentVerse == null
                  ? _buildWelcomeContent()
                  : _buildVerseContent(),
        ),
      ],
    );
  }

  Widget _buildWelcomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome to Bible Reader',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Enter a Bible reference above to start reading, or browse popular verses below:',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          const Text(
            'Popular Verses:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...dailyVerses.take(5).map((verse) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    verse.reference,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  subtitle: Text(
                    verse.text[_selectedVersion] ?? verse.text.values.first,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    _searchController.text = verse.reference;
                    _loadVerse(verse.reference);
                  },
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildVerseContent() {
    final verseText = _currentVerse!.text[_selectedVersion] ??
        _currentVerse!.text.values.first;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reference Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentReference!,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _selectedVersion,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Verse Text
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              verseText,
              style: const TextStyle(
                fontSize: 18,
                height: 1.6,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(
                      text:
                          '"$verseText" - ${_currentReference!} ($_selectedVersion)',
                    ));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Verse copied to clipboard'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, color: Colors.white),
                  label:
                      const Text('Copy', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement share functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Share functionality coming soon'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  },
                  icon: const Icon(Icons.share, color: Colors.white),
                  label: const Text('Share',
                      style: TextStyle(color: Colors.white)),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Other Versions
          if (_currentVerse!.text.length > 1) ...[
            const Text(
              'Other Versions:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ..._currentVerse!.text.entries
                .where((entry) => entry.key != _selectedVersion)
                .map((entry) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              entry.value,
                              style: const TextStyle(
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Search verses...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: _searchVerses,
          ),
        ),
        Expanded(
          child: _searchResults.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Search for Bible verses',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final verse = _searchResults[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(
                          verse.reference,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        subtitle: Text(
                          verse.text[_selectedVersion] ??
                              verse.text.values.first,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          _tabController.animateTo(0);
                          _searchController.text = verse.reference;
                          _loadVerse(verse.reference);
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEGWhiteTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ellen G. White Library',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Access to Ellen G. White writings and commentary on Bible passages.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),

          // Popular Books
          const Text(
            'Popular Books:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          ..._getEGWhiteBooks().map((book) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(
                    Icons.library_books,
                    color: Colors.green,
                  ),
                  title: Text(
                    book['title']!,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(book['description']!),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // TODO: Implement E.G. White book reader
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Opening ${book['title']}...'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                ),
              )),

          const SizedBox(height: 24),

          // Search E.G. White
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Search E.G. White Writings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search topic or Bible reference...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (query) {
                      // TODO: Implement E.G. White search
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Searching for "$query"...'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, String>> _getEGWhiteBooks() {
    return [
      {
        'title': 'Steps to Christ',
        'description':
            'A guide to finding peace with God and growing in Christian faith.',
      },
      {
        'title': 'The Desire of Ages',
        'description': 'The life and ministry of Jesus Christ.',
      },
      {
        'title': 'The Great Controversy',
        'description': 'The cosmic conflict between good and evil.',
      },
      {
        'title': 'Patriarchs and Prophets',
        'description': 'Stories from the Old Testament.',
      },
      {
        'title': 'The Acts of the Apostles',
        'description': 'The early Christian church and apostolic ministry.',
      },
      {
        'title': 'Prophets and Kings',
        'description': 'The history of Israel from Solomon to Malachi.',
      },
    ];
  }
}
