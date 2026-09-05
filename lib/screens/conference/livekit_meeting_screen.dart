import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/meeting_links_config.dart';
import '../../models/meeting_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meeting_provider.dart';
import '../../services/ports/meeting_gateway.dart';
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
  late final TextEditingController _roomController;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _roomController = TextEditingController(text: _initialRoomName());
  }

  String _initialRoomName() {
    if (widget.customRoomName != null) return widget.customRoomName!;
    if (widget.meetingType != null) {
      final url = AliveMeetConfig.roomFor(widget.meetingType!);
      final uri = Uri.tryParse(url);
      return uri?.pathSegments.isNotEmpty == true
          ? uri!.pathSegments.last
          : widget.meetingType!.name;
    }
    return '';
  }

  Future<void> _joinMeeting(MeetingGateway gateway) async {
    final roomName = _roomController.text.trim();
    if (roomName.isEmpty) {
      _showMessage('Enter a room name before joining.');
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      _showMessage('Please sign in before joining a meeting.');
      return;
    }

    setState(() => _isJoining = true);
    try {
      await gateway.executionAndJoin(
        roomName: roomName,
        userId: user.uid,
        userName: user.displayNameOrFallback,
        meetingType: widget.meetingType?.name ?? 'general',
      );
    } catch (e) {
      _showMessage(
          'ALIVE Meet could not be joined. Please check your connection and try again.');
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
    final gateway = ref.watch(meetingGatewayProvider);
    final sessionAsync = ref.watch(meetingSessionStreamProvider);
    final MeetingSession session =
        sessionAsync.value ?? gateway.currentSession;
    final connected = session.isConnected;
    final isAudioMuted = session.isAudioMuted;
    final isVideoMuted = session.isVideoMuted;

    return Scaffold(
      appBar: CustomAppBar(
        title: widget.meetingType?.displayName ?? 'ALIVE Meet',
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
                labelText: 'ALIVE Meet room',
                border: OutlineInputBorder(),
              ),
              readOnly:
                  widget.meetingType != null || widget.customRoomName != null,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isJoining || connected
                  ? null
                  : () => _joinMeeting(gateway),
              icon: _isJoining
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.video_call),
              label: Text(connected ? 'Connected' : 'Join ALIVE Meet'),
            ),
            const SizedBox(height: 16),
            if (connected) ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: gateway.toggleAudio,
                    icon: Icon(isAudioMuted ? Icons.mic_off : Icons.mic),
                    label: Text(isAudioMuted ? 'Unmute' : 'Mute'),
                  ),
                  FilledButton.icon(
                    onPressed: gateway.toggleVideo,
                    icon: Icon(isVideoMuted ? Icons.videocam_off : Icons.videocam),
                    label: Text(isVideoMuted ? 'Camera On' : 'Camera Off'),
                  ),
                  OutlinedButton.icon(
                    onPressed: gateway.leaveMeeting,
                    icon: const Icon(Icons.call_end),
                    label: const Text('Leave'),
                  ),
                ],
              ),
              if (session.participants.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Participants (${session.participants.length}):',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: session.participants.length,
                    itemBuilder: (context, index) {
                      final participant = session.participants[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            participant.name.isNotEmpty
                                ? participant.name[0].toUpperCase()
                                : '?',
                          ),
                        ),
                        title: Text(
                          participant.isLocal
                              ? '${participant.name} (You)'
                              : participant.name,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              participant.isAudioMuted
                                  ? Icons.mic_off
                                  : Icons.mic,
                              size: 18,
                              color: participant.isAudioMuted
                                  ? Colors.red
                                  : Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              participant.isVideoMuted
                                  ? Icons.videocam_off
                                  : Icons.videocam,
                              size: 18,
                              color: participant.isVideoMuted
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _roomController.dispose();
    super.dispose();
  }
}
