import 'package:flutter/material.dart';
import '../../models/study_guide_models.dart';
import '../../services/study_guide_service.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive_utils.dart';

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
      final user = _authService.currentUser;
      if (user != null) {
        final results = await Future.wait([
          _studyGuideService.getStudyGuides(
            type: _selectedType,
            difficulty: _selectedDifficulty,
            searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
          ),
          _studyGuideService.getUserProgress(user.uid),
          _studyGuideService.getStudyStatistics(user.uid),
        ]);
        
        setState(() {
          _studyGuides = results[0] as List<StudyGuide>;
          _userProgress = results[1] as List<UserStudyProgress>;
          _statistics = results[2] as Map<String, dynamic>;
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
      appBar: AppBar(
        title: const Text('Study Guides'),
        bottom: TabBar(
          controller: _tabController,
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
              'Welcome to Study Guides',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 24, tablet: 28, desktop: 32),
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8, tablet: 10, desktop: 12)),
            Text(
              'Deepen your understanding of Scripture through structured Bible studies',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 16, tablet: 18, desktop: 20),
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
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 14, tablet: 16, desktop: 18),
                ),
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
            Colors.blue,
          ),
        ),
        SizedBox(width: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
        Expanded(
          child: _buildStatCard(
            'Completed',
            '${_statistics['completedStudies'] ?? 0}',
            Icons.check_circle,
            Colors.green,
          ),
        ),
        SizedBox(width: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
        Expanded(
          child: _buildStatCard(
            'In Progress',
            '${_statistics['inProgressStudies'] ?? 0}',
            Icons.schedule,
            Colors.orange,
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
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 24, tablet: 28, desktop: 32),
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 14, desktop: 16),
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
          style: TextStyle(
            fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 20, tablet: 24, desktop: 28),
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
          style: TextStyle(
            fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 20, tablet: 24, desktop: 28),
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
                    style: TextStyle(fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 16, tablet: 18, desktop: 20)),
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
                  initialValue: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: [null, ...StudyGuideType.values].map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type?.name.toUpperCase() ?? 'All Types'),
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
                  initialValue: _selectedDifficulty,
                  decoration: const InputDecoration(
                    labelText: 'Difficulty',
                    border: OutlineInputBorder(),
                  ),
                  items: [null, ...StudyDifficulty.values].map((difficulty) {
                    return DropdownMenuItem(
                      value: difficulty,
                      child: Text(difficulty?.name.toUpperCase() ?? 'All Levels'),
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
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 18, tablet: 20, desktop: 22),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 4, tablet: 6, desktop: 8)),
                        Text(
                          guide.description,
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 14, tablet: 16, desktop: 18),
                            color: Colors.grey[600],
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
                  _buildInfoChip(guide.type.name.toUpperCase(), Colors.blue),
                  SizedBox(width: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8, tablet: 10, desktop: 12)),
                  _buildInfoChip(guide.difficulty.name.toUpperCase(), Colors.orange),
                  SizedBox(width: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8, tablet: 10, desktop: 12)),
                  _buildInfoChip('${guide.estimatedDurationMinutes}min', Colors.green),
                ],
              ),
              if (userProgress.status != StudyStatus.notStarted) ...[
                SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
                LinearProgressIndicator(
                  value: userProgress.progressPercentage / 100,
                  backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    userProgress.status == StudyStatus.completed
                        ? Colors.green
                        : AppTheme.primaryColor,
                  ),
                ),
                SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 4, tablet: 6, desktop: 8)),
                Text(
                  '${userProgress.progressPercentage.toInt()}% Complete',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 14, desktop: 16),
                    color: Colors.grey[600],
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
            Icon(Icons.timeline, size: ResponsiveUtils.getResponsiveValue(context: context, mobile: 64, tablet: 72, desktop: 80), color: Colors.grey),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 16, tablet: 20, desktop: 24)),
            Text(
              'No study progress yet',
              style: TextStyle(fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 18, tablet: 20, desktop: 22), color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8, tablet: 10, desktop: 12)),
            Text(
              'Start a study guide to track your progress',
              style: TextStyle(fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 14, tablet: 16, desktop: 18), color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
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
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 16, tablet: 18, desktop: 20),
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
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress.status == StudyStatus.completed
                      ? Colors.green
                      : AppTheme.primaryColor,
                ),
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8, tablet: 10, desktop: 12)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${progress.progressPercentage.toInt()}% Complete',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 14, desktop: 16),
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    'Lesson ${progress.currentLessonNumber}',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 14, desktop: 16),
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              if (progress.totalTimeSpentMinutes > 0) ...[
                SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 4, tablet: 6, desktop: 8)),
                Text(
                  'Time spent: ${_formatDuration(progress.totalTimeSpentMinutes)}',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 14, desktop: 16),
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
            style: TextStyle(
              fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 24, tablet: 28, desktop: 32),
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
                Colors.green,
              ),
            ),
            SizedBox(width: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
            Expanded(
              child: _buildStatCard(
                'Total Time',
                _formatDuration(_statistics['totalTimeSpentMinutes'] ?? 0),
                Icons.access_time,
                Colors.blue,
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
                Colors.purple,
              ),
            ),
            SizedBox(width: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
            Expanded(
              child: _buildStatCard(
                'Active Studies',
                '${_statistics['inProgressStudies'] ?? 0}',
                Icons.play_circle,
                Colors.orange,
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
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 18, tablet: 20, desktop: 22),
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
                      style: TextStyle(fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 14, tablet: 16, desktop: 18)),
                    ),
                    Text(
                      '${entry.value}',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 14, tablet: 16, desktop: 18),
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
        color = Colors.grey;
        text = 'Not Started';
        break;
      case StudyStatus.inProgress:
        color = Colors.orange;
        text = 'In Progress';
        break;
      case StudyStatus.completed:
        color = Colors.green;
        text = 'Completed';
        break;
      case StudyStatus.reviewed:
        color = Colors.blue;
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
        style: TextStyle(
          fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 14, desktop: 16),
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
        style: TextStyle(
          fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 10, tablet: 12, desktop: 14),
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
          title: Text(
            'Study Guide: ${guide.title}',
            style: TextStyle(
              fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 18, tablet: 20, desktop: 22),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Description: ${guide.description}',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 14, tablet: 16, desktop: 18),
                ),
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8, tablet: 10, desktop: 12)),
              Text(
                'Type: ${guide.type.name.toUpperCase()}',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 14, tablet: 16, desktop: 18),
                ),
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8, tablet: 10, desktop: 12)),
              Text(
                'Difficulty: ${guide.difficulty.name.toUpperCase()}',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 14, tablet: 16, desktop: 18),
                ),
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8, tablet: 10, desktop: 12)),
              Text(
                'Duration: ${guide.estimatedDurationMinutes} minutes',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 14, tablet: 16, desktop: 18),
                ),
              ),
              if (progress != null) ...[
                SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8, tablet: 10, desktop: 12)),
                Text(
                  'Progress: ${progress.progressPercentage.toInt()}%',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 14, tablet: 16, desktop: 18),
                  ),
                ),
                SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8, tablet: 10, desktop: 12)),
                Text(
                  'Current Lesson: ${progress.currentLessonNumber}',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 14, tablet: 16, desktop: 18),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 14, tablet: 16, desktop: 18),
                ),
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




