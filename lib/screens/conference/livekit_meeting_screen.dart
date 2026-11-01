import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../config/meeting_links_config.dart';
import '../../models/meeting_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meeting_provider.dart';
import '../../services/platform/media_permission_adapter.dart';
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
    // Auto-prompt media permissions upfront (Google Meet flow)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MediaPermissionService.requestMediaPermissions();
    });
  }

  String _initialRoomName() {
    if (widget.customRoomName != null) return widget.customRoomName!;
    if (widget.meetingType != null) {
      return widget.meetingType!.displayName;
    }
    return 'ALIVE Meeting';
  }

  String _getRoomSlug() {
    if (widget.meetingType != null) {
      return AliveMeetConfig.roomFor(widget.meetingType!);
    }
    final text = _roomController.text.trim();
    if (text.isEmpty) return 'alive-meet';
    return text.replaceAll(' ', '-').toLowerCase();
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

    // Google Meet flow: Auto-prompt microphone & camera upfront
    await MediaPermissionService.requestMediaPermissions();

    setState(() => _isJoining = true);
    try {
      final isAdmin = RoleAccessService.instance.canAccessAdmin() || widget.isModerator;
      final roomSlug = _getRoomSlug();
      final roomTitle = widget.meetingType?.displayName ?? roomName;

      await gateway.executionAndJoin(
        roomName: roomSlug,
        userId: user.uid,
        userName: user.displayNameOrFallback,
        meetingType: widget.meetingType?.name ?? 'general',
        notifyMembers: isAdmin && _notifyMembers,
        meetingTitle: roomTitle,
      );
    } catch (e) {
      final errStr = e.toString();
      debugPrint('[LiveKitMeetingScreen] Join error: $e');

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
      } else if (errStr.contains('No element') ||
          errStr.contains('Bad state')) {
        errorMessage =
            'ALIVE Meet connection interrupted. Please check your network and try again.';
      } else if (errStr.contains('permission') ||
          errStr.contains('NotAllowedError') ||
          errStr.contains('device') ||
          errStr.contains('NotFound') ||
          errStr.contains('not detected')) {
        errorMessage =
            'Microphone or camera not detected. Joining in listen-only mode.';
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

  void _showPermanentlyDeniedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
          'Microphone or camera permission is permanently disabled. Please allow access in App Settings to participate with audio and video.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await openAppSettings();
            },
            child: const Text('Open Settings'),
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
        showDonationButton: false,
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
                    initialRoomName: _roomController.text.trim(),
                    initialMeetingType: widget.meetingType?.displayName,
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
                labelText: 'Meeting Room',
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
            // Notice / Error banner
            if (session.error != null && !connected) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: session.error!.toLowerCase().contains('listen-only') ||
                          session.error!.toLowerCase().contains('device not detected')
                      ? Colors.amber.withValues(alpha: 0.15)
                      : Theme.of(context)
                          .colorScheme
                          .errorContainer
                          .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: session.error!.toLowerCase().contains('listen-only') ||
                            session.error!.toLowerCase().contains('device not detected')
                        ? Colors.amber.shade700.withValues(alpha: 0.4)
                        : Theme.of(context).colorScheme.error.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      session.error!.toLowerCase().contains('listen-only') ||
                              session.error!.toLowerCase().contains('device not detected')
                          ? Icons.info_outline_rounded
                          : Icons.error_outline,
                      color: session.error!.toLowerCase().contains('listen-only') ||
                              session.error!.toLowerCase().contains('device not detected')
                          ? Colors.amber.shade800
                          : Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        session.error!,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: session.error!.toLowerCase().contains('listen-only') ||
                                          session.error!.toLowerCase().contains('device not detected')
                                      ? (Theme.of(context).brightness == Brightness.dark
                                          ? Colors.amber.shade200
                                          : Colors.amber.shade900)
                                      : Theme.of(context).colorScheme.error,
                                ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (connected) ...[
              // Audio Lock notice banner
              if (session.isRoomAudioLocked) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_rounded, size: 16, color: Colors.amber.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isAdmin
                              ? 'Room Audio Locked: Standard participants cannot unmute themselves.'
                              : 'Microphones are locked by the host. Raise your hand to request to speak.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.amber.shade200
                                : Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      if (!isAdmin && !widget.isModerator && session.isRoomAudioLocked && isAudioMuted) {
                        _showMessage('The host has locked microphones. Raise your hand to ask to speak.');
                        return;
                      }
                      try {
                        await gateway.toggleAudio();
                      } catch (e) {
                        _showMessage(e.toString().replaceAll('Exception: ', ''));
                      }
                    },
                    icon: Icon(isAudioMuted ? Icons.mic_off : Icons.mic),
                    label: Text(
                      !isAdmin && !widget.isModerator && session.isRoomAudioLocked && isAudioMuted
                          ? 'Muted (Locked)'
                          : (isAudioMuted ? 'Unmute' : 'Mute'),
                    ),
                    style: !isAdmin && !widget.isModerator && session.isRoomAudioLocked && isAudioMuted
                        ? FilledButton.styleFrom(
                            backgroundColor: Colors.grey.shade700,
                          )
                        : null,
                  ),
                  FilledButton.icon(
                    onPressed: gateway.toggleVideo,
                    icon: Icon(isVideoMuted ? Icons.videocam_off : Icons.videocam),
                    label: Text(isVideoMuted ? 'Camera On' : 'Camera Off'),
                  ),
                  // Raise Hand button for all attendees
                  OutlinedButton.icon(
                    onPressed: () async {
                      final newRaised = !session.isHandRaised;
                      await gateway.raiseHand(raised: newRaised);
                      _showMessage(newRaised ? 'Hand raised' : 'Hand lowered');
                    },
                    icon: Icon(
                      session.isHandRaised ? Icons.pan_tool_rounded : Icons.pan_tool_outlined,
                      color: session.isHandRaised ? const Color(0xFFD49B28) : null,
                    ),
                    label: Text(session.isHandRaised ? 'Lower Hand' : 'Raise Hand'),
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

              // Host / Moderator Controls Area
              if (isAdmin || widget.isModerator) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1B2432)
                        : const Color(0xFFF3EBE0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFD49B28).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.admin_panel_settings_rounded, size: 16, color: Color(0xFFD49B28)),
                          SizedBox(width: 6),
                          Text(
                            'Host Moderation Controls',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD49B28),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          // "Mute All" button
                          ElevatedButton.icon(
                            onPressed: () async {
                              await gateway.muteAll();
                              _showMessage('Broadcast command sent: All participants muted.');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade800,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.volume_off_rounded, size: 16),
                            label: const Text('Mute All'),
                          ),
                          // Hard Lockout toggle ("Disallow Participants to Unmute")
                          OutlinedButton.icon(
                            onPressed: () async {
                              final newLock = !session.isRoomAudioLocked;
                              await gateway.setRoomAudioLock(newLock);
                              _showMessage(newLock
                                  ? 'Host Hard Lockout activated: Participants cannot unmute.'
                                  : 'Host Hard Lockout released: Participants can now unmute.');
                            },
                            icon: Icon(
                              session.isRoomAudioLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                              size: 16,
                            ),
                            label: Text(session.isRoomAudioLocked ? 'Unlock Mics' : 'Lock Mics'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

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
                      final displayName = _formatParticipantName(participant);
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : 'M',
                          ),
                        ),
                        title: Text(
                          participant.isLocal
                              ? '$displayName (You)'
                              : displayName,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (participant.isHandRaised) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD49B28).withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFD49B28), width: 1),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.pan_tool_rounded, size: 13, color: Color(0xFFD49B28)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Hand Raised',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD49B28)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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

  String _formatParticipantName(ParticipantInfo p) {
    if (p.isLocal) return 'You';
    final raw = p.name.trim();
    if (raw.isEmpty || raw == p.identity || (raw.length > 20 && !raw.contains(' '))) {
      return 'ALIVE Member';
    }
    return raw;
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
