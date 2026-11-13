import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/discipleship_models.dart';
import '../../services/auth_service.dart';
import '../../services/discipleship_service.dart';
import '../../services/role_access_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/error_handler.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/custom_app_bar.dart';
import 'components/discipleship_helpers.dart';
import 'components/discipleship_mentee_dialog.dart';
import 'components/discipleship_officer_inbox.dart';
import 'components/discipleship_prayer_sheet.dart';
import 'components/discipleship_report_dialog.dart';
import 'components/discipleship_stages_card.dart';

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
  List<PrayerRequest> _answeredPrayerRequests = [];
  int _selectedPrayerSubTab = 0; // 0: Active, 1: Answered
  DiscipleshipStatistics _statistics = DiscipleshipStatistics.empty;

  bool _isLoading = true;
  String _searchQuery = '';
  DiscipleshipLevel? _selectedLevel;

  List<DiscipleshipReport> _userReports = [];
  List<DiscipleshipReport> _officerReports = [];
  List<OfficerOfficeAssignment> _officerAssignments = [];
  OfficerOfficeAssignment? _selectedOfficerOffice;

  bool get _canAccessOfficerInbox {
    final roleService = RoleAccessService.instance;
    if (roleService.canAccessAdmin() ||
        roleService.hasRole('coordinator') ||
        roleService.hasRole('director') ||
        roleService.hasRole('leader') ||
        roleService.hasRole('bod')) {
      return true;
    }
    final uid = _authService.currentUser?.uid;
    if (uid != null && _officerAssignments.any((a) => a.officerId == uid)) {
      return true;
    }
    return false;
  }

  int get _tabCount => _canAccessOfficerInbox ? 6 : 5;

  void _updateTabController() {
    final count = _tabCount;
    if (_tabController.length != count) {
      final oldIndex = _tabController.index;
      _tabController.dispose();
      _tabController = TabController(
        length: count,
        vsync: this,
        initialIndex: oldIndex >= count ? count - 1 : oldIndex,
      );
      _tabController.addListener(() => setState(() {}));
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _tabController.addListener(() => setState(() {}));
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
      var user = _authService.currentUser;
      user ??= await _authService.getCurrentUser();
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final results = await Future.wait([
        _discipleshipService.getContacts(
          discipleMakerId: user.uid,
          searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
          level: _selectedLevel,
        ),
        _discipleshipService.getInteractions(
          discipleMakerId: user.uid,
          startDate: DateTime.now().subtract(const Duration(days: 30)),
        ),
        _discipleshipService.getStudySessions(
          discipleMakerId: user.uid,
          startDate: DateTime.now().subtract(const Duration(days: 30)),
        ),
        _discipleshipService.getPrayerRequests(
          discipleMakerId: user.uid,
          status: PrayerRequestStatus.active,
        ),
        _discipleshipService.getPrayerRequests(
          discipleMakerId: user.uid,
          status: PrayerRequestStatus.answered,
        ),
        _discipleshipService.getDiscipleshipStatistics(user.uid),
        _discipleshipService.getReports(discipleMakerId: user.uid),
        _discipleshipService.getOfficerAssignments(),
      ]);

      final contacts = results[0] as List<DiscipleshipContact>;
      final interactions = results[1] as List<ContactInteraction>;
      final studySessions = results[2] as List<StudySession>;
      final prayerRequests = results[3] as List<PrayerRequest>;
      final answeredPrayerRequests = results[4] as List<PrayerRequest>;
      final statistics = results[5] as DiscipleshipStatistics;
      final userReports = results[6] as List<DiscipleshipReport>;
      final assignments = results[7] as List<OfficerOfficeAssignment>;

      final userId = user.uid;
      final myOffice = assignments.where((a) => a.officerId == userId).firstOrNull;
      _selectedOfficerOffice ??= myOffice ?? (assignments.isNotEmpty ? assignments.first : null);

      List<DiscipleshipReport> officerReports = [];
      if (_selectedOfficerOffice != null && RoleAccessService.instance.hasRole('coordinator')) {
        officerReports = await _discipleshipService.getReportsForOfficer(
          officerId: _selectedOfficerOffice!.officerId,
          officeTitle: _selectedOfficerOffice!.officeTitle,
        );
      }

      if (mounted) {
        setState(() {
          _contacts = contacts;
          _recentInteractions = interactions.take(10).toList();
          _recentStudySessions = studySessions.take(10).toList();
          _activePrayerRequests = prayerRequests;
          _answeredPrayerRequests = answeredPrayerRequests;
          _statistics = statistics;
          _userReports = userReports;
          _officerAssignments = assignments;
          _officerReports = officerReports;
          _isLoading = false;
        });
        _updateTabController();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: ${ErrorHandler.getUserFriendlyMessage(e)}')),
        );
      }
    }
  }

  String _getContactName(String contactId) {
    final contact = _contacts.firstWhere(
      (c) => c.id == contactId,
      orElse: () => DiscipleshipContact(
        id: '',
        discipleMakerId: '',
        firstName: 'Unknown',
        lastName: '',
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
        showAddInteractionDialog(context, contact: contact, onSuccess: _loadData);
        break;
      case 'study':
        showAddStudySessionDialog(context, contact: contact, onSuccess: _loadData);
        break;
      case 'prayer':
        showAddPrayerRequestDialog(
          context,
          forContact: contact,
          contacts: _contacts,
          onSuccess: _loadData,
        );
        break;
      case 'level':
        showUpdateLevelDialog(context, contact: contact, onSuccess: _loadData);
        break;
      case 'request_deletion':
        showRequestDeletionDialog(context, contact: contact, onSuccess: _loadData);
        break;
    }
  }

  void _showContactDetails(DiscipleshipContact contact) {
    showContactDetailsDialog(
      context,
      contact: contact,
      recentInteractions: _recentInteractions,
      recentStudySessions: _recentStudySessions,
      activePrayerRequests: _activePrayerRequests,
      onAddInteraction: (c) => showAddInteractionDialog(context, contact: c, onSuccess: _loadData),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Discipleship Tracker',
        showBackButton: true,
        showDonationButton: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kTextTabBarHeight),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkGold
                  : AppTheme.lightPrimary,
              indicatorWeight: 3,
              labelColor: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkGold
                  : AppTheme.lightPrimary,
              unselectedLabelColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : const Color(0xFF475569),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                const Tab(text: 'Overview'),
                const Tab(text: 'Contacts'),
                const Tab(text: 'Activities'),
                const Tab(text: 'Prayer'),
                const Tab(text: 'Reports'),
                if (_canAccessOfficerInbox) const Tab(text: 'Officer Inbox'),
              ],
            ),
          ),
        ),
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
                    DiscipleshipOverviewTab(statistics: _statistics),
                    _buildContactsTab(),
                    _buildActivitiesTab(),
                    _buildPrayerTab(),
                    DiscipleshipReportsTab(
                      reports: _userReports,
                      canAccessOfficerInbox: _canAccessOfficerInbox,
                      onGenerateReport: () => showGenerateReportDialog(
                        context,
                        officerAssignments: _officerAssignments,
                        onSuccess: _loadData,
                      ),
                      onRefresh: _loadData,
                    ),
                    if (_canAccessOfficerInbox)
                      DiscipleshipOfficerInboxView(
                        officerAssignments: _officerAssignments,
                        selectedOffice: _selectedOfficerOffice,
                        reports: _officerReports,
                        onOfficeChanged: (val) async {
                          if (val != null) {
                            setState(() => _selectedOfficerOffice = val);
                            final rep = await _discipleshipService.getReportsForOfficer(
                              officerId: val.officerId,
                              officeTitle: val.officeTitle,
                            );
                            if (mounted) setState(() => _officerReports = rep);
                          }
                        },
                        onRefresh: _loadData,
                      ),
                  ],
                ),
    );
  }

  Widget _buildAddFab() {
    if (_authService.currentUser == null) return const SizedBox.shrink();
    if (_tabController.index == 4 || (_canAccessOfficerInbox && _tabController.index == 5)) {
      return const SizedBox.shrink();
    }
    return FloatingActionButton(
      onPressed: () => showAddContactDialog(context, _loadData),
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
                Icon(Icons.trending_up_rounded, size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Discipleship Tracker',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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

  Widget _buildContactsTab() {
    return Column(
      children: [
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
                ),
              ),
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
                              DiscipleshipHelpers.getLevelDisplayName(level),
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
                    return DiscipleshipContactCard(
                      contact: contact,
                      onTap: () => _showContactDetails(contact),
                      onAction: (action) => _handleContactAction(contact, action),
                    );
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
          TabBar(
            labelColor: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkGold
                : AppTheme.lightPrimary,
            unselectedLabelColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : const Color(0xFF475569),
            indicatorColor: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkGold
                : AppTheme.lightPrimary,
            tabs: const [
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

  Widget _buildInteractionsList() {
    return _recentInteractions.isEmpty
        ? const Center(child: Text('No recent interactions'))
        : ListView.builder(
            itemCount: _recentInteractions.length,
            itemBuilder: (context, index) {
              final interaction = _recentInteractions[index];
              return ListTile(
                leading: Icon(DiscipleshipHelpers.getMethodIcon(interaction.method)),
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
                leading: Icon(Icons.book, color: DiscipleshipHelpers.getStudyTypeColor(session.type)),
                title: Text(session.title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${DateFormat('MMM dd, yyyy').format(session.date)} • ${session.durationMinutes} min'),
                    if (session.topic != null) Text('Topic: ${session.topic}'),
                  ],
                ),
                trailing: session.rating != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < session.rating! ? Icons.star : Icons.star_border,
                            size: 16,
                            color: Colors.amber,
                          ),
                        ),
                      )
                    : null,
              );
            },
          );
  }

  Widget _buildPrayerTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentList = _selectedPrayerSubTab == 0
        ? _activePrayerRequests
        : _answeredPrayerRequests;

    return Column(
      children: [
        Padding(
          padding: context.responsivePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Prayer Tracker',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => showAddPrayerRequestDialog(
                      context,
                      contacts: _contacts,
                      onSuccess: _loadData,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Prayer'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Segmented Switch: Active Prayers vs Answered Testimonies
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedPrayerSubTab = 0),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedPrayerSubTab == 0
                                ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _selectedPrayerSubTab == 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    )
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.favorite_rounded,
                                size: 16,
                                color: _selectedPrayerSubTab == 0 ? Colors.red : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Active (${_activePrayerRequests.length})',
                                style: TextStyle(
                                  fontWeight: _selectedPrayerSubTab == 0 ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 13,
                                  color: _selectedPrayerSubTab == 0
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedPrayerSubTab = 1),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedPrayerSubTab == 1
                                ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _selectedPrayerSubTab == 1
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    )
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: _selectedPrayerSubTab == 1 ? Colors.green : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Answered (${_answeredPrayerRequests.length})',
                                style: TextStyle(
                                  fontWeight: _selectedPrayerSubTab == 1 ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 13,
                                  color: _selectedPrayerSubTab == 1
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: currentList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _selectedPrayerSubTab == 0 ? Icons.favorite_outline : Icons.check_circle_outline,
                        size: 64,
                        color: _selectedPrayerSubTab == 0 ? Colors.grey : Colors.green.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _selectedPrayerSubTab == 0
                            ? 'No active prayer requests'
                            : 'No answered prayers yet',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _selectedPrayerSubTab == 0
                              ? 'Tap + Add Prayer to record a prayer request for your disciples.'
                              : 'When God answers your prayers, tap "Mark as Answered" to record testimonies and celebrate breakthrough here.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: currentList.length,
                  itemBuilder: (context, index) {
                    final prayer = currentList[index];
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
                    return DiscipleshipPrayerCard(
                      prayer: prayer,
                      contact: contact,
                      onRefresh: _loadData,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
