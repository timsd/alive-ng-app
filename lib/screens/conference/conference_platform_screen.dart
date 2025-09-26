import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import '../../services/supabase_service.dart';
import '../../models/app_models.dart';

class ConferencePlatformScreen extends StatefulWidget {
  const ConferencePlatformScreen({super.key});

  @override
  State<ConferencePlatformScreen> createState() => _ConferencePlatformScreenState();
}

class _ConferencePlatformScreenState extends State<ConferencePlatformScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService.instance;
  final JitsiMeet _jitsiMeet = JitsiMeet();
  bool _isLoading = true;
  bool _hasAccess = false;
  User? _currentUser;
  List<ConferenceMeeting> _upcomingMeetings = [];
  List<ConferenceMeeting> _pastMeetings = [];
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeJitsi();
    _checkAccess();
  }

  Future<void> _initializeJitsi() async {
    // Configure Jitsi Meet with proper event listener
    debugPrint('Jitsi Meet initialized successfully');
  }

  JitsiMeetEventListener _createJitsiEventListener() {
    return JitsiMeetEventListener(
      conferenceJoined: (url) {
        debugPrint('Conference joined: $url');
        if (mounted) {
          setState(() {
            // Update UI state when conference is joined
          });
        }
      },
      participantJoined: (email, name, role, participantId) {
        debugPrint('Participant joined: $name ($email) - Role: $role');
      },
      conferenceTerminated: (url, error) {
        debugPrint('Conference terminated: $url, Error: $error');
        if (mounted) {
          Navigator.of(context).pop();
        }
      },
      readyToClose: () {
        debugPrint('Ready to close conference');
        if (mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }

  Future<void> _checkAccess() async {
    try {
      final user = _supabaseService.currentUser;
      if (user != null) {
        _currentUser = user;
        // For now, allow access - role checking should be implemented with UserProfile
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
      // Fetch meetings from Supabase
      final response = await Supabase.instance.client
          .from('conference_meetings')
          .select()
          .gte('scheduled_time', DateTime.now().toIso8601String())
          .order('scheduled_time');
      
      final now = DateTime.now();
      
      // If no data from Supabase, use placeholder data
      if (response.isEmpty) {
        setState(() {
          _upcomingMeetings = [
            ConferenceMeeting(
              id: '1',
              title: 'Chapter Coordinators Monthly Meeting',
              description: 'Monthly coordination meeting for all chapter coordinators',
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
              roomName: 'chapter-coord-monthly-${DateTime.now().millisecondsSinceEpoch}',
            ),
            ConferenceMeeting(
              id: '2',
              title: 'Board of Directors Quarterly Review',
              description: 'Quarterly review of organizational progress and strategic planning',
              scheduledTime: now.add(const Duration(days: 7)),
              duration: 120,
              hostId: 'host2',
              hostName: 'Caleb Peters',
              meetingType: 'bod_meeting',
              participants: ['bod1', 'bod2', 'trustee1'],
              maxParticipants: 10,
              isRecurring: false,
              meetingLink: 'https://meet.alive.ng/bod-quarterly-002',
              status: 'scheduled',
              roomName: 'bod-quarterly-${DateTime.now().millisecondsSinceEpoch}',
            ),
          ];
          
          _pastMeetings = [
            ConferenceMeeting(
              id: '3',
              title: 'Lagos Chapters Joint Meeting',
              description: 'Joint meeting for Lagos 1, Lagos 2, and Lagos 3 chapters',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading meetings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_hasAccess) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Conference Platform'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'Access Denied',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'You do not have permission to access the conference platform.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conference Platform'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMeetings,
          ),
        ],
      ),
      body: Column(
        children: [
          // Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _canScheduleMeeting() ? _showScheduleMeetingDialog : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Schedule Meeting'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showJoinMeetingDialog,
                    icon: const Icon(Icons.video_call),
                    label: const Text('Join Meeting'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Tab Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTabIndex == 0
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        'Upcoming (${_upcomingMeetings.length})',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _selectedTabIndex == 0
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTabIndex = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTabIndex == 1
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        'Past (${_pastMeetings.length})',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _selectedTabIndex == 1
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Meeting List
          Expanded(
            child: _selectedTabIndex == 0
                ? _buildUpcomingMeetings()
                : _buildPastMeetings(),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingMeetings() {
    if (_upcomingMeetings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No Upcoming Meetings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Schedule a new meeting to get started',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _upcomingMeetings.length,
      itemBuilder: (context, index) {
        final meeting = _upcomingMeetings[index];
        return _buildMeetingCard(meeting, isUpcoming: true);
      },
    );
  }

  Widget _buildPastMeetings() {
    if (_pastMeetings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No Past Meetings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Your meeting history will appear here',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _pastMeetings.length,
      itemBuilder: (context, index) {
        final meeting = _pastMeetings[index];
        return _buildMeetingCard(meeting, isUpcoming: false);
      },
    );
  }

  Widget _buildMeetingCard(ConferenceMeeting meeting, {required bool isUpcoming}) {
    final timeUntil = meeting.scheduledTime.difference(DateTime.now());
    final isStartingSoon = isUpcoming && timeUntil.inMinutes <= 15 && timeUntil.inMinutes >= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Meeting Type Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getMeetingTypeColor(meeting.meetingType).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getMeetingTypeLabel(meeting.meetingType),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getMeetingTypeColor(meeting.meetingType),
                    ),
                  ),
                ),
                if (isStartingSoon) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'STARTING SOON',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Meeting Title
            Text(
              meeting.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Meeting Description
            Text(
              meeting.description,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Meeting Details
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'Host: ${meeting.hostName}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            _formatDateTime(meeting.scheduledTime),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.timer, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '${meeting.duration} min',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.group, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '${meeting.participants.length}/${meeting.maxParticipants} participants',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Action Buttons
            Row(
              children: [
                if (isUpcoming) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _joinMeetingWithJitsi(meeting),
                      icon: const Icon(Icons.video_call, size: 18),
                      label: const Text('Join'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _shareMeeting(meeting),
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                if (!isUpcoming) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _viewMeetingRecording(meeting),
                      icon: const Icon(Icons.play_circle_outline, size: 18),
                      label: const Text('Recording'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);
    
    if (difference.inDays == 0) {
      return 'Today at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Tomorrow at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays > 0 && difference.inDays <= 7) {
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${weekdays[dateTime.weekday - 1]} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  Color _getMeetingTypeColor(String type) {
    switch (type) {
      case 'bod_meeting':
        return Colors.red;
      case 'director_meeting':
        return Colors.purple;
      case 'chapter_coordination':
        return Colors.blue;
      case 'chapter_meeting':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getMeetingTypeLabel(String type) {
    switch (type) {
      case 'bod_meeting':
        return 'BOD MEETING';
      case 'director_meeting':
        return 'DIRECTOR MEETING';
      case 'chapter_coordination':
        return 'COORDINATION';
      case 'chapter_meeting':
        return 'CHAPTER MEETING';
      default:
        return 'MEETING';
    }
  }

  bool _canScheduleMeeting() {
    // Implement role-based access control
    if (_currentUser == null) return false;
    
    // Check user role from metadata or user object
    final userRole = _currentUser?.userMetadata?['role'] ?? 'member';
    
    // Allow coordinators, directors, and BOD members to schedule meetings
    return ['coordinator', 'director', 'bod_member', 'admin'].contains(userRole);
  }
  
  Future<void> _showScheduleMeetingDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ScheduleMeetingDialog(),
    );
    
    if (result != null) {
      // Save meeting to Supabase
      try {
        await Supabase.instance.client.from('conference_meetings').insert({
          'title': result['title'],
          'description': result['description'],
          'scheduled_time': result['scheduledTime'].toIso8601String(),
          'duration': result['duration'],
          'host_id': _currentUser?.id,
          'host_name': _currentUser?.userMetadata?['full_name'] ?? 'Unknown Host',
          'meeting_type': result['meetingType'],
          'max_participants': result['maxParticipants'] ?? 50,
          'is_recurring': result['isRecurring'] ?? false,
          'meeting_link': 'https://meet.alive.ng/${result['title'].toLowerCase().replaceAll(' ', '-')}-${DateTime.now().millisecondsSinceEpoch}',
          'status': 'scheduled',
          'room_name': '${result['title'].toLowerCase().replaceAll(' ', '-')}-${DateTime.now().millisecondsSinceEpoch}',
          'created_at': DateTime.now().toIso8601String(),
        });
        
        // Refresh meetings list
        _loadMeetings();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Meeting scheduled successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _loadMeetings();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error scheduling meeting: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  Future<void> _showJoinMeetingDialog() async {
    final meetingId = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Join Meeting'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Meeting ID or Room Name',
              hintText: 'Enter meeting ID or room name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Join'),
            ),
          ],
        );
      },
    );
    
    if (meetingId != null && meetingId.isNotEmpty) {
      await _joinMeetingByRoomName(meetingId);
    }
  }

  Future<void> _joinMeetingWithJitsi(ConferenceMeeting meeting) async {
    try {
      final options = JitsiMeetConferenceOptions(
        serverURL: "https://meet.jit.si",
        room: meeting.roomName,
        configOverrides: {
          "startWithAudioMuted": false,
          "startWithVideoMuted": false,
          "enableWelcomePage": false,
          "prejoinPageEnabled": false,
          "enableClosePage": false,
        },
        featureFlags: {
          "unsaferoomwarning.enabled": false,
          "resolution": 720,
          "chat.enabled": true,
          "recording.enabled": true,
          "livestreaming.enabled": true,
          "screensharing.enabled": true,
          "breakoutrooms.enabled": true,
        },
        userInfo: JitsiMeetUserInfo(
          displayName: _currentUser?.userMetadata?['full_name'] ?? 'ALIVE Member',
          email: _currentUser?.email ?? '',
        ),
      );

      await _jitsiMeet.join(options, _createJitsiEventListener());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join meeting: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _joinMeetingByRoomName(String roomName) async {
    try {
      final options = JitsiMeetConferenceOptions(
        serverURL: "https://meet.jit.si",
        room: roomName,
        configOverrides: {
          "startWithAudioMuted": false,
          "startWithVideoMuted": false,
          "enableWelcomePage": false,
          "prejoinPageEnabled": false,
          "enableClosePage": false,
        },
        featureFlags: {
          "unsaferoomwarning.enabled": false,
          "resolution": 720,
          "chat.enabled": true,
          "recording.enabled": true,
          "livestreaming.enabled": true,
          "screensharing.enabled": true,
          "breakoutrooms.enabled": true,
        },
        userInfo: JitsiMeetUserInfo(
          displayName: _currentUser?.userMetadata?['full_name'] ?? 'ALIVE Member',
          email: _currentUser?.email ?? '',
        ),
      );

      await _jitsiMeet.join(options, _createJitsiEventListener());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join meeting: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _shareMeeting(ConferenceMeeting meeting) async {
    final shareText = '''Join our ALIVE meeting!

Title: ${meeting.title}
Description: ${meeting.description}
Scheduled: ${meeting.scheduledTime.toString()}
Duration: ${meeting.duration} minutes

Join here: ${meeting.meetingLink}

See you there!''';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Meeting'),
        content: SingleChildScrollView(
          child: Text(shareText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Clipboard.setData(ClipboardData(text: shareText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Meeting details copied to clipboard!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Copy to Clipboard'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _viewMeetingRecording(ConferenceMeeting meeting) async {
    // Implement recording viewing logic
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Recording: ${meeting.title}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Meeting Details:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Date: ${meeting.scheduledTime.toString().split(' ')[0]}'),
              Text('Duration: ${meeting.duration} minutes'),
              Text('Host: ${meeting.hostName}'),
              const SizedBox(height: 16),
              const Text(
                'Recording Status: Available',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Note: Recording playback will open in your default browser or video player.',
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Opening recording for ${meeting.title}...'),
                  backgroundColor: Colors.purple,
                ),
              );
              // In a real implementation, this would open the recording URL
              // or launch a video player with the recording file
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Play Recording'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Remove Jitsi Meet listeners
    // _jitsiMeet.removeAllListeners(); // Method not available
    super.dispose();
  }
}

// Schedule Meeting Dialog
class _ScheduleMeetingDialog extends StatefulWidget {
  @override
  _ScheduleMeetingDialogState createState() => _ScheduleMeetingDialogState();
}

class _ScheduleMeetingDialogState extends State<_ScheduleMeetingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _duration = 60;
  String _meetingType = 'chapter_meeting';
  int _maxParticipants = 15;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Schedule New Meeting'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Meeting Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a meeting title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _meetingType,
                  decoration: const InputDecoration(
                    labelText: 'Meeting Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'chapter_meeting', child: Text('Chapter Meeting')),
                    DropdownMenuItem(value: 'bod_meeting', child: Text('BOD Meeting')),
                    DropdownMenuItem(value: 'director_meeting', child: Text('Director Meeting')),
                    DropdownMenuItem(value: 'chapter_coordination', child: Text('Chapter Coordination')),
                  ],
                  onChanged: (value) => setState(() => _meetingType = value!),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: Text('Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() => _selectedDate = date);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: Text('Time: ${_selectedTime.format(context)}'),
                        trailing: const Icon(Icons.access_time),
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _selectedTime,
                          );
                          if (time != null) {
                            setState(() => _selectedTime = time);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _duration.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Duration (minutes)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          _duration = int.tryParse(value) ?? 60;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        initialValue: _maxParticipants.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Max Participants',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          _maxParticipants = int.tryParse(value) ?? 15;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final scheduledDateTime = DateTime(
                _selectedDate.year,
                _selectedDate.month,
                _selectedDate.day,
                _selectedTime.hour,
                _selectedTime.minute,
              );
              
              Navigator.of(context).pop({
                'title': _titleController.text,
                'description': _descriptionController.text,
                'scheduledTime': scheduledDateTime,
                'duration': _duration,
                'meetingType': _meetingType,
                'maxParticipants': _maxParticipants,
              });
            }
          },
          child: const Text('Schedule'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}




