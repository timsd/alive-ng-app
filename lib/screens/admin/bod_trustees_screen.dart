import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/appwrite_profile_service.dart';
import '../../services/auth_service.dart';
import '../../models/app_models.dart';
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
  bool _isLoading = true;
  bool _hasAccess = false;
  String? _currentUserId;

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
      }
    } catch (e) {
      _hasAccess = false;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
        title: const Text('Board of Directors & Trustees'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Message
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.admin_panel_settings,
                          color: Colors.green,
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
                            return Text(
                              'Welcome, $userEmail',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This is the exclusive Board of Directors and Trustees portal for ALIVE Nigeria leadership.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Board of Directors Section
            _buildSection(
              'Board of Directors',
              Icons.business_center,
              [
                _buildMemberCard(
                  'Nwoko Patience Mfon',
                  'Executive President & Chairman',
                  'Leading the strategic direction of ALIVE Nigeria',
                  Icons.person,
                ),
                _buildMemberCard(
                  'Caleb Peters',
                  'Secretary/Communication Director',
                  'Managing organizational communications and documentation',
                  Icons.chat,
                ),
                _buildMemberCard(
                  'Godstime Esuku',
                  'Director: ALIVE Mission Training Center (AMTC)',
                  'Overseeing missionary training and development programs',
                  Icons.school,
                ),
                _buildMemberCard(
                  'Timothy Olodude',
                  'Treasure / Director of Logistics',
                  'Managing financial operations and logistical coordination',
                  Icons.account_balance_wallet,
                ),
                _buildMemberCard(
                  'Emenike Ekechi',
                  'Director: Evangelism/Programming/Health',
                  'Leading evangelistic initiatives and health programs',
                  Icons.health_and_safety,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Trustees Section
            _buildSection(
              'Board of Trustees',
              Icons.security,
              [
                _buildMemberCard(
                  'Trustee Position 1',
                  'Chairman',
                  'Overseeing organizational governance and compliance',
                  Icons.gavel,
                ),
                _buildMemberCard(
                  'Trustee Position 2',
                  'Financial Trustee',
                  'Ensuring financial accountability and transparency',
                  Icons.account_balance,
                ),
                _buildMemberCard(
                  'Trustee Position 3',
                  'Legal Trustee',
                  'Managing legal affairs and regulatory compliance',
                  Icons.balance,
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
                  child: Container(),
                ),
              ],
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
        title: const Text('Start Board Meeting'),
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
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
        title: const Text('Quick Board Meeting'),
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
