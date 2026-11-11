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
  final void Function(ParticipantInfo participant)? onDirectChat;
  final String Function(ParticipantInfo p) formatParticipantName;

  const MeetingParticipantsList({
    super.key,
    required this.session,
    required this.gateway,
    required this.isLeader,
    required this.onParticipantTap,
    this.onDirectChat,
    required this.formatParticipantName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final participants = session.participants.isNotEmpty
        ? session.participants
        : [
            ParticipantInfo(
              identity: 'local',
              name: 'You',
              isLocal: true,
              isAudioEnabled: !session.isAudioMuted,
              isVideoEnabled: !session.isVideoMuted,
              isHandRaised: session.isHandRaised,
            )
          ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final participant = participants[index];
        final displayName = formatParticipantName(participant);
        final isHost = gateway.isParticipantHost(participant.identity);
        final isCoHost = gateway.isParticipantCoHost(participant.identity);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            onTap: () {
              if (!participant.isLocal && !isLeader && onDirectChat != null) {
                onDirectChat!(participant);
              } else {
                onParticipantTap(participant);
              }
            },
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: participant.isLocal
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF0D9488),
              backgroundImage: (participant.avatarUrl != null && participant.avatarUrl!.isNotEmpty)
                  ? NetworkImage(participant.avatarUrl!)
                  : null,
              onBackgroundImageError: (participant.avatarUrl != null && participant.avatarUrl!.isNotEmpty)
                  ? (_, __) {}
                  : null,
              child: (participant.avatarUrl != null && participant.avatarUrl!.isNotEmpty)
                  ? null
                  : Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : 'M',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    participant.isLocal ? '$displayName (You)' : displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isHost) ...[
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
                ] else if (isCoHost) ...[
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
              participant.isLocal
                  ? 'Your audio/video controls'
                  : (isLeader
                      ? 'Tap for options or 💬 to direct chat'
                      : 'Tap to direct chat with $displayName'),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (participant.isHandRaised) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD49B28).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD49B28), width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pan_tool_rounded, size: 13, color: Color(0xFFD49B28)),
                        SizedBox(width: 4),
                        Text(
                          'Raised',
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
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: (participant.isAudioMuted ? Colors.red : Colors.green).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    participant.isAudioMuted ? Icons.mic_off : Icons.mic,
                    size: 16,
                    color: participant.isAudioMuted ? Colors.red : Colors.green,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: (participant.isVideoMuted ? Colors.red : Colors.green).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    participant.isVideoMuted ? Icons.videocam_off : Icons.videocam,
                    size: 16,
                    color: participant.isVideoMuted ? Colors.red : Colors.green,
                  ),
                ),
                if (!participant.isLocal) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Direct chat with $displayName',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (onDirectChat != null) {
                            onDirectChat!(participant);
                          } else {
                            onParticipantTap(participant);
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 16,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
