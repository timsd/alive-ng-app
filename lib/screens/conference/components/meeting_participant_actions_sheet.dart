import 'package:flutter/material.dart';

import '../../../models/meeting_models.dart';
import '../../../services/ports/meeting_gateway.dart';

/// Bottom sheet widget for moderating a specific conference participant
/// (promoting to host/co-host, muting, lowering hand, granting screen share, removing).
class MeetingParticipantActionsSheet extends StatelessWidget {
  final ParticipantInfo participant;
  final MeetingGateway gateway;
  final bool isLeaderOrHost;
  final void Function(String message) showMessage;
  final void Function(ParticipantInfo participant)? onStartDirectChat;

  const MeetingParticipantActionsSheet({
    super.key,
    required this.participant,
    required this.gateway,
    required this.isLeaderOrHost,
    required this.showMessage,
    this.onStartDirectChat,
  });

  static Future<void> show({
    required BuildContext context,
    required ParticipantInfo participant,
    required MeetingGateway gateway,
    required bool isLeaderOrHost,
    required void Function(String message) showMessage,
    void Function(ParticipantInfo participant)? onStartDirectChat,
  }) {
    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => MeetingParticipantActionsSheet(
        participant: participant,
        gateway: gateway,
        isLeaderOrHost: isLeaderOrHost,
        showMessage: showMessage,
        onStartDirectChat: onStartDirectChat,
      ),
    );
  }

  String _formatParticipantName(ParticipantInfo p) {
    if (p.name.isNotEmpty && !p.name.startsWith('user_') && !p.name.startsWith('guest_')) {
      return p.name;
    }
    return 'Participant (${p.identity.length > 5 ? p.identity.substring(0, 5) : p.identity})';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _formatParticipantName(participant);
    final theme = Theme.of(context);
    final isHost = gateway.isParticipantHost(participant.identity);
    final isCoHost = gateway.isParticipantCoHost(participant.identity);
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      fontSize: 12,
      height: 1.3,
    );

    return ListTileTheme(
      data: ListTileThemeData(subtitleTextStyle: subtitleStyle),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFFD49B28),
                    backgroundImage: (participant.avatarUrl != null && participant.avatarUrl!.isNotEmpty)
                        ? NetworkImage(participant.avatarUrl!)
                        : null,
                    child: (participant.avatarUrl != null && participant.avatarUrl!.isNotEmpty)
                        ? null
                        : Text(
                            displayName.isNotEmpty ? displayName[0].toUpperCase() : 'M',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          participant.isLocal ? '$displayName (You)' : displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          participant.isLocal
                              ? (isLeaderOrHost ? 'Host / Moderator (You)' : 'Participant (You)')
                              : (isHost
                                  ? 'Meeting Host'
                                  : (isCoHost ? 'Meeting Co-Host' : 'Meeting Participant')),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),

            // Local user options
            if (participant.isLocal) ...[
              ListTile(
                leading: Icon(
                  participant.isAudioMuted ? Icons.mic : Icons.mic_off,
                  color: participant.isAudioMuted ? Colors.green : Colors.red,
                ),
                title: Text(participant.isAudioMuted ? 'Unmute My Microphone' : 'Mute My Microphone'),
                onTap: () async {
                  Navigator.of(context).pop();
                  try {
                    await gateway.toggleAudio();
                  } catch (e) {
                    showMessage(e.toString().replaceAll('Exception: ', ''));
                  }
                },
              ),
              ListTile(
                leading: Icon(
                  participant.isVideoMuted ? Icons.videocam : Icons.videocam_off,
                  color: participant.isVideoMuted ? Colors.green : Colors.red,
                ),
                title: Text(participant.isVideoMuted ? 'Turn Camera On' : 'Turn Camera Off'),
                onTap: () async {
                  Navigator.of(context).pop();
                  try {
                    await gateway.toggleVideo();
                  } catch (e) {
                    showMessage(e.toString().replaceAll('Exception: ', ''));
                  }
                },
              ),
              ListTile(
                leading: Icon(
                  participant.isHandRaised ? Icons.pan_tool_outlined : Icons.pan_tool,
                  color: const Color(0xFFD49B28),
                ),
                title: Text(participant.isHandRaised ? 'Lower My Hand' : 'Raise My Hand'),
                onTap: () async {
                  Navigator.of(context).pop();
                  try {
                    await gateway.raiseHand(raised: !participant.isHandRaised);
                  } catch (e) {
                    showMessage(e.toString().replaceAll('Exception: ', ''));
                  }
                },
              ),
            ] else ...[
              // Direct 1-on-1 messaging for any remote participant
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFD49B28)),
                title: Text('Direct Message $displayName'),
                subtitle: const Text('Send a private 1-on-1 message in meeting chat'),
                onTap: () {
                  Navigator.of(context).pop();
                  onStartDirectChat?.call(participant);
                },
              ),

              if (isLeaderOrHost) ...[
                // Moderator / Host Controls over remote participant
              ListTile(
                leading: const Icon(Icons.mic_off_outlined, color: Colors.red),
                title: Text('Mute $displayName'),
                subtitle: const Text('Mutes their microphone across the meeting'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await gateway.muteParticipant(participant.identity);
                  showMessage('Muted $displayName');
                },
              ),
              if (participant.isHandRaised)
                ListTile(
                  leading: const Icon(Icons.pan_tool_rounded, color: Color(0xFFD49B28)),
                  title: Text('Lower Hand for $displayName'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await gateway.lowerParticipantHand(participant.identity);
                    showMessage('Lowered hand for $displayName');
                  },
                ),
              ListTile(
                leading: Icon(
                  isCoHost ? Icons.remove_moderator_outlined : Icons.add_moderator_outlined,
                  color: Colors.blue,
                ),
                title: Text(isCoHost ? 'Revoke Co-Host Rights' : 'Make Co-Host'),
                subtitle: Text(isCoHost
                    ? 'Reverts $displayName to a regular participant'
                    : 'Grants moderation, muting, and admission privileges'),
                onTap: () async {
                  Navigator.of(context).pop();
                  if (isCoHost) {
                    await gateway.revokeParticipantCoHost(participant.identity);
                    showMessage('Revoked co-host privileges from $displayName');
                  } else {
                    await gateway.makeParticipantCoHost(participant.identity);
                    showMessage('Appointed $displayName as Meeting Co-Host');
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.screen_share_outlined, color: Colors.teal),
                title: Text('Grant Screen Share'),
                subtitle: Text('Allows $displayName to present their screen to the room'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await gateway.grantScreenShare(participant.identity);
                  showMessage('Screen share permission granted to $displayName');
                },
              ),
              // Assign to breakout room if active
              if (gateway.currentSession.isBreakoutActive)
                ListTile(
                  leading: const Icon(Icons.workspaces_outlined, color: Colors.teal),
                  title: Text('Move to Breakout Room'),
                  subtitle: const Text('Assign this participant to a specific breakout session'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showBreakoutRoomPicker(context, displayName);
                  },
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person_remove_outlined, color: Colors.red),
                title: Text(
                  'Remove $displayName from Meeting',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  await gateway.removeParticipant(participant.identity);
                  showMessage('Removed $displayName from the meeting');
                },
              ),
            ] else ...[
              // Standard attendee viewing another attendee
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(displayName),
                subtitle: Text(isHost ? 'Meeting Host' : (isCoHost ? 'Meeting Co-Host' : 'Participant')),
              ),
            ],
          ],
        ],
      ),
      ),
    ),
    );
  }

  void _showBreakoutRoomPicker(BuildContext context, String displayName) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Move $displayName to:'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: gateway.currentSession.breakoutRooms.map((r) {
            return ListTile(
              title: Text(r.name),
              onTap: () async {
                Navigator.of(dialogCtx).pop();
                await gateway.assignParticipantToBreakout(
                  participantId: participant.identity,
                  participantName: displayName,
                  targetRoomId: r.id,
                );
                showMessage('Assigned $displayName to ${r.name}');
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

