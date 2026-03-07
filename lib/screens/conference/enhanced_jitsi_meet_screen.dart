import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/jitsi_meet_service.dart';
import '../../config/meeting_links_config.dart';
import '../../config/jitsi_config.dart';
import '../../providers/firebase_auth_provider.dart';
import '../../widgets/custom_app_bar.dart';

/// Enhanced Jitsi Meet screen with full customization and feature control
class EnhancedJitsiMeetScreen extends ConsumerStatefulWidget {
  final MeetingType? meetingType;
  final String? customRoomName;
  final bool isModerator;

  const EnhancedJitsiMeetScreen({
    super.key,
    this.meetingType,
    this.customRoomName,
    this.isModerator = false,
  });

  @override
  ConsumerState<EnhancedJitsiMeetScreen> createState() => _EnhancedJitsiMeetScreenState();
}

class _EnhancedJitsiMeetScreenState extends ConsumerState<EnhancedJitsiMeetScreen> {
  final JitsiMeetService _jitsiService = JitsiMeetService();
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  
  bool _isLoading = false;
  bool _chatEnabled = JitsiConfig.featureFlags['chat.enabled'];
  bool _inviteEnabled = JitsiConfig.featureFlags['invite.enabled'];
  bool _liveStreamingEnabled = JitsiConfig.featureFlags['live-streaming.enabled'];
  bool _recordingEnabled = JitsiConfig.featureFlags['recording.enabled'];
  bool _tileViewEnabled = JitsiConfig.featureFlags['tile-view.enabled'];
  bool _toolboxAlwaysVisible = JitsiConfig.featureFlags['toolbox.alwaysVisible'];
  bool _addPeopleEnabled = JitsiConfig.featureFlags['add-people.enabled'];
  bool _raiseHandEnabled = JitsiConfig.featureFlags['raise-hand.enabled'];
  bool _helpEnabled = JitsiConfig.featureFlags['help.enabled'];
  bool _meetingNameEnabled = JitsiConfig.featureFlags['meeting-name.enabled'];
  bool _prejoinPageEnabled = JitsiConfig.featureFlags['prejoinpage.enabled'];
  bool _kickOutEnabled = JitsiConfig.featureFlags['kick-out.enabled'];

  @override
  void initState() {
    super.initState();
    _initializeService();
    _setupInitialValues();
  }

  Future<void> _initializeService() async {
    try {
      await _jitsiService.initialize();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize Jitsi Meet: $e')),
        );
      }
    }
  }

  void _setupInitialValues() {
    final user = ref.read(authStateProvider).user;
    
    // Set display name from user profile
    if (user != null) {
      _displayNameController.text = user.displayName ?? user.email ?? 'Anonymous';
    }

    // Set room name if predefined meeting type
    if (widget.meetingType != null) {
      final url = MeetingLinksConfig.getMeetingUrl(widget.meetingType!);
      _roomNameController.text = _extractRoomNameFromUrl(url);
    } else if (widget.customRoomName != null) {
      _roomNameController.text = widget.customRoomName!;
    }

    // Enable moderator features if user is moderator
    if (widget.isModerator) {
      _liveStreamingEnabled = true;
      _recordingEnabled = true;
      _kickOutEnabled = true;
    }
  }

  String _extractRoomNameFromUrl(String url) {
    final uri = Uri.parse(url);
    return uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'default-room';
  }

  Map<String, dynamic> _buildFeatureFlags() {
    return {
      'chat.enabled': _chatEnabled,
      'invite.enabled': _inviteEnabled,
      'live-streaming.enabled': _liveStreamingEnabled,
      'recording.enabled': _recordingEnabled,
      'tile-view.enabled': _tileViewEnabled,
      'toolbox.alwaysVisible': _toolboxAlwaysVisible,
      'add-people.enabled': _addPeopleEnabled,
      'raise-hand.enabled': _raiseHandEnabled,
      'help.enabled': _helpEnabled,
      'meeting-name.enabled': _meetingNameEnabled,
      'prejoinpage.enabled': _prejoinPageEnabled,
      'kick-out.enabled': _kickOutEnabled,
    };
  }

  Future<void> _joinMeeting() async {
    if (_roomNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a room name')),
      );
      return;
    }

    if (_displayNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your display name')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = ref.read(authStateProvider).user;
      
      await _jitsiService.joinMeeting(
        roomName: _roomNameController.text.trim(),
        displayName: _displayNameController.text.trim(),
        email: user?.email,
        avatarUrl: user?.photoURL,
        isModerator: widget.isModerator,
        customFeatureFlags: _buildFeatureFlags(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join meeting: $e')),
        );
      }
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
    return Scaffold(
      appBar: CustomAppBar(
        title: widget.meetingType?.displayName ?? 'Video Conference',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Meeting Info Section
            _buildMeetingInfoSection(),
            const SizedBox(height: 24),
            
            // Feature Flags Section
            _buildFeatureFlagsSection(),
            const SizedBox(height: 24),
            
            // Join Button
            _buildJoinButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Meeting Information',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            
            // Room Name
            TextFormField(
              controller: _roomNameController,
              decoration: const InputDecoration(
                labelText: 'Room Name',
                hintText: 'Enter meeting room name',
                border: OutlineInputBorder(),
              ),
              enabled: widget.meetingType == null && widget.customRoomName == null,
            ),
            const SizedBox(height: 16),
            
            // Display Name
            TextFormField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Your Display Name',
                hintText: 'Enter your name',
                border: OutlineInputBorder(),
              ),
            ),
            
            if (widget.meetingType != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This is a ${widget.meetingType!.displayName}',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureFlagsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Meeting Features',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            
            // Feature toggles
            _buildFeatureToggle('Chat', _chatEnabled, (value) => setState(() => _chatEnabled = value)),
            _buildFeatureToggle('Invite Others', _inviteEnabled, (value) => setState(() => _inviteEnabled = value)),
            _buildFeatureToggle('Live Streaming', _liveStreamingEnabled, (value) => setState(() => _liveStreamingEnabled = value), enabled: widget.isModerator),
            _buildFeatureToggle('Recording', _recordingEnabled, (value) => setState(() => _recordingEnabled = value), enabled: widget.isModerator),
            _buildFeatureToggle('Tile View', _tileViewEnabled, (value) => setState(() => _tileViewEnabled = value)),
            _buildFeatureToggle('Always Show Controls', _toolboxAlwaysVisible, (value) => setState(() => _toolboxAlwaysVisible = value)),
            _buildFeatureToggle('Add People', _addPeopleEnabled, (value) => setState(() => _addPeopleEnabled = value)),
            _buildFeatureToggle('Raise Hand', _raiseHandEnabled, (value) => setState(() => _raiseHandEnabled = value)),
            _buildFeatureToggle('Help Button', _helpEnabled, (value) => setState(() => _helpEnabled = value)),
            _buildFeatureToggle('Show Meeting Name', _meetingNameEnabled, (value) => setState(() => _meetingNameEnabled = value)),
            _buildFeatureToggle('Pre-join Page', _prejoinPageEnabled, (value) => setState(() => _prejoinPageEnabled = value)),
            _buildFeatureToggle('Kick Out Participants', _kickOutEnabled, (value) => setState(() => _kickOutEnabled = value), enabled: widget.isModerator),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureToggle(String title, bool value, ValueChanged<bool> onChanged, {bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: enabled ? null : Colors.grey,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }

  Widget _buildJoinButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _joinMeeting,
        icon: _isLoading 
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.video_call),
        label: Text(_isLoading ? 'Joining...' : 'Join Meeting'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }
}
