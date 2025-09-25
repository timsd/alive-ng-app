import 'package:flutter/material.dart';
import '../../models/chapter_models.dart';
import '../../services/chapter_service.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';

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
  ChapterType? _selectedType;
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
      _currentUserId = _authService.currentUser?.id;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chapters'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
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
          _buildStatisticsCards(),
          const SizedBox(height: 24),
          _buildRecentActivities(),
          const SizedBox(height: 24),
          _buildUpcomingTasks(),
        ],
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My Chapter Statistics',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
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
                  Colors.blue,
                ),
                _buildStatCard(
                  'Activities',
                  '${_userStatistics['totalActivities'] ?? 0}',
                  Icons.event,
                  Colors.green,
                ),
                _buildStatCard(
                  'Tasks',
                  '${_userStatistics['totalTasks'] ?? 0}',
                  Icons.task,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Completion Rate',
                  '${_userStatistics['activityCompletionRate'] ?? 0}%',
                  Icons.check_circle,
                  Colors.purple,
                ),
              ],
            );
          }
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
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
        const Text(
          'Recent Activities',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
        const Text(
          'Upcoming Tasks',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
      color: Colors.grey[100],
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
                child: DropdownButtonFormField<ChapterType?>(
                  initialValue: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Chapter Type',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<ChapterType?>(
                      value: null,
                      child: Text('All Types'),
                    ),
                    ...ChapterType.values.map((type) => DropdownMenuItem(
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
    return _userMemberships.isEmpty
        ? const Center(child: Text('You are not a member of any chapters'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _userMemberships.length,
            itemBuilder: (context, index) {
              return _buildMembershipCard(_userMemberships[index]);
            },
          );
  }

  Widget _buildActivitiesTab() {
    return _userActivities.isEmpty
        ? const Center(child: Text('No activities assigned'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _userActivities.length,
            itemBuilder: (context, index) {
              return _buildActivityCard(_userActivities[index]);
            },
          );
  }

  Widget _buildTasksTab() {
    return _userTasks.isEmpty
        ? const Center(child: Text('No tasks assigned'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _userTasks.length,
            itemBuilder: (context, index) {
              return _buildTaskCard(_userTasks[index]);
            },
          );
  }

  Widget _buildChapterCard(Chapter chapter) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor,
          child: Text(
            chapter.name.substring(0, 1).toUpperCase(),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          chapter.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_chapterService.getTypeDescription(chapter.type)),
            Text(
              chapter.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () => _navigateToChapterDetails(chapter),
      ),
    );
  }

  Widget _buildMembershipCard(ChapterMember membership) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(membership.role),
          child: Icon(
            _getRoleIcon(membership.role),
            color: Colors.white,
          ),
        ),
        title: Text(
          'Chapter ID: ${membership.chapterId}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_chapterService.getRoleDescription(membership.role)),
            Text('Joined: ${_formatDate(membership.joinedAt)}'),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () =>
            _navigateToChapterDetails(null, chapterId: membership.chapterId),
      ),
    );
  }

  Widget _buildActivityCard(ChapterActivity activity) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getActivityStatusColor(activity.status),
          child: Icon(
            _getActivityTypeIcon(activity.type),
            color: Colors.white,
          ),
        ),
        title: Text(
          activity.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_chapterService.getActivityDescription(activity.type)),
            Text('Date: ${_formatDate(activity.scheduledAt)}'),
            Text('Status: ${activity.status.name.toUpperCase()}'),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () => _navigateToActivityDetails(activity),
      ),
    );
  }

  Widget _buildTaskCard(ChapterTask task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getTaskPriorityColor(task.priority),
          child: Text(
            task.priority.toString(),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          task.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text('Due: ${_formatDate(task.dueDate)}'),
            Text('Status: ${task.status.name.toUpperCase()}'),
          ],
        ),
        trailing: task.status == ActivityStatus.completed
            ? const Icon(Icons.check_circle, color: Colors.green)
            : IconButton(
                icon: const Icon(Icons.check),
                onPressed: () => _completeTask(task),
              ),
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    if (_tabController.index == 1) {
      // Browse tab - Create chapter
      return FloatingActionButton(
        onPressed: _createChapter,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add),
      );
    }
    return null;
  }

  // Helper methods
  Color _getRoleColor(MemberRole role) {
    switch (role) {
      case MemberRole.coordinator:
        return Colors.red;
      case MemberRole.director:
        return Colors.purple;
      case MemberRole.bod:
        return Colors.blue;
      case MemberRole.trustee:
        return Colors.green;
      case MemberRole.member:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(MemberRole role) {
    switch (role) {
      case MemberRole.coordinator:
        return Icons.admin_panel_settings;
      case MemberRole.director:
        return Icons.business;
      case MemberRole.bod:
        return Icons.corporate_fare;
      case MemberRole.trustee:
        return Icons.verified_user;
      case MemberRole.member:
        return Icons.person;
    }
  }

  Color _getActivityStatusColor(ActivityStatus status) {
    switch (status) {
      case ActivityStatus.planned:
        return Colors.blue;
      case ActivityStatus.ongoing:
        return Colors.orange;
      case ActivityStatus.completed:
        return Colors.green;
      case ActivityStatus.cancelled:
        return Colors.red;
    }
  }

  IconData _getActivityTypeIcon(ActivityType type) {
    switch (type) {
      case ActivityType.evangelism:
        return Icons.campaign;
      case ActivityType.outreach:
        return Icons.volunteer_activism;
      case ActivityType.training:
        return Icons.school;
      case ActivityType.meeting:
        return Icons.meeting_room;
      case ActivityType.conference:
        return Icons.event_seat;
      case ActivityType.workshop:
        return Icons.build;
      case ActivityType.service:
        return Icons.handshake;
      case ActivityType.other:
        return Icons.more_horiz;
    }
  }

  Color _getTaskPriorityColor(int priority) {
    if (priority >= 8) return Colors.red;
    if (priority >= 5) return Colors.orange;
    return Colors.blue;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Navigation methods
  void _navigateToChapterDetails(Chapter? chapter, {String? chapterId}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chapter Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (chapter != null) ...[
                Text('Name: ${chapter.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Type: ${_chapterService.getTypeDescription(chapter.type)}'),
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
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening chapter management...')),
              );
            },
            child: const Text('Manage'),
          ),
        ],
      ),
    );
  }

  void _navigateToActivityDetails(ChapterActivity activity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Activity Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Title: ${activity.title}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Managing activity: ${activity.title}')),
              );
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  // Action methods
  void _createChapter() {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final leaderController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Chapter'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Chapter Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: leaderController,
                decoration: const InputDecoration(
                  labelText: 'Chapter Leader',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              nameController.dispose();
              locationController.dispose();
              leaderController.dispose();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && 
                  locationController.text.isNotEmpty && 
                  leaderController.text.isNotEmpty) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Creating chapter: ${nameController.text}'),
                  ),
                );
                nameController.dispose();
                locationController.dispose();
                leaderController.dispose();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all fields'),
                  ),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeTask(ChapterTask task) async {
    try {
      await _chapterService.completeTask(task.id);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task completed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing task: $e')),
        );
      }
    }
  }
}
