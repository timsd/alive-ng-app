import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/meeting_links_config.dart';
import '../../services/appwrite_auth_service.dart';
import '../../services/livekit_meeting_service.dart';
import '../../widgets/custom_app_bar.dart';

class LiveKitMeetingScreen extends ConsumerStatefulWidget {
  final MeetingType? meetingType;
  final String? customRoomName;
  final bool isModerator;

  const LiveKitMeetingScreen({
    super.key,
    this.meetingType,
    this.customRoomName,
    this.isModerator = false,
  });

  @override
  ConsumerState<LiveKitMeetingScreen> createState() =>
      _LiveKitMeetingScreenState();
}

class _LiveKitMeetingScreenState extends ConsumerState<LiveKitMeetingScreen> {
  final LiveKitMeetingService _meetingService = LiveKitMeetingService();
  late final TextEditingController _roomController;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _roomController = TextEditingController(text: _initialRoomName());
    _meetingService.addListener(_onMeetingChanged);
  }

  String _initialRoomName() {
    if (widget.customRoomName != null) return widget.customRoomName!;
    if (widget.meetingType != null) {
      final url = MeetingLinksConfig.getMeetingUrl(widget.meetingType!);
      final uri = Uri.tryParse(url);
      return uri?.pathSegments.isNotEmpty == true
          ? uri!.pathSegments.last
          : widget.meetingType!.name;
    }
    return '';
  }

  void _onMeetingChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _joinMeeting() async {
    final roomName = _roomController.text.trim();
    if (roomName.isEmpty) {
      _showMessage('Enter a room name before joining.');
      return;
    }

    final user = ref.read(appwriteUserProvider);
    if (user == null) {
      _showMessage('Please sign in before joining a meeting.');
      return;
    }

    setState(() => _isJoining = true);
    try {
      await _meetingService.executionAndJoin(
        roomName: roomName,
        userId: user.$id,
        userName: user.name.isNotEmpty ? user.name : user.email,
      );
    } catch (e) {
      _showMessage('Failed to join LiveKit room: $e');
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connected = _meetingService.isConnected;

    return Scaffold(
      appBar: CustomAppBar(
        title: widget.meetingType?.displayName ?? 'LiveKit Meeting',
        showBackButton: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _roomController,
              decoration: const InputDecoration(
                labelText: 'Room',
                border: OutlineInputBorder(),
              ),
              readOnly: widget.meetingType != null || widget.customRoomName != null,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isJoining || connected ? null : _joinMeeting,
              icon: _isJoining
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.video_call),
              label: Text(connected ? 'Connected' : 'Join Meeting'),
            ),
            const SizedBox(height: 16),
            if (connected)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: _meetingService.toggleAudio,
                    icon: Icon(_meetingService.isAudioMuted
                        ? Icons.mic_off
                        : Icons.mic),
                    label: Text(_meetingService.isAudioMuted
                        ? 'Unmute'
                        : 'Mute'),
                  ),
                  FilledButton.icon(
                    onPressed: _meetingService.toggleVideo,
                    icon: Icon(_meetingService.isVideoMuted
                        ? Icons.videocam_off
                        : Icons.videocam),
                    label: Text(_meetingService.isVideoMuted
                        ? 'Camera On'
                        : 'Camera Off'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _meetingService.leaveMeeting,
                    icon: const Icon(Icons.call_end),
                    label: const Text('Leave'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _meetingService.removeListener(_onMeetingChanged);
    _meetingService.dispose();
    _roomController.dispose();
    super.dispose();
  }
}
