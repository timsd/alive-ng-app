import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../services/appwrite_profile_service.dart';
import '../../services/auth_service.dart';
import '../../services/leadership_service.dart';
import '../../services/role_access_service.dart';
import '../../models/app_models.dart' hide LeadershipRecord;
import '../../models/leadership_models.dart';
import 'board_reports_screen.dart';
import 'board_decisions_screen.dart';
import 'board_documents_screen.dart';
import '../conference/livekit_meeting_screen.dart';
import '../../config/meeting_links_config.dart';

class BodTrusteesScreen extends StatefulWidget {
  const BodTrusteesScreen({super.key});

  @override
  State<BodTrusteesScreen> createState() => _BodTrusteesScreenState();
}

class _BodTrusteesScreenState extends State<BodTrusteesScreen> {
  final AppwriteProfileService _profileService = AppwriteProfileService();
  final AuthService _authService = AuthService.instance;
  final LeadershipService _leadershipService = LeadershipService();
  bool _isLoading = true;
  bool _hasAccess = false;
  bool _isAdmin = false;
  String? _currentUserId;
  List<LeadershipRecord> _records = [];
  String _tenureFilter = 'all';

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      // Check if user has admin, leader, or BOD access
      final user = _authService.currentUser;
      if (user != null) {
        final userProfile = await _profileService.getUserProfileModel(user.uid);
        _currentUserId = user.uid;

        // Only admin, leader, and BOD members can access this page
        final role = userProfile?.role ?? '';
        _hasAccess = role == 'admin' ||
            role == 'leader' ||
            role == 'bod' ||
            role == 'trustee';
        _isAdmin = RoleAccessService.instance.hasRole('admin');
        if (_hasAccess) await _loadLeadership();
      }
    } catch (e) {
      _hasAccess = false;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLeadership() async {
    try {
      final results = await Future.wait([
        _leadershipService.getRecordsByPosition(LeadershipPosition.bod),
        _leadershipService.getRecordsByPosition(LeadershipPosition.trustee),
      ]);
      final merged = <LeadershipRecord>[...results[0], ...results[1]];
      merged.sort((a, b) => b.startDate.compareTo(a.startDate));
      if (mounted) setState(() => _records = merged);
    } catch (_) {
      // Board screen still works when leadership history is unavailable.
    }
  }

  List<String> get _tenures {
    final tenures = _records.map(_tenureLabel).toSet().toList()..sort();
    return ['all', ...tenures];
  }

  String _tenureLabel(LeadershipRecord record) {
    final end = record.endDate;
    final startYear = record.startDate.year;
    final endYear = end?.year ?? DateTime.now().year;
    return startYear == endYear ? '$startYear' : '$startYear–$endYear';
  }

  /// Directors serve 2-year terms (not 3). This is used to auto-calculate
  /// the default end date when an admin creates a new director record.
  Duration get _directorTerm {
    const years = 2;
    return Duration(days: years * 365);
  }

  List<LeadershipRecord> _filteredRecords(LeadershipPosition position) {
    return _records.where((record) {
      if (record.position != position) return false;
      if (_tenureFilter != 'all' && _tenureLabel(record) != _tenureFilter) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.green,
          ),
        ),
      );
    }

    if (!_hasAccess) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'Access Denied',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You do not have permission to access this page.',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This page is restricted to Board of Directors,\nTrustees, Leaders, and Administrators only.',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Board of Directors & Trustees',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          if (_isAdmin)
            IconButton(
              tooltip: 'Add leader',
              icon: const Icon(Icons.person_add),
              color: Theme.of(context).colorScheme.onPrimary,
              onPressed: () => _showLeaderEditor(),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Message
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.admin_panel_settings,
                          color: Theme.of(context).colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        FutureBuilder<UserProfile?>(
                          future: _currentUserId != null
                              ? _profileService
                                  .getUserProfileModel(_currentUserId!)
                              : Future<UserProfile?>.value(null),
                          builder: (context, snapshot) {
                            final profile = snapshot.data;
                            final userEmail = profile?.email ??
                                profile?.fullName ??
                                'Administrator';
                            return Expanded(
                              child: Text(
                                'Welcome, $userEmail',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This is the exclusive Board of Directors and Trustees portal for ALIVE Nigeria leadership.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.history, color: Colors.green),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Leadership by tenure',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _tenureFilter,
                  items: _tenures
                      .map((tenure) => DropdownMenuItem(
                            value: tenure,
                            child: Text(tenure == 'all' ? 'All tenures' : tenure),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _tenureFilter = value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Board of Directors Section
            _buildLeadershipSection(
              'Directors',
              Icons.business_center,
              _filteredRecords(LeadershipPosition.bod),
              fallback: [
                _buildMemberCard(
                  'Nwoko Patience Mfon',
                  'Executive President & Chairman',
                  'Leading the strategic direction of ALIVE Nigeria',
                  Icons.person,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Trustees Section
            _buildLeadershipSection(
              'Board of Trustees',
              Icons.security,
              _filteredRecords(LeadershipPosition.trustee),
              fallback: [
                _buildMemberCard(
                  'Trustee Position 1',
                  'Chairman',
                  'Overseeing organizational governance and compliance',
                  Icons.gavel,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    'Board Meeting',
                    Icons.video_call,
                    'Start a board meeting',
                    () => _startBoardMeeting(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    'Reports',
                    Icons.assessment,
                    'View organizational reports',
                    () => _viewReports(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    'Decisions',
                    Icons.how_to_vote,
                    'Board decisions & voting',
                    () => _viewDecisions(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    'Documents',
                    Icons.folder,
                    'Access board documents',
                    () => _viewDocuments(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    'Meeting Files',
                    Icons.share,
                    'Share meeting files',
                    () => context.go('/meeting-file-sharing'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    'Meeting Notes',
                    Icons.note_alt,
                    'Fathom-style notes + transcript',
                    () => _openMeetingNotes(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadershipSection(
    String title,
    IconData icon,
    List<LeadershipRecord> records, {
    required List<Widget> fallback,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (records.isEmpty) ...fallback else ...records.map(_buildLeadershipCard),
      ],
    );
  }

  Widget _buildLeadershipCard(LeadershipRecord record) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM yyyy');
    final tenure = _tenureLabel(record);
    final range = '${dateFormat.format(record.startDate)} - ${record.endDate == null ? 'Present' : dateFormat.format(record.endDate!)}';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: theme.colorScheme.surface,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary,
          child: const Icon(Icons.person, color: Colors.white),
        ),
        title: Text(
          record.userName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${record.positionTitle}\nTenure: $tenure ($range)',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _isAdmin
            ? IconButton(
                tooltip: 'Edit leader',
                icon: Icon(Icons.edit, color: theme.colorScheme.primary),
                onPressed: () => _showLeaderEditor(record: record),
              )
            : null,
      ),
    );
  }

  void _openMeetingNotes() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BoardMeetingNotesScreen()));
  }

  Future<void> _showLeaderEditor({LeadershipRecord? record}) async {
    final nameController = TextEditingController(text: record?.userName ?? '');
    final emailController = TextEditingController(text: record?.userEmail ?? '');
    final titleController = TextEditingController(text: record?.positionTitle ?? '');
    var position = record?.position ?? LeadershipPosition.director;
    var start = record?.startDate ?? DateTime.now();
    DateTime? end = record?.endDate;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(record == null ? 'Add leader' : 'Edit leader'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full name')),
                TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Role title')),
                DropdownButton<LeadershipPosition>(
                  value: position,
                  items: const [
                    DropdownMenuItem(value: LeadershipPosition.bod, child: Text('Director')),
                    DropdownMenuItem(value: LeadershipPosition.trustee, child: Text('Trustee')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => position = value);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Directors serve 2-year terms.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  if (record == null) {
                    await _leadershipService.createRecord(LeadershipRecord(
                      id: 'new',
                      userId: _currentUserId ?? 'admin',
                      userName: nameController.text.trim(),
                      userEmail: emailController.text.trim(),
                      position: position,
                      positionTitle: titleController.text.trim(),
                      startDate: start,
                      endDate: end,
                      yearsOfService: 0,
                      status: ServiceStatus.active,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ));
                  } else {
                    await _leadershipService.updateRecord(record.id, {
                      'user_name': nameController.text.trim(),
                      'position': position.name,
                      'position_title': titleController.text.trim(),
                      'start_date': start.toIso8601String(),
                    });
                  }
                  if (mounted) {
                    Navigator.pop(context);
                    await _loadLeadership();
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: Colors.green,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildMemberCard(
      String name, String position, String description, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(
            icon,
            color: Colors.white,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              position,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildActionCard(
      String title, IconData icon, String subtitle, VoidCallback onTap) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: Colors.green,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startBoardMeeting() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Expanded(child: Text('Start Board Meeting')),
            IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose how to start the board meeting:'),
            SizedBox(height: 16),
            Text('• Quick Meeting: Start immediately'),
            Text('• Scheduled Meeting: Join existing meeting'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startQuickMeeting();
            },
            child: const Text('Quick Meeting'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToConferencePlatform();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Conference Platform',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _startQuickMeeting() {
    final roomName = 'board-meeting-${DateTime.now().millisecondsSinceEpoch}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Expanded(child: Text('Quick Board Meeting')),
            IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Meeting room created successfully!'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  const Text(
                    'Room Name:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    roomName,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Share this room name with other board members to join the meeting.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Launch LiveKit meeting with the room name
              await _joinMeeting(roomName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.tertiary,
              foregroundColor: Theme.of(context).colorScheme.onTertiary,
            ),
            child: const Text('Join Meeting'),
          ),
        ],
      ),
    );
  }

  void _navigateToConferencePlatform() {
    context.push('/conference');
  }

  void _viewReports() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BoardReportsScreen(),
      ),
    );
  }

  void _viewDecisions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BoardDecisionsScreen(),
      ),
    );
  }

  void _viewDocuments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BoardDocumentsScreen(),
      ),
    );
  }

  Future<void> _joinMeeting(String _) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LiveKitMeetingScreen(
          meetingType: MeetingType.board,
        ),
      ),
    );
  }
}

class BoardMeetingNotesScreen extends StatefulWidget {
  const BoardMeetingNotesScreen({super.key});

  @override
  State<BoardMeetingNotesScreen> createState() => _BoardMeetingNotesScreenState();
}

class _BoardMeetingNotesScreenState extends State<BoardMeetingNotesScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextEditingController _notesController = TextEditingController();
  final List<String> _transcriptLines = [];
  bool _listening = false;

  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    final available = await _speech.initialize();
    if (!available || !mounted) return;
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        final words = result.recognizedWords.trim();
        if (words.isEmpty) return;
        setState(() {
          if (_transcriptLines.isEmpty) {
            _transcriptLines.add(words);
          } else {
            _transcriptLines[_transcriptLines.length - 1] = words;
          }
        });
      },
    );
  }

  void _addSummaryPoint(String point) {
    final text = point.trim();
    if (text.isEmpty) return;
    setState(() {
      _notesController.text = _notesController.text.isEmpty ? '- $text' : '${_notesController.text}\n- $text';
    });
  }

  @override
  void dispose() {
    _speech.stop();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meeting notes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Live transcript', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_transcriptLines.isEmpty)
                    const Text('Tap Start to capture board discussion as text.')
                  else
                    ..._transcriptLines.map((line) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(line),
                        )),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _toggleListening,
                    icon: Icon(_listening ? Icons.stop : Icons.mic),
                    label: Text(_listening ? 'Stop' : 'Start'),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fathom-style summary', style: Theme.of(context).textTheme.titleMedium),
                  TextField(controller: _notesController, minLines: 4, maxLines: 8, decoration: const InputDecoration(hintText: 'Key decisions, action items, owners...')),
                  Row(
                    children: [
                      TextButton.icon(onPressed: () => _addSummaryPoint('Decision:'), icon: const Icon(Icons.check), label: const Text('Decision')),
                      TextButton.icon(onPressed: () => _addSummaryPoint('Action:'), icon: const Icon(Icons.task), label: const Text('Action')),
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
}
