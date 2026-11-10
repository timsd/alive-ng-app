import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/meeting_models.dart';
import '../../../providers/meeting_provider.dart';
import '../livekit_meeting_screen.dart';

/// Global floating Picture-in-Picture / overlay widget for active meetings.
/// Displayed when a user minimizes an active conference to browse other parts of the app.
class MeetingFloatingOverlay extends ConsumerStatefulWidget {
  const MeetingFloatingOverlay({super.key});

  @override
  ConsumerState<MeetingFloatingOverlay> createState() => _MeetingFloatingOverlayState();
}

class _MeetingFloatingOverlayState extends ConsumerState<MeetingFloatingOverlay> {
  Offset? _position;

  void _expandMeeting(BuildContext context, MeetingSession session) {
    ref.read(isMeetingMinimizedProvider.notifier).state = false;

    // Navigate or push back to LiveKitMeetingScreen
    final nav = Navigator.of(context, rootNavigator: true);
    nav.push(
      MaterialPageRoute(
        builder: (_) => LiveKitMeetingScreen(
          customRoomName: session.roomName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(meetingSessionStreamProvider);
    final isMinimized = ref.watch(isMeetingMinimizedProvider);

    final session = sessionAsync.value;
    final isConnected = session?.isConnected ?? false;

    // Only render overlay if meeting is actively connected AND user minimized the screen
    if (!isConnected || !isMinimized || session == null) {
      return const SizedBox.shrink();
    }

    final gateway = ref.read(meetingGatewayProvider);
    final screenSize = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Default position at bottom-right corner, above bottom navigation bar
    final defaultPos = Offset(
      screenSize.width - 260,
      screenSize.height - 120 - bottomPadding,
    );

    final currentPos = _position ?? defaultPos;

    // Clamp within screen boundaries
    final clampedX = currentPos.dx.clamp(12.0, screenSize.width - 250);
    final clampedY = currentPos.dy.clamp(40.0, screenSize.height - 80 - bottomPadding);

    final roomTitle = session.isInBreakoutRoom
        ? (session.activeBreakoutRoomName ?? 'Breakout Room')
        : (session.roomName.isNotEmpty ? session.roomName : 'ALIVE Meet');

    return Positioned(
      left: clampedX,
      top: clampedY,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              clampedX + details.delta.dx,
              clampedY + details.delta.dy,
            );
          });
        },
        onTap: () => _expandMeeting(context, session),
        child: Material(
          elevation: 10,
          borderRadius: BorderRadius.circular(24),
          color: Colors.transparent,
          child: Container(
            width: 240,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF141A28),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFD49B28).withValues(alpha: 0.7),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Pulsing Green Live Indicator
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                // Room info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        roomTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${session.participants.length} connected • Tap to open',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 9,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Quick Mic Toggle
                InkWell(
                  onTap: () async {
                    try {
                      await gateway.toggleAudio();
                    } catch (_) {}
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: session.isAudioMuted
                          ? Colors.red.withValues(alpha: 0.25)
                          : Colors.green.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      session.isAudioMuted ? Icons.mic_off : Icons.mic,
                      size: 16,
                      color: session.isAudioMuted ? Colors.redAccent : Colors.greenAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Expand Icon
                InkWell(
                  onTap: () => _expandMeeting(context, session),
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.open_in_full_rounded,
                      size: 16,
                      color: Color(0xFFD49B28),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

