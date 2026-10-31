import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../../models/chapter_models.dart';
import '../../services/chapter_service.dart';
import '../../services/auth_service.dart';
import '../../main.dart';
import '../../config/appwrite_backend_config.dart';
import '../../widgets/custom_app_bar.dart';
import '../../config/meeting_links_config.dart';
import '../conference/livekit_meeting_screen.dart';
import '../../providers/appwrite_auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../constants/app_constants.dart';
import 'package:go_router/go_router.dart';

class ChapterScreen extends ConsumerStatefulWidget {
  const ChapterScreen({super.key});

  @override
  ConsumerState<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends ConsumerState<ChapterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ChapterService _chapterService = ChapterService();
  final AuthService _authService = AuthService.instance;

  List<Chapter> _chapters = [];
  List<ChapterMember> _userMemberships = [];
  List<ChapterActivity> _userActivities = [];
  List<ChapterTask> _userTasks = [];
  ChapterUserStatistics _userStatistics = ChapterUserStatistics.empty;

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

      // Always load public chapters so guests and unauthenticated users can explore
      final chapters = await _chapterService.getChapters(
        type: _selectedType,
        isActive: true,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      );

      List<ChapterMember> memberships = [];
      List<ChapterActivity> activities = [];
      List<ChapterTask> tasks = [];
      var statistics = ChapterUserStatistics.empty;

      if (_currentUserId != null) {
        final results = await Future.wait([
          _chapterService.getUserMemberships(_currentUserId!),
          _chapterService.getUserActivities(_currentUserId!),
          _chapterService.getUserTasks(_currentUserId!),
          _chapterService.getUserChapterStatistics(_currentUserId!),
        ]);
        memberships = results[0] as List<ChapterMember>;
        activities = results[1] as List<ChapterActivity>;
        tasks = results[2] as List<ChapterTask>;
        statistics = results[3] as ChapterUserStatistics;

        // Ensure every chapter in user's memberships is resolved by name
        for (final m in memberships) {
          if (!chapters.any((c) => c.id == m.chapterId)) {
            try {
              final chapterDoc =
                  await _chapterService.getChapterById(m.chapterId);
              if (chapterDoc != null) {
                chapters.add(chapterDoc);
              }
            } catch (_) {}
          }
        }
      }

