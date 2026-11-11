import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart' hide Row;
import '../../config/appwrite_backend_config.dart';
import '../../services/appwrite_client.dart';
import '../../services/appwrite_profile_service.dart';
import '../../services/channel_membership_sync_service.dart';
import '../../models/app_models.dart';
import '../../utils/error_handler.dart';
import '../../models/leadership_models.dart';
import '../../services/leadership_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart';
import '../../config/meeting_links_config.dart';
import '../conference/livekit_meeting_screen.dart';

class LeadershipArchiveScreen extends StatefulWidget {
  const LeadershipArchiveScreen({super.key});

  @override
  State<LeadershipArchiveScreen> createState() =>
      _LeadershipArchiveScreenState();
}

class _LeadershipArchiveScreenState extends State<LeadershipArchiveScreen>
    with TickerProviderStateMixin {
  final LeadershipService _leadershipService = LeadershipService();
  late TabController _tabController;

  List<LeadershipRecord> _activeRecords = [];
  List<LeadershipRecord> _completedRecords = [];
  List<LeadershipRecord> _archivedRecords = [];
  Map<String, dynamic> _statistics = {};

  List<Map<String, dynamic>> _trustees = [];
  List<Map<String, dynamic>> _directors = [];
  List<UserProfile> _registeredUsers = [];

  bool _isLoading = true;
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  LeadershipPosition? _selectedPosition;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final futures = await Future.wait([
        _leadershipService.getActiveRecords(),
        _leadershipService.getAllRecords(status: ServiceStatus.completed),
        _leadershipService.getArchivedRecords(),
        _leadershipService.getLeadershipStatistics(),
        _loadOfficeHolders(),
        _loadRegisteredUsers(),
      ]);

      setState(() {
        _activeRecords = futures[0] as List<LeadershipRecord>;
        _completedRecords = futures[1] as List<LeadershipRecord>;
        _archivedRecords = futures[2] as List<LeadershipRecord>;
        _statistics = futures[3] as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = ErrorHandler.getUserFriendlyMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _loadOfficeHolders() async {
    try {
      final tables = TablesDB(appwriteClient);
      final res = await tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.orgOfficeHoldersCollectionId,
        queries: [Query.limit(100)],
      );
      final rows = res.rows.map((r) {
        final map = Map<String, dynamic>.from(r.data);
        map['\$id'] = r.$id;
        return map;
      }).toList();

      final trusteeRows = rows.where((r) {
        final officeId = (r['office_id'] ?? '').toString().toLowerCase();
        return officeId == 'trustee' || officeId == 'board_of_trustees';
      }).toList();

      final directorRows = rows.where((r) {
        final officeId = (r['office_id'] ?? '').toString().toLowerCase();
        return officeId != 'trustee' && officeId != 'board_of_trustees';
      }).toList();

      if (mounted) {
        setState(() {
          _trustees = trusteeRows.isNotEmpty ? trusteeRows : _defaultTrustees();
          _directors = directorRows.isNotEmpty ? directorRows : _defaultDirectors();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _trustees = _defaultTrustees();
          _directors = _defaultDirectors();
        });
      }
    }
  }

  Future<void> _loadRegisteredUsers() async {
    try {
      final users = await AppwriteProfileService().getAllUsers();
      if (mounted) {
        setState(() {
          _registeredUsers = users;
        });
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> _defaultTrustees() => [
        {
          'office_id': 'trustee',
          'office_title': 'Chairman, Board of Trustees',
          'full_name': 'Jerry Kwarba',
          'email': '',
          'user_id': '',
        },
        {
          'office_id': 'trustee',
          'office_title': 'Trustee',
          'full_name': 'Imoh Imeh',
          'email': '',
          'user_id': '',
        },
      ];

  List<Map<String, dynamic>> _defaultDirectors() => [
        {
          'office_id': 'executive_president',
          'office_title': 'Executive President & Chairman',
          'full_name': 'Nwoko Patience Mfon',
          'email': 'jamespat84@gmail.com',
          'user_id': '',
        },
        {
          'office_id': 'secretary',
          'office_title': 'Secretary & Communication Director',
          'full_name': 'Caleb Peters',
          'email': 'peterscaleb50@gmail.com',
          'user_id': '6abceded858b8dff1858',
        },
        {
          'office_id': 'speaker',
          'office_title': 'Speaker & Director, AMTC',
          'full_name': 'Godstime Esuku',
          'email': 'deovolente52@gmail.com',
          'user_id': '6ad7c8bf4cbbd6a3395a',
        },
        {
          'office_id': 'treasurer',
          'office_title': 'Treasurer & Director of Logistics',
          'full_name': 'Timothy Olodude',
          'email': 'dammyolodude@gmail.com',
          'user_id': '6a875b8ec9a90f0a6a55',
        },
        {
          'office_id': 'director_evangelism',
          'office_title': 'Director of Evangelism & Programming',
          'full_name': 'Emenike Ekechi',
          'email': 'praiseelechi@gmail.com',
          'user_id': '',
        },
        {
          'office_id': 'bod',
          'office_title': 'Director (BOD)',
          'full_name': 'Okechukwu Elechi',
          'email': 'okechukwuelechi33@gmail.com',
          'user_id': '6af371a672420765763b',
        },
        {
          'office_id': 'bod',
          'office_title': 'Director (BOD & Trustee)',
          'full_name': 'Imoh Imeh',
          'email': '',
          'user_id': '',
        },
        {
          'office_id': 'bod',
          'office_title': 'Director (BOD)',
          'full_name': 'Ajibade Ayodeji',
          'email': '',
          'user_id': '',
        },
        {
          'office_id': 'bod',
          'office_title': 'Director (BOD)',
          'full_name': 'Fatola Samson',
          'email': '',
          'user_id': '',
        },
        {
          'office_id': 'bod',
          'office_title': 'Director (BOD)',
          'full_name': 'Bassey Etido',
          'email': '',
          'user_id': '',
        },
        {
          'office_id': 'bod',
          'office_title': 'Director (BOD)',
          'full_name': 'Joshua Umahi',
          'email': '',
          'user_id': '',
        },
        {
          'office_id': 'bod',
          'office_title': 'Director (BOD)',
          'full_name': 'Frank A',
          'email': '',
          'user_id': '',
        },
        {
          'office_id': 'bod',
          'office_title': 'Director (BOD)',
          'full_name': 'Emeka Okoro',
          'email': '',
          'user_id': '',
        },
        {
          'office_id': 'bod',
          'office_title': 'Director (BOD)',
          'full_name': 'Nancy Elechi',
          'email': '',
          'user_id': '',
        },
      ];

  List<LeadershipRecord> _getFilteredRecords(List<LeadershipRecord> records) {
    var filtered = records;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((record) {
        return record.userName
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            record.userEmail
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            record.positionTitle
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            record.positionDisplayName
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());
      }).toList();
    }

    if (_selectedPosition != null) {
      filtered = filtered
          .where((record) => record.position == _selectedPosition)
          .toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Leadership Directory',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddChooserDialog,
            tooltip: 'Add Leadership / Board Member',
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget()
          : _error != null
              ? AppErrorWidget(
                  message: _error!,
                  onAction: _loadData,
                )
              : Column(
                  children: [
                    // Leadership quick-join banner
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Card(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Icon(Icons.video_call, color: Theme.of(context).primaryColor),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Leadership Meeting is available',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => const LiveKitMeetingScreen(
                                        meetingType: MeetingType.leadership,
                                        isModerator: true,
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
                    ),
                    _buildSearchAndFilters(theme),
                    _buildTabBar(theme),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOfficeHoldersTab(_directors, false),
                          _buildOfficeHoldersTab(_trustees, true),
                          _buildRecordsTab(_getFilteredRecords(_activeRecords),
                              'Active Leaders'),
                          _buildRecordsTab(
                              _getFilteredRecords(_completedRecords),
                              'Completed Service'),
                          _buildStatisticsTab(theme),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSearchAndFilters(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, email, or position...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Filters
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<LeadershipPosition>(
                  initialValue: _selectedPosition,
                  decoration: const InputDecoration(
                    labelText: 'Position',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<LeadershipPosition>(
                      value: null,
                      child: Text('All Positions'),
                    ),
                    ...LeadershipPosition.values.map(
                      (position) => DropdownMenuItem(
                        value: position,
                        child: Text(position.displayName),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedPosition = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _selectedPosition = null;
                  });
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surface,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: theme.colorScheme.primary,
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.business_center_rounded, size: 18),
                const SizedBox(width: 6),
                Text('Directors (${_directors.length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.security_rounded, size: 18),
                const SizedBox(width: 6),
                Text('Trustees (${_trustees.length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person, size: 18),
                const SizedBox(width: 6),
                Text('Active (${_activeRecords.length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 18),
                const SizedBox(width: 6),
                Text('Completed (${_completedRecords.length})'),
              ],
            ),
          ),
          const Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.analytics, size: 18),
                SizedBox(width: 6),
                Text('Statistics'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficeHoldersTab(List<Map<String, dynamic>> rawHolders, bool isTrustee) {
    final theme = Theme.of(context);
    final query = _searchQuery.trim().toLowerCase();
    final holders = rawHolders.where((h) {
      if (query.isEmpty) return true;
      final name = (h['full_name'] ?? '').toString().toLowerCase();
      final email = (h['email'] ?? '').toString().toLowerCase();
      final title = (h['office_title'] ?? '').toString().toLowerCase();
      return name.contains(query) || email.contains(query) || title.contains(query);
    }).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            border: Border(
              bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isTrustee ? Icons.security_rounded : Icons.business_center_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isTrustee
                      ? 'Board of Trustees (${holders.length})'
                      : 'Board of Directors (${holders.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showAddOfficeHolderDialog(isTrustee),
                icon: const Icon(Icons.add, size: 16),
                label: Text(isTrustee ? 'Add Trustee' : 'Add Director'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: holders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isTrustee ? Icons.security_rounded : Icons.business_center_rounded,
                        size: 48,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No ${isTrustee ? 'trustees' : 'directors'} found',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showAddOfficeHolderDialog(isTrustee),
                        icon: const Icon(Icons.add),
                        label: Text('Add ${isTrustee ? 'Trustee' : 'Director'}'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: holders.length,
                  itemBuilder: (context, index) {
                    final holder = holders[index];
                    return _buildOfficeHolderCard(holder, isTrustee);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildOfficeHolderCard(Map<String, dynamic> holder, bool isTrustee) {
    final theme = Theme.of(context);
    final fullName = (holder['full_name'] ?? 'Unnamed').toString();
    final officeTitle = (holder['office_title'] ?? (isTrustee ? 'Trustee' : 'Director')).toString();
    final email = (holder['email'] ?? '').toString();
    final userId = (holder['user_id'] ?? '').toString();
    final isLinked = userId.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isTrustee
                      ? Colors.amber.withValues(alpha: 0.2)
                      : theme.colorScheme.primary.withValues(alpha: 0.15),
                  child: Icon(
                    isTrustee ? Icons.shield_rounded : Icons.person_rounded,
                    color: isTrustee ? Colors.amber.shade900 : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        officeTitle,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.email_outlined,
                                size: 14,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                email,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Edit details / Link account',
                  onPressed: () => _showEditOfficeHolderDialog(holder, isTrustee),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  tooltip: 'Remove',
                  onPressed: () => _confirmDeleteOfficeHolder(holder),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isLinked
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isLinked
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.amber.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isLinked ? Icons.verified_user_rounded : Icons.pending_actions_rounded,
                    size: 14,
                    color: isLinked ? Colors.green.shade700 : Colors.amber.shade900,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isLinked ? 'Linked App Account' : 'Pending App Registration',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isLinked ? Colors.green.shade800 : Colors.amber.shade900,
                    ),
                  ),
                  if (isLinked) ...[
                    const SizedBox(width: 4),
                    Text(
                      '($userId)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddChooserDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Add to Leadership Directory',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.business_center_rounded, color: Colors.white, size: 20),
                ),
                title: const Text('Add Board Director'),
                subtitle: const Text('Executive, Directorate, or Board of Directors member'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddOfficeHolderDialog(false);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.amber,
                  child: Icon(Icons.security_rounded, color: Colors.white, size: 20),
                ),
                title: const Text('Add Board Trustee'),
                subtitle: const Text('Board of Trustees governance and oversight member'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddOfficeHolderDialog(true);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: Icon(Icons.history_edu_rounded, color: Colors.white, size: 20),
                ),
                title: const Text('Add Leadership Service Record'),
                subtitle: const Text('Track active, completed, or historical ministry tenure'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreateRecordDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddOfficeHolderDialog(bool isTrustee) {
    _showOfficeHolderFormDialog(
      isTrustee: isTrustee,
      title: isTrustee ? 'Add Board Trustee' : 'Add Board Director',
    );
  }

  void _showEditOfficeHolderDialog(Map<String, dynamic> holder, bool isTrustee) {
    _showOfficeHolderFormDialog(
      isTrustee: isTrustee,
      title: isTrustee ? 'Edit Board Trustee' : 'Edit Board Director',
      holder: holder,
    );
  }

  void _showOfficeHolderFormDialog({
    required bool isTrustee,
    required String title,
    Map<String, dynamic>? holder,
  }) {
    final nameCtrl = TextEditingController(text: holder?['full_name'] ?? '');
    final titleCtrl = TextEditingController(
      text: holder?['office_title'] ?? (isTrustee ? 'Trustee' : 'Director (BOD)'),
    );
    final emailCtrl = TextEditingController(text: holder?['email'] ?? '');
    String selectedUserId = holder?['user_id'] ?? '';
    final officeId = holder?['office_id'] ?? (isTrustee ? 'trustee' : 'bod');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Link Registered User Account',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedUserId.isNotEmpty ? selectedUserId : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      hintText: 'Select registered app member...',
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('-- Unlinked / Not yet registered --'),
                      ),
                      ..._registeredUsers.map((u) {
                        final label = '${u.fullName} (${u.email})';
                        return DropdownMenuItem<String>(
                          value: u.id,
                          child: Text(label, overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setDialogState(() {
                        selectedUserId = val ?? '';
                        if (selectedUserId.isNotEmpty) {
                          final match =
                              _registeredUsers.where((u) => u.id == selectedUserId).firstOrNull;
                          if (match != null) {
                            nameCtrl.text = match.fullName ?? '';
                            emailCtrl.text = match.email ?? '';
                          }
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Office / Role Title *',
                      border: const OutlineInputBorder(),
                      helperText: isTrustee
                          ? 'e.g. Chairman, Board of Trustees or Trustee'
                          : 'e.g. Executive President, Secretary, Director (BOD)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (selectedUserId.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Linked Account ID: $selectedUserId\nRole will be updated to ${isTrustee ? 'trustee' : 'bod'} & enrolled in leadership channels.',
                              style: const TextStyle(fontSize: 11, color: Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty || titleCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Name and title are required')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  await _saveOfficeHolder(
                    docId: holder?['\$id'],
                    fullName: nameCtrl.text.trim(),
                    officeTitle: titleCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    userId: selectedUserId,
                    isTrustee: isTrustee,
                    officeId: officeId,
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveOfficeHolder({
    String? docId,
    required String fullName,
    required String officeTitle,
    required String email,
    required String userId,
    required bool isTrustee,
    required String officeId,
  }) async {
    try {
      final tables = TablesDB(appwriteClient);
      final payload = <String, dynamic>{
        'office_id': officeId.isNotEmpty ? officeId : (isTrustee ? 'trustee' : 'bod'),
        'office_title': officeTitle.trim(),
        'scope': 'national',
        'chapter_id': '',
        'user_id': userId.trim(),
        'full_name': fullName.trim(),
        'email': email.trim(),
        'supervisor_user_id': '',
        'supervisor_name': isTrustee ? 'Board of Trustees' : 'Executive President',
        'term_start': DateTime.now().toUtc().toIso8601String(),
        'term_end': DateTime.now().add(const Duration(days: 365 * 3)).toUtc().toIso8601String(),
        'ended_reason': '',
        'is_current': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (docId != null && docId.isNotEmpty) {
        await tables.updateRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.orgOfficeHoldersCollectionId,
          rowId: docId,
          data: payload,
        );
      } else {
        payload['created_at'] = DateTime.now().toUtc().toIso8601String();
        await tables.createRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.orgOfficeHoldersCollectionId,
          rowId: ID.unique(),
          data: payload,
        );
      }

      if (userId.trim().isNotEmpty) {
        final targetRole = isTrustee ? 'trustee' : 'bod';
        try {
          await AppwriteProfileService().updateUserRole(userId.trim(), targetRole);
          final profile = await AppwriteProfileService().getUserProfileModel(userId.trim());
          if (profile != null) {
            await ChannelMembershipSyncService.instance.syncUserChannels(profile);
          }
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${isTrustee ? 'Trustee' : 'Director'} saved successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: ${ErrorHandler.getUserFriendlyMessage(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteOfficeHolder(Map<String, dynamic> holder) async {
    final name = (holder['full_name'] ?? 'Member').toString();
    final docId = (holder['\$id'] ?? '').toString();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Removal'),
        content: Text('Are you sure you want to remove "$name" from leadership?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (docId.isNotEmpty) {
          final tables = TablesDB(appwriteClient);
          await tables.deleteRow(
            databaseId: AppwriteBackendConfig.databaseId,
            tableId: AppwriteBackendConfig.orgOfficeHoldersCollectionId,
            rowId: docId,
          );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$name removed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove: ${ErrorHandler.getUserFriendlyMessage(e)}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildStatisticsTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Leadership Overview',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          // Summary cards
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.5,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildStatCard(
                'Active Leaders',
                _statistics['active_leaders']?.toString() ?? '0',
                Icons.person,
                Colors.green,
                theme,
              ),
              _buildStatCard(
                'Completed Services',
                _statistics['completed_services']?.toString() ?? '0',
                Icons.check_circle,
                Colors.blue,
                theme,
              ),
              _buildStatCard(
                'Archived Records',
                _statistics['archived_records']?.toString() ?? '0',
                Icons.archive,
                Colors.orange,
                theme,
              ),
              _buildStatCard(
                'Total Records',
                _statistics['total_records']?.toString() ?? '0',
                Icons.analytics,
                Colors.purple,
                theme,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Position breakdown
          Text(
            'Active Positions',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          if (_statistics['position_counts'] != null)
            ..._buildPositionBreakdown(_statistics['position_counts'], theme),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPositionBreakdown(
    Map<String, dynamic> positionCounts,
    ThemeData theme,
  ) {
    return positionCounts.entries.map((entry) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primary,
            child: Text(
              entry.value.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(entry.key),
          subtitle: Text('${entry.value} active leader(s)'),
        ),
      );
    }).toList();
  }

  Widget _buildRecordsTab(List<LeadershipRecord> records, String title) {
    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No records found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return _buildRecordCard(record);
      },
    );
  }

  Widget _buildRecordCard(LeadershipRecord record) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showRecordDetails(record),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.userName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          record.positionTitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _getStatusColor(record.status).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      record.statusDisplayName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _getStatusColor(record.status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Details
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow(
                          Icons.email,
                          record.userEmail,
                          theme,
                        ),
                        if (record.userPhone != null)
                          _buildDetailRow(
                            Icons.phone,
                            record.userPhone!,
                            theme,
                          ),
                        _buildDetailRow(
                          Icons.calendar_today,
                          'Started: ${_formatDate(record.startDate)}',
                          theme,
                        ),
                        if (record.endDate != null)
                          _buildDetailRow(
                            Icons.event_available,
                            'Ended: ${_formatDate(record.endDate!)}',
                            theme,
                          ),
                        _buildDetailRow(
                          Icons.access_time,
                          '${record.yearsOfService} year(s) of service',
                          theme,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Actions
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showRecordDetails(record),
                    icon: const Icon(Icons.visibility),
                    label: const Text('View Details'),
                  ),
                  if (record.isActive)
                    TextButton.icon(
                      onPressed: () => _completeService(record),
                      icon: const Icon(Icons.check),
                      label: const Text('Complete'),
                    ),
                  if (record.isCompleted)
                    TextButton.icon(
                      onPressed: () => _archiveRecord(record),
                      icon: const Icon(Icons.archive),
                      label: const Text('Archive'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ServiceStatus status) {
    switch (status) {
      case ServiceStatus.pending:
        return Colors.amber;
      case ServiceStatus.approved:
        return Colors.green;
      case ServiceStatus.active:
        return Colors.green;
      case ServiceStatus.completed:
        return Colors.blue;
      case ServiceStatus.rejected:
        return Colors.red;
      case ServiceStatus.inactive:
        return Colors.grey;
      case ServiceStatus.archived:
        return Colors.orange;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _createLeadershipRecord(
    String name,
    String position,
    String department,
    DateTime startDate,
    String status,
    String notes,
  ) async {
    try {
      final parsedStatus = switch (status.toLowerCase()) {
        'completed' => ServiceStatus.completed,
        'inactive' => ServiceStatus.inactive,
        'archived' => ServiceStatus.archived,
        _ => ServiceStatus.active,
      };
      final parsedPosition = switch (department.toLowerCase()) {
        String s when s.contains('trustee') => LeadershipPosition.trustee,
        String s when s.contains('director') => LeadershipPosition.director,
        String s when s.contains('chapter') => LeadershipPosition.chapterCoordinator,
        _ => LeadershipPosition.bod,
      };
      final record = LeadershipRecord(
        id: '',
        userId: name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_'),
        userName: name,
        userEmail: department.contains('@') ? department.trim() : 'office@alivenigeria.org',
        userPhone: null,
        position: parsedPosition,
        positionTitle: position,
        startDate: startDate,
        endDate: parsedStatus == ServiceStatus.completed ? DateTime.now() : null,
        yearsOfService: (DateTime.now().difference(startDate).inDays / 365).round(),
        status: parsedStatus,
        notes: notes,
        achievements: null,
        contactInfo: department.isNotEmpty ? {'department': department} : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: null,
        updatedBy: null,
      );

      await _leadershipService.createRecord(record);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leadership record created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating record: ${ErrorHandler.getUserFriendlyMessage(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _completeLeadershipService(
    LeadershipRecord record,
    DateTime endDate,
    String achievementsText,
    String finalNotes,
  ) async {
    try {
      final achievements = achievementsText
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      final yearsOfService = endDate.difference(record.startDate).inDays / 365;

      await _leadershipService.updateRecord(
        record.id,
        {
          'end_date': endDate.toIso8601String(),
          'status': ServiceStatus.completed.name,
          'achievements': achievements.join('\n'),
          'notes': finalNotes,
          'years_of_service': yearsOfService.round(),
          'updated_at': DateTime.now().toIso8601String(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Service completed for ${record.userName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing service: ${ErrorHandler.getUserFriendlyMessage(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _archiveLeadershipRecord(LeadershipRecord record) async {
    try {
      await _leadershipService.updateRecord(
        record.id,
        {
          'status': ServiceStatus.archived.name,
          'updated_at': DateTime.now().toIso8601String(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Record archived for ${record.userName}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error archiving record: ${ErrorHandler.getUserFriendlyMessage(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRecordDetails(LeadershipRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leadership Record Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSimpleDetailRow('Name', record.userName),
              _buildSimpleDetailRow('Position', record.positionDisplayName),
              _buildSimpleDetailRow('Title', record.positionTitle),
              _buildSimpleDetailRow('Start Date', _formatDate(record.startDate)),
              if (record.endDate != null)
                _buildSimpleDetailRow('End Date', _formatDate(record.endDate!)),
              _buildSimpleDetailRow('Status', record.statusDisplayName),
              _buildSimpleDetailRow('Years of Service', '${record.yearsOfService} years'),
              if (record.achievements != null && record.achievements!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Achievements:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 4),
                  child: Text('• ${record.achievements!}'),
                ),
              ],
              if (record.notes != null && record.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(record.notes!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showCreateRecordDialog() {
    final nameController = TextEditingController();
    final positionController = TextEditingController();
    final departmentController = TextEditingController();
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedStatus = 'Active';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Leadership Record'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: positionController,
                  decoration: const InputDecoration(
                    labelText: 'Position',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: departmentController,
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Start Date'),
                  subtitle: Text(_formatDate(selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setDialogState(() {
                        selectedDate = date;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Active', 'Inactive', 'Completed'].map((status) => 
                    DropdownMenuItem(value: status, child: Text(status))
                  ).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        selectedStatus = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty && 
                    positionController.text.isNotEmpty) {
                  await _createLeadershipRecord(
                    nameController.text,
                    positionController.text,
                    departmentController.text,
                    selectedDate,
                    selectedStatus,
                    notesController.text,
                  );
                  if (mounted && context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _completeService(LeadershipRecord record) {
    final achievementsController = TextEditingController();
    final notesController = TextEditingController(text: record.notes);
    DateTime endDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Complete Service - ${record.userName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Position: ${record.positionDisplayName}',
                     style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Start Date: ${_formatDate(record.startDate)}'),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('End Date'),
                  subtitle: Text(_formatDate(endDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: endDate,
                      firstDate: record.startDate,
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setDialogState(() {
                        endDate = date;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: achievementsController,
                  decoration: const InputDecoration(
                    labelText: 'Achievements (one per line)',
                    border: OutlineInputBorder(),
                    hintText: 'List key achievements during service...',
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Final Notes',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _completeLeadershipService(
                  record,
                  endDate,
                  achievementsController.text,
                  notesController.text,
                );
                if (mounted && context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Complete Service'),
            ),
          ],
        ),
      ),
    );
  }

  void _archiveRecord(LeadershipRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Leadership Record'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to archive the leadership record for:'),
            const SizedBox(height: 8),
            Text(record.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Position: ${record.positionDisplayName}'),
            Text('Position Title: ${record.positionTitle}'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Archived records can be restored later if needed.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _archiveLeadershipRecord(record);
              if (mounted && context.mounted) {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }
}




