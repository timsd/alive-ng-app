import 'package:flutter/material.dart';

import '../../../models/meeting_models.dart';
import '../../../services/ports/meeting_gateway.dart';

/// Modal bottom sheet widget for secondary meeting tools & host moderation controls.
class MeetingMoreActionsSheet extends StatelessWidget {
  final MeetingSession session;
  final MeetingGateway gateway;
  final bool isLeader;
  final bool isBroadcasting;
  final VoidCallback onOpenBreakoutRooms;
  final VoidCallback onOpenProjector;
  final VoidCallback onOpenScribe;
  final VoidCallback onShareLink;
  final VoidCallback onReturnToMainRoom;
  final VoidCallback onMuteAll;
  final ValueChanged<bool> onToggleMicLock;
  final ValueChanged<bool> onToggleWaitingRoom;
  final VoidCallback onToggleBroadcast;
  final VoidCallback onEndMeetingForAll;

  const MeetingMoreActionsSheet({
    super.key,
    required this.session,
    required this.gateway,
    required this.isLeader,
    required this.isBroadcasting,
    required this.onOpenBreakoutRooms,
    required this.onOpenProjector,
    required this.onOpenScribe,
    required this.onShareLink,
    required this.onReturnToMainRoom,
    required this.onMuteAll,
    required this.onToggleMicLock,
    required this.onToggleWaitingRoom,
    required this.onToggleBroadcast,
    required this.onEndMeetingForAll,
  });

  static Future<void> show({
    required BuildContext context,
    required MeetingSession session,
    required MeetingGateway gateway,
    required bool isLeader,
    required bool isBroadcasting,
    required VoidCallback onOpenBreakoutRooms,
    required VoidCallback onOpenProjector,
    required VoidCallback onOpenScribe,
    required VoidCallback onShareLink,
    required VoidCallback onReturnToMainRoom,
    required VoidCallback onMuteAll,
    required ValueChanged<bool> onToggleMicLock,
    required ValueChanged<bool> onToggleWaitingRoom,
    required VoidCallback onToggleBroadcast,
    required VoidCallback onEndMeetingForAll,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => MeetingMoreActionsSheet(
        session: session,
        gateway: gateway,
        isLeader: isLeader,
        isBroadcasting: isBroadcasting,
        onOpenBreakoutRooms: onOpenBreakoutRooms,
        onOpenProjector: onOpenProjector,
        onOpenScribe: onOpenScribe,
        onShareLink: onShareLink,
        onReturnToMainRoom: onReturnToMainRoom,
        onMuteAll: onMuteAll,
        onToggleMicLock: onToggleMicLock,
        onToggleWaitingRoom: onToggleWaitingRoom,
        onToggleBroadcast: onToggleBroadcast,
        onEndMeetingForAll: onEndMeetingForAll,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      fontSize: 12,
      height: 1.3,
    );

    return ListTileTheme(
      data: ListTileThemeData(subtitleTextStyle: subtitleStyle),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.apps_rounded, color: Color(0xFFD49B28)),
                      const SizedBox(width: 8),
                      Text(
                        'Meeting Actions & Tools',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(),

                // Quick tools
                ListTile(
                  leading: Badge(
                    isLabelVisible: session.isBreakoutActive,
                    label: Text('${session.breakoutRooms.length}'),
                    child: const Icon(Icons.workspaces_rounded, color: Colors.teal),
                  ),
                  title: const Text('Breakout Rooms'),
                  subtitle: Text(
                    session.isBreakoutActive
                        ? 'Active sessions (${session.breakoutRooms.length} rooms)'
                        : (isLeader ? 'Create and assign discussion sub-rooms' : 'View breakout rooms'),
                    style: subtitleStyle,
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    onOpenBreakoutRooms();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.tv_rounded, color: Colors.blueAccent),
                  title: const Text('Projector / Full Stage Display'),
                  subtitle: Text(
                    'Optimal viewing for projectors and shared TV screens',
                    style: subtitleStyle,
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    onOpenProjector();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.draw_rounded, color: Color(0xFFD49B28)),
                  title: const Text('ALIVE Scribe & Minutes'),
                  subtitle: Text(
                    'Real-time speech-to-text notes and transcript export',
                    style: subtitleStyle,
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    onOpenScribe();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share_rounded, color: Colors.purple),
                  title: const Text('Share Meeting Link'),
                  subtitle: Text(
                    'Copy invitation link or share via WhatsApp / Email',
                    style: subtitleStyle,
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    onShareLink();
                  },
                ),
                if (session.isInBreakoutRoom)
                  ListTile(
                    leading: const Icon(Icons.keyboard_return_rounded, color: Colors.amber),
                    title: const Text('Return to Main Plenary Room'),
                    subtitle: Text(
                      'Leave breakout session and rejoin plenary room',
                      style: subtitleStyle,
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      onReturnToMainRoom();
                    },
                  ),

                // Host / Leader section
                if (isLeader) ...[
                  const Divider(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.admin_panel_settings_rounded, size: 18, color: Color(0xFFD49B28)),
                        const SizedBox(width: 8),
                        Text(
                          'Host Moderation Controls',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFD49B28),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.volume_off_rounded, color: Colors.red),
                    title: const Text('Mute All Participants'),
                    subtitle: Text(
                      'Instantly mutes microphones for everyone except host',
                      style: subtitleStyle,
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      onMuteAll();
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      session.isRoomAudioLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                      color: session.isRoomAudioLocked ? Colors.green : Colors.orange,
                    ),
                    title: Text(session.isRoomAudioLocked
                        ? 'Unlock Participant Microphones'
                        : 'Lock All Microphones (Disallow Unmuting)'),
                    subtitle: Text(
                      session.isRoomAudioLocked
                          ? 'Participants are now permitted to unmute themselves'
                          : 'Participants cannot unmute unless granted permission',
                      style: subtitleStyle,
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      onToggleMicLock(!session.isRoomAudioLocked);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      session.isWaitingRoomEnabled ? Icons.door_sliding : Icons.meeting_room_outlined,
                      color: session.isWaitingRoomEnabled ? const Color(0xFFD49B28) : Colors.grey,
                    ),
                    title: Text(session.isWaitingRoomEnabled
                        ? 'Waiting Room: Active (Host Approval Required)'
                        : 'Waiting Room: Off (Direct Join)'),
                    subtitle: Text(
                      'Require host to admit new attendees from virtual lobby',
                      style: subtitleStyle,
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      onToggleWaitingRoom(!session.isWaitingRoomEnabled);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      isBroadcasting ? Icons.stop_rounded : Icons.live_tv_rounded,
                      color: isBroadcasting ? Colors.red : Colors.blue,
                    ),
                    title: Text(isBroadcasting
                        ? 'Stop YouTube Live Broadcast'
                        : 'Go Live (Broadcast to YouTube)'),
                    subtitle: Text(
                      'Stream meeting output via LiveKit cloud egress',
                      style: subtitleStyle,
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      onToggleBroadcast();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.power_settings_new_rounded, color: Colors.red),
                    title: const Text('End Meeting for All',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'Disconnects all participants and closes room',
                      style: subtitleStyle,
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      onEndMeetingForAll();
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