      setState(() {
        _chapters = chapters;
        _userMemberships = memberships;
        _userActivities = activities;
        _userTasks = tasks;
        _userStatistics = statistics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load chapter data right now.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for auth state changes and auto-reload
    ref.listen(appwriteUserStreamProvider, (previous, next) {
      final oldId = previous?.value?.uid;
      final newId = next.value?.uid;
      if (oldId != newId) {
        _loadData();
      }
    });

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Chapters',
        showBackButton: true,
        bottom: TabBar(
          controller: _tabController,
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
                _currentUserId == null
                    ? _buildSignedOutState(
                        customMessage:
                            'Sign in to view your chapter memberships, leadership roles, and connect with your team.',
                      )
                    : _buildMyChaptersTab(),
                _currentUserId == null
                    ? _buildSignedOutState(
                        customMessage:
                            'Sign in to view and register for chapter events and mission outreach activities.',
                      )
                    : _buildActivitiesTab(),
                _currentUserId == null
                    ? _buildSignedOutState(
                        customMessage:
                            'Sign in to view, update, and manage your assigned chapter tasks and responsibilities.',
                      )
                    : _buildTasksTab(),
              ],
            ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildSignedOutState({String? customMessage}) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.groups_rounded,
                      size: 52, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Sign in to access',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    customMessage ??
                        'Chapter activities, reports, and tasks are available after sign-in so we can load your membership and assignments correctly.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.go(AppConstants.authRoute),
                    icon: const Icon(Icons.login),
                    label: const Text('Sign In'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
                      builder: (context) => LiveKitMeetingScreen(
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: constraints.maxWidth > 600 ? 1.8 : 1.4,
            children: [
              _buildStatCard(
                'Chapters',
                '${_userStatistics.totalChapters}',
                Icons.group,
                Theme.of(context).colorScheme.primary,
              ),
              _buildStatCard(
                'Activities',
                '${_userStatistics.totalActivities}',
                Icons.event,
                Theme.of(context).colorScheme.tertiary,
              ),
              _buildStatCard(
                'Tasks',
                '${_userStatistics.totalTasks}',
                Icons.task,
                Theme.of(context).colorScheme.secondary,
              ),
              _buildStatCard(
                'Completion Rate',
                '${_userStatistics.activityCompletionRate}%',
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
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
                  isExpanded: true,
                  initialValue: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Worker Type',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<WorkersType?>(
                      value: null,
                      child: Text('All Worker Types',
                          overflow: TextOverflow.ellipsis),
                    ),
                    ...WorkersType.values.map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(_chapterService.getTypeDescription(type),
                              overflow: TextOverflow.ellipsis),
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
        final chapter = _chapters.cast<Chapter?>().firstWhere(
              (c) => c?.id == membership.chapterId,
              orElse: () => null,
            );

        final chapterDisplayName = chapter != null
            ? (chapter.name.toLowerCase().contains('chapter')
                ? chapter.name
                : '${chapter.name} Chapter')
            : 'Chapter (${membership.chapterId.length > 8 ? membership.chapterId.substring(0, 8) : membership.chapterId}...)';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.groups_rounded,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            title: Text(
              chapterDisplayName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Role: ${_formatRole(membership.role)}${chapter != null ? ' • ${_chapterService.getTypeDescription(chapter.type)}' : ''}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _navigateToChapterDetails(
              chapter,
              chapterId: membership.chapterId,
            ),
          ),
        );
      },
    );
  }

  String _formatRole(MemberRole role) {
    switch (role) {
      case MemberRole.coordinator:
        return 'Coordinator';
      case MemberRole.director:
        return 'Director';
      case MemberRole.bod:
        return 'Board Member';
      case MemberRole.trustee:
        return 'Trustee';
      case MemberRole.member:
        return 'Member';
    }
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
    return FloatingActionButton.extended(
      onPressed: _showJoinChapterDialog,
      icon: const Icon(Icons.group_add_rounded),
      label: const Text('Join Chapter'),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy HH:mm').format(date);
  }

  // Navigation methods
  Future<void> _navigateToChapterDetails(Chapter? chapter,
      {String? chapterId}) async {
    Chapter? targetChapter = chapter;
    if (targetChapter == null && chapterId != null) {
      targetChapter = _chapters.cast<Chapter?>().firstWhere(
            (c) => c?.id == chapterId,
            orElse: () => null,
          );
      if (targetChapter == null) {
        try {
          targetChapter = await _chapterService.getChapterById(chapterId);
          if (targetChapter != null && mounted) {
            setState(() {
              if (!_chapters.any((c) => c.id == targetChapter!.id)) {
                _chapters.add(targetChapter!);
              }
            });
          }
        } catch (_) {}
      }
    }

    if (!mounted) return;

    final displayName = targetChapter != null
        ? (targetChapter.name.toLowerCase().contains('chapter')
            ? targetChapter.name
            : '${targetChapter.name} Chapter')
        : 'Chapter Details';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(displayName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (targetChapter != null) ...[
                _buildChapterDetailRow('Name', displayName),
                _buildChapterDetailRow('Type',
                    _chapterService.getTypeDescription(targetChapter.type)),
                _buildChapterDetailRow(
                    'Members', '${targetChapter.memberIds.length}'),
                _buildChapterDetailRow(
                    'Coordinator',
                    (targetChapter.coordinatorId != null &&
                            targetChapter.coordinatorId!.isNotEmpty)
                        ? targetChapter.coordinatorId!
                        : 'Not assigned'),
                _buildChapterDetailRow(
                    'Status', targetChapter.isActive ? 'Active' : 'Inactive'),
              ] else ...[
                Text('Chapter ID: $chapterId'),
                const SizedBox(height: 8),
                const Text(
                    'Chapter information could not be retrieved at this time.'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (targetChapter != null)
            _userMemberships
                    .any((m) => m.chapterId == targetChapter!.id && m.isActive)
                ? const Chip(
                    avatar:
                        Icon(Icons.check_circle, size: 16, color: Colors.green),
                    label: Text('Active Member'),
                  )
                : FilledButton.icon(
                    icon: const Icon(Icons.group_add_rounded, size: 18),
                    label: const Text('Join Chapter'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _handleJoinChapterFlow(targetChapter!);
                    },
                  ),
        ],
      ),
    );
  }

  Widget _buildChapterDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
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

  void _showJoinChapterDialog() {
    if (_currentUserId == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sign In Required'),
          content: const Text('Please sign in to join an ALIVE Nigeria chapter.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.go(AppConstants.authRoute);
              },
              child: const Text('Sign In'),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.group_add_rounded,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Select Chapter to Join',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: _chapters.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final chapter = _chapters[index];
                      final isCurrent = _userMemberships
                          .any((m) => m.chapterId == chapter.id && m.isActive);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.12),
                          child: Icon(Icons.location_city_rounded,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                        title: Text(chapter.name,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            '${_chapterService.getTypeDescription(chapter.type)} • ${chapter.memberIds.length} members'),
                        trailing: isCurrent
                            ? const Chip(
                                avatar: Icon(Icons.check, size: 14),
                                label: Text('Current', style: TextStyle(fontSize: 11)),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pop(ctx);
                          _handleJoinChapterFlow(chapter);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleJoinChapterFlow(Chapter targetChapter) async {
    if (_currentUserId == null) {
      context.go(AppConstants.authRoute);
      return;
    }

    // Check if already in target chapter
    final isInTarget = _userMemberships
        .any((m) => m.chapterId == targetChapter.id && m.isActive);
    if (isInTarget) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are already an active member of ${targetChapter.name}.'),
        ),
      );
      return;
    }

    // 1. One user to a chapter rule: Warn if user belongs to another chapter
    final existingMembership = _userMemberships
        .where((m) => m.isActive && m.chapterId != targetChapter.id)
        .firstOrNull;

    if (existingMembership != null) {
      final currentChapter = _chapters
          .where((c) => c.id == existingMembership.chapterId)
          .firstOrNull;
      final currentName = currentChapter?.name ?? 'your current chapter';

      final proceedTransfer = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(child: Text('Chapter Transfer Warning')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ALIVE Nigeria guidelines allow membership in only ONE chapter at a time.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'You are currently assigned to "$currentName". Joining "${targetChapter.name}" will automatically remove and transfer you from "$currentName".',
              ),
              const SizedBox(height: 12),
              const Text('Do you wish to proceed with this transfer?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm Transfer'),
            ),
          ],
        ),
      );

