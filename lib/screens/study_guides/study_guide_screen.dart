import 'package:flutter/material.dart';
import '../../models/study_guide_models.dart';
import '../../services/study_guide_service.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';

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
          _studyGuideService.getUserProgress(user.id),
          _studyGuideService.getStudyStatistics(user.id),
        ]);
        
        setState(() {
          _studyGuides = results[0] as List<StudyGuide>;
          _userProgress = results[1] as List<UserStudyProgress>;
          _statistics = results[2] as Map<String, dynamic>;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Guides'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: 16),
          _buildQuickStats(),
          const SizedBox(height: 16),
          _buildFeaturedStudyGuides(),
          const SizedBox(height: 16),
          _buildRecentProgress(),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome to Study Guides',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Deepen your understanding of Scripture through structured Bible studies',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _tabController.animateTo(1),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryColor,
              ),
              child: const Text('Browse Study Guides'),
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
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Completed',
            '${_statistics['completedStudies'] ?? 0}',
            Icons.check_circle,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
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
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
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
        const Text(
          'Featured Study Guides',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
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
        const Text(
          'Recent Progress',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
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
              ? const Center(
                  child: Text(
                    'No study guides found',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
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
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
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
          const SizedBox(height: 12),
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
              const SizedBox(width: 12),
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
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _startOrContinueStudy(guide),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          guide.description,
                          style: TextStyle(
                            fontSize: 14,
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
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(guide.type.name.toUpperCase(), Colors.blue),
                  const SizedBox(width: 8),
                  _buildInfoChip(guide.difficulty.name.toUpperCase(), Colors.orange),
                  const SizedBox(width: 8),
                  _buildInfoChip('${guide.estimatedDurationMinutes}min', Colors.green),
                ],
              ),
              if (userProgress.status != StudyStatus.notStarted) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: userProgress.progressPercentage / 100,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    userProgress.status == StudyStatus.completed
                        ? Colors.green
                        : AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${userProgress.progressPercentage.toInt()}% Complete',
                  style: TextStyle(
                    fontSize: 12,
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
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No study progress yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Start a study guide to track your progress',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
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
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _continueStudy(studyGuide, progress),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      studyGuide.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusChip(progress.status),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress.progressPercentage / 100,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress.status == StudyStatus.completed
                      ? Colors.green
                      : AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${progress.progressPercentage.toInt()}% Complete',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    'Lesson ${progress.currentLessonNumber}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              if (progress.totalTimeSpentMinutes > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Time spent: ${_formatDuration(progress.totalTimeSpentMinutes)}',
                  style: TextStyle(
                    fontSize: 12,
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

  Widget _buildStatisticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Study Statistics',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailedStats(),
          const SizedBox(height: 16),
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
            const SizedBox(width: 12),
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
        const SizedBox(height: 12),
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
            const SizedBox(width: 12),
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
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Study Types Distribution',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...typeDistribution.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key.toUpperCase(),
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      '${entry.value}',
                      style: const TextStyle(
                        fontSize: 14,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
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
      final existingProgress = await _studyGuideService.getUserStudyProgress(user.id, guide.id);
      
      if (existingProgress == null) {
        // Start new study
        await _studyGuideService.startStudyGuide(user.id, guide.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Started study: ${guide.title}')),
        );
      } else {
        // Continue existing study
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Continuing study: ${guide.title}')),
        );
      }
      
      // Navigate to study guide detail screen
      // TODO: Implement navigation to study guide detail screen
      
      _loadData(); // Refresh data
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting study: $e')),
      );
    }
  }

  Future<void> _continueStudy(StudyGuide guide, UserStudyProgress progress) async {
    // Navigate to study guide detail screen with current progress
    // TODO: Implement navigation to study guide detail screen
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Continuing study: ${guide.title}')),
    );
  }
}
