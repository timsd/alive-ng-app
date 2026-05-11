import 'package:flutter/material.dart';
import 'enhanced_jitsi_meet_screen.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firebase_database_service.dart';
import '../../models/app_models.dart';
import '../../utils/responsive_utils.dart';
import '../../config/app_config.dart';
import '../../widgets/custom_app_bar.dart';

class ConferencePlatformScreen extends StatefulWidget {
  const ConferencePlatformScreen({super.key});

  @override
  State<ConferencePlatformScreen> createState() =>
      _ConferencePlatformScreenState();
}

class _ConferencePlatformScreenState extends State<ConferencePlatformScreen> {
  final FirebaseDatabaseService _firebaseService =
      FirebaseDatabaseService.instance;
  bool _isLoading = true;
  bool _hasAccess = false;
  User? _currentUser;
  UserProfile? _userProfile;
  List<ConferenceMeeting> _upcomingMeetings = [];
  List<ConferenceMeeting> _pastMeetings = [];
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userProfile = await _firebaseService.getUserProfile(user.uid);
        _currentUser = user;
        _userProfile = userProfile;
        _hasAccess = true;
        if (_hasAccess) {
          await _loadMeetings();
        }
      }
    } catch (e) {
      _hasAccess = false;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMeetings() async {
    try {
      final now = DateTime.now();
      final snapshot = await FirebaseFirestore.instance
          .collection('conference_meetings')
          .where('scheduled_time',
              isGreaterThanOrEqualTo: now.toIso8601String())
          .orderBy('scheduled_time')
          .get();

      final meetings = snapshot.docs
          .map<ConferenceMeeting>(
              (doc) => ConferenceMeeting.fromMap(doc.data(), doc.id))
          .toList();

      setState(() {
        _upcomingMeetings =
            meetings.where((m) => m.scheduledTime.isAfter(now)).toList();
        _pastMeetings =
            meetings.where((m) => m.scheduledTime.isBefore(now)).toList();
      });

      if (meetings.isEmpty && !AppConfig.isLiveMode) {
        setState(() {
          _upcomingMeetings = [
            ConferenceMeeting(
              id: '1',
              title: 'Chapter Coordinators Monthly Meeting',
              description:
                  'Monthly coordination meeting for all chapter coordinators',
              scheduledTime: now.add(const Duration(days: 2)),
              duration: 60,
              hostId: 'host1',
              hostName: 'Nwoko Patience Mfon',
              meetingType: 'chapter_coordination',
              participants: ['coord1', 'coord2', 'coord3'],
              maxParticipants: 20,
              isRecurring: true,
              meetingLink: 'https://meet.alive.ng/chapter-coord-001',
              status: 'scheduled',
              roomName:
                  'chapter-coord-monthly-${DateTime.now().millisecondsSinceEpoch}',
            ),
          ];
          _pastMeetings = [
            ConferenceMeeting(
              id: '3',
              title: 'Lagos Chapters Joint Meeting',
              description:
                  'Joint meeting for Lagos 1, Lagos 2, and Lagos 3 chapters',
              scheduledTime: now.subtract(const Duration(days: 3)),
              duration: 90,
              hostId: 'host3',
              hostName: 'Timothy Olodude',
              meetingType: 'chapter_meeting',
              participants: ['member1', 'member2', 'coord1'],
              maxParticipants: 15,
              isRecurring: false,
              meetingLink: 'https://meet.alive.ng/lagos-joint-003',
              status: 'completed',
              roomName: 'lagos-joint-meeting-past',
            ),
          ];
        });
      }
    } catch (e) {
      if (mounted) {
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading meetings: $e'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_hasAccess) {
      return Scaffold(
        appBar: CustomAppBar(
          title: 'Conference Platform',
          showBackButton: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 64.0,
                  tablet: 72.0,
                  desktop: 80.0,
                ),
                color: theme.colorScheme.outline,
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 16.0,
                tablet: 20.0,
                desktop: 24.0,
              )),
              Text(
                'Access Denied',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 24.0,
                        tablet: 28.0,
                        desktop: 32.0,
                      ),
                    ),
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 8.0,
                tablet: 10.0,
                desktop: 12.0,
              )),
              Text(
                'You do not have permission to access the conference platform.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Conference Platform',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMeetings,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!AppConfig.isLiveMode)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 16.0,
                  tablet: 20.0,
                  desktop: 24.0,
                ),
                vertical: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 8.0,
                  tablet: 10.0,
                  desktop: 12.0,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 12.0,
                      tablet: 14.0,
                      desktop: 16.0,
                    ),
                  ),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .secondary
                        .withValues(alpha: 0.3),
                  ),
                ),
                padding: EdgeInsets.all(
                  ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 12.0,
                    tablet: 14.0,
                    desktop: 16.0,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    SizedBox(
                        width: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 8.0,
                      tablet: 10.0,
                      desktop: 12.0,
                    )),
                    Expanded(
                      child: Text(
                        'Demo mode: showing sample meetings. Connect Firebase to view and schedule live meetings.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _loadMeetings,
                      child: const Text('Refresh'),
                    )
                  ],
                ),
              ),
            ),
          Container(
            padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 16.0,
              tablet: 20.0,
              desktop: 24.0,
            )),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _canScheduleMeeting()
                        ? _showScheduleMeetingDialog
                        : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Schedule Meeting'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showJoinMeetingDialog,
                    icon: const Icon(Icons.video_call),
                    label: const Text('Join Meeting'),
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTabIndex = 0),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTabIndex == 0
                            ? Theme.of(context).colorScheme.primary
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        'Upcoming (${_upcomingMeetings.length})',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: _selectedTabIndex == 0
                                  ? theme.colorScheme.onPrimary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                            ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTabIndex = 1),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTabIndex == 1
                            ? Theme.of(context).colorScheme.primary
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        'Past (${_pastMeetings.length})',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: _selectedTabIndex == 1
                                  ? theme.colorScheme.onPrimary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                            ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _selectedTabIndex == 0
                ? _buildMeetingsList(_upcomingMeetings)
                : _buildMeetingsList(_pastMeetings),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingsList(List<ConferenceMeeting> meetings) {
    final theme = Theme.of(context);
    if (meetings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No Meetings Found',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: meetings.length,
      itemBuilder: (context, index) => _buildMeetingCard(meetings[index]),
    );
  }

  Widget _buildMeetingCard(ConferenceMeeting meeting) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.6),
        ),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(meeting.title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(meeting.description,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16),
                const SizedBox(width: 4),
                Text(meeting.scheduledTime.toString(),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => _shareMeeting(meeting),
                    child: const Text('Share')),
                const SizedBox(width: 8),
                ElevatedButton(
                    onPressed: () => _joinMeeting(meeting),
                    child: const Text('Join')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _canScheduleMeeting() {
    if (_currentUser == null) return false;
    final userRole = _userProfile?.role ?? 'member';
    return ['coordinator', 'director', 'bod_member', 'admin']
        .contains(userRole);
  }

  Future<void> _showScheduleMeetingDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    String selectedType = 'general';
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Schedule Meeting',
              style: Theme.of(context).textTheme.titleLarge),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Date & Time'),
                  subtitle: Text(selectedDate.toString()),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      if (!context.mounted) return;
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                      );
                      if (time != null) {
                        setDialogState(() {
                          selectedDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Meeting Type'),
                  items: const [
                    DropdownMenuItem(
                        value: 'general', child: Text('General Meeting')),
                    DropdownMenuItem(
                        value: 'chapter_meeting',
                        child: Text('Chapter Meeting')),
                    DropdownMenuItem(
                        value: 'committee', child: Text('Committee Meeting')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedType = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        final roomName =
            '${titleController.text.toLowerCase().replaceAll(' ', '-')}-${DateTime.now().millisecondsSinceEpoch}';
        final meeting = ConferenceMeeting(
          id: '',
          title: titleController.text,
          description: descriptionController.text,
          scheduledTime: selectedDate,
          duration: 60,
          hostId: _currentUser?.uid ?? '',
          hostName: _userProfile?.fullName ?? 'Anonymous',
          meetingType: selectedType,
          participants: [],
          maxParticipants: 100,
          isRecurring: false,
          meetingLink: 'https://meet.alive.ng/$roomName',
          status: 'scheduled',
          roomName: roomName,
        );

        await FirebaseFirestore.instance
            .collection('conference_meetings')
            .add(meeting.toMap());
        _loadMeetings();
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Meeting scheduled successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Error scheduling meeting: $e'),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _showJoinMeetingDialog() async {
    final roomController = TextEditingController();
    final navigator = Navigator.of(context);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Join Custom Meeting',
            style: Theme.of(context).textTheme.titleLarge),
        content: TextField(
          controller: roomController,
          decoration: const InputDecoration(
            labelText: 'Room Name',
            hintText: 'e.g. board-meeting-001',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, roomController.text),
            child: const Text('Join'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      navigator.push(
        MaterialPageRoute(
          builder: (context) => EnhancedJitsiMeetScreen(
            customRoomName: result,
            isModerator: _userProfile?.role == 'admin' ||
                _userProfile?.role == 'moderator',
          ),
        ),
      );
    }
  }

  Future<void> _joinMeeting(ConferenceMeeting meeting) async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EnhancedJitsiMeetScreen(
          customRoomName: meeting.roomName,
          isModerator: _userProfile?.role == 'admin' ||
              _userProfile?.role == 'moderator',
        ),
      ),
    );
  }

  Future<void> _shareMeeting(ConferenceMeeting meeting) async {
    final shareText = '''Join our ALIVE meeting!
Title: ${meeting.title}
Join here: ${meeting.meetingLink}''';
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Meeting details copied to clipboard!')));
  }
}
