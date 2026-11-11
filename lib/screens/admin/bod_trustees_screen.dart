import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import 'package:go_router/go_router.dart';
import 'leader_meeting_transcription_screen.dart';
import '../../services/appwrite_profile_service.dart';
import '../../services/auth_service.dart';
import '../../services/role_access_service.dart';
import '../../models/app_models.dart';
import 'board_reports_screen.dart';
import 'board_decisions_screen.dart';
import 'board_documents_screen.dart';
import '../conference/livekit_meeting_screen.dart';
import '../../config/meeting_links_config.dart';
import '../../widgets/custom_app_bar.dart';

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
      final user = _authService.currentUser;
      if (user != null) {
        final userProfile = await _profileService.getUserProfileModel(user.uid);
        _currentUserId = user.uid;

        final role = userProfile?.role ?? '';
        _hasAccess = role == 'admin' ||
            role == 'super_admin' ||
            role == 'leader' ||
            role == 'bod' ||
            role == 'trustee' ||
            RoleAccessService.instance.canAccessAdmin();
      }
    } catch (_) {
      _hasAccess = false;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: colorScheme.primary,
          ),
        ),
      );
    }

    if (!_hasAccess) {
      return Scaffold(
        appBar: const CustomAppBar(
          title: 'Access Denied',
          showBackButton: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 72,
                  color: colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Access Denied',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You do not have permission to access this page.',
                  style: TextStyle(
                    fontSize: 15,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'This portal is restricted to Board of Directors,\nTrustees, Leaders, and Administrators only.',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Board of Directors',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Message
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              color: colorScheme.primaryContainer.withValues(alpha: 0.35),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.admin_panel_settings_rounded,
                            color: colorScheme.onPrimaryContainer,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: FutureBuilder<UserProfile?>(
                            future: _currentUserId != null
                                ? _profileService
                                    .getUserProfileModel(_currentUserId!)
                                : Future<UserProfile?>.value(null),
                            builder: (context, snapshot) {
                              final profile = snapshot.data;
                              final userName = profile?.fullName?.isNotEmpty == true
                                  ? profile!.fullName!
                                  : profile?.email ?? 'Administrator';
                              return Text(
                                'Welcome, $userName',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'This is the exclusive Board of Directors portal for ALIVE Nigeria executive leadership.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Link to Leadership Directory
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.badge_rounded, color: colorScheme.primary, size: 24),
                ),
                title: Text(
                  'Leadership Directory',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('View, edit and update Trustees & Directors roster'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () => context.push(AppConstants.leadershipDirectoryRoute),
              ),
            ),
            const SizedBox(height: 24),

            // Quick Actions (Image 4)
            Text(
              'Quick Actions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    'Board Meeting',
                    Icons.video_call_rounded,
                    'Start a board meeting',
                    () => _startBoardMeeting(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    'Reports',
                    Icons.assessment_rounded,
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
                    Icons.how_to_vote_rounded,
                    'Board decisions & voting',
                    () => _viewDecisions(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    'Documents',
                    Icons.folder_rounded,
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
                    Icons.share_rounded,
                    'Share meeting files',
                    () => context.go('/meeting-file-sharing'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    'Meeting Notes',
                    Icons.note_alt_rounded,
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

  Widget _buildActionCard(
    String title,
    IconData icon,
    String subtitle,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      color: colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 26,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startBoardMeeting() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Expanded(child: Text('Start Board Meeting')),
            IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
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
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToConferencePlatform();
            },
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
            child: const Text('Conference Platform'),
          ),
        ],
      ),
    );
  }

  void _startQuickMeeting() {
    final roomName = 'board-meeting-${DateTime.now().millisecondsSinceEpoch}';
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Expanded(child: Text('Quick Board Meeting')),
            IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
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
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  Text(
                    'Room Name:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    roomName,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
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
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _joinMeeting(roomName);
            },
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.tertiary,
              foregroundColor: colorScheme.onTertiary,
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

  Future<void> _joinMeeting(String roomName) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveKitMeetingScreen(
          customRoomName: roomName,
          meetingType: MeetingType.board,
        ),
      ),
    );
  }

  void _openMeetingNotes() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LeaderMeetingTranscriptionScreen()),
    );
  }
}
