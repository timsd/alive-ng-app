import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../config/meeting_links_config.dart';
import '../../models/meeting_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meeting_provider.dart';
import '../../services/ports/meeting_gateway.dart';
import '../../services/role_access_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../admin/leader_meeting_transcription_screen.dart';

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
  bool _isBroadcasting = false;
  bool _notifyMembers = true;
  String? _activeEgressId;

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

    // Proactively request camera & microphone permissions
    if (!kIsWeb) {
      try {
        final statuses = await [
          Permission.camera,
          Permission.microphone,
        ].request();
        debugPrint('Media permissions requested: $statuses');
      } catch (permErr) {
        debugPrint('Media permission request error: $permErr');
      }
    }

    setState(() => _isJoining = true);
    try {
      final isAdmin = RoleAccessService.instance.canAccessAdmin() || widget.isModerator;
      await gateway.executionAndJoin(
        roomName: roomName,
        userId: user.uid,
        userName: user.displayNameOrFallback,
        meetingType: widget.meetingType?.name ?? 'general',
        notifyMembers: isAdmin && _notifyMembers,
        meetingTitle: roomName,
      );
    } catch (e) {
      final errStr = e.toString();
      final isPermissionOrDeviceError = errStr.contains('No element') ||
          errStr.contains('Bad state') ||
          errStr.contains('permission') ||
          errStr.contains('NotAllowedError') ||
          errStr.contains('NotFoundError') ||
          errStr.contains('device') ||
          errStr.contains('MediaStream');

      if (isPermissionOrDeviceError) {
        _showPermissionDialog(gateway);
        return;
      }

      // Extract user-friendly error message
      String errorMessage =
          'ALIVE Meet could not be joined. Please check your connection and try again.';
      if (errStr.contains('certificate') ||
          errStr.contains('SSL') ||
          errStr.contains('TLS')) {
        errorMessage =
            'SSL certificate error. The LiveKit server certificate may be self-signed or expired.';
      } else if (errStr.contains('timeout')) {
        errorMessage =
            'Connection timed out. Please check your internet connection.';
      } else if (errStr.contains('Token not found')) {
        errorMessage =
            'Failed to generate meeting token. Please try again later.';
      } else if (e is Exception) {
        final cleanMsg = errStr.replaceAll('Exception: ', '').trim();
        if (cleanMsg.isNotEmpty && cleanMsg.length < 120) {
          errorMessage = cleanMsg;
        }
      }
      _showMessage(errorMessage);
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  Future<void> _showPermissionDialog(MeetingGateway gateway) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFE5B94D).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mic_none_rounded,
            size: 32,
            color: Color(0xFFD49B28),
          ),
        ),
        title: const Text(
          'Allow Camera & Microphone',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ALIVE Meet requires access to your microphone and camera to connect your audio and video.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        kIsWeb ? Icons.language : Icons.settings,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        kIsWeb
                            ? 'How to allow in browser:'
                            : 'How to allow in settings:',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    kIsWeb
                        ? '1. Click the permissions or lock icon in the address bar.\n2. Set Camera and Microphone to "Allow".\n3. Tap "Restart & Join" below.'
                        : '1. Tap "Open App Settings" below.\n2. Enable Camera and Microphone permissions.\n3. Return here and tap "Restart & Join".',
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          if (!kIsWeb)
            OutlinedButton(
              onPressed: () async {
                await openAppSettings();
              },
              child: const Text('Open App Settings'),
            ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              _joinMeeting(gateway);
            },
            child: const Text('Restart & Join'),
          ),
        ],
      ),
    );
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

    final isAdmin = RoleAccessService.instance.canAccessAdmin() || widget.isModerator;

    return Scaffold(
      appBar: CustomAppBar(
        title: widget.meetingType?.displayName ?? 'ALIVE Meet',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.note_alt_outlined),
            tooltip: 'Scribe & Notes',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LeaderMeetingTranscriptionScreen(
                    initialMeetingTitle:
                        widget.meetingType?.displayName ?? _roomController.text,
                  ),
                ),
              );
            },
          ),
        ],
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
              readOnly: !isAdmin && (widget.meetingType != null || widget.customRoomName != null),
            ),
            if (isAdmin && !connected) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Notify members via push notification'),
                subtitle: const Text('Sends a background push notification when meeting starts'),
                value: _notifyMembers,
                onChanged: (val) => setState(() => _notifyMembers = val),
              ),
            ],
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
              label: Text(_isJoining
                  ? 'Joining...'
                  : connected
                      ? 'Connected'
                      : (isAdmin ? 'Start / Join ALIVE Meet' : 'Join ALIVE Meet')),
            ),
            // Connection status banner
            if (session.status == RoomStatus.connecting ||
                session.status == RoomStatus.reconnecting) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        session.status == RoomStatus.reconnecting
                            ? 'Reconnecting to meeting...'
                            : 'Connecting to meeting...',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Error banner
            if (session.error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .errorContainer
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        session.error!,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                  // Go Live button — streams to YouTube via LiveKit egress
                  if (widget.isModerator)
                    FilledButton.icon(
                      onPressed: _isBroadcasting
                          ? () => _stopBroadcast(gateway)
                          : () => _startBroadcast(gateway),
                      icon: Icon(_isBroadcasting ? Icons.stop : Icons.live_tv),
                      label: Text(_isBroadcasting ? 'Stop Live' : 'Go Live'),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            _isBroadcasting ? Colors.red : null,
                      ),
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

  Future<void> _startBroadcast(MeetingGateway gateway) async {
    final meetingType = widget.meetingType?.name ?? 'general';
    try {
      final egressId = await gateway.startBroadcast(meetingType: meetingType);
      if (!mounted) return;
      setState(() {
        _isBroadcasting = true;
        _activeEgressId = egressId;
      });
      _showMessage('Live stream started');
    } catch (e) {
      _showMessage('Go Live failed: $e');
    }
  }

  Future<void> _stopBroadcast(MeetingGateway gateway) async {
    if (_activeEgressId == null) return;
    try {
      await gateway.stopBroadcast(egressId: _activeEgressId!);
      if (!mounted) return;
      setState(() {
        _isBroadcasting = false;
        _activeEgressId = null;
      });
      _showMessage('Live stream stopped');
    } catch (e) {
      _showMessage('Stop Live failed: $e');
    }
  }

  @override
  void dispose() {
    _roomController.dispose();
    super.dispose();
  }
}
