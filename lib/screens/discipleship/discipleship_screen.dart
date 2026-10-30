import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/discipleship_models.dart';
import '../../services/discipleship_service.dart';
import '../../services/auth_service.dart';
import '../../services/role_access_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/custom_app_bar.dart';

class DiscipleshipScreen extends StatefulWidget {
  const DiscipleshipScreen({super.key});

  @override
  State<DiscipleshipScreen> createState() => _DiscipleshipScreenState();
}

class _DiscipleshipScreenState extends State<DiscipleshipScreen>
    with TickerProviderStateMixin {
  final DiscipleshipService _discipleshipService = DiscipleshipService();
  final AuthService _authService = AuthService.instance;
  late TabController _tabController;

  List<DiscipleshipContact> _contacts = [];
  List<ContactInteraction> _recentInteractions = [];
  List<StudySession> _recentStudySessions = [];
  List<PrayerRequest> _activePrayerRequests = [];
  DiscipleshipStatistics _statistics = DiscipleshipStatistics.empty;

  bool _isLoading = true;
  String _searchQuery = '';
  DiscipleshipLevel? _selectedLevel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadData();
  }

  List<DiscipleshipReport> _userReports = [];
  List<DiscipleshipReport> _officerReports = [];
  List<OfficerOfficeAssignment> _officerAssignments = [];
  OfficerOfficeAssignment? _selectedOfficerOffice;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      var user = _authService.currentUser;
      user ??= await _authService.getCurrentUser();
      if (user == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final contacts = await _discipleshipService.getContacts(
        discipleMakerId: user.uid,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        level: _selectedLevel,
      );

      final interactions = await _discipleshipService.getInteractions(
        discipleMakerId: user.uid,
        startDate: DateTime.now().subtract(const Duration(days: 30)),
      );

      final studySessions = await _discipleshipService.getStudySessions(
        discipleMakerId: user.uid,
        startDate: DateTime.now().subtract(const Duration(days: 30)),
      );

      final prayerRequests = await _discipleshipService.getPrayerRequests(
        discipleMakerId: user.uid,
        status: PrayerRequestStatus.active,
      );

      final statistics =
          await _discipleshipService.getDiscipleshipStatistics(user.uid);

      final userReports =
          await _discipleshipService.getReports(discipleMakerId: user.uid);
      final assignments = await _discipleshipService.getOfficerAssignments();
      _selectedOfficerOffice ??=
          assignments.isNotEmpty ? assignments.first : null;

      List<DiscipleshipReport> officerReports = [];
      // Only resolve an inbox for an officer/coordinator. Loading it for a
      // plain member put them on the first office by default, which is the
      // data leak the Officer Inbox tab gate now prevents.
      if (_selectedOfficerOffice != null &&
          RoleAccessService.instance.hasRole('coordinator')) {
        officerReports = await _discipleshipService.getReportsForOfficer(
          officerId: _selectedOfficerOffice!.officerId,
          officeTitle: _selectedOfficerOffice!.officeTitle,
        );
      }

      setState(() {
        _contacts = contacts;
        _recentInteractions = interactions.take(10).toList();
        _recentStudySessions = studySessions.take(10).toList();
        _activePrayerRequests = prayerRequests;
        _statistics = statistics;
        _userReports = userReports;
        _officerAssignments = assignments;
        _officerReports = officerReports;
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
      // CustomAppBar (like the other top-level screens) so the back arrow is
      // always present. The previous plain AppBar relied on
      // `automaticallyImplyLeading`, which renders nothing when this route is
      // reached by a root-level `context.go(...)` with no stack to pop.
      appBar: CustomAppBar(
        title: 'Discipleship Tracker',
        showBackButton: true,
        // This screen has its own add/refresh actions below.
        showDonationButton: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kTextTabBarHeight),
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
            labelStyle:
                Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            unselectedLabelStyle: Theme.of(context).textTheme.labelLarge,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Contacts'),
              Tab(text: 'Activities'),
              Tab(text: 'Prayer'),
              Tab(text: 'Reports'),
              Tab(text: 'Officer Inbox'),
            ],
          ),
        ),
        // The "+" moved to a floating action button. Keeping it in the app bar
        // put a permanent "add" affordance next to the title on every tab,
        // which invited adding records on tabs where it does not apply (e.g.
        // Officer Inbox, which is read/review only).
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: _buildAddFab(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _authService.currentUser == null
              ? _buildGuestState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildContactsTab(),
                    _buildActivitiesTab(),
                    _buildPrayerTab(),
                    _buildReportsTab(),
                    _buildOfficerInboxTab(),
                  ],
                ),
    );
  }

  /// Context-aware FAB. It is hidden where adding makes no sense (Reports and
  /// Officer Inbox are review-only) so a single "+" never implies an action
  /// the current tab cannot perform.
  Widget _buildAddFab() {
    // Never show a "create" affordance to a signed-out visitor.
    if (_authService.currentUser == null) return const SizedBox.shrink();
    if (_tabController.index == 4 || _tabController.index == 5) {
      return const SizedBox.shrink();
    }
    return FloatingActionButton(
      onPressed: _showAddContactDialog,
      tooltip: 'Add contact',
      child: const Icon(Icons.add),
    );
  }

  Widget _buildGuestState() {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          margin: const EdgeInsets.all(24),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.trending_up_rounded,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Discipleship Tracker',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Sign in to track your discipleship contacts, Bible study sessions, and spiritual growth milestones.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.go('/auth'),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Sign in to Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: context.responsivePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistics Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Contacts',
                  _statistics.totalContacts.toString(),
                  Icons.people,
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(
                  width: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 16.0,
                tablet: 20.0,
                desktop: 24.0,
              )),
              Expanded(
                child: _buildStatCard(
                  'Active Contacts',
                  _statistics.activeContacts.toString(),
                  Icons.person_add,
                  Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ],
          ),
          SizedBox(
              height: ResponsiveUtils.getResponsiveValue(
            context: context,
            mobile: 16.0,
            tablet: 20.0,
            desktop: 24.0,
          )),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Baptisms',
                  _statistics.totalBaptisms.toString(),
                  Icons.water_drop,
                  Theme.of(context).colorScheme.secondary,
                ),
              ),
              SizedBox(
                  width: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 16.0,
                tablet: 20.0,
                desktop: 24.0,
              )),
              Expanded(
                child: _buildStatCard(
                  'Study Sessions',
                  _statistics.totalStudySessions.toString(),
                  Icons.book,
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          SizedBox(
              height: ResponsiveUtils.getResponsiveValue(
            context: context,
            mobile: 24.0,
            tablet: 28.0,
            desktop: 32.0,
          )),

          // Level Distribution
          Card(
            child: Padding(
              padding: context.responsivePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discipleship Levels',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  SizedBox(
                      height: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 16.0,
                    tablet: 20.0,
                    desktop: 24.0,
                  )),
                  ..._buildLevelDistribution(),
                ],
              ),
            ),
          ),
          SizedBox(
              height: ResponsiveUtils.getResponsiveValue(
            context: context,
            mobile: 16.0,
            tablet: 20.0,
            desktop: 24.0,
          )),

          // Recent Activity
          Card(
            child: Padding(
              padding: context.responsivePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Activity (Last 30 Days)',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  SizedBox(
                      height: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 16.0,
                    tablet: 20.0,
                    desktop: 24.0,
                  )),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              _statistics.recentInteractions.toString(),
                              style: TextStyle(
                                  fontSize: context.responsiveFontSize(24),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue),
                            ),
                            const Text('Interactions'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              _statistics.recentStudySessions.toString(),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.tertiary,
                                  ),
                            ),
                            Text('Study Sessions',
                                style: Theme.of(context).textTheme.labelMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsTab() {
    return Column(
      children: [
        // Search and Filter
        Padding(
          padding: context.responsivePadding,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search contacts...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                    _loadData();
                  },
                ),
              ),
              SizedBox(
                  width: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 16.0,
                tablet: 20.0,
                desktop: 24.0,
              )),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<DiscipleshipLevel?>(
                    isExpanded: true,
                    isDense: true,
                    value: _selectedLevel,
                    hint: const Text('All Levels', overflow: TextOverflow.ellipsis),
                    items: [
                      const DropdownMenuItem<DiscipleshipLevel?>(
                        value: null,
                        child: Text('All Levels', overflow: TextOverflow.ellipsis),
                      ),
                      ...DiscipleshipLevel.values.map((level) => DropdownMenuItem(
                            value: level,
                            child: Text(
                              _getLevelDisplayName(level),
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedLevel = value);
                      _loadData();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        // Contacts List
        Expanded(
          child: _contacts.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No contacts found'),
                      Text('Tap + to add your first contact'),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _contacts.length,
                  itemBuilder: (context, index) {
                    final contact = _contacts[index];
                    return _buildContactCard(contact);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildActivitiesTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: AppTheme.primaryColor,
            tabs: [
              Tab(text: 'Interactions'),
              Tab(text: 'Study Sessions'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildInteractionsList(),
                _buildStudySessionsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerTab() {
    return Column(
      children: [
        Padding(
          padding: context.responsivePadding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Prayer Requests',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddPrayerRequestDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Prayer'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _activePrayerRequests.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_outline,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No active prayer requests'),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _activePrayerRequests.length,
                  itemBuilder: (context, index) {
                    final prayer = _activePrayerRequests[index];
                    return _buildPrayerRequestCard(prayer);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildReportsTab() {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.analytics_rounded, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Discipleship Reports',
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Compile and dispatch reports directly to designated Coordinators and Directors.',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _showGenerateReportDialog,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Generate & Dispatch Report'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your Submitted Reports (${_userReports.length})',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (_userReports.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(Icons.description_outlined, size: 56, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text(
                      'No reports submitted yet.',
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap "Generate & Dispatch Report" to create your first report.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._userReports.map((report) {
              final isReviewed = report.status.toLowerCase() == 'reviewed';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${DateFormat.yMMMd().format(report.reportPeriodStart)} – ${DateFormat.yMMMd().format(report.reportPeriodEnd)}',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isReviewed ? Colors.green.withValues(alpha: 0.15) : Colors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              report.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isReviewed ? Colors.green[800] : Colors.blue[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Routed To: ${report.routedOfficeTitle ?? 'Leadership Office'}${report.routedOfficerName != null ? ' (${report.routedOfficerName})' : ''}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          _buildMetricChip('Contacts', report.totalContacts.toString()),
                          _buildMetricChip('Active', report.activeContacts.toString()),
                          _buildMetricChip('Baptisms', report.baptisms.toString()),
                          _buildMetricChip('Studies', report.studySessions.toString()),
                          _buildMetricChip('Interactions', report.interactions.toString()),
                        ],
                      ),
                      if (report.highlights != null && report.highlights!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text('Highlights: ${report.highlights}', style: theme.textTheme.bodySmall),
                      ],
                      if (report.feedback != null && report.feedback!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.rate_review_rounded, size: 16, color: Colors.amber),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Feedback from ${report.feedbackOfficerName ?? 'Officer'}:',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(report.feedback!, style: theme.textTheme.bodyMedium),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildOfficerInboxTab() {
    final theme = Theme.of(context);
    final roleService = RoleAccessService.instance;

    // Officer/coordinator+ only. Previously this tab was visible to every
    // signed-in member and defaulted to the FIRST office in a device-local
    // list, so any user could read (and reply to) reports addressed to an
    // officer they were not.
    if (!roleService.hasRole('coordinator')) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'Officer inbox',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Only coordinators, directors and administrators can review '
                  'and respond to dispatched reports.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Officer Office / Inbox View',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select your designated office to review dispatched reports and send feedback.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  if (_officerAssignments.isEmpty)
                    const Text('No officer assignments found. Contact the Administrator.')
                  else
                    DropdownButtonFormField<OfficerOfficeAssignment>(
                      initialValue: _selectedOfficerOffice,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Holding Office',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      items: _officerAssignments.map((a) {
                        return DropdownMenuItem(
                          value: a,
                          child: Text('${a.officeTitle} (${a.officerName})', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) async {
                        if (val != null) {
                          setState(() => _selectedOfficerOffice = val);
                          final reports = await _discipleshipService.getReportsForOfficer(
                            officerId: val.officerId,
                            officeTitle: val.officeTitle,
                          );
                          if (mounted) {
                            setState(() => _officerReports = reports);
                          }
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Received Reports for ${_selectedOfficerOffice?.officeTitle ?? 'Office'} (${_officerReports.length})',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (_officerReports.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined, size: 56, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text(
                      'No reports dispatched to this office yet.',
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._officerReports.map((report) {
              final isReviewed = report.status.toLowerCase() == 'reviewed';
              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Period: ${DateFormat.yMMMd().format(report.reportPeriodStart)} – ${DateFormat.yMMMd().format(report.reportPeriodEnd)}',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isReviewed ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              report.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isReviewed ? Colors.green[800] : Colors.orange[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          _buildMetricChip('Total Disciples', report.totalContacts.toString()),
                          _buildMetricChip('Active', report.activeContacts.toString()),
                          _buildMetricChip('New', report.newContacts.toString()),
                          _buildMetricChip('Baptisms', report.baptisms.toString()),
                          _buildMetricChip('Studies', report.studySessions.toString()),
                          _buildMetricChip('Interactions', report.interactions.toString()),
                        ],
                      ),
                      if (report.highlights != null && report.highlights!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Highlights: ${report.highlights}', style: theme.textTheme.bodySmall),
                      ],
                      if (report.challenges != null && report.challenges!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Challenges: ${report.challenges}', style: theme.textTheme.bodySmall),
                      ],
                      if (report.goals != null && report.goals!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Goals: ${report.goals}', style: theme.textTheme.bodySmall),
                      ],
                      if (report.feedback != null && report.feedback!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            'Your Feedback: "${report.feedback}"',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _showSendFeedbackDialog(report),
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                        label: Text(report.feedback != null ? 'Update Feedback' : 'Send Feedback'),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String value) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: context.responsivePadding,
        child: Column(
          children: [
            Icon(icon, size: context.responsiveIconSize(32), color: color),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 8.0,
              tablet: 10.0,
              desktop: 12.0,
            )),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLevelDistribution() {
    final levelDistribution = _statistics.levelDistribution;

    return DiscipleshipLevel.values.map((level) {
      final count = levelDistribution[level.name] ?? 0;
      final percentage = _statistics.totalContacts > 0
          ? (count / _statistics.totalContacts * 100).round()
          : 0;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(_getLevelDisplayName(level)),
            ),
            Expanded(
              flex: 2,
              child: LinearProgressIndicator(
                value: _statistics.totalContacts > 0
                    ? count / _statistics.totalContacts
                    : 0,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation(_getLevelColor(level)),
              ),
            ),
            SizedBox(
                width: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 8.0,
              tablet: 10.0,
              desktop: 12.0,
            )),
            Text(
              '$count ($percentage%)',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildContactCard(DiscipleshipContact contact) {
    return Card(
      margin: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getResponsiveValue(
            context: context,
            mobile: 16.0,
            tablet: 20.0,
            desktop: 24.0,
          ),
          vertical: ResponsiveUtils.getResponsiveValue(
            context: context,
            mobile: 4.0,
            tablet: 6.0,
            desktop: 8.0,
          )),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getLevelColor(contact.currentLevel),
          child: Text(
            contact.firstName[0].toUpperCase(),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(contact.fullName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getLevelDisplayName(contact.currentLevel)),
            if (contact.lastContact != null)
              Text(
                'Last contact: ${DateFormat('MMM dd, yyyy').format(contact.lastContact!)}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: Text('View Details'),
            ),
            const PopupMenuItem(
              value: 'interaction',
              child: Text('Add Interaction'),
            ),
            const PopupMenuItem(
              value: 'study',
              child: Text('Add Study Session'),
            ),
            const PopupMenuItem(
              value: 'prayer',
              child: Text('Add Prayer Request'),
            ),
            const PopupMenuItem(
              value: 'level',
              child: Text('Update Level'),
            ),
            const PopupMenuItem(
              value: 'request_deletion',
              child: Text('Request Deletion', style: TextStyle(color: Colors.red)),
            ),
          ],
          onSelected: (value) => _handleContactAction(contact, value),
        ),
        onTap: () => _showContactDetails(contact),
      ),
    );
  }

  Widget _buildInteractionsList() {
    return _recentInteractions.isEmpty
        ? const Center(child: Text('No recent interactions'))
        : ListView.builder(
            itemCount: _recentInteractions.length,
            itemBuilder: (context, index) {
              final interaction = _recentInteractions[index];
              return ListTile(
                leading: Icon(_getMethodIcon(interaction.method)),
                title: Text(interaction.title),
                subtitle: Text(
                  '${DateFormat('MMM dd, yyyy').format(interaction.date)} • ${interaction.durationMinutes} min',
                ),
                trailing: Text(_getContactName(interaction.contactId)),
              );
            },
          );
  }

  Widget _buildStudySessionsList() {
    return _recentStudySessions.isEmpty
        ? const Center(child: Text('No recent study sessions'))
        : ListView.builder(
            itemCount: _recentStudySessions.length,
            itemBuilder: (context, index) {
              final session = _recentStudySessions[index];
              return ListTile(
                leading:
                    Icon(Icons.book, color: _getStudyTypeColor(session.type)),
                title: Text(session.title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${DateFormat('MMM dd, yyyy').format(session.date)} • ${session.durationMinutes} min'),
                    if (session.topic != null) Text('Topic: ${session.topic}'),
                  ],
                ),
                trailing: session.rating != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                            5,
                            (i) => Icon(
                                  i < session.rating!
                                      ? Icons.star
                                      : Icons.star_border,
                                  size: 16,
                                  color: Colors.amber,
                                )),
                      )
                    : null,
              );
            },
          );
  }

  Widget _buildPrayerRequestCard(PrayerRequest prayer) {
    final theme = Theme.of(context);
    final contact = _contacts.firstWhere(
      (c) => c.id == prayer.contactId,
      orElse: () => DiscipleshipContact(
        id: '',
        discipleMakerId: '',
        firstName: prayer.contactId.isEmpty ? 'General' : 'Disciple',
        lastName: prayer.contactId.isEmpty ? 'Prayer' : 'Contact',
        currentLevel: DiscipleshipLevel.prospect,
        firstContact: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final isAnswered = prayer.status == PrayerRequestStatus.answered;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isAnswered
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAnswered ? Icons.check_circle_rounded : Icons.favorite_rounded,
              color: isAnswered ? Colors.green : Colors.red,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  prayer.request,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: isAnswered ? TextDecoration.none : null,
                  ),
                ),
              ),
              if (isAnswered)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'ANSWERED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                'For: ${contact.fullName}',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.primary,
                ),
              ),
              Text(
                'Requested: ${DateFormat('MMM dd, yyyy').format(prayer.dateRequested)}'
                '${prayer.status != PrayerRequestStatus.active ? ' • Status: ${prayer.status.name.toUpperCase()}' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (prayer.category != null)
                Text('Category: ${prayer.category}', style: theme.textTheme.bodySmall),
              if (prayer.notes != null && prayer.notes!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Note: ${prayer.notes}',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (isAnswered && prayer.answer != null && prayer.answer!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Testimony: ${prayer.answer}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.green,
                    ),
                  ),
                ),
            ],
          ),
          trailing: PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'history',
                child: Text('View Prayer History'),
              ),
              if (!isAnswered)
                const PopupMenuItem(
                  value: 'answer',
                  child: Text('Mark as Answered'),
                ),
              const PopupMenuItem(
                value: 'update',
                child: Text('Update Status & Notes'),
              ),
            ],
            onSelected: (value) => _handlePrayerAction(prayer, value),
          ),
        ),
      ),
    );
  }

  // Helper methods
  String _getLevelDisplayName(DiscipleshipLevel level) {
    return level.name
        .split('')
        .map((c) => c == level.name[0] ? c.toUpperCase() : c)
        .join('');
  }

  Color _getLevelColor(DiscipleshipLevel level) {
    switch (level) {
      case DiscipleshipLevel.prospect:
        return Colors.grey;
      case DiscipleshipLevel.interested:
        return Colors.blue;
      case DiscipleshipLevel.studying:
        return Colors.orange;
      case DiscipleshipLevel.convinced:
        return Colors.purple;
      case DiscipleshipLevel.committed:
        return Colors.red;
      case DiscipleshipLevel.baptized:
        return Colors.green;
      case DiscipleshipLevel.disciple:
        return Colors.teal;
      case DiscipleshipLevel.leader:
        return Colors.indigo;
    }
  }

  IconData _getMethodIcon(ContactMethod method) {
    switch (method) {
      case ContactMethod.inPerson:
        return Icons.person;
      case ContactMethod.phone:
        return Icons.phone;
      case ContactMethod.video:
        return Icons.video_call;
      case ContactMethod.email:
        return Icons.email;
      case ContactMethod.text:
        return Icons.message;
      case ContactMethod.socialMedia:
        return Icons.share;
      case ContactMethod.other:
        return Icons.more_horiz;
    }
  }

  Color _getStudyTypeColor(StudyType type) {
    switch (type) {
      case StudyType.bibleStudy:
        return Colors.blue;
      case StudyType.prophecySeminar:
        return Colors.purple;
      case StudyType.healthSeminar:
        return Colors.green;
      case StudyType.evangelisticSeries:
        return Colors.red;
      case StudyType.personalStudy:
        return Colors.orange;
      case StudyType.smallGroup:
        return Colors.teal;
      case StudyType.other:
        return Colors.grey;
    }
  }

  String _getContactName(String contactId) {
    final contact = _contacts.firstWhere(
      (c) => c.id == contactId,
      orElse: () => DiscipleshipContact(
        id: '',
        discipleMakerId: '',
        firstName: 'Unknown',
        lastName: 'Contact',
        currentLevel: DiscipleshipLevel.prospect,
        firstContact: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    return contact.fullName;
  }

  void _handleContactAction(DiscipleshipContact contact, String action) {
    switch (action) {
      case 'view':
        _showContactDetails(contact);
        break;
      case 'interaction':
        _showAddInteractionDialog(contact);
        break;
      case 'study':
        _showAddStudySessionDialog(contact);
        break;
      case 'prayer':
        _showAddPrayerRequestDialog(forContact: contact);
        break;
      case 'level':
        _showUpdateLevelDialog(contact);
        break;
      case 'request_deletion':
        _showRequestDeletionDialog(contact);
        break;
    }
  }

  void _handlePrayerAction(PrayerRequest prayer, String action) {
    if (action == 'history') {
      _showPrayerHistoryDialog(prayer);
    } else if (action == 'answer') {
      _showMarkAnsweredDialog(prayer);
    } else if (action == 'update') {
      _showUpdatePrayerStatusDialog(prayer);
    }
  }

  void _showMarkAnsweredDialog(PrayerRequest prayer) {
    final testimonyController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.celebration_rounded, color: Colors.amber, size: 44),
        title: const Text('Mark Prayer Answered'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Prayer: "${prayer.request}"',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: testimonyController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Testimony / Notes on Answer (Optional)',
                  hintText: 'Share how God answered this prayer...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              final user = _authService.currentUser;
              // Captured before the await, while the State's `dialogContext` is
              // certainly still valid. The `dialogContext` named in this dialog's
              // builder shadows the State, so an `if (dialogContext.mounted)` check does not
              // prove that shadowed one is safe to use after the await.
              final navigator = Navigator.of(dialogContext);
              final messenger = ScaffoldMessenger.of(dialogContext);
              try {
                await _discipleshipService.markPrayerAnswered(
                  requestId: prayer.id,
                  testimony: testimonyController.text.trim(),
                  actorName: user?.displayName ?? 'Disciple Maker',
                );
                // The dialog may have been dismissed while the service call was
                // in flight, so guard the dialog's own dialogContext, not the State's.
                if (dialogContext.mounted) {
                  navigator.pop(dialogContext);
                }
                if (dialogContext.mounted) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Prayer marked as answered. Praise the Lord!')),
                  );
                  _loadData();
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              }
            },
            child: const Text('Confirm Answered'),
          ),
        ],
      ),
    );
  }

  void _showUpdatePrayerStatusDialog(PrayerRequest prayer) {
    var status = prayer.status;
    final notesController = TextEditingController(text: prayer.notes ?? '');
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Update Prayer Status & Notes'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Prayer: "${prayer.request}"', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DropdownButtonFormField<PrayerRequestStatus>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                  items: PrayerRequestStatus.values
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.name.toUpperCase()),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => status = val);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Progress Notes / Update',
                    hintText: 'Add ongoing notes or state updates...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final user = _authService.currentUser;
                try {
                  await _discipleshipService.updatePrayerStatusAndNotes(
                    requestId: prayer.id,
                    status: status,
                    note: notesController.text.trim(),
                    actorName: user?.displayName ?? 'Disciple Maker',
                  );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Prayer status updated.')),
                    );
                    _loadData();
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Failed: $e')));
                  }
                }
              },
              child: const Text('Save Status'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrayerHistoryDialog(PrayerRequest prayer) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Prayer History & Timeline'),
        content: SizedBox(
          width: double.maxFinite,
          child: prayer.history.isEmpty
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.history_rounded, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(
                      'Requested on ${DateFormat('MMM dd, yyyy').format(prayer.dateRequested)}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (prayer.status == PrayerRequestStatus.answered && prayer.dateAnswered != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Answered on ${DateFormat('MMM dd, yyyy').format(prayer.dateAnswered!)}',
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: prayer.history.length,
                  separatorBuilder: (dialogContext, i) => const Divider(),
                  itemBuilder: (dialogContext, i) {
                    final h = prayer.history[i];
                    final isAns = h.status == PrayerRequestStatus.answered;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        isAns ? Icons.check_circle : Icons.history,
                        color: isAns ? Colors.green : Colors.blue,
                      ),
                      title: Text(
                        '${h.action.replaceAll('_', ' ').toUpperCase()} • ${h.status.name.toUpperCase()}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (h.note != null && h.note!.isNotEmpty)
                            Text(h.note!, style: const TextStyle(fontSize: 12)),
                          Text(
                            '${DateFormat('MMM dd, yyyy HH:mm').format(h.timestamp.toLocal())}${h.actorName != null ? ' by ${h.actorName}' : ''}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showRequestDeletionDialog(DiscipleshipContact contact) async {
    final hasActivity = await _discipleshipService.checkContactHasActivity(contact.id);
    if (!mounted) return;

    if (hasActivity) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
          title: const Text('Cannot Delete Disciple'),
          content: Text(
            '${contact.fullName} has attached discipleship activities (interactions, Bible study sessions, prayers, or milestones).\n\nOnly disciples with zero attached activity can be nominated for deletion.',
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Understood'),
            ),
          ],
        ),
      );
      return;
    }

    final reasonController = TextEditingController();
    String requesterRole = 'Coordinator';
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 48),
          title: const Text('Request Disciple Deletion'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nominate ${contact.fullName} for deletion. As a Coordinator/Director, this deletion request requires final approval by an Administrator.',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: requesterRole,
                  decoration: const InputDecoration(
                    labelText: 'Your Office / Role *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Coordinator', child: Text('Coordinator')),
                    DropdownMenuItem(value: 'Director', child: Text('Director')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => requesterRole = val);
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason for deletion *',
                    hintText: 'e.g. Created duplicate entry with 0 activity',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Please enter a reason for deletion.')),
                  );
                  return;
                }
                final user = _authService.currentUser;
                try {
                  await _discipleshipService.requestContactDeletion(
                    contact: contact,
                    requesterId: user?.uid ?? '',
                    requesterName: user?.displayName ?? 'Officer',
                    requesterRole: requesterRole,
                    reason: reason,
                  );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Deletion request queued for Admin approval.')),
                    );
                    _loadData();
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Request failed: $e')));
                  }
                }
              },
              child: const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
  }

  void _showGenerateReportDialog() {
    var frequency = ReportFrequency.monthly;
    DateTime startDate = DateTime.now().subtract(const Duration(days: 30));
    DateTime endDate = DateTime.now();
    OfficerOfficeAssignment? routedOfficer =
        _officerAssignments.isNotEmpty ? _officerAssignments.first : null;
    final highlightsController = TextEditingController();
    final challengesController = TextEditingController();
    final goalsController = TextEditingController();
    final prayerRequestsController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Generate & Dispatch Report'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<ReportFrequency>(
                  initialValue: frequency,
                  decoration: const InputDecoration(labelText: 'Report Frequency', border: OutlineInputBorder()),
                  items: ReportFrequency.values
                      .map((f) => DropdownMenuItem(value: f, child: Text(f.name.toUpperCase())))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => frequency = val);
                  },
                ),
                const SizedBox(height: 14),
                if (_officerAssignments.isNotEmpty)
                  DropdownButtonFormField<OfficerOfficeAssignment>(
                    initialValue: routedOfficer,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Dispatch To Officer / Office *',
                      border: OutlineInputBorder(),
                    ),
                    items: _officerAssignments
                        .map((a) => DropdownMenuItem(
                              value: a,
                              child: Text('${a.officeTitle} (${a.officerName})', overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => routedOfficer = val);
                    },
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setDialogState(() => startDate = picked);
                        },
                        child: Text('Start: ${DateFormat.MMMd().format(startDate)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: endDate,
                            firstDate: startDate,
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setDialogState(() => endDate = picked);
                        },
                        child: Text('End: ${DateFormat.MMMd().format(endDate)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: highlightsController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Highlights / Victories', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: challengesController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Challenges / Needs', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: goalsController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Goals for Next Period', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: prayerRequestsController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Prayer Requests for Mission', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton.icon(
              icon: const Icon(Icons.send_rounded),
              label: const Text('Dispatch Report'),
              onPressed: () async {
                final user = _authService.currentUser;
                if (user == null) return;
                try {
                  await _discipleshipService.generateAndSubmitReport(
                    discipleMakerId: user.uid,
                    routedOfficerId: routedOfficer?.officerId,
                    routedOfficeTitle: routedOfficer?.officeTitle,
                    routedOfficerName: routedOfficer?.officerName,
                    startDate: startDate,
                    endDate: endDate,
                    frequency: frequency,
                    highlights: highlightsController.text.trim().isEmpty ? null : highlightsController.text.trim(),
                    challenges: challengesController.text.trim().isEmpty ? null : challengesController.text.trim(),
                    goals: goalsController.text.trim().isEmpty ? null : goalsController.text.trim(),
                    prayerRequests: prayerRequestsController.text.trim().isEmpty ? null : prayerRequestsController.text.trim(),
                  );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('Report dispatched to ${routedOfficer?.officeTitle ?? 'Office'} successfully!')),
                    );
                    _loadData();
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Failed: $e')));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSendFeedbackDialog(DiscipleshipReport report) {
    final feedbackController = TextEditingController(text: report.feedback ?? '');
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send Officer Feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report Period: ${DateFormat.yMMMd().format(report.reportPeriodStart)} – ${DateFormat.yMMMd().format(report.reportPeriodEnd)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: feedbackController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Officer Feedback & Encouragement *',
                hintText: 'Write feedback, guidance, or words of encouragement...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final text = feedbackController.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Please enter feedback.')),
                );
                return;
              }
              try {
                await _discipleshipService.submitReportFeedback(
                  reportId: report.id,
                  feedback: text,
                  officerName: _selectedOfficerOffice?.officerName ?? 'Officer',
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Feedback sent to disciple maker!')),
                  );
                  _loadData();
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              }
            },
            child: const Text('Send Feedback'),
          ),
        ],
      ),
    );
  }

  void _showAddContactDialog() {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    var level = DiscipleshipLevel.prospect;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add Disciple'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: firstNameController, decoration: const InputDecoration(labelText: 'First Name *')),
                const SizedBox(height: 8),
                TextField(controller: lastNameController, decoration: const InputDecoration(labelText: 'Last Name *')),
                const SizedBox(height: 8),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address *',
                    hintText: 'example@domain.com',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number *',
                    hintText: '+234...',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<DiscipleshipLevel>(
                  initialValue: level,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Initial Level'),
                  items: DiscipleshipLevel.values
                      .map((l) => DropdownMenuItem(value: l, child: Text(_getLevelDisplayName(l))))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => level = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final user = _authService.currentUser;
                if (user == null) return;
                final fName = firstNameController.text.trim();
                final lName = lastNameController.text.trim();
                final email = emailController.text.trim();
                final phone = phoneController.text.trim();

                if (fName.isEmpty || lName.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('First and last name are required.')),
                  );
                  return;
                }
                if (email.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Email address is mandatory.')),
                  );
                  return;
                }
                if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(email)) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid email address.')),
                  );
                  return;
                }
                if (phone.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Phone number is mandatory.')),
                  );
                  return;
                }

                try {
                  await _discipleshipService.createContact(DiscipleshipContact(
                    id: '',
                    discipleMakerId: user.uid,
                    firstName: fName,
                    lastName: lName,
                    email: email,
                    phone: phone,
                    currentLevel: level,
                    firstContact: DateTime.now(),
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ));
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _loadData();
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Could not add disciple: $e')));
                  }
                }
              },
              child: const Text('Add Disciple'),
            ),
          ],
        ),
      ),
    );
  }

  void _showContactDetails(DiscipleshipContact contact) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(contact.fullName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Level: ${_getLevelDisplayName(contact.currentLevel)}'),
            if (contact.email != null) Text('Email: ${contact.email}'),
            if (contact.phone != null) Text('Phone: ${contact.phone}'),
            Text('First contact: ${DateFormat('MMM dd, yyyy').format(contact.firstContact)}'),
            if (contact.lastContact != null) Text('Last contact: ${DateFormat('MMM dd, yyyy').format(contact.lastContact!)}'),
            if (contact.baptismDate != null) Text('Baptized: ${DateFormat('MMM dd, yyyy').format(contact.baptismDate!)}'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
      ),
    );
  }

  void _showAddInteractionDialog(DiscipleshipContact contact) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    var method = ContactMethod.inPerson;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Log interaction with ${contact.firstName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
              TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Notes')),
              DropdownButton<ContactMethod>(
                value: method, isExpanded: true,
                items: ContactMethod.values.map((m) => DropdownMenuItem(value: m, child: Text(m.name))).toList(),
                onChanged: (value) { if (value != null) setDialogState(() => method = value); },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                final user = _authService.currentUser;
                if (user == null) return;
                try {
                  await _discipleshipService.createInteraction(ContactInteraction(
                    id: '', contactId: contact.id, discipleMakerId: user.uid, method: method,
                    title: titleController.text.trim(), description: descriptionController.text.trim(),
                    date: DateTime.now(), createdAt: DateTime.now(),
                  ));
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _loadData();
                } catch (e) {
                  if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Save failed: $e')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddStudySessionDialog(DiscipleshipContact contact) {
    final titleController = TextEditingController();
    final topicController = TextEditingController();
    var type = StudyType.bibleStudy;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Study session with ${contact.firstName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
              TextField(controller: topicController, decoration: const InputDecoration(labelText: 'Topic')),
              DropdownButton<StudyType>(
                value: type, isExpanded: true,
                items: StudyType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
                onChanged: (value) { if (value != null) setDialogState(() => type = value); },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                final user = _authService.currentUser;
                if (user == null) return;
                try {
                  await _discipleshipService.createStudySession(StudySession(
                    id: '', contactId: contact.id, discipleMakerId: user.uid, type: type,
                    title: titleController.text.trim(), topic: topicController.text.trim(),
                    date: DateTime.now(), createdAt: DateTime.now(),
                  ));
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _loadData();
                } catch (e) {
                  if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Save failed: $e')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateLevelDialog(DiscipleshipContact contact) {
    var level = contact.currentLevel;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Update ${contact.firstName}\'s level'),
          content: DropdownButton<DiscipleshipLevel>(
            value: level, isExpanded: true,
            items: DiscipleshipLevel.values.map((l) => DropdownMenuItem(value: l, child: Text(_getLevelDisplayName(l)))).toList(),
            onChanged: (value) { if (value != null) setDialogState(() => level = value); },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _discipleshipService.updateContactLevel(contact.id, level);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _loadData();
                } catch (e) {
                  if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Update failed: $e')));
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPrayerRequestDialog({DiscipleshipContact? forContact}) {
    final requestController = TextEditingController();
    String? selectedContactId =
        forContact?.id ?? (_contacts.isNotEmpty ? _contacts.first.id : null);

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(forContact != null
              ? 'Prayer for ${forContact.fullName}'
              : 'Add Prayer Request'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (forContact == null) ...[
                  const Text('Select Disciple *',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  if (_contacts.isEmpty)
                    const Text(
                        'No disciples available. Please add a disciple first.',
                        style:
                            TextStyle(color: Colors.redAccent, fontSize: 12))
                  else
                    DropdownButtonFormField<String>(
                      initialValue: selectedContactId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: _contacts.map((c) {
                        return DropdownMenuItem<String>(
                          value: c.id,
                          child: Text(c.fullName),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedContactId = val);
                        }
                      },
                    ),
                  const SizedBox(height: 12),
                ],
                const Text('Prayer Request *',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: requestController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'What specific prayer need would you like to log?',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (requestController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter prayer request details')),
                  );
                  return;
                }
                if (selectedContactId == null || selectedContactId!.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Please select a disciple for this prayer')),
                  );
                  return;
                }
                final user = _authService.currentUser;
                if (user == null) return;
                try {
                  await _discipleshipService.createPrayerRequest(PrayerRequest(
                    id: '',
                    contactId: selectedContactId!,
                    discipleMakerId: user.uid,
                    request: requestController.text.trim(),
                    dateRequested: DateTime.now(),
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ));
                  if (dialogContext.mounted) Navigator.pop(dialogCtx);
                  _loadData();
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('Save failed: $e')),
                    );
                  }
                }
              },
              child: const Text('Save Prayer'),
            ),
          ],
        ),
      ),
    );
  }
}
