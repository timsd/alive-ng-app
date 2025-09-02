import 'package:flutter/material.dart';
import '../../models/leadership_models.dart';
import '../../services/leadership_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/loading_widget.dart';

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

  bool _isLoading = true;
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  ServiceStatus? _selectedStatus;
  LeadershipPosition? _selectedPosition;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

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
        title: 'Leadership Archive',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateRecordDialog,
            tooltip: 'Add Leadership Record',
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget()
          : _error != null
              ? CustomErrorWidget(
                  message: _error!,
                  onRetry: _loadData,
                )
              : Column(
                  children: [
                    _buildSearchAndFilters(theme),
                    _buildTabBar(theme),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildStatisticsTab(theme),
                          _buildRecordsTab(_getFilteredRecords(_activeRecords),
                              'Active Leaders'),
                          _buildRecordsTab(
                              _getFilteredRecords(_completedRecords),
                              'Completed Service'),
                          _buildRecordsTab(
                              _getFilteredRecords(_archivedRecords),
                              'Archived Records'),
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
        tabs: [
          Tab(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.analytics),
                const SizedBox(height: 4),
                const Text('Statistics'),
              ],
            ),
          ),
          Tab(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person),
                const SizedBox(height: 4),
                Text('Active (${_activeRecords.length})'),
              ],
            ),
          ),
          Tab(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle),
                const SizedBox(height: 4),
                Text('Completed (${_completedRecords.length})'),
              ],
            ),
          ),
          Tab(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.archive),
                const SizedBox(height: 4),
                Text('Archived (${_archivedRecords.length})'),
              ],
            ),
          ),
        ],
      ),
    );
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
                        ),
                        const SizedBox(height: 4),
                        Text(
                          record.positionTitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
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

  Color _getStatusColor(ServiceStatus status) {
    switch (status) {
      case ServiceStatus.active:
        return Colors.green;
      case ServiceStatus.completed:
        return Colors.blue;
      case ServiceStatus.archived:
        return Colors.orange;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showRecordDetails(LeadershipRecord record) {
    // TODO: Implement record details dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing details for ${record.userName}'),
      ),
    );
  }

  void _showCreateRecordDialog() {
    // TODO: Implement create record dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Create record dialog - Coming soon'),
      ),
    );
  }

  void _completeService(LeadershipRecord record) {
    // TODO: Implement complete service dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Completing service for ${record.userName}'),
      ),
    );
  }

  void _archiveRecord(LeadershipRecord record) {
    // TODO: Implement archive confirmation dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Archiving record for ${record.userName}'),
      ),
    );
  }
}
