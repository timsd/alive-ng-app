import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:appwrite/appwrite.dart';
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
import 'components/office_holder_form_dialog.dart';

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
  List<Map<String, dynamic>> _bod = [];
  List<Map<String, dynamic>> _directors = [];
  List<UserProfile> _registeredUsers = [];

  bool _isLoading = true;
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  LeadershipPosition? _selectedPosition;
  String _tenureFilter = 'all';

  List<String> get _availableTenures {
    final tenures = <String>{'2026'};
    for (final r in _activeRecords) {
      tenures.add(r.startDate.year.toString());
    }
    for (final r in _completedRecords) {
      tenures.add(r.startDate.year.toString());
    }
    for (final r in _archivedRecords) {
      tenures.add(r.startDate.year.toString());
    }
    for (final h in [..._directors, ..._bod, ..._trustees]) {
      final start = h['term_start'] != null ? DateTime.tryParse(h['term_start'].toString()) : null;
      final y = start?.year.toString() ?? (h['tenure_year']?.toString());
      if (y != null && y.isNotEmpty) tenures.add(y);
    }
    final sorted = tenures.toList()..sort((a, b) => b.compareTo(a));
    return ['all', ...sorted];
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
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

      final activeRows = rows.where((r) {
        final isCurrent = r['is_current'] != false && r['is_current'] != 'false';
        final status = (r['status'] ?? '').toString().toLowerCase();
        return isCurrent && status != 'archived' && status != 'completed';
      }).toList();

      final trusteeRows = activeRows.where((r) {
        final officeId = (r['office_id'] ?? '').toString().toLowerCase();
        return officeId == 'trustee' || officeId == 'board_of_trustees';
      }).toList();

      final bodRows = activeRows.where((r) {
        final officeId = (r['office_id'] ?? '').toString().toLowerCase();
        return officeId == 'bod' || officeId == 'board_of_directors';
      }).toList();

      final directorRows = activeRows.where((r) {
        final officeId = (r['office_id'] ?? '').toString().toLowerCase();
        return officeId != 'trustee' &&
            officeId != 'board_of_trustees' &&
            officeId != 'bod' &&
            officeId != 'board_of_directors';
      }).toList();

      // Collect archived office holders to show in archive tab
      final archivedOfficeHolders = rows.where((r) {
        final isCurrent = r['is_current'] == false || r['is_current'] == 'false';
        final status = (r['status'] ?? '').toString().toLowerCase();
        return isCurrent || status == 'archived' || status == 'completed';
      }).map((r) {
        final start = r['term_start'] != null ? DateTime.tryParse(r['term_start'].toString()) : null;
        final end = r['term_end'] != null ? DateTime.tryParse(r['term_end'].toString()) : null;
        final offId = (r['office_id'] ?? '').toString().toLowerCase();
        final pos = offId == 'trustee' || offId == 'board_of_trustees'
            ? LeadershipPosition.trustee
            : (offId == 'bod' || offId == 'board_of_directors'
                ? LeadershipPosition.bod
                : LeadershipPosition.director);
        final sDate = start ?? DateTime(2023, 1, 1);
        final eDate = end ?? DateTime.now();
        final years = (eDate.difference(sDate).inDays / 365.25).clamp(0.0, 50.0).round();
        return LeadershipRecord(
          id: r['\$id'] ?? '',
          userId: r['user_id'] ?? '',
          userName: r['full_name'] ?? 'Member',
          userEmail: r['email'] ?? '',
          position: pos,
          positionTitle: r['office_title'] ?? 'Leader',
          startDate: sDate,
          endDate: eDate,
          yearsOfService: years,
          status: ServiceStatus.archived,
          achievements: r['description'] ?? '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }).toList();

      List<Map<String, dynamic>> dedupe(List<Map<String, dynamic>> list) {
        final seen = <String, Map<String, dynamic>>{};
        for (final item in list) {
          final name = (item['full_name'] ?? '').toString().trim().toLowerCase();
          if (name.isEmpty) continue;
          if (!seen.containsKey(name)) {
            seen[name] = Map<String, dynamic>.from(item);
          } else {
            final existing = seen[name]!;
            final curTitle = (existing['office_title'] ?? '').toString();
            final newTitle = (item['office_title'] ?? '').toString();
            if (newTitle.isNotEmpty && !curTitle.contains(newTitle)) {
              existing['office_title'] = '$curTitle • $newTitle';
            }
            if ((existing['user_id'] ?? '').toString().isEmpty &&
                (item['user_id'] ?? '').toString().isNotEmpty) {
              existing['user_id'] = item['user_id'];
              existing['email'] = item['email'];
            }
          }
        }
        return seen.values.toList();
      }

      if (mounted) {
        setState(() {
          _trustees = trusteeRows.isNotEmpty ? dedupe(trusteeRows) : _defaultTrustees();
          _bod = bodRows.isNotEmpty ? dedupe(bodRows) : _defaultBod();
          _directors = directorRows.isNotEmpty ? dedupe(directorRows) : _defaultDirectors();
          for (final arc in archivedOfficeHolders) {
            if (!_archivedRecords.any((r) => r.id == arc.id || (r.userName == arc.userName && r.positionTitle == arc.positionTitle))) {
              _archivedRecords.add(arc);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _trustees = _defaultTrustees();
          _bod = _defaultBod();
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
          'office_title': 'Chairman of Trustees',
          'full_name': 'Jerry Kwarba',
          'email': '',
          'user_id': '',
          'description': 'Overseeing organizational governance, spiritual counsel, and compliance',
          'term_start': '2026-09-01T00:00:00.000Z',
          'tenure_year': '2026',
          'status': 'active',
        },
        {
          'office_id': 'trustee',
          'office_title': 'Trustee',
          'full_name': 'Imoh Imeh',
          'email': '',
          'user_id': '',
          'description': 'Board governance, oversight, and advisory',
          'term_start': '2026-09-01T00:00:00.000Z',
          'tenure_year': '2026',
          'status': 'active',
        },
      ];

  List<Map<String, dynamic>> _defaultBod() => [
        {
          'office_id': 'bod',
          'office_title': 'Board Member (Affairs Liaison) • President',
          'full_name': 'Nwoko Patience Mfon',
          'email': 'jamespat84@gmail.com',
          'user_id': '',
          'description': 'Strategic leadership, advisory, and governance',
          'term_start': '2026-09-01T00:00:00.000Z',
          'tenure_year': '2026',
          'status': 'active',
        },
        {
          'office_id': 'bod',
          'office_title': 'Board Member (Finance Liaison) • Treasurer',
          'full_name': 'Timothy Olodude',
          'email': 'dammyolodude@gmail.com',
          'user_id': '6a875b8ec9a90f0a6a55',
          'description': 'Strategic leadership, financial oversight, and governance',
          'term_start': '2026-09-01T00:00:00.000Z',
          'tenure_year': '2026',
          'status': 'active',
        },
        {
          'office_id': 'bod',
          'office_title': 'Director (Board Member)',
          'full_name': 'Okechukwu Elechi',
          'email': 'okechukwuelechi33@gmail.com',
          'user_id': '6af371a672420765763b',
          'description': 'Strategic leadership, advisory, and governance',
          'term_start': '2026-09-01T00:00:00.000Z',
          'tenure_year': '2026',
          'status': 'active',
        },
        {
          'office_id': 'bod',
          'office_title': 'Director (Board Member)',
          'full_name': 'Imoh Imeh',
          'email': '',
          'user_id': '',
          'description': 'Strategic leadership, advisory, and governance',
          'term_start': '2026-09-01T00:00:00.000Z',
          'tenure_year': '2026',
          'status': 'active',
        },
        {
          'office_id': 'bod',
          'office_title': 'Director (Board Member)',
          'full_name': 'Ajibade Ayodeji',
          'email': '',
          'user_id': '',
          'description': 'Strategic leadership, advisory, and governance',
          'term_start': '2026-09-01T00:00:00.000Z',
          'tenure_year': '2026',
          'status': 'active',
        },
        {
          'office_id': 'bod',
          'office_title': 'Director (Board Member)',
          'full_name': 'Fatola Samson',
          'email': '',
          'user_id': '',
          'description': 'Strategic leadership, advisory, and governance',
          'term_start': '2026-09-01T00:00:00.000Z',
          'tenure_year': '2026',
          'status': 'active',
        },
        {
          'office_id': 'bod',
          'office_title': 'Director (Board Member)',
          'full_name': 'Bassey Etido',
          'email': '',
          'user_id': '',
          'description': 'Strategic leadership, advisory, and governance',
          'term_start': '2026-09-01T00:00:00.000Z',
          'tenure_year': '2026',
          'status': 'active',
        },
        {
          'office_id': 'bod',
          'office_title': 'Director (Board Member)',
          'full_name': 'Joshua Umahi',
          'email': '',
          'user_id': '',
          'description': 'Strategic leadership, advisory, and governance',
          'term_start': '2026-09-01T00:00:00.000Z',
          'tenure_year': '2026',
          'status': 'active',
        },
        {
          'office_id': 'bod',
          'office_title': 'Director (Board Member)',
          'full_name': 'Frank A',
          'email': '',
          'user_id': '',
          'description': 'Strategic leadership, advisory, and governance',
          'term_start': '2026-09-01T00:00:00.000Z',
          'tenure_year': '2026',
          'status': 'active',
        },
        {
          'office_id': 'bod',
          'office_title': 'Director (Board Member)',
          'full_name': 'Emeka Okoro',
          'email': '',
          'user_id': '',
          'description': 'Strategic leadership, advisory, and governance',
          'term_start': '2026-09-01T00:00:00.000Z',
          'tenure_year': '2026',
          'status': 'active',
        },
        {
          'office_id': 'bod',
          'office_title': 'Director (Board Member)',
          'full_name': 'Nancy Elechi',
          'email': '',
          'user_id': '',
          'description': 'Strategic leadership, advisory, and governance',
          'term_start': '2026-09-01T00:00:00.000Z',
          'tenure_year': '2026',
          'status': 'active',
        },
      ];

  List<Map<String, dynamic>> _defaultDirectors() => [
        {
          'office_id': 'executive_president',
          'office_title': 'Executive President',
          'full_name': 'Nwoko Patience Mfon',
          'email': 'jamespat84@gmail.com',
          'user_id': '',
          'description': 'Leading the strategic direction and operations of ALIVE Nigeria',
          'term_start': '2026-09-01T00:00:00.000Z',
          'tenure_year': '2026',
          'status': 'active',
        },
        {
          'office_id': 'secretary',
          'office_title': 'Secretary & Communication Director',
          'full_name': 'Caleb Peters',
          'email': 'peterscaleb50@gmail.com',
          'user_id': '6abceded858b8dff1858',
          'description': 'Secretariat, media communications, and public relations',
          'term_start': '2026-09-01T00:00:00.000Z',
          'tenure_year': '2026',
          'status': 'active',
        },
        {
          'office_id': 'speaker',
          'office_title': 'Speaker & Director, AMTC',
          'full_name': 'Godstime Esuku',
          'email': 'deovolente52@gmail.com',
          'user_id': '6ad7c8bf4cbbd6a3395a',
          'description': 'Spiritual preaching and missionary training center direction',
          'term_start': '2026-09-01T00:00:00.000Z',
          'tenure_year': '2026',
          'status': 'active',
        },
        {
          'office_id': 'treasurer',
          'office_title': 'Treasurer & Director of Logistics',
          'full_name': 'Timothy Olodude',
          'email': 'dammyolodude@gmail.com',
          'user_id': '6a875b8ec9a90f0a6a55',
          'description': 'Financial stewardship, resource deployment, and event logistics',
          'term_start': '2026-09-01T00:00:00.000Z',
          'tenure_year': '2026',
          'status': 'active',
        },
        {
          'office_id': 'director_evangelism',
          'office_title': 'Director of Evangelism, Programming & Health',
          'full_name': 'Emenike Ekechi',
          'email': 'praiseelechi@gmail.com',
          'user_id': '',
          'description': 'Evangelistic campaigns, campus missions, programming, and health ministry',
          'term_start': '2026-09-01T00:00:00.000Z',
          'tenure_year': '2026',
          'status': 'active',
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

    if (_tenureFilter != 'all') {
      filtered = filtered
          .where((record) => record.startDate.year.toString() == _tenureFilter)
          .toList();
    }

    return filtered;
  }

  String _getSmartAddLabel() {
    switch (_tabController.index) {
      case 0:
        return 'Add Director';
      case 1:
        return 'Add Board Member';
      case 2:
        return 'Add Trustee';
      case 3:
      case 4:
      case 5:
        return 'Add Record';
      default:
        return 'Add Member';
    }
  }

  void _handleSmartAdd() {
    switch (_tabController.index) {
      case 0:
        _showAddOfficeHolderDialog('director');
        break;
      case 1:
        _showAddOfficeHolderDialog('bod');
        break;
      case 2:
        _showAddOfficeHolderDialog('trustee');
        break;
      case 3:
      case 4:
      case 5:
        _showCreateRecordDialog();
        break;
      default:
        _showAddChooserDialog();
        break;
    }
  }

  void _joinLeadershipMeeting() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LiveKitMeetingScreen(
          meetingType: MeetingType.leadership,
          isModerator: true,
        ),
      ),
    );
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
                    // Leadership quick actions: compact Join button + smart contextual Add button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: _joinLeadershipMeeting,
                            icon: const Icon(Icons.video_call_rounded, size: 18),
                            label: const Text(
                              'Join',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: _handleSmartAdd,
                            icon: const Icon(Icons.person_add_rounded, size: 18),
                            label: Text(
                              _getSmartAddLabel(),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildSearchAndFilters(theme),
                    _buildTabBar(theme),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOfficeHoldersTab(_directors, 'director'),
                          _buildOfficeHoldersTab(_bod, 'bod'),
                          _buildOfficeHoldersTab(_trustees, 'trustee'),
                          _buildRecordsTab(_getFilteredRecords(_activeRecords),
                              'Active Leaders'),
                          _buildRecordsTab(
                              _getFilteredRecords(_completedRecords),
                              'Completed Service'),
                          _buildRecordsTab(
                              _getFilteredRecords(_archivedRecords),
                              'Archived Records'),
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
          // Leadership by tenure dropdown filter (Images 2 & 3)
          Row(
            children: [
              Icon(Icons.history_edu_rounded, color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Leadership by tenure',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _tenureFilter,
                    borderRadius: BorderRadius.circular(12),
                    dropdownColor: theme.colorScheme.surface,
                    items: _availableTenures
                        .map((tenure) => DropdownMenuItem(
                              value: tenure,
                              child: Text(
                                tenure == 'all' ? 'All Tenures' : tenure,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _tenureFilter = value);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

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
                  borderRadius: BorderRadius.circular(16),
                  dropdownColor: theme.colorScheme.surfaceContainerHigh,
                  menuMaxHeight: 380,
                  icon: const Icon(Icons.arrow_drop_down_rounded),
                  decoration: InputDecoration(
                    labelText: 'Position',
                    labelStyle: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  items: [
                    DropdownMenuItem<LeadershipPosition>(
                      value: null,
                      child: Text(
                        'All Positions',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    ...LeadershipPosition.values.map(
                      (position) => DropdownMenuItem(
                        value: position,
                        child: Text(
                          position.displayName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
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
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _selectedPosition = null;
                  });
                },
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                icon: const Icon(Icons.clear, size: 18),
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
                const Icon(Icons.groups_rounded, size: 18),
                const SizedBox(width: 6),
                Text('Directors (${_directors.length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.business_center_rounded, size: 18),
                const SizedBox(width: 6),
                Text('BOD (${_bod.length})'),
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
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.archive_rounded, size: 18),
                const SizedBox(width: 6),
                Text('Archive (${_archivedRecords.length})'),
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

  Widget _buildOfficeHoldersTab(List<Map<String, dynamic>> rawHolders, String category) {
    final theme = Theme.of(context);
    final query = _searchQuery.trim().toLowerCase();
    final holders = rawHolders.where((h) {
      if (query.isNotEmpty) {
        final name = (h['full_name'] ?? '').toString().toLowerCase();
        final email = (h['email'] ?? '').toString().toLowerCase();
        final title = (h['office_title'] ?? '').toString().toLowerCase();
        if (!name.contains(query) && !email.contains(query) && !title.contains(query)) {
          return false;
        }
      }
      if (_tenureFilter != 'all') {
        final start = h['term_start'] != null ? DateTime.tryParse(h['term_start'].toString()) : null;
        final year = start?.year.toString() ?? (h['tenure_year']?.toString() ?? '2026');
        if (year != _tenureFilter) return false;
      }
      return true;
    }).toList();

    final isTrustee = category == 'trustee';
    final isBod = category == 'bod';
    final label = isTrustee
        ? 'Trustees'
        : isBod
            ? 'Board of Directors'
            : 'Directors';
    final icon = isTrustee
        ? Icons.security_rounded
        : isBod
            ? Icons.business_center_rounded
            : Icons.groups_rounded;
    final addLabel = isTrustee
        ? 'Add Trustee'
        : isBod
            ? 'Add Board Member'
            : 'Add Director';

    if (holders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No $label found for selected tenure',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _showAddOfficeHolderDialog(category),
              icon: const Icon(Icons.add),
              label: Text(addLabel),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: holders.length,
      itemBuilder: (context, index) {
        final holder = holders[index];
        return _buildOfficeHolderCard(holder, category);
      },
    );
  }

  Widget _buildOfficeHolderCard(Map<String, dynamic> holder, String category) {
    final theme = Theme.of(context);
    final fullName = (holder['full_name'] ?? 'Unnamed').toString();
    final isTrustee = category == 'trustee';
    final isBod = category == 'bod';
    final defaultTitle = isTrustee
        ? 'Trustee'
        : isBod
            ? 'Director (Board Member)'
            : 'Director';
    final officeTitle = (holder['office_title'] ?? defaultTitle).toString();
    final description = (holder['description'] ?? holder['bio'] ?? '').toString();
    final email = (holder['email'] ?? '').toString();
    final userId = (holder['user_id'] ?? '').toString();
    final isLinked = userId.isNotEmpty;
    final statusStr = (holder['status'] ?? (isLinked ? 'active' : 'pending')).toString().toLowerCase();
    final isPending = statusStr == 'pending' || !isLinked;

    IconData getLeadingIcon() {
      final t = officeTitle.toLowerCase();
      if (t.contains('president')) return Icons.person_rounded;
      if (t.contains('secretary') || t.contains('communication')) return Icons.description_rounded;
      if (t.contains('speaker') || t.contains('amtc') || t.contains('school')) return Icons.school_rounded;
      if (t.contains('treasurer') || t.contains('finance') || t.contains('logistics')) return Icons.account_balance_wallet_rounded;
      if (t.contains('evangelism') || t.contains('health')) return Icons.campaign_rounded;
      if (isTrustee || t.contains('chairman') || t.contains('trustee')) return Icons.gavel_rounded;
      if (isBod || t.contains('board')) return Icons.business_center_rounded;
      return Icons.person_rounded;
    }

    String getTenureText() {
      final start = holder['term_start'] != null ? DateTime.tryParse(holder['term_start'].toString()) : null;
      final end = holder['term_end'] != null ? DateTime.tryParse(holder['term_end'].toString()) : null;
      final startYear = start?.year ?? 2026;
      final startMonth = start != null ? DateFormat('MMM yyyy').format(start) : 'Sep 2026';
      final endMonth = end != null ? DateFormat('MMM yyyy').format(end) : 'Present';
      return '$startYear ($startMonth - $endMonth)';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      color: theme.colorScheme.surface,
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
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                  child: Icon(
                    getLeadingIcon(),
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              fullName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isPending ? const Color(0xFFECE6D8) : Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isPending ? 'PENDING' : 'ACTIVE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isPending ? const Color(0xFF6B6355) : Colors.green.shade800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
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
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'Tenure: ${getTenureText()}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
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
                  onPressed: () => _showEditOfficeHolderDialog(holder, category),
                ),
                IconButton(
                  icon: const Icon(Icons.archive_outlined, size: 20, color: Colors.orange),
                  tooltip: 'Archive (Out of Tenure)',
                  onPressed: () => _confirmArchiveOfficeHolder(holder, category),
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
                  child: Icon(Icons.groups_rounded, color: Colors.white, size: 20),
                ),
                title: const Text('Add Director'),
                subtitle: const Text('Executive Directorate officer (President, Secretary, Treasurer, etc.)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddOfficeHolderDialog('director');
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.indigo,
                  child: Icon(Icons.business_center_rounded, color: Colors.white, size: 20),
                ),
                title: const Text('Add Board Member (BOD)'),
                subtitle: const Text('Board of Directors strategic governance member'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddOfficeHolderDialog('bod');
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.amber,
                  child: Icon(Icons.security_rounded, color: Colors.white, size: 20),
                ),
                title: const Text('Add Trustee'),
                subtitle: const Text('Trustees apex governance and oversight member'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddOfficeHolderDialog('trustee');
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

  void _showAddOfficeHolderDialog(String category) {
    final isTrustee = category == 'trustee';
    final isBod = category == 'bod';
    _showOfficeHolderFormDialog(
      category: category,
      title: isTrustee
          ? 'Add Trustee'
          : isBod
              ? 'Add Board Member (BOD)'
              : 'Add Director',
    );
  }

  void _showEditOfficeHolderDialog(Map<String, dynamic> holder, String category) {
    final isTrustee = category == 'trustee';
    final isBod = category == 'bod';
    _showOfficeHolderFormDialog(
      category: category,
      title: isTrustee
          ? 'Edit Trustee'
          : isBod
              ? 'Edit Board Member (BOD)'
              : 'Edit Director',
      holder: holder,
    );
  }

  void _showOfficeHolderFormDialog({
    required String category,
    required String title,
    Map<String, dynamic>? holder,
  }) {
    OfficeHolderFormDialog.show(
      context,
      holder: holder,
      category: category,
      registeredUsers: _registeredUsers,
      onSave: ({
        String? docId,
        required String fullName,
        required String officeTitle,
        required String description,
        required String tenureYear,
        required String tenureEndYear,
        required bool isCurrent,
        required String email,
        required String userId,
        required String category,
        required String officeId,
      }) async {
        await _saveOfficeHolder(
          docId: docId,
          fullName: fullName,
          officeTitle: officeTitle,
          description: description,
          tenureYear: tenureYear,
          tenureEndYear: tenureEndYear,
          isCurrent: isCurrent,
          email: email,
          userId: userId,
          category: category,
          officeId: officeId,
        );
      },
    );
  }

  Future<void> _saveOfficeHolder({
    String? docId,
    required String fullName,
    required String officeTitle,
    required String description,
    required String tenureYear,
    String? tenureEndYear,
    bool isCurrent = true,
    required String email,
    required String userId,
    required String category,
    required String officeId,
  }) async {
    try {
      final tables = TablesDB(appwriteClient);
      final isTrustee = category == 'trustee';
      final isBod = category == 'bod';
      final parsedYear = int.tryParse(tenureYear) ?? DateTime.now().year;
      final parsedEndYear = int.tryParse(tenureEndYear ?? '') ?? (parsedYear + 3);
      final termStartDate = DateTime.utc(parsedYear, 9, 1);
      final termEndDate = DateTime.utc(parsedEndYear, 8, 31);
      final payload = <String, dynamic>{
        'office_id': officeId.isNotEmpty ? officeId : (isTrustee ? 'trustee' : (isBod ? 'bod' : 'director')),
        'office_title': officeTitle.trim(),
        'description': description.trim(),
        'scope': 'national',
        'chapter_id': '',
        'user_id': userId.trim(),
        'full_name': fullName.trim(),
        'email': email.trim(),
        'supervisor_user_id': '',
        'supervisor_name': isTrustee ? 'Trustees' : (isBod ? 'Trustees' : 'Board of Directors'),
        'term_start': termStartDate.toIso8601String(),
        'term_end': termEndDate.toIso8601String(),
        'tenure_year': '$parsedYear - $parsedEndYear',
        'tenure_start_year': parsedYear.toString(),
        'tenure_end_year': parsedEndYear.toString(),
        'ended_reason': isCurrent ? '' : 'Tenure Completed',
        'is_current': isCurrent,
        'status': isCurrent ? 'active' : 'archived',
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
        final targetRole = isCurrent
            ? (isTrustee ? 'trustee' : (isBod ? 'bod' : 'director'))
            : 'member';
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
              '${isTrustee ? 'Trustee' : (isBod ? 'Board Member' : 'Director')} saved successfully',
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

  Future<void> _confirmArchiveOfficeHolder(
      Map<String, dynamic> holder, String category) async {
    final name = (holder['full_name'] ?? 'Member').toString();
    final docId = (holder['\$id'] ?? '').toString();
    final userId = (holder['user_id'] ?? '').toString();
    final officeTitle = (holder['office_title'] ?? 'Leader').toString();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.archive_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Archive (Tenure Ended)'),
          ],
        ),
        content: Text(
          'Mark tenure for "$name" ($officeTitle) as completed and move to Leadership Archive?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.archive_rounded, size: 16),
            label: const Text('Archive Member'),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (docId.isNotEmpty) {
          final tables = TablesDB(appwriteClient);
          await tables.updateRow(
            databaseId: AppwriteBackendConfig.databaseId,
            tableId: AppwriteBackendConfig.orgOfficeHoldersCollectionId,
            rowId: docId,
            data: {
              'is_current': false,
              'status': 'archived',
              'ended_reason': 'Tenure Completed',
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
          );
        }

        // Demote role to regular member so they lose elevated admin permissions when tenure ends
        if (userId.trim().isNotEmpty) {
          try {
            await AppwriteProfileService().updateUserRole(userId.trim(), 'member');
            final profile = await AppwriteProfileService().getUserProfileModel(userId.trim());
            if (profile != null) {
              await ChannelMembershipSyncService.instance.syncUserChannels(profile);
            }
          } catch (_) {}
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$name archived successfully (Tenure Ended)'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to archive: ${ErrorHandler.getUserFriendlyMessage(e)}'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
    final activeDirectors = _directors.length;
    final activeBod = _bod.length;
    final activeTrustees = _trustees.length;
    final activeOther = _activeRecords.length;
    final liveActiveLeaders = activeDirectors + activeBod + activeTrustees + activeOther;
    final liveCompleted = _completedRecords.length;
    final liveArchived = _archivedRecords.length;
    final liveTotal = liveActiveLeaders + liveCompleted + liveArchived;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Leadership Overview',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.sync_rounded),
                tooltip: 'Sync Statistics',
                onPressed: _loadData,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Primary 4 Stat Cards
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.45,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            children: [
              _buildStatCard(
                'Active Leaders',
                liveActiveLeaders.toString(),
                Icons.people_alt_rounded,
                Colors.green,
                theme,
              ),
              _buildStatCard(
                'Completed Services',
                liveCompleted.toString(),
                Icons.check_circle_rounded,
                Colors.blue,
                theme,
              ),
              _buildStatCard(
                'Archived Records',
                liveArchived.toString(),
                Icons.archive_rounded,
                Colors.orange,
                theme,
              ),
              _buildStatCard(
                'Total Roster Records',
                liveTotal.toString(),
                Icons.analytics_rounded,
                Colors.purple,
                theme,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Active Governing & Executive Breakdown
          Text(
            'Active Leadership Groups',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF1E3A5F),
                    child: Icon(Icons.groups_rounded, color: Colors.white, size: 20),
                  ),
                  title: const Text('Executive Directors', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Operational leadership & ministry department heads',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$activeDirectors Active',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF2E4057),
                    child: Icon(Icons.business_center_rounded, color: Colors.white, size: 20),
                  ),
                  title: const Text('Board of Directors (BOD)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Strategic governance & executive advisory members',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$activeBod Active',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF3B2F2F),
                    child: Icon(Icons.gavel_rounded, color: Colors.white, size: 20),
                  ),
                  title: const Text('Board of Trustees', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Custodians of organizational integrity & compliance',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$activeTrustees Active',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
                    ),
                  ),
                ),
                if (activeOther > 0) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF335C67),
                      child: Icon(Icons.share_location_rounded, color: Colors.white, size: 20),
                    ),
                    title: const Text('Chapter & Ministry Coordinators', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      'Field coordinators and operational appointment holders',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$activeOther Active',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
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
    final theme = Theme.of(context);

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
                  borderRadius: BorderRadius.circular(16),
                  dropdownColor: theme.colorScheme.surfaceContainerHigh,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
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




