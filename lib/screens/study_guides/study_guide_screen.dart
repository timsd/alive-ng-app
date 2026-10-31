import 'package:flutter/material.dart';
import '../../models/study_guide_models.dart';
import '../../services/study_guide_service.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/custom_app_bar.dart';

class StudyGuideScreen extends StatefulWidget {
  const StudyGuideScreen({super.key});

  @override
  State<StudyGuideScreen> createState() => _StudyGuideScreenState();
}

class _StudyGuideScreenState extends State<StudyGuideScreen> with TickerProviderStateMixin {
  final StudyGuideService _studyGuideService = StudyGuideService();
  final AuthService _authService = AuthService.instance;
  late TabController _tabController;
  
  List<StudyGuide> _studyGuides = [];
  List<UserStudyProgress> _userProgress = [];
  Map<String, dynamic> _statistics = {};
  bool _isLoading = true;
  String _searchQuery = '';
  StudyGuideType? _selectedType;
  StudyDifficulty? _selectedDifficulty;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final guides = await _studyGuideService.getStudyGuides(
        type: _selectedType,
        difficulty: _selectedDifficulty,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      );
      final user = _authService.currentUser;
      List<UserStudyProgress> progress = [];
      Map<String, dynamic> stats = {'totalStudies': guides.length};
      if (user != null) {
        final results = await Future.wait([
          _studyGuideService.getUserProgress(user.uid),
          _studyGuideService.getStudyStatistics(user.uid),
        ]);
        progress = results[0] as List<UserStudyProgress>;
        stats = results[1] as Map<String, dynamic>;
      }
      if (mounted) {
        setState(() {
          _studyGuides = guides;
          _userProgress = progress;
          _statistics = stats;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Study Guides',
        showBackButton: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.onPrimary,
          labelColor: Theme.of(context).colorScheme.onPrimary,
          unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.72),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.library_books), text: 'Browse'),
            Tab(icon: Icon(Icons.timeline), text: 'Progress'),
            Tab(icon: Icon(Icons.analytics), text: 'Statistics'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildBrowseTab(),
                _buildProgressTab(),
                _buildStatisticsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(context: context, mobile: 16, tablet: 20, desktop: 24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(),
          SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 16, tablet: 20, desktop: 24)),
          _buildQuickStats(),
          SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 16, tablet: 20, desktop: 24)),
          _buildFeaturedStudyGuides(),
          SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 16, tablet: 20, desktop: 24)),
          _buildRecentProgress(),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: ResponsiveUtils.getResponsiveValue(context: context, mobile: 4, tablet: 6, desktop: 8),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(context: context, mobile: 20, tablet: 24, desktop: 28)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
          gradient: LinearGradient(
            colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deepen your understanding of Scripture through structured Bible studies',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
              ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 16, tablet: 20, desktop: 24)),
            ElevatedButton(
              onPressed: () => _tabController.animateTo(1),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.onPrimary,
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: Text(
                'Browse Study Guides',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Studies',
            '${_statistics['totalStudies'] ?? 0}',
            Icons.library_books,
            Theme.of(context).colorScheme.primary,
          ),
        ),
        SizedBox(width: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
        Expanded(
          child: _buildStatCard(
            'Completed',
            '${_statistics['completedStudies'] ?? 0}',
            Icons.check_circle,
            Theme.of(context).colorScheme.tertiary,
          ),
        ),
        SizedBox(width: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
        Expanded(
          child: _buildStatCard(
            'In Progress',
            '${_statistics['inProgressStudies'] ?? 0}',
            Icons.schedule,
            Theme.of(context).colorScheme.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: ResponsiveUtils.getResponsiveValue(context: context, mobile: 2, tablet: 3, desktop: 4),
      child: Padding(
        padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(context: context, mobile: 16, tablet: 20, desktop: 24)),
        child: Column(
          children: [
            Icon(icon, color: color, size: ResponsiveUtils.getResponsiveValue(context: context, mobile: 32, tablet: 36, desktop: 40)),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8, tablet: 10, desktop: 12)),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedStudyGuides() {
    final featuredGuides = _studyGuides.take(3).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Featured Study Guides',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
        ...featuredGuides.map((guide) => _buildStudyGuideCard(guide)),
      ],
    );
  }

  Widget _buildRecentProgress() {
    final recentProgress = _userProgress.take(3).toList();
    
    if (recentProgress.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Progress',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
        ...recentProgress.map((progress) => _buildProgressCard(progress)),
      ],
    );
  }

  Widget _buildBrowseTab() {
    return Column(
      children: [
        _buildSearchAndFilters(),
        Expanded(
          child: _studyGuides.isEmpty
              ? Center(
                  child: Text(
                    'No study guides found',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(context: context, mobile: 16, tablet: 20, desktop: 24)),
                  itemCount: _studyGuides.length,
                  itemBuilder: (context, index) {
                    return _buildStudyGuideCard(_studyGuides[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(context: context, mobile: 16, tablet: 20, desktop: 24)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search study guides...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
              _loadData();
            },
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<StudyGuideType>(
                  isExpanded: true,
                  initialValue: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: [null, ...StudyGuideType.values].map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type?.name.toUpperCase() ?? 'All Types',
                          overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedType = value);
                    _loadData();
                  },
                ),
              ),
              SizedBox(width: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
              Expanded(
                child: DropdownButtonFormField<StudyDifficulty>(
                  isExpanded: true,
                  initialValue: _selectedDifficulty,
                  decoration: const InputDecoration(
                    labelText: 'Difficulty',
                    border: OutlineInputBorder(),
                  ),
                  items: [null, ...StudyDifficulty.values].map((difficulty) {
                    return DropdownMenuItem(
                      value: difficulty,
                      child: Text(difficulty?.name.toUpperCase() ?? 'All Levels',
                          overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedDifficulty = value);
                    _loadData();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudyGuideCard(StudyGuide guide) {
    final userProgress = _userProgress.firstWhere(
      (p) => p.studyGuideId == guide.id,
      orElse: () => UserStudyProgress(
        id: '',
        userId: '',
        studyGuideId: guide.id,
        status: StudyStatus.notStarted,
        startedAt: DateTime.now(),
        currentLessonNumber: 1,
        progressPercentage: 0.0,
        totalTimeSpentMinutes: 0,
        notes: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    return Card(
      margin: EdgeInsets.only(bottom: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
      elevation: ResponsiveUtils.getResponsiveValue(context: context, mobile: 2, tablet: 3, desktop: 4),
      child: InkWell(
        onTap: () => _startOrContinueStudy(guide),
        borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
        child: Padding(
          padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(context: context, mobile: 16, tablet: 20, desktop: 24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          guide.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 4, tablet: 6, desktop: 8)),
                        Text(
                          guide.description,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(userProgress.status),
                ],
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
              Row(
                children: [
                  _buildInfoChip(guide.type.name.toUpperCase(), Theme.of(context).colorScheme.primary),
                  SizedBox(width: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8, tablet: 10, desktop: 12)),
                  _buildInfoChip(guide.difficulty.name.toUpperCase(), Theme.of(context).colorScheme.secondary),
                  SizedBox(width: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8, tablet: 10, desktop: 12)),
                  _buildInfoChip('${guide.estimatedDurationMinutes}min', Theme.of(context).colorScheme.tertiary),
                ],
              ),
              if (userProgress.status != StudyStatus.notStarted) ...[
                SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
                LinearProgressIndicator(
                  value: userProgress.progressPercentage / 100,
                  backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    userProgress.status == StudyStatus.completed
                        ? Theme.of(context).colorScheme.tertiary
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
                SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 4, tablet: 6, desktop: 8)),
                Text(
                  '${userProgress.progressPercentage.toInt()}% Complete',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressTab() {
    if (_userProgress.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline, size: ResponsiveUtils.getResponsiveValue(context: context, mobile: 64, tablet: 72, desktop: 80), color: Theme.of(context).colorScheme.outline),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 16, tablet: 20, desktop: 24)),
            Text(
              'No study progress yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8, tablet: 10, desktop: 12)),
            Text(
              'Start a study guide to track your progress',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(context: context, mobile: 16, tablet: 20, desktop: 24)),
      itemCount: _userProgress.length,
      itemBuilder: (context, index) {
        return _buildProgressCard(_userProgress[index]);
      },
    );
  }

  Widget _buildProgressCard(UserStudyProgress progress) {
    final studyGuide = _studyGuides.firstWhere(
      (sg) => sg.id == progress.studyGuideId,
      orElse: () => StudyGuide(
        id: progress.studyGuideId,
        title: 'Unknown Study Guide',
        description: '',
        type: StudyGuideType.doctrine,
        difficulty: StudyDifficulty.beginner,
        estimatedDurationMinutes: 0,
        objectives: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    return Card(
      margin: EdgeInsets.only(bottom: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
      elevation: ResponsiveUtils.getResponsiveValue(context: context, mobile: 2, tablet: 3, desktop: 4),
      child: InkWell(
        onTap: () => _continueStudy(studyGuide, progress),
        borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
        child: Padding(
          padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(context: context, mobile: 16, tablet: 20, desktop: 24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      studyGuide.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusChip(progress.status),
                ],
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8, tablet: 10, desktop: 12)),
              LinearProgressIndicator(
                value: progress.progressPercentage / 100,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress.status == StudyStatus.completed
                      ? Theme.of(context).colorScheme.tertiary
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8, tablet: 10, desktop: 12)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${progress.progressPercentage.toInt()}% Complete',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    'Lesson ${progress.currentLessonNumber}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              if (progress.totalTimeSpentMinutes > 0) ...[
                SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 4, tablet: 6, desktop: 8)),
                Text(
                  'Time spent: ${_formatDuration(progress.totalTimeSpentMinutes)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(context: context, mobile: 16, tablet: 20, desktop: 24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Study Statistics',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 16, tablet: 20, desktop: 24)),
          _buildDetailedStats(),
          SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 16, tablet: 20, desktop: 24)),
          _buildTypeDistribution(),
        ],
      ),
    );
  }

  Widget _buildDetailedStats() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Completion Rate',
                '${_statistics['completionRate'] ?? 0}%',
                Icons.trending_up,
                Theme.of(context).colorScheme.tertiary,
              ),
            ),
            SizedBox(width: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
            Expanded(
              child: _buildStatCard(
                'Total Time',
                _formatDuration(_statistics['totalTimeSpentMinutes'] ?? 0),
                Icons.access_time,
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Average Progress',
                '${(_statistics['averageProgress'] ?? 0.0).toInt()}%',
                Icons.analytics,
                Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(width: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
            Expanded(
              child: _buildStatCard(
                'Completed',
                '${_statistics['completedStudies'] ?? 0}',
                Icons.check_circle,
                Theme.of(context).colorScheme.tertiary,
              ),
            ),
            SizedBox(width: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
            Expanded(
              child: _buildStatCard(
                'In Progress',
                '${_statistics['inProgressStudies'] ?? 0}',
                Icons.schedule,
                Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeDistribution() {
    final typeDistribution = _statistics['typeDistribution'] as Map<String, dynamic>? ?? {};
    
    if (typeDistribution.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Card(
      elevation: ResponsiveUtils.getResponsiveValue(context: context, mobile: 2, tablet: 3, desktop: 4),
      child: Padding(
        padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(context: context, mobile: 16, tablet: 20, desktop: 24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Study Types Distribution',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
            ...typeDistribution.entries.map((entry) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.getResponsiveValue(context: context, mobile: 4, tablet: 6, desktop: 8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key.toUpperCase(),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      '${entry.value}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(StudyStatus status) {
    Color color;
    String text;
    
    switch (status) {
      case StudyStatus.notStarted:
        color = Theme.of(context).colorScheme.outline;
        text = 'Not Started';
        break;
      case StudyStatus.inProgress:
        color = Theme.of(context).colorScheme.secondary;
        text = 'In Progress';
        break;
      case StudyStatus.completed:
        color = Theme.of(context).colorScheme.tertiary;
        text = 'Completed';
        break;
      case StudyStatus.reviewed:
        color = Theme.of(context).colorScheme.primary;
        text = 'Reviewed';
        break;
    }
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8, tablet: 10, desktop: 12), 
        vertical: ResponsiveUtils.getResponsiveValue(context: context, mobile: 4, tablet: 6, desktop: 8)
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
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

  Widget _buildInfoChip(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8, tablet: 10, desktop: 12), 
        vertical: ResponsiveUtils.getResponsiveValue(context: context, mobile: 4, tablet: 6, desktop: 8)
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
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
  
  

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return remainingMinutes > 0 ? '${hours}h ${remainingMinutes}m' : '${hours}h';
    }
  }

  Future<void> _startOrContinueStudy(StudyGuide guide) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;
      
      // Check if user has existing progress
      final existingProgress = await _studyGuideService.getUserStudyProgress(user.uid, guide.id);
      
      if (existingProgress == null) {
        // Start new study
        await _studyGuideService.startStudyGuide(user.uid, guide.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Started study: ${guide.title}')),
          );
        }
      } else {
        // Continue existing study
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Continuing study: ${guide.title}')),
          );
        }
      }
      
      // Navigate to study guide detail screen
      _navigateToStudyDetail(guide, existingProgress);
      
      _loadData(); // Refresh data
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting study: $e')),
        );
      }
    }
  }

  Future<void> _continueStudy(StudyGuide guide, UserStudyProgress progress) async {
    // Navigate to study guide detail screen with current progress
    _navigateToStudyDetail(guide, progress);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Continuing study: ${guide.title}')),
    );
  }

  void _navigateToStudyDetail(StudyGuide guide, UserStudyProgress? progress) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Study Guide: ${guide.title}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Description: ${guide.description}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8, tablet: 10, desktop: 12)),
              Text(
                'Type: ${guide.type.name.toUpperCase()}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8, tablet: 10, desktop: 12)),
              Text(
                'Difficulty: ${guide.difficulty.name.toUpperCase()}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8, tablet: 10, desktop: 12)),
              Text(
                'Duration: ${guide.estimatedDurationMinutes} minutes',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (progress != null) ...[
                SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8, tablet: 10, desktop: 12)),
                Text(
                  'Progress: ${progress.progressPercentage.toInt()}%',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8, tablet: 10, desktop: 12)),
                Text(
                  'Current Lesson: ${progress.currentLessonNumber}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Opening study guide: ${guide.title}',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 14, tablet: 16, desktop: 18),
                      ),
                    ),
                    backgroundColor: AppTheme.primaryColor,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Open Study',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 14, tablet: 16, desktop: 18),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

}




