import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/language_provider.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/search_utils.dart';
import '../../utils/text_formatter.dart';
import '../../services/interactive_lessons_service.dart';
import '../../models/tract_models.dart';
import '../books/tract_reader_screen.dart';
import 'interactive_lesson_reader_screen.dart';

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
  final InteractiveLessonsService _lessonsService =
      InteractiveLessonsService.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadFromService();
    _lessonsService.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    if (mounted) {
      _loadFromService();
    }
  }

  void _loadFromService() {
    setState(() {
      _allLessons =
          _lessonsService.activeLessons.map((l) => l.toJson()).toList();
      _updateFilteredLessons();
    });
  }

  @override
  void dispose() {
    _lessonsService.removeListener(_onServiceUpdate);
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
    var lessons = List<Map<String, dynamic>>.from(_allLessons);
    
    if (_selectedCategory != 'All') {
      lessons = lessons.where((lesson) => lesson['category'] == _selectedCategory).toList();
    }
    if (_selectedLevel != 'All') {
      lessons = lessons.where((lesson) => lesson['level'] == _selectedLevel).toList();
    }
    if (_searchQuery.isNotEmpty) {
      lessons = SearchUtils.rankFilter(
        lessons,
        _searchQuery,
        (lesson) => [
          lesson['title']?.toString() ?? '',
          lesson['description']?.toString() ?? '',
        ],
      );
    }
    return lessons;
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
            padding: context.responsivePadding,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: translate('search_lessons'),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: context.responsiveBorderRadius,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  onChanged: _applySearchFilter,
                ),
                SizedBox(height: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 12.0,
                  tablet: 14.0,
                  desktop: 16.0,
                )),
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
                    SizedBox(width: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 12.0,
                      tablet: 14.0,
                      desktop: 16.0,
                    )),
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
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
            indicatorColor: Theme.of(context).colorScheme.primary,
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
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getResponsiveValue(
          context: context,
          mobile: 12.0,
          tablet: 14.0,
          desktop: 16.0,
        ),
        vertical: ResponsiveUtils.getResponsiveValue(
          context: context,
          mobile: 4.0,
          tablet: 5.0,
          desktop: 6.0,
        ),
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
        borderRadius: context.responsiveBorderRadius,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(label, overflow: TextOverflow.ellipsis),
          items: options.map((String option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(
                option,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
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
              size: context.responsiveIconSize(64),
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 16.0,
              tablet: 20.0,
              desktop: 24.0,
            )),
            Text(
              ref.read(translationProvider)('no_lessons_found'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: context.responsivePadding,
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
      margin: EdgeInsets.only(
        bottom: ResponsiveUtils.getResponsiveValue(
          context: context,
          mobile: 16.0,
          tablet: 18.0,
          desktop: 20.0,
        ),
      ),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: context.responsiveBorderRadius,
      ),
      child: InkWell(
        borderRadius: context.responsiveBorderRadius,
        onTap: () => _showLessonDetails(lesson),
        child: Padding(
          padding: context.responsivePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      lesson['title'],
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.outline,
                    ),
                    onPressed: () => _toggleFavorite(index),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 8.0,
                tablet: 10.0,
                desktop: 12.0,
              )),
              // Description
              Text(
                lesson['description'],
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 12.0,
                tablet: 14.0,
                desktop: 16.0,
              )),
              // Tags Row
              Row(
                children: [
                  _buildTag(lesson['category'], Colors.blue),
                  SizedBox(width: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 8.0,
                    tablet: 10.0,
                    desktop: 12.0,
                  )),
                  _buildTag(lesson['level'], Colors.green),
                  SizedBox(width: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 8.0,
                    tablet: 10.0,
                    desktop: 12.0,
                  )),
                  _buildTag(lesson['duration'], Colors.orange),
                ],
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 12.0,
                tablet: 14.0,
                desktop: 16.0,
              )),
              // Progress Bar
              if (progress > 0) ...[
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isCompleted ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    SizedBox(width: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 8.0,
                      tablet: 10.0,
                      desktop: 12.0,
                    )),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: context.responsiveFontSize(12),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 8.0,
                  tablet: 10.0,
                  desktop: 12.0,
                )),
              ],
              // Status
              if (isCompleted)
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: context.responsiveIconSize(16),
                    ),
                    SizedBox(width: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 4.0,
                      tablet: 5.0,
                      desktop: 6.0,
                    )),
                    Text(
                      'Completed',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.tertiary,
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
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getResponsiveValue(
          context: context,
          mobile: 8.0,
          tablet: 10.0,
          desktop: 12.0,
        ),
        vertical: ResponsiveUtils.getResponsiveValue(
          context: context,
          mobile: 4.0,
          tablet: 5.0,
          desktop: 6.0,
        ),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: context.responsiveBorderRadius,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _toggleFavorite(int index) {
    if (index >= 0 && index < _filteredLessons.length) {
      final lesson = _filteredLessons[index];
      final id = lesson['id']?.toString();
      if (id != null) {
        _lessonsService.toggleFavorite(id);
      }
    }
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
            SizedBox(height: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 16.0,
              tablet: 18.0,
              desktop: 20.0,
            )),
            Row(
              children: [
                Icon(Icons.category, size: context.responsiveIconSize(16), color: Theme.of(context).colorScheme.outline),
                SizedBox(width: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 4.0,
                  tablet: 5.0,
                  desktop: 6.0,
                )),
                Text('${ref.read(translationProvider)('category')}: ${TextFormatter.formatText(lesson['category'])}'),
              ],
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 8.0,
              tablet: 10.0,
              desktop: 12.0,
            )),
            Row(
              children: [
                Icon(Icons.signal_cellular_alt, size: context.responsiveIconSize(16), color: Theme.of(context).colorScheme.outline),
                SizedBox(width: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 4.0,
                  tablet: 5.0,
                  desktop: 6.0,
                )),
                Text('${ref.read(translationProvider)('level')}: ${TextFormatter.formatText(lesson['level'])}'),
              ],
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 8.0,
              tablet: 10.0,
              desktop: 12.0,
            )),
            Row(
              children: [
                Icon(Icons.access_time, size: context.responsiveIconSize(16), color: Theme.of(context).colorScheme.outline),
                SizedBox(width: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 4.0,
                  tablet: 5.0,
                  desktop: 6.0,
                )),
                Text('${ref.read(translationProvider)('duration')}: ${lesson['duration']}'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(ref.read(translationProvider)('close')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              final lessonId = lesson['id']?.toString() ??
                  'lesson_${(lesson['title'] ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
              _lessonsService.updateLessonProgress(lessonId, 0.5);
              if (lessonId == "lesson_something_we_can_trust" || (lesson["title"] ?? "").toString().toLowerCase().contains("something we can trust")) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => InteractiveLessonReaderScreen(
                      lessonId: lessonId,
                      title: lesson["title"] ?? "Lesson 1: Something We Can Trust",
                    ),
                  ),
                );
                return;
              }
              final tract = Tract(
                id: lessonId,
                title: lesson['title'] ?? 'Interactive Lesson',
                description: lesson['description'] ?? '',
                category: lesson['category'] ?? 'Bible Study',
                pages: 8,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => TractReaderScreen(tract: tract),
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
