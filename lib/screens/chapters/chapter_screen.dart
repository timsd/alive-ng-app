import 'package:flutter/material.dart';
import '../../widgets/modern_dropdown.dart';
import '../../utils/error_handler.dart';
import 'package:appwrite/appwrite.dart';
import '../../models/app_models.dart';
import '../../models/chapter_models.dart';
import '../../services/admin_notification_service.dart';
import '../../services/appwrite_profile_service.dart';
import '../../services/chapter_service.dart';
import '../../services/auth_service.dart';
import '../../utils/appwrite_id_utils.dart';
import '../../main.dart';
import '../../config/appwrite_backend_config.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/overview_stat_card.dart';
import '../../config/meeting_links_config.dart';
import '../conference/livekit_meeting_screen.dart';
import '../../providers/appwrite_auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../constants/app_constants.dart';
import 'package:go_router/go_router.dart';
import '../admin/chapter_reports_screen.dart';

class ChapterScreen extends ConsumerStatefulWidget {
  const ChapterScreen({super.key});

  @override
  ConsumerState<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends ConsumerState<ChapterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ChapterService _chapterService = ChapterService();
  final AppwriteProfileService _profileService = AppwriteProfileService();
  final AuthService _authService = AuthService.instance;

  List<Chapter> _chapters = [];
  List<ChapterMember> _userMemberships = [];
  List<ChapterActivity> _userActivities = [];
  List<ChapterTask> _userTasks = [];
  ChapterUserStatistics _userStatistics = ChapterUserStatistics.empty;
  UserProfile? _currentUserProfile;

  bool _isLoading = true;
  String _searchQuery = '';
  WorkersType? _selectedType;
  String? _currentUserId;

  bool get _isUserChapterApproved {
    if (_currentUserProfile == null) return false;
    return _currentUserProfile!.isChapterApproved;
  }

  bool get _canSubmitReport {
    final role = (_currentUserProfile?.role ?? '').toLowerCase();
    final isWorkerOrCoordRole = role.contains('coordinator') ||
        role.contains('coor') ||
        role.contains('field_worker') ||
        role.contains('campus_missionary') ||
        role.contains('amtc') ||
        role.contains('director') ||
        role == 'admin' ||
        role == 'super_admin';
    final hasCoordMembership = _userMemberships.any((m) =>
        m.role == MemberRole.coordinator ||
        m.role == MemberRole.director ||
        m.role == MemberRole.bod);
    return isWorkerOrCoordRole || hasCoordMembership;
  }

  void _openSubmitReport() {
    String? defaultChapter;
    if (_userMemberships.isNotEmpty) {
      final firstCId = _userMemberships.first.chapterId;
      final matched = _chapters.cast<Chapter?>().firstWhere(
            (c) => c?.id == firstCId,
            orElse: () => null,
          );
      defaultChapter = matched?.name ?? firstCId;
    } else if (_currentUserProfile?.localChapter != null &&
        _currentUserProfile!.localChapter!.isNotEmpty) {
      defaultChapter = _currentUserProfile!.localChapter;
    } else if (_currentUserProfile?.chapterId != null &&
        _currentUserProfile!.chapterId!.isNotEmpty) {
      defaultChapter = _currentUserProfile!.chapterId;
    }

    ChapterReportsScreen.showChapterReportSubmitDialog(
      context,
      initialChapter: defaultChapter,
    );
  }

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
        try {
          _currentUserProfile =
              await _profileService.getUserProfileModel(_currentUserId!);
        } catch (_) {}

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

