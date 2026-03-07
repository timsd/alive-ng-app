import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/layout_fix_utils.dart';

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

  void _openStoryReader(BuildContext context, String title, String description) {
    // Navigate to a story reader screen with the story content
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 14.0,
                tablet: 16.0,
                desktop: 18.0,
              )),
              Text(
                'This is where the full story content would be displayed. The story reader would include features like:\n\n• Audio narration\n• Interactive illustrations\n• Reading progress tracking\n• Bookmark functionality\n• Sharing options',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Added "$title" to favorites'),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () {},
                  ),
                ),
              );
            },
            child: const Text('Add to Favorites'),
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
            Tab(icon: Icon(Icons.auto_stories), text: 'Bible Stories'),
            Tab(icon: Icon(Icons.favorite), text: 'Favorites'),
            Tab(icon: Icon(Icons.history), text: 'Recently Read'),
            Tab(icon: Icon(Icons.download), text: 'Downloaded'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 12.0,
              tablet: 16.0,
              desktop: 20.0,
            )),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search stories...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 10.0,
                        tablet: 12.0,
                        desktop: 14.0,
                      )),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      // Search functionality can be implemented here if needed
                    });
                  },
                ),
                SizedBox(height: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 10.0,
                  tablet: 12.0,
                  desktop: 14.0,
                )),
                LayoutFixUtils.safeRow(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedAgeGroup,
                        decoration: InputDecoration(
                          labelText: 'Age Group',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(context: context, mobile: 6, tablet: 8, desktop: 10)),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: ResponsiveUtils.getResponsiveValue(context: context, mobile: 10, tablet: 12, desktop: 14),
                            vertical: ResponsiveUtils.getResponsiveValue(context: context, mobile: 6, tablet: 8, desktop: 10),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All Ages')),
                          DropdownMenuItem(value: '3-5', child: Text('3-5 years')),
                          DropdownMenuItem(value: '6-8', child: Text('6-8 years')),
                          DropdownMenuItem(value: '9-12', child: Text('9-12 years')),
                          DropdownMenuItem(value: '13+', child: Text('13+ years')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedAgeGroup = value!;
                          });
                        },
                      ),
                    ),
                    SizedBox(width: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 10.0,
                      tablet: 12.0,
                      desktop: 14.0,
                    )),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(context: context, mobile: 6, tablet: 8, desktop: 10)),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: ResponsiveUtils.getResponsiveValue(context: context, mobile: 10, tablet: 12, desktop: 14),
                            vertical: ResponsiveUtils.getResponsiveValue(context: context, mobile: 6, tablet: 8, desktop: 10),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All Stories')),
                          DropdownMenuItem(value: 'Old Testament', child: Text('Old Testament')),
                          DropdownMenuItem(value: 'New Testament', child: Text('New Testament')),
                          DropdownMenuItem(value: 'Jesus Stories', child: Text('Jesus Stories')),
                          DropdownMenuItem(value: 'Miracles', child: Text('Miracles')),
                          DropdownMenuItem(value: 'Parables', child: Text('Parables')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value!;
                          });
                        },
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
                _buildBibleStoriesTab(),
                _buildFavoritesTab(),
                _buildRecentlyReadTab(),
                _buildDownloadedTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBibleStoriesTab() {
    return GridView.builder(
      padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20),
        mainAxisSpacing: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20),
      ),
      itemCount: 24, // Using sample data - replace with Supabase query
      itemBuilder: (context, index) {
        final storyTitles = [
          'Noah and the Ark',
          'David and Goliath',
          'Daniel in the Lion\'s Den',
          'Moses and the Red Sea',
          'Jesus Feeds 5000',
          'The Good Samaritan',
          'Jesus Walks on Water',
          'The Lost Sheep',
          'Jonah and the Big Fish',
          'The Birth of Jesus',
          'Jesus Heals the Blind Man',
          'The Prodigal Son',
          'Abraham and Isaac',
          'Joseph and His Brothers',
          'The Ten Commandments',
          'Jesus Calms the Storm',
          'The Wise Men Visit Jesus',
          'Elijah and the Fire',
          'The Boy Samuel',
          'Jesus and the Children',
          'The Creation Story',
          'Adam and Eve',
          'Cain and Abel',
          'The Tower of Babel',
        ];
        final title = storyTitles[index % storyTitles.length];
        return _buildStoryCard(context, index, _favoriteStories.contains(title), false);
      },
    );
  }

  Widget _buildFavoritesTab() {
    final storyTitles = [
      'Noah and the Ark',
      'David and Goliath',
      'Daniel in the Lion\'s Den',
      'Moses and the Red Sea',
      'Jesus Feeds 5000',
      'The Good Samaritan',
      'Jesus Walks on Water',
      'The Lost Sheep',
      'Jonah and the Big Fish',
      'The Birth of Jesus',
      'Jesus Heals the Blind Man',
      'The Prodigal Son',
      'Abraham and Isaac',
      'Joseph and His Brothers',
      'The Ten Commandments',
      'Jesus Calms the Storm',
      'The Wise Men Visit Jesus',
      'Elijah and the Fire',
      'The Boy Samuel',
      'Jesus and the Children',
      'The Creation Story',
      'Adam and Eve',
      'Cain and Abel',
      'The Tower of Babel',
    ];
    
    final favoriteIndices = <int>[];
    for (int i = 0; i < storyTitles.length; i++) {
      if (_favoriteStories.contains(storyTitles[i])) {
        favoriteIndices.add(i);
      }
    }
    
    if (favoriteIndices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: ResponsiveUtils.getResponsiveValue(context: context, mobile: 56, tablet: 64, desktop: 72),
              color: Colors.grey[400],
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 14, tablet: 16, desktop: 18)),
            Text(
              'No favorite stories yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 6, tablet: 8, desktop: 10)),
            Text(
              'Tap the heart icon on any story to add it to your favorites',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return GridView.builder(
      padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20),
        mainAxisSpacing: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20),
      ),
      itemCount: favoriteIndices.length,
      itemBuilder: (context, index) {
        final storyIndex = favoriteIndices[index];
        return _buildStoryCard(context, storyIndex, true, false);
      },
    );
  }

  Widget _buildRecentlyReadTab() {
    return ListView.builder(
      padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
      itemCount: 10, // Using sample data - replace with Supabase query
      itemBuilder: (context, index) {
        return _buildRecentStoryItem(context, index);
      },
    );
  }

  Widget _buildDownloadedTab() {
    return GridView.builder(
      padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20),
        mainAxisSpacing: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20),
      ),
      itemCount: 6, // Using sample data - replace with Supabase query
      itemBuilder: (context, index) {
        final storyTitles = [
          'Noah and the Ark',
          'David and Goliath',
          'Daniel in the Lion\'s Den',
          'Moses and the Red Sea',
          'Jesus Feeds 5000',
          'The Good Samaritan',
          'Jesus Walks on Water',
          'The Lost Sheep',
          'Jonah and the Big Fish',
          'The Birth of Jesus',
          'Jesus Heals the Blind Man',
          'The Prodigal Son',
          'Abraham and Isaac',
          'Joseph and His Brothers',
          'The Ten Commandments',
          'Jesus Calms the Storm',
          'The Wise Men Visit Jesus',
          'Elijah and the Fire',
          'The Boy Samuel',
          'Jesus and the Children',
          'The Creation Story',
          'Adam and Eve',
          'Cain and Abel',
          'The Tower of Babel',
        ];
        final title = storyTitles[index % storyTitles.length];
        return _buildStoryCard(context, index, _favoriteStories.contains(title), true);
      },
    );
  }

  Widget _buildStoryCard(BuildContext context, int index, bool isFavorite, bool isDownloaded) {
    final storyTitles = [
      'Noah and the Ark',
      'David and Goliath',
      'Daniel in the Lion\'s Den',
      'Moses and the Red Sea',
      'Jesus Feeds 5000',
      'The Good Samaritan',
      'Jesus Walks on Water',
      'The Lost Sheep',
      'Jonah and the Big Fish',
      'The Birth of Jesus',
      'Jesus Heals the Blind Man',
      'The Prodigal Son',
      'Abraham and Isaac',
      'Joseph and His Brothers',
      'The Ten Commandments',
      'Jesus Calms the Storm',
      'The Wise Men Visit Jesus',
      'Elijah and the Fire',
      'The Boy Samuel',
      'Jesus and the Children',
      'The Creation Story',
      'Adam and Eve',
      'Cain and Abel',
      'The Tower of Babel',
    ];

    final categories = [
      'Old Testament',
      'Old Testament',
      'Old Testament',
      'Old Testament',
      'Jesus Stories',
      'Parables',
      'Miracles',
      'Parables',
      'Old Testament',
      'New Testament',
      'Miracles',
      'Parables',
      'Old Testament',
      'Old Testament',
      'Old Testament',
      'Miracles',
      'New Testament',
      'Old Testament',
      'Old Testament',
      'Jesus Stories',
      'Old Testament',
      'Old Testament',
      'Old Testament',
      'Old Testament',
    ];

    final ageGroups = [
      '3-5',
      '6-8',
      '6-8',
      '6-8',
      '9-12',
      '9-12',
      '6-8',
      '3-5',
      '3-5',
      '3-5',
      '6-8',
      '9-12',
      '9-12',
      '9-12',
      '9-12',
      '6-8',
      '3-5',
      '9-12',
      '6-8',
      '3-5',
      '3-5',
      '6-8',
      '6-8',
      '6-8',
    ];

    final readingTimes = [
      '5 min',
      '7 min',
      '6 min',
      '8 min',
      '10 min',
      '12 min',
      '6 min',
      '4 min',
      '5 min',
      '6 min',
      '7 min',
      '15 min',
      '12 min',
      '20 min',
      '18 min',
      '8 min',
      '7 min',
      '10 min',
      '9 min',
      '5 min',
      '10 min',
      '8 min',
      '6 min',
      '7 min',
    ];

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
    ];

    final color = colors[index % colors.length];
    final title = storyTitles[index % storyTitles.length];
    final category = categories[index % categories.length];
    final ageGroup = ageGroups[index % ageGroups.length];
    final readingTime = readingTimes[index % readingTimes.length];

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(context: context, mobile: 14, tablet: 16, desktop: 18)),
      ),
      child: InkWell(
        onTap: () {
          _openStory(context, title);
        },
        borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(context: context, mobile: 14, tablet: 16, desktop: 18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Story Image/Icon
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.8),
                      color.withValues(alpha: 0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(ResponsiveUtils.getResponsiveValue(context: context, mobile: 14, tablet: 16, desktop: 18)),
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.auto_stories,
                        size: ResponsiveUtils.getResponsiveValue(context: context, mobile: 42, tablet: 48, desktop: 54),
                        color: Colors.white,
                      ),
                    ),
                    if (isDownloaded)
                      Positioned(
                        top: ResponsiveUtils.getResponsiveValue(context: context, mobile: 6, tablet: 8, desktop: 10),
                        left: ResponsiveUtils.getResponsiveValue(context: context, mobile: 6, tablet: 8, desktop: 10),
                        child: Container(
                          padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(context: context, mobile: 3, tablet: 4, desktop: 5)),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(context: context, mobile: 10, tablet: 12, desktop: 14)),
                          ),
                          child: Icon(
                            Icons.download_done,
                            size: ResponsiveUtils.getResponsiveValue(context: context, mobile: 14, tablet: 16, desktop: 18),
                            color: Colors.white,
                          ),
                        ),
                      ),
                    Positioned(
                      top: ResponsiveUtils.getResponsiveValue(context: context, mobile: 6, tablet: 8, desktop: 10),
                      right: ResponsiveUtils.getResponsiveValue(context: context, mobile: 6, tablet: 8, desktop: 10),
                      child: IconButton(
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? Colors.red : Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            if (_favoriteStories.contains(title)) {
                              _favoriteStories.remove(title);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Removed "$title" from favorites'),
                                  action: SnackBarAction(
                                    label: 'Undo',
                                    onPressed: () {
                                      setState(() {
                                        _favoriteStories.add(title);
                                      });
                                    },
                                  ),
                                ),
                              );
                            } else {
                              _favoriteStories.add(title);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added "$title" to favorites'),
                                  action: SnackBarAction(
                                    label: 'Undo',
                                    onPressed: () {
                                      setState(() {
                                        _favoriteStories.remove(title);
                                      });
                                    },
                                  ),
                                ),
                              );
                            }
                          });
                        },
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
                padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(context: context, mobile: 10, tablet: 12, desktop: 14)),
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
                    SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 3, tablet: 4, desktop: 5)),
                    Text(
                      category,
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
                            horizontal: ResponsiveUtils.getResponsiveValue(context: context, mobile: 5, tablet: 6, desktop: 7),
                            vertical: ResponsiveUtils.getResponsiveValue(context: context, mobile: 1, tablet: 2, desktop: 3),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(context: context, mobile: 6, tablet: 8, desktop: 10)),
                          ),
                          child: Text(
                            ageGroup,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 9, tablet: 10, desktop: 11),
                            ),
                          ),
                        ),
                        LayoutFixUtils.safeRow(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: ResponsiveUtils.getResponsiveValue(context: context, mobile: 10, tablet: 12, desktop: 14),
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: ResponsiveUtils.getResponsiveValue(context: context, mobile: 1, tablet: 2, desktop: 3)),
                            LayoutFixUtils.safeText(
                              readingTime,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 9, tablet: 10, desktop: 11),
                                color: Colors.grey[600],
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

  Widget _buildRecentStoryItem(BuildContext context, int index) {
    final storyTitles = [
      'Noah and the Ark',
      'David and Goliath',
      'Daniel in the Lion\'s Den',
      'Moses and the Red Sea',
      'Jesus Feeds 5000',
      'The Good Samaritan',
      'Jesus Walks on Water',
      'The Lost Sheep',
      'Jonah and the Big Fish',
      'The Birth of Jesus',
    ];

    final readDates = [
      'Today',
      'Yesterday',
      '2 days ago',
      '3 days ago',
      '4 days ago',
      '5 days ago',
      '1 week ago',
      '1 week ago',
      '2 weeks ago',
      '2 weeks ago',
    ];

    final progress = [1.0, 0.8, 0.6, 1.0, 0.3, 1.0, 0.9, 1.0, 0.5, 1.0][index];

    return Card(
      margin: EdgeInsets.only(bottom: ResponsiveUtils.getResponsiveValue(context: context, mobile: 10, tablet: 12, desktop: 14)),
      child: ListTile(
        leading: Container(
          width: ResponsiveUtils.getResponsiveValue(context: context, mobile: 50, tablet: 56, desktop: 62),
          height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 50, tablet: 56, desktop: 62),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor.withValues(alpha: 0.8),
                Theme.of(context).primaryColor.withValues(alpha: 0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(context: context, mobile: 6, tablet: 8, desktop: 10)),
          ),
          child: const Icon(
            Icons.auto_stories,
            color: Colors.white,
          ),
        ),
        title: Text(
          storyTitles[index % storyTitles.length],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last read: ${readDates[index]}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 3, tablet: 4, desktop: 5)),
            if (progress < 1.0)
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 1, tablet: 2, desktop: 3)),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: ResponsiveUtils.getResponsiveValue(context: context, mobile: 14, tablet: 16, desktop: 18),
                    color: Colors.green,
                  ),
                  SizedBox(width: ResponsiveUtils.getResponsiveValue(context: context, mobile: 3, tablet: 4, desktop: 5)),
                  Text(
                    'Completed',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.green,
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
            _openStory(context, storyTitles[index % storyTitles.length]);
          },
        ),
        onTap: () {
          _openStory(context, storyTitles[index % storyTitles.length]);
        },
      ),
    );
  }

  void _openStory(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open Story'),
        content: Text(
          'Opening "$title" story. This will provide an interactive reading experience with audio narration, animations, and activities.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openStoryReader(context, title, 'An engaging Bible story for children with interactive elements and moral lessons.');
            },
            child: const Text('Read Story'),
          ),
        ],
      ),
    );
  }
}



