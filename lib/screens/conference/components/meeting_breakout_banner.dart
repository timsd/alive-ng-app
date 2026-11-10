import 'package:flutter/material.dart';

import '../../../models/meeting_models.dart';
import '../../../services/ports/meeting_gateway.dart';

/// Banner shown when breakout sessions or sub-rooms are active in a meeting.
class MeetingBreakoutBanner extends StatelessWidget {
  final MeetingSession session;
  final MeetingGateway gateway;
  final bool isLeader;
  final VoidCallback onOpenBreakoutRooms;
  final VoidCallback onAskHostHelp;
  final VoidCallback onReturnToMainRoom;
  final String Function(DateTime? endsAt) formatRemaining;

  const MeetingBreakoutBanner({
    super.key,
    required this.session,
    required this.gateway,
    required this.isLeader,
    required this.onOpenBreakoutRooms,
    required this.onAskHostHelp,
    required this.onReturnToMainRoom,
    required this.formatRemaining,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = formatRemaining(session.breakoutEndsAt);
    final inSubRoom = session.isInBreakoutRoom;
    final broadcastMsg = session.breakoutBroadcastMessage;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade600.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.workspaces_rounded,
                size: 18,
                color: Colors.teal.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  inSubRoom
                      ? 'Breakout Room: ${session.activeBreakoutRoomName}'
                      : 'Breakout Sessions Active (${session.breakoutRooms.length} Rooms)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              if (remaining.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade800,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        remaining,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (broadcastMsg != null && broadcastMsg.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFD49B28).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.campaign_rounded, size: 16, color: Color(0xFFD49B28)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Host Broadcast: $broadcastMsg',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: onOpenBreakoutRooms,
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: Text(inSubRoom ? 'Switch / View Rooms' : 'View / Join Rooms'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              if (inSubRoom && !isLeader)
                OutlinedButton.icon(
                  onPressed: onAskHostHelp,
                  icon: const Icon(Icons.support_agent_rounded, size: 16),
                  label: const Text('Ask Host for Help'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              if (inSubRoom)
                OutlinedButton.icon(
                  onPressed: onReturnToMainRoom,
                  icon: const Icon(Icons.keyboard_return_rounded, size: 16),
                  label: const Text('Return to Main Room'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