      if (proceedTransfer != true) return;
    }

    // 2. Location proximity check: Warn if distant from chapter physical activities
    if (!mounted) return;
    final proceedLocation = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.near_me_outlined, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(child: Text('Physical Location Notice')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${targetChapter.name} conducts physical community fellowships, evangelism, and local missions within its designated territory.',
            ),
            const SizedBox(height: 10),
            Text(
              'If your current physical location is outside this area, physical attendance may be limited, though you will participate in all virtual sessions.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please confirm that you intend to join this chapter:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Confirm & Join'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (proceedLocation != true || !mounted) return;

    // 3. Execute membership join and update profile
    setState(() => _isLoading = true);
    try {
      // Remove from existing chapter if transferring
      if (existingMembership != null) {
        await _chapterService.removeMember(existingMembership.chapterId, _currentUserId!);
      }

      // Add to target chapter
      await _chapterService.addMember(targetChapter.id, _currentUserId!, MemberRole.member);

      // Update user record with pending chapter approval
      try {
        final tables = TablesDB(appwriteClient);
        await tables.updateRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.usersCollectionId,
          rowId: _currentUserId!,
          data: {
            'local_chapter': targetChapter.name,
            'chapter_approval_status': 'pending',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        );
      } catch (e) {
        debugPrint('Profile update note: $e');
      }

      await _loadData();

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Joined Chapter!'),
              ],
            ),
            content: Text(
              'You have successfully submitted your membership for "${targetChapter.name}". Your chapter coordinator and admin will review and approve your active chapter assignment.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Got it'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join chapter: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
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