    final isFrontDoorLocked = !_isLoading &&
        _currentUserId != null &&
        !_isUserChapterApproved &&
        !_canSubmitReport;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Chapters',
        showBackButton: true,
        bottom: isFrontDoorLocked
            ? null
            : TabBar(
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
          : isFrontDoorLocked
              ? _buildChapterFrontDoorGate()
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
      floatingActionButton:
          isFrontDoorLocked ? null : _buildFloatingActionButton(),
    );
  }

  Widget _buildChapterFrontDoorGate() {
    final theme = Theme.of(context);
    final profile = _currentUserProfile;
    final status = (profile?.chapterApprovalStatus ?? '').toLowerCase();
    final isRejected = status == 'rejected';
    final requestedChapter = (profile?.localChapter?.trim().isNotEmpty == true)
        ? profile!.localChapter!.trim()
        : null;
    final isPending = !isRejected &&
        (status == 'pending' ||
            (requestedChapter != null && requestedChapter.isNotEmpty));

    final IconData icon;
    final Color accentColor;
    final String title;
    final String message;

    if (isRejected) {
      icon = Icons.block_rounded;
      accentColor = theme.colorScheme.error;
      title = 'Chapter Access Declined';
      message = requestedChapter != null
          ? 'Your request to join "$requestedChapter" was not approved. You can request to join another chapter or contact an administrator.'
          : 'Your chapter membership request was declined. You can apply to a chapter below.';
    } else if (isPending) {
      icon = Icons.lock_clock_rounded;
      accentColor = Colors.amber.shade700;
      title = 'Awaiting Chapter Approval';
      message = requestedChapter != null
          ? 'Your request for "$requestedChapter" has been sent to the Admin and Chapter Coordinator. Once approved, full chapter access will unlock here.'
          : 'Your chapter membership is awaiting Admin and Chapter Coordinator approval. Once approved, full chapter access will unlock here.';
    } else {
      icon = Icons.door_front_door_outlined;
      accentColor = theme.colorScheme.primary;
      title = 'Join a Chapter to Enter';
      message =
          'Select your local chapter to request membership. Once approved by leadership, you will have full access to chapter activities, tasks, and fellowship.';
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: accentColor.withValues(alpha: 0.4)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 44, color: accentColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (requestedChapter != null) ...[
                    const SizedBox(height: 8),
                    Chip(
                      avatar: Icon(Icons.location_city_rounded,
                          size: 16, color: accentColor),
                      label: Text(requestedChapter),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: _showJoinChapterDialog,
                        icon: Icon(isPending
                            ? Icons.swap_horiz_rounded
                            : Icons.group_add_rounded),
                        label: Text(isPending
                            ? 'Change Chapter'
                            : isRejected
                                ? 'Re-apply to Chapter'
                                : 'Join a Chapter'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Refresh Status'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
    final pendingChapterName = _currentUserProfile?.localChapter;
    final isPendingApproval = _currentUserProfile != null &&
        !_currentUserProfile!.isChapterApproved &&
        pendingChapterName != null &&
        pendingChapterName.trim().isNotEmpty;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGeneralMeetingBanner(),
            if (isPendingApproval) ...[
              _buildPendingApprovalCard(pendingChapterName),
              const SizedBox(height: 16),
            ],
            _buildStatisticsCards(),
            const SizedBox(height: 24),
            _buildRecentActivities(),
            const SizedBox(height: 24),
            _buildUpcomingTasks(),
          ],
        ),
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
        'super_admin',
        'admin',
        'bod',
        'director',
        'coordinator',
        'chapter_leader',
        'moderator',
      ];
      const moderatorRoles = [
        'super_admin',
        'admin',
        'bod',
        'director',
      ];
      canStartGeneral = allowedRoles.contains(role);
      isModerator = moderatorRoles.contains(role);
    }

    if (!canStartGeneral) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: theme.colorScheme.primaryContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFFF0C969).withValues(alpha: 0.2)
                      : theme.colorScheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.video_call_rounded,
                  color: isDark
                      ? const Color(0xFFF0C969)
                      : theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'General Meeting',
                  style: theme.textTheme.titleMedium?.copyWith(
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
    return OverviewStatCard(
      title: title,
      value: value,
      icon: icon,
      color: color,
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
                child: ModernDropdownFormField<WorkersType?>(
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

  Widget _buildSubmitReportShortcutBanner() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.assessment_rounded,
                  color: colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Coordinator & Mission Reports',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Submit your monthly activity, missionary outreach, or chapter progress report directly.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: _openSubmitReport,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Submit Report'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyChaptersTab() {
    final pendingChapterName = _currentUserProfile?.localChapter;
    final isPendingApproval = _currentUserProfile != null &&
        !_currentUserProfile!.isChapterApproved &&
        pendingChapterName != null &&
        pendingChapterName.trim().isNotEmpty;

    if (_userMemberships.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_canSubmitReport) ...[
            _buildSubmitReportShortcutBanner(),
            const SizedBox(height: 16),
          ],
          if (isPendingApproval)
            _buildPendingApprovalCard(pendingChapterName)
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('You are not a member of any chapters'),
              ),
            ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_canSubmitReport) ...[
          _buildSubmitReportShortcutBanner(),
          const SizedBox(height: 16),
        ],
        if (isPendingApproval) ...[
          _buildPendingApprovalCard(pendingChapterName),
          const SizedBox(height: 12),
        ],
        ..._userMemberships.map((membership) {
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
        }),
      ],
    );
  }

  Widget _buildPendingApprovalCard(String chapterName) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.amber.shade300, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.amber.withValues(alpha: 0.16),
                  child: Icon(
                    Icons.hourglass_top_rounded,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFE7D39B)
                        : Colors.amber.shade900,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapterName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Awaiting Leadership Approval',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFE7D39B)
                              : Colors.amber.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Text(
                    'Pending',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Your membership request has been submitted to the chapter coordinator and admin team. Once approved, all chapter activities, tasks, team communications, and local mission schedules will be accessible.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
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
    if (_currentUserId != null && !_isUserChapterApproved) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_clock_rounded, size: 54, color: Colors.amber.shade700),
              const SizedBox(height: 14),
              const Text(
                'Chapter Activities Awaiting Approval',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Your chapter assignment is currently awaiting leadership approval. Once approved, local fellowship activities, outreach schedules, and meetings will be accessible here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (_canSubmitReport)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _showCreateActivityDialog,
                icon: const Icon(Icons.event_available_rounded),
                label: const Text('Create Chapter Activity'),
              ),
            ),
          ),
        Expanded(
          child: _userActivities.isEmpty
              ? const Center(child: Text('No activities found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _userActivities.length,
                  itemBuilder: (context, index) {
                    return _buildActivityCard(_userActivities[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTasksTab() {
    if (_currentUserId != null && !_isUserChapterApproved) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.task_alt_rounded, size: 54, color: Colors.amber.shade700),
              const SizedBox(height: 14),
              const Text(
                'Chapter Tasks Awaiting Approval',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Team tasks and assignments will appear here once your chapter membership is confirmed and approved by leadership.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (_canSubmitReport)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _showAssignTaskDialog,
                icon: const Icon(Icons.add_task_rounded),
                label: const Text('Assign Task to Chapter Member'),
              ),
            ),
          ),
        Expanded(
          child: _userTasks.isEmpty
              ? const Center(child: Text('No tasks found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _userTasks.length,
                  itemBuilder: (context, index) {
                    return _buildTaskCard(_userTasks[index]);
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _showCreateActivityDialog() async {
    if (_chapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No chapters available yet.')),
      );
      return;
    }
    String selectedChapterId = _userMemberships.isNotEmpty
        ? _userMemberships.first.chapterId
        : _chapters.first.id;
    if (!_chapters.any((c) => c.id == selectedChapterId)) {
      selectedChapterId = _chapters.first.id;
    }
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final locationController = TextEditingController();
    ActivityType selectedType = ActivityType.evangelism;
    DateTime scheduledAt = DateTime.now().add(const Duration(days: 2));
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Text('Create Chapter Activity'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ModernDropdownFormField<String>(
                    value: selectedChapterId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Chapter *',
                      border: OutlineInputBorder(),
                    ),
                    items: _chapters
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedChapterId = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  ModernDropdownFormField<ActivityType>(
                    value: selectedType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Activity Type',
                      border: OutlineInputBorder(),
                    ),
                    items: ActivityType.values
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t.name.toUpperCase()),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Activity Title *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_rounded),
                    title: const Text('Scheduled Date'),
                    subtitle: Text(DateFormat.yMMMd().format(scheduledAt)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogCtx,
                        initialDate: scheduledAt,
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() => scheduledAt = picked);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (titleController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Title is required')),
                        );
                        return;
                      }
                      setDialogState(() => isSaving = true);
                      try {
                        final now = DateTime.now();
                        await _chapterService.createActivity(
                          ChapterActivity(
                            id: AppwriteIdUtils.uniqueId(),
                            chapterId: selectedChapterId,
                            title: titleController.text.trim(),
                            description: descController.text.trim(),
                            type: selectedType,
                            status: ActivityStatus.planned,
                            scheduledAt: scheduledAt,
                            location: locationController.text.trim().isEmpty
                                ? null
                                : locationController.text.trim(),
                            assignedMemberIds: const [],
                            resources: const {},
                            results: const {},
                            createdBy: _currentUserId ?? 'coordinator',
                            createdAt: now,
                            updatedAt: now,
                          ),
                        );
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        await _loadData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Chapter activity created!'),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed: ${ErrorHandler.getUserFriendlyMessage(e)}',
                              ),
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAssignTaskDialog() async {
    if (_chapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No chapters available yet.')),
      );
      return;
    }
    String selectedChapterId = _userMemberships.isNotEmpty
        ? _userMemberships.first.chapterId
        : _chapters.first.id;
    if (!_chapters.any((c) => c.id == selectedChapterId)) {
      selectedChapterId = _chapters.first.id;
    }
    List<ChapterMember> members =
        await _chapterService.getChapterMembers(selectedChapterId);
    if (!mounted) return;

    String selectedAssignee =
        members.isNotEmpty ? members.first.userId : (_currentUserId ?? 'all');
    final titleController = TextEditingController();
    final descController = TextEditingController();
    int priority = 3;
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Text('Assign Task to Member'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ModernDropdownFormField<String>(
                    value: selectedChapterId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Chapter *',
                      border: OutlineInputBorder(),
                    ),
                    items: _chapters
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (val) async {
                      if (val != null) {
                        final updatedMembers =
                            await _chapterService.getChapterMembers(val);
                        setDialogState(() {
                          selectedChapterId = val;
                          members = updatedMembers;
                          selectedAssignee = members.isNotEmpty
                              ? members.first.userId
                              : (_currentUserId ?? 'all');
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  ModernDropdownFormField<String>(
                    value: selectedAssignee,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Assign To *',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      ...members.map((m) => DropdownMenuItem(
                            value: m.userId,
                            child: Text(
                              'Member (${m.role.name}) — ${m.userId.substring(0, m.userId.length > 8 ? 8 : m.userId.length)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                      if (members.isEmpty)
                        DropdownMenuItem(
                          value: _currentUserId ?? 'all',
                          child: const Text('Myself / Chapter Team'),
                        ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedAssignee = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Task Title *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Instructions / Details',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ModernDropdownFormField<int>(
                    value: priority,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Priority',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Low (1)')),
                      DropdownMenuItem(value: 3, child: Text('Medium (3)')),
                      DropdownMenuItem(value: 5, child: Text('High (5)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => priority = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_rounded),
                    title: const Text('Due Date'),
                    subtitle: Text(DateFormat.yMMMd().format(dueDate)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogCtx,
                        initialDate: dueDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() => dueDate = picked);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (titleController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Task title is required')),
                        );
                        return;
                      }
                      setDialogState(() => isSaving = true);
                      try {
                        final now = DateTime.now();
                        await _chapterService.createTask(
                          ChapterTask(
                            id: AppwriteIdUtils.uniqueId(),
                            chapterId: selectedChapterId,
                            title: titleController.text.trim(),
                            description: descController.text.trim(),
                            assignedTo: selectedAssignee,
                            assignedBy: _currentUserId ?? 'coordinator',
                            dueDate: dueDate,
                            status: ActivityStatus.planned,
                            priority: priority,
                            tags: const [],
                            metadata: const {},
                            createdAt: now,
                            updatedAt: now,
                          ),
                        );
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        await _loadData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Task assigned!')),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed: ${ErrorHandler.getUserFriendlyMessage(e)}',
                              ),
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Assign Task'),
            ),
          ],
        ),
      ),
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
                Text('Chapter: $displayName'),
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
                : (_currentUserProfile != null &&
                        !_currentUserProfile!.isChapterApproved &&
                        (_currentUserProfile!.localChapter?.toLowerCase() ==
                                targetChapter.name.toLowerCase() ||
                            _currentUserProfile!.chapterId == targetChapter.id))
                    ? Chip(
                        avatar: Icon(
                          Icons.hourglass_top_rounded,
                          size: 16,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFE7D39B)
                              : Colors.amber.shade900,
                        ),
                        label: Text(
                          'Pending Approval',
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFE7D39B)
                                : Colors.amber.shade900,
                          ),
                        ),
                        backgroundColor: Colors.amber.withValues(alpha: 0.14),
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
            'approval_status': 'pending',
          },
        );
      } catch (e) {
        debugPrint('Profile update note: $e');
      }

      // Notify Admin & Chapter Coordinator of the join request (best-effort)
      try {
        final user = _authService.currentUser;
        await AdminNotificationService.instance.notifyAdminOfChapterJoinRequest(
          userId: _currentUserId!,
          userName: _currentUserProfile?.fullName ?? user?.name ?? 'Member',
          userEmail: _currentUserProfile?.email ?? user?.email ?? '',
          chapterName: targetChapter.name,
          source: 'chapter_join',
        );
      } catch (_) {}

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
            content: Text('Failed to join chapter: ${ErrorHandler.getUserFriendlyMessage(e)}'),
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
          SnackBar(content: Text('Error: ${ErrorHandler.getUserFriendlyMessage(e)}')),
        );
      }
    }
  }
}

