import 'package:flutter/material.dart';

import '../../../models/meeting_models.dart';
import '../../../services/ports/meeting_gateway.dart';

/// Active participant list displaying names, roles (host/co-host), audio/video states,
/// raised hands, and interactive taps for management and private direct messaging.
class MeetingParticipantsList extends StatelessWidget {
  final MeetingSession session;
  final MeetingGateway gateway;
  final bool isLeader;
  final void Function(ParticipantInfo participant) onParticipantTap;
  final String Function(ParticipantInfo p) formatParticipantName;

  const MeetingParticipantsList({
    super.key,
    required this.session,
    required this.gateway,
    required this.isLeader,
    required this.onParticipantTap,
    required this.formatParticipantName,
  });

  @override
  Widget build(BuildContext context) {
    if (session.participants.isEmpty) {
      return const Expanded(
        child: Center(
          child: Text(
            'Connecting to stage audio...',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        itemCount: session.participants.length,
        itemBuilder: (context, index) {
          final participant = session.participants[index];
          final displayName = formatParticipantName(participant);

          return ListTile(
            onTap: () => onParticipantTap(participant),
            leading: CircleAvatar(
              backgroundImage: (participant.avatarUrl != null && participant.avatarUrl!.isNotEmpty)
                  ? NetworkImage(participant.avatarUrl!)
                  : null,
              child: (participant.avatarUrl != null && participant.avatarUrl!.isNotEmpty)
                  ? null
                  : Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : 'M',
                    ),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    participant.isLocal ? '$displayName (You)' : displayName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (gateway.isParticipantHost(participant.identity)) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD49B28).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFD49B28), width: 0.8),
                    ),
                    child: const Text(
                      'HOST',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD49B28),
                      ),
                    ),
                  ),
                ] else if (gateway.isParticipantCoHost(participant.identity)) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.teal, width: 0.8),
                    ),
                    child: const Text(
                      'CO-HOST',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              isLeader
                  ? 'Tap to manage (mute, video, host, co-host, direct message)'
                  : (participant.isLocal ? 'Tap for your audio/video controls' : 'Tap to send direct message'),
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
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
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD49B28),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Icon(
                  participant.isAudioMuted ? Icons.mic_off : Icons.mic,
                  size: 18,
                  color: participant.isAudioMuted ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 8),
                Icon(
                  participant.isVideoMuted ? Icons.videocam_off : Icons.videocam,
                  size: 18,
                  color: participant.isVideoMuted ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

