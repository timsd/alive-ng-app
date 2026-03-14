import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/discipleship_models.dart';
import '../../services/discipleship_service.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive_utils.dart';
import '../admin/board_reports_screen.dart';

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
  Map<String, dynamic> _statistics = {};

  bool _isLoading = true;
  String _searchQuery = '';
  DiscipleshipLevel? _selectedLevel;

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
      final user = _authService.currentUser;
      if (user == null) return;

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

      setState(() {
        _contacts = contacts;
        _recentInteractions = interactions.take(10).toList();
        _recentStudySessions = studySessions.take(10).toList();
        _activePrayerRequests = prayerRequests;
        _statistics = statistics;
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
        title: const Text('Discipleship Tracker'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          unselectedLabelStyle: Theme.of(context).textTheme.labelLarge,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Contacts'),
            Tab(text: 'Activities'),
            Tab(text: 'Prayer'),
            Tab(text: 'Reports'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddContactDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildContactsTab(),
                _buildActivitiesTab(),
                _buildPrayerTab(),
                _buildReportsTab(),
              ],
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
                  _statistics['totalContacts']?.toString() ?? '0',
                  Icons.people,
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(width: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 16.0,
                tablet: 20.0,
                desktop: 24.0,
              )),
              Expanded(
                child: _buildStatCard(
                  'Active Contacts',
                  _statistics['activeContacts']?.toString() ?? '0',
                  Icons.person_add,
                  Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveValue(
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
                  _statistics['totalBaptisms']?.toString() ?? '0',
                  Icons.water_drop,
                  Theme.of(context).colorScheme.secondary,
                ),
              ),
              SizedBox(width: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 16.0,
                tablet: 20.0,
                desktop: 24.0,
              )),
              Expanded(
                child: _buildStatCard(
                  'Study Sessions',
                  _statistics['totalStudySessions']?.toString() ?? '0',
                  Icons.book,
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveValue(
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
                  SizedBox(height: ResponsiveUtils.getResponsiveValue(
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
          SizedBox(height: ResponsiveUtils.getResponsiveValue(
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
                  SizedBox(height: ResponsiveUtils.getResponsiveValue(
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
                              _statistics['recentActivity']?['interactions']
                                      ?.toString() ??
                                  '0',
                              style: TextStyle(
                                fontSize: context.responsiveFontSize(24),
                                fontWeight: FontWeight.bold,
                                color: Colors.blue
                              ),
                            ),
                            const Text('Interactions'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                                _statistics['recentActivity']?['studySessions']
                                        ?.toString() ??
                                    '0',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.tertiary,
                                    ),
                              ),
                              Text('Study Sessions', style: Theme.of(context).textTheme.labelMedium),
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
              SizedBox(width: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 16.0,
                tablet: 20.0,
                desktop: 24.0,
              )),
              DropdownButton<DiscipleshipLevel?>(
                value: _selectedLevel,
                hint: const Text('All Levels'),
                items: [
                  const DropdownMenuItem<DiscipleshipLevel?>(
                    value: null,
                    child: Text('All Levels'),
                  ),
                  ...DiscipleshipLevel.values.map((level) => DropdownMenuItem(
                        value: level,
                        child: Text(_getLevelDisplayName(level)),
                      )),
                ],
                onChanged: (value) {
                  setState(() => _selectedLevel = value);
                  _loadData();
                },
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
                style: TextStyle(fontSize: context.responsiveFontSize(18), fontWeight: FontWeight.bold),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.analytics, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Discipleship Reports',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'View and generate detailed reports on discipleship progress.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BoardReportsScreen(initialCategory: 'discipleship'),
              ),
            ),
            icon: const Icon(Icons.assessment),
            label: const Text('View Discipleship Reports'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
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
            SizedBox(height: ResponsiveUtils.getResponsiveValue(
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
    final levelDistribution =
        _statistics['levelDistribution'] as Map<String, dynamic>? ?? {};

    return DiscipleshipLevel.values.map((level) {
      final count = levelDistribution[level.name] ?? 0;
      final percentage = _statistics['totalContacts'] > 0
          ? (count / _statistics['totalContacts'] * 100).round()
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
                value: _statistics['totalContacts'] > 0
                    ? count / _statistics['totalContacts']
                    : 0,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation(_getLevelColor(level)),
              ),
            ),
            SizedBox(width: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 8.0,
              tablet: 10.0,
              desktop: 12.0,
            )),
            Text('$count ($percentage%)', style: TextStyle(fontSize: context.responsiveFontSize(12))),
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
        )
      ),
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
                style: TextStyle(fontSize: context.responsiveFontSize(12)),
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
              value: 'level',
              child: Text('Update Level'),
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
    final contact = _contacts.firstWhere(
      (c) => c.id == prayer.contactId,
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.favorite, color: Colors.red),
        title: Text(prayer.request),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('For: ${contact.fullName}'),
            Text(
                'Requested: ${DateFormat('MMM dd, yyyy').format(prayer.dateRequested)}'),
            if (prayer.category != null) Text('Category: ${prayer.category}'),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'answer',
              child: Text('Mark as Answered'),
            ),
            const PopupMenuItem(
              value: 'update',
              child: Text('Update Status'),
            ),
          ],
          onSelected: (value) => _handlePrayerAction(prayer, value),
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

  // Action handlers
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
      case 'level':
        _showUpdateLevelDialog(contact);
        break;
    }
  }

  void _handlePrayerAction(PrayerRequest prayer, String action) {
    // Implementation for prayer actions
  }

  // Dialog methods
  void _showAddContactDialog() {
    // Implementation for add contact dialog
  }

  void _showContactDetails(DiscipleshipContact contact) {
    // Implementation for contact details
  }

  void _showAddInteractionDialog(DiscipleshipContact contact) {
    // Implementation for add interaction dialog
  }

  void _showAddStudySessionDialog(DiscipleshipContact contact) {
    // Implementation for add study session dialog
  }

  void _showUpdateLevelDialog(DiscipleshipContact contact) {
    // Implementation for update level dialog
  }

  void _showAddPrayerRequestDialog() {
    // Implementation for add prayer request dialog
  }
}




