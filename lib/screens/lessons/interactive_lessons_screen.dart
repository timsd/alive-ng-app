import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/language_provider.dart';
import '../../services/study_guide_service.dart';
import '../../widgets/custom_app_bar.dart';

class InteractiveLessonsScreen extends ConsumerStatefulWidget {
  const InteractiveLessonsScreen({super.key});

  @override
  ConsumerState<InteractiveLessonsScreen> createState() => _InteractiveLessonsScreenState();
}

class _InteractiveLessonsScreenState extends ConsumerState<InteractiveLessonsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _selectedLevel = 'All';
  String _searchQuery = '';
  
  // Define lesson lists
  List<Map<String, dynamic>> _allLessons = [];
  List<Map<String, dynamic>> _progressLessons = [];
  List<Map<String, dynamic>> _favoriteLessons = [];
  List<Map<String, dynamic>> _completedLessons = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // Initialize sample lesson data
    _allLessons = [
      {
        'title': 'The Great Controversy',
        'description': 'Understanding the cosmic conflict between good and evil',
        'category': 'Bible Study',
        'level': 'Intermediate',
        'duration': '45 min',
        'isFavorite': false,
        'progress': 0.0,
        'isCompleted': false,
      },
      {
        'title': 'Daniel and Revelation',
        'description': 'Exploring apocalyptic prophecies and their meanings',
        'category': 'Prophecy',
        'level': 'Advanced',
        'duration': '60 min',
        'isFavorite': true,
        'progress': 0.7,
        'isCompleted': false,
      },
      {
        'title': 'Steps to Christ',
        'description': 'A guide to finding Jesus and growing in faith',
        'category': 'Bible Study',
        'level': 'Beginner',
        'duration': '30 min',
        'isFavorite': false,
        'progress': 1.0,
        'isCompleted': true,
      },
      {
        'title': 'Healthy Living Principles',
        'description': 'Biblical principles for physical and mental health',
        'category': 'Health',
        'level': 'Beginner',
        'duration': '40 min',
        'isFavorite': true,
        'progress': 0.3,
        'isCompleted': false,
      },
      {
        'title': 'Prayer and Meditation',
        'description': 'Deepening your relationship with God through prayer',
        'category': 'Bible Study',
        'level': 'Beginner',
        'duration': '35 min',
        'isFavorite': true,
        'progress': 1.0,
        'isCompleted': true,
      },
    ];
    
    _updateFilteredLessons();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _updateFilteredLessons() {
    _progressLessons = _allLessons.where((lesson) => lesson['progress'] > 0 && lesson['progress'] < 1.0).toList();
    _favoriteLessons = _allLessons.where((lesson) => lesson['isFavorite'] == true).toList();
    _completedLessons = _allLessons.where((lesson) => lesson['isCompleted'] == true).toList();
  }

  List<Map<String, dynamic>> get _filteredLessons {
    return _allLessons.where((lesson) {
      final matchesCategory = _selectedCategory == 'All' || lesson['category'] == _selectedCategory;
      final matchesLevel = _selectedLevel == 'All' || lesson['level'] == _selectedLevel;
      final matchesSearch = _searchQuery.isEmpty || 
          lesson['title'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
          lesson['description'].toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesLevel && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final translate = ref.watch(translationProvider);
    
    return Scaffold(
      appBar: CustomAppBar(
        title: translate('interactive_lessons'),
        showBackButton: true,
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: translate('search_lessons'),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                  onChanged: _applySearchFilter,
                ),
                const SizedBox(height: 12),
                // Filter Row
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterDropdown(
                        'Category',
                        _selectedCategory,
                        ['All', 'Bible Study', 'Prophecy', 'Health', 'Doctrine'],
                        _applyCategoryFilter,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFilterDropdown(
                        'Level',
                        _selectedLevel,
                        ['All', 'Beginner', 'Intermediate', 'Advanced'],
                        _applyLevelFilter,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Tab Bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).primaryColor,
            tabs: [
              Tab(text: translate('all_lessons')),
                Tab(text: translate('in_progress')),
                Tab(text: translate('favorites')),
                Tab(text: translate('completed')),
            ],
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLessonList(_filteredLessons),
                _buildLessonList(_progressLessons),
                _buildLessonList(_favoriteLessons),
                _buildLessonList(_completedLessons),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> options,
    Function(String) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(label),
          items: options.map((String option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(option),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              onChanged(newValue);
            }
          },
        ),
      ),
    );
  }

  Widget _buildLessonList(List<Map<String, dynamic>> lessons) {
    if (lessons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No lessons found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lessons.length,
      itemBuilder: (context, index) {
        final lesson = lessons[index];
        return _buildLessonCard(lesson, index);
      },
    );
  }

  Widget _buildLessonCard(Map<String, dynamic> lesson, int index) {
    final progress = lesson['progress'] as double;
    final isFavorite = lesson['isFavorite'] as bool;
    final isCompleted = lesson['isCompleted'] as bool;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showLessonDetails(lesson),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      lesson['title'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.grey,
                    ),
                    onPressed: () => _toggleFavorite(index),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Description
              Text(
                lesson['description'],
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              // Tags Row
              Row(
                children: [
                  _buildTag(lesson['category'], Colors.blue),
                  const SizedBox(width: 8),
                  _buildTag(lesson['level'], Colors.green),
                  const SizedBox(width: 8),
                  _buildTag(lesson['duration'], Colors.orange),
                ],
              ),
              const SizedBox(height: 12),
              // Progress Bar
              if (progress > 0) ...[
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isCompleted ? Colors.green : Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              // Status
              if (isCompleted)
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Completed',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _toggleFavorite(int index) {
    setState(() {
      _allLessons[index]['isFavorite'] = !_allLessons[index]['isFavorite'];
      _updateFilteredLessons();
    });
  }

  void _showLessonDetails(Map<String, dynamic> lesson) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lesson['title']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lesson['description']),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.category, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('Category: ${lesson['category']}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.signal_cellular_alt, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('Level: ${lesson['level']}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('Duration: ${lesson['duration']}'),
              ],
            ),
          ],
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
                  content: Text('Opening lesson: ${lesson['title']}'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Begin Lesson'),
          ),
        ],
      ),
    );
  }

  void _applySearchFilter(String query) {
    setState(() {
      _searchQuery = query;
    });
  }
  
  void _applyCategoryFilter(String category) {
    setState(() {
      _selectedCategory = category;
    });
  }
  
  void _applyLevelFilter(String level) {
    setState(() {
      _selectedLevel = level;
    });
  }
}