import 'package:flutter/material.dart';
import '../../models/chapter_models.dart';
import '../../services/chapter_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../config/meeting_links_config.dart';
import '../conference/enhanced_jitsi_meet_screen.dart';
import '../../providers/firebase_auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ChapterScreen extends StatefulWidget {
  const ChapterScreen({super.key});

  @override
  State<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends State<ChapterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ChapterService _chapterService = ChapterService();
  final AuthService _authService = AuthService.instance;

  List<Chapter> _chapters = [];
  List<ChapterMember> _userMemberships = [];
  List<ChapterActivity> _userActivities = [];
  List<ChapterTask> _userTasks = [];
  Map<String, dynamic> _userStatistics = {};

  bool _isLoading = true;
  String _searchQuery = '';
  WorkersType? _selectedType;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
      _currentUserId = _authService.currentUser?.uid;
      if (_currentUserId == null) return;

      final results = await Future.wait([
        _chapterService.getChapters(
          type: _selectedType,
          isActive: true,
          searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        ),
        _chapterService.getUserMemberships(_currentUserId!),
        _chapterService.getUserActivities(_currentUserId!),
        _chapterService.getUserTasks(_currentUserId!),
        _chapterService.getUserChapterStatistics(_currentUserId!),
      ]);

      setState(() {
        _chapters = results[0] as List<Chapter>;
        _userMemberships = results[1] as List<ChapterMember>;
        _userActivities = results[2] as List<ChapterActivity>;
        _userTasks = results[3] as List<ChapterTask>;
        _userStatistics = results[4] as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Chapters',
        showBackButton: true,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.onPrimary,
          labelColor: theme.colorScheme.onPrimary,
          unselectedLabelColor:
              theme.colorScheme.onPrimary.withValues(alpha: 0.7),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Browse'),
            Tab(text: 'My Chapters'),
            Tab(text: 'Activities'),
            Tab(text: 'Tasks'),
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
                _buildMyChaptersTab(),
                _buildActivitiesTab(),
                _buildTasksTab(),
              ],
            ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGeneralMeetingBanner(),
          _buildStatisticsCards(),
          const SizedBox(height: 24),
          _buildRecentActivities(),
          const SizedBox(height: 24),
          _buildUpcomingTasks(),
        ],
      ),
    );
  }

  Widget _buildGeneralMeetingBanner() {
    final container = ProviderScope.containerOf(context);
    final userProfileAsync = container.read(currentUserProfileProvider);

    bool canStartGeneral = false;
    bool isModerator = false;
    if (userProfileAsync.hasValue && userProfileAsync.value != null) {
      final role = (userProfileAsync.value!.role).toLowerCase();
      const allowedRoles = [
        'admin',
        'bod',
        'director',
        'coordinator',
        'chapter_leader',
        'moderator',
      ];
      const moderatorRoles = [
        'admin',
        'bod',
        'director',
      ];
      canStartGeneral = allowedRoles.contains(role);
      isModerator = moderatorRoles.contains(role);
    }

    if (!canStartGeneral) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Icon(Icons.video_call, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'General Meeting is available',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => EnhancedJitsiMeetScreen(
                        meetingType: MeetingType.general,
                        isModerator: isModerator,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Join'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Chapter Statistics',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard(
                'Chapters',
                '${_userStatistics['totalChapters'] ?? 0}',
                Icons.group,
                Theme.of(context).colorScheme.primary,
              ),
              _buildStatCard(
                'Activities',
                '${_userStatistics['totalActivities'] ?? 0}',
                Icons.event,
                Theme.of(context).colorScheme.tertiary,
              ),
              _buildStatCard(
                'Tasks',
                '${_userStatistics['totalTasks'] ?? 0}',
                Icons.task,
                Theme.of(context).colorScheme.secondary,
              ),
              _buildStatCard(
                'Completion Rate',
                '${_userStatistics['activityCompletionRate'] ?? 0}%',
                Icons.check_circle,
                Theme.of(context).colorScheme.primary,
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivities() {
    final recentActivities = _userActivities.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activities',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        if (recentActivities.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No recent activities'),
            ),
          )
        else
          ...recentActivities.map((activity) => _buildActivityCard(activity)),
      ],
    );
  }

  Widget _buildUpcomingTasks() {
    final upcomingTasks = _userTasks
        .where((task) => task.status != ActivityStatus.completed)
        .take(5)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upcoming Tasks',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        if (upcomingTasks.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No upcoming tasks'),
            ),
          )
        else
          ...upcomingTasks.map((task) => _buildTaskCard(task)),
      ],
    );
  }

  Widget _buildBrowseTab() {
    return Column(
      children: [
        _buildSearchAndFilter(),
        Expanded(
          child: _chapters.isEmpty
              ? const Center(child: Text('No chapters found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _chapters.length,
                  itemBuilder: (context, index) {
                    return _buildChapterCard(_chapters[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom:
              BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search chapters...',
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
                child: DropdownButtonFormField<WorkersType?>(
                  initialValue: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Worker Type',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<WorkersType?>(
                      value: null,
                      child: Text('All Worker Types'),
                    ),
                    ...WorkersType.values.map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(_chapterService.getTypeDescription(type)),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedType = value);
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

  Widget _buildMyChaptersTab() {
    if (_userMemberships.isEmpty) {
      return const Center(child: Text('You are not a member of any chapters'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userMemberships.length,
      itemBuilder: (context, index) {
        final membership = _userMemberships[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.group),
            title: Text('Chapter: ${membership.chapterId}'),
            subtitle: Text('Role: ${membership.role}'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _navigateToChapterDetails(null,
                chapterId: membership.chapterId),
          ),
        );
      },
    );
  }

  Widget _buildActivitiesTab() {
    if (_userActivities.isEmpty) {
      return const Center(child: Text('No activities found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userActivities.length,
      itemBuilder: (context, index) {
        return _buildActivityCard(_userActivities[index]);
      },
    );
  }

  Widget _buildTasksTab() {
    if (_userTasks.isEmpty) {
      return const Center(child: Text('No tasks found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userTasks.length,
      itemBuilder: (context, index) {
        return _buildTaskCard(_userTasks[index]);
      },
    );
  }

  Widget _buildActivityCard(ChapterActivity activity) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListTile(
        title: Text(activity.title),
        subtitle: Text(_formatDate(activity.scheduledAt)),
        trailing: Chip(label: Text(activity.status.toString().split('.').last)),
        onTap: () => _navigateToActivityDetails(activity),
      ),
    );
  }

  Widget _buildTaskCard(ChapterTask task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListTile(
        title: Text(task.title),
        subtitle: Text('Due: ${_formatDate(task.dueDate)}'),
        trailing: Checkbox(
          value: task.status == ActivityStatus.completed,
          onChanged: (value) => _completeTask(task),
        ),
      ),
    );
  }

  Widget _buildChapterCard(Chapter chapter) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListTile(
        title: Text(chapter.name),
        subtitle: Text(_chapterService.getTypeDescription(chapter.type)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _navigateToChapterDetails(chapter),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _createChapter,
      child: const Icon(Icons.add),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy HH:mm').format(date);
  }

  // Navigation methods
  void _navigateToChapterDetails(Chapter? chapter, {String? chapterId}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chapter Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (chapter != null) ...[
                Text('Name: ${chapter.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                    'Type: ${_chapterService.getTypeDescription(chapter.type)}'),
                const SizedBox(height: 8),
                Text('Members: ${chapter.memberIds.length}'),
                const SizedBox(height: 8),
                Text('Coordinator: ${chapter.coordinatorId ?? "Not assigned"}'),
                const SizedBox(height: 8),
                Text('Status: ${chapter.isActive ? "Active" : "Inactive"}'),
              ] else ...[
                Text('Chapter ID: $chapterId'),
                const SizedBox(height: 8),
                const Text('Loading chapter details...'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _navigateToActivityDetails(ChapterActivity activity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activity Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Title: ${activity.title}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Description: ${activity.description}'),
              const SizedBox(height: 8),
              Text('Date: ${_formatDate(activity.scheduledAt)}'),
              const SizedBox(height: 8),
              Text('Location: ${activity.location}'),
              const SizedBox(height: 8),
              Text('Assigned Members: ${activity.assignedMemberIds.length}'),
              const SizedBox(height: 8),
              Text('Status: ${activity.status}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _createChapter() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Chapter creation not implemented in this view')),
    );
  }

  Future<void> _completeTask(ChapterTask task) async {
    try {
      await _chapterService.completeTask(task.id);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
