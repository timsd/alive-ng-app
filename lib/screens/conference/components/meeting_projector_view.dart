import 'package:flutter/material.dart';

import '../../../utils/error_handler.dart';
import '../../../models/meeting_models.dart';
import '../../../services/ports/meeting_gateway.dart';
import 'meeting_stage_view.dart';

/// Full screen immersive Projector / Stage Display widget for ALIVE sanctuary screens and TVs.
class MeetingProjectorView extends StatelessWidget {
  final MeetingSession session;
  final MeetingGateway gateway;
  final bool isLeader;
  final bool canShareScreen;
  final String roomTitle;
  final VoidCallback onExitProjector;
  final VoidCallback onOpenBreakoutRooms;
  final VoidCallback onLeaveMeeting;
  final void Function(ParticipantInfo participant) onParticipantTap;
  final void Function(String message) showMessage;

  const MeetingProjectorView({
    super.key,
    required this.session,
    required this.gateway,
    required this.isLeader,
    required this.canShareScreen,
    required this.roomTitle,
    required this.onExitProjector,
    required this.onOpenBreakoutRooms,
    required this.onLeaveMeeting,
    required this.onParticipantTap,
    required this.showMessage,
  });

  @override
  Widget build(BuildContext context) {
    final activePresenter = session.activeScreenShareName;
    final isPresenting = session.isScreenShareEnabled || activePresenter != null;

    return SafeArea(
      child: Stack(
        children: [
          // Main Stage Canvas
          Column(
            children: [
              // Projector Header Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: const Color(0xFF111418),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      tooltip: 'Exit Projector Display',
                      onPressed: onExitProjector,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: session.isInBreakoutRoom
                            ? Colors.teal.shade800
                            : Colors.red.shade900,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            session.isInBreakoutRoom
                                ? Icons.workspaces_rounded
                                : Icons.fiber_manual_record,
                            size: 10,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            session.isInBreakoutRoom ? 'BREAKOUT' : 'LIVE STAGE',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.isInBreakoutRoom
                                ? (session.activeBreakoutRoomName ?? 'Breakout Room')
                                : roomTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            isPresenting
                                ? 'Screen Share: ${activePresenter ?? "You are presenting"}'
                                : 'Attendees: ${session.participants.length} connected',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (isLeader || session.isBreakoutActive)
                      IconButton(
                        icon: const Icon(Icons.workspaces_rounded, color: Colors.white),
                        tooltip: 'Breakout Rooms',
                        onPressed: onOpenBreakoutRooms,
                      ),
                    IconButton(
                      icon: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white),
                      tooltip: 'Exit Projector Display',
                      onPressed: onExitProjector,
                    ),
                  ],
                ),
              ),

              // Central Stage Area (Optimized for Sanctuary / Conference Projectors)
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFF0A0D11),
                  child: Center(
                    child: isPresenting
                        ? MeetingScreenShareStage(session: session, gateway: gateway)
                        : MeetingVideoGridStage(
                            session: session,
                            gateway: gateway,
                            isLeader: isLeader,
                            onParticipantTap: onParticipantTap,
                          ),
                  ),
                ),
              ),

              // Floating Controls Bar at Bottom
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: const Color(0xFF111418),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      onPressed: () async {
                        try {
                          await gateway.toggleAudio();
                        } catch (e) {
                          showMessage(e.toString().replaceAll('Exception: ', ''));
                        }
                      },
                      icon: Icon(session.isAudioMuted ? Icons.mic_off : Icons.mic),
                      style: IconButton.styleFrom(
                        backgroundColor: session.isAudioMuted
                            ? Colors.red.withValues(alpha: 0.3)
                            : Colors.green.withValues(alpha: 0.3),
                        foregroundColor: session.isAudioMuted ? Colors.red : Colors.green,
                      ),
                      tooltip: session.isAudioMuted ? 'Unmute' : 'Mute',
                    ),
                    const SizedBox(width: 14),
                    IconButton.filledTonal(
                      onPressed: () async {
                        try {
                          await gateway.toggleVideo();
                        } catch (e) {
                          showMessage(e.toString().replaceAll('Exception: ', ''));
                        }
                      },
                      icon: Icon(session.isVideoMuted ? Icons.videocam_off : Icons.videocam),
                      style: IconButton.styleFrom(
                        backgroundColor: session.isVideoMuted
                            ? Colors.red.withValues(alpha: 0.3)
                            : Colors.blue.withValues(alpha: 0.3),
                        foregroundColor: session.isVideoMuted ? Colors.red : Colors.blue,
                      ),
                      tooltip: session.isVideoMuted ? 'Camera On' : 'Camera Off',
                    ),
                    if (canShareScreen) ...[
                      const SizedBox(width: 14),
                      IconButton.filledTonal(
                        onPressed: () async {
                          try {
                            await gateway.toggleScreenShare();
                            showMessage(session.isScreenShareEnabled
                                ? 'Screen sharing stopped.'
                                : 'Screen sharing started.');
                          } catch (e) {
                            showMessage(ErrorHandler.getUserFriendlyMessage(e));
                          }
                        },
                        icon: Icon(session.isScreenShareEnabled
                            ? Icons.stop_screen_share_rounded
                            : Icons.screen_share_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: session.isScreenShareEnabled
                              ? Colors.teal.shade700
                              : Colors.white12,
                          foregroundColor: Colors.white,
                        ),
                        tooltip: session.isScreenShareEnabled
                            ? 'Stop Sharing'
                            : 'Share Screen',
                      ),
                    ],
                    if (isLeader || session.isBreakoutActive) ...[
                      const SizedBox(width: 14),
                      IconButton.filledTonal(
                        onPressed: onOpenBreakoutRooms,
                        icon: const Icon(Icons.workspaces_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: session.isBreakoutActive
                              ? Colors.teal.shade700
                              : Colors.white12,
                          foregroundColor: Colors.white,
                        ),
                        tooltip: 'Breakout Rooms',
                      ),
                    ],
                    const SizedBox(width: 14),
                    IconButton.filledTonal(
                      onPressed: onExitProjector,
                      icon: const Icon(Icons.view_compact_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white12,
                        foregroundColor: Colors.white,
                      ),
                      tooltip: 'Standard Meeting View',
                    ),
                    const SizedBox(width: 14),
                    IconButton.filledTonal(
                      onPressed: onLeaveMeeting,
                      icon: const Icon(Icons.call_end),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.shade900,
                        foregroundColor: Colors.white,
                      ),
                      tooltip: 'Leave Meeting',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

