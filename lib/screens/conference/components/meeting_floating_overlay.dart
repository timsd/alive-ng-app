import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/meeting_models.dart';
import '../../../providers/meeting_provider.dart';
import '../../../utils/navigation_keys.dart';
import '../livekit_meeting_screen.dart';

/// Global floating Picture-in-Picture / portrait overlay widget for active meetings.
/// Displayed when a user minimizes an active conference to browse other parts of the app.
class MeetingFloatingOverlay extends ConsumerStatefulWidget {
  const MeetingFloatingOverlay({super.key});

  @override
  ConsumerState<MeetingFloatingOverlay> createState() =>
      _MeetingFloatingOverlayState();
}

class _MeetingFloatingOverlayState
    extends ConsumerState<MeetingFloatingOverlay> {
  static const double _cardWidth = 128.0;
  static const double _cardHeight = 192.0;

  Offset? _position;

  void _expandMeeting(BuildContext context, MeetingSession session) {
    ref.read(isMeetingMinimizedProvider.notifier).state = false;

    final nav = rootNavigatorKey.currentState ??
        Navigator.maybeOf(context, rootNavigator: true);
    nav?.push(
      MaterialPageRoute(
        builder: (_) => LiveKitMeetingScreen(
          customRoomName: session.roomName,
        ),
      ),
    );
  }

  ParticipantInfo? _pickFeaturedParticipant(MeetingSession session) {
    final participants = session.participants;
    if (participants.isEmpty) return null;
    for (final p in participants) {
      if (p.isSpeaking && !p.isVideoMuted) return p;
    }
    for (final p in participants) {
      if (!p.isLocal && !p.isVideoMuted) return p;
    }
    for (final p in participants) {
      if (p.isSpeaking) return p;
    }
    for (final p in participants) {
      if (p.isLocal && !p.isVideoMuted) return p;
    }
    for (final p in participants) {
      if (!p.isLocal) return p;
    }
    return participants.first;
  }

  @override
  Widget build(BuildContext context) {
    final gateway = ref.watch(meetingGatewayProvider);
    final sessionAsync = ref.watch(meetingSessionStreamProvider);
    final isMinimized = ref.watch(isMeetingMinimizedProvider);
    final isPipMode = ref.watch(isMeetingPipModeProvider);

    final session = sessionAsync.value ?? gateway.currentSession;
    final isConnected = session.isConnected;

    // Render portrait floating overlay whenever meeting is active and minimized
    // in-app, and not currently in OS-level Picture-in-Picture mode.
    if (!isConnected || !isMinimized || isPipMode) {
      return const SizedBox.shrink();
    }

    final screenSize = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final defaultPos = Offset(
      screenSize.width - _cardWidth - 14,
      screenSize.height - _cardHeight - 84 - bottomPadding,
    );

    final currentPos = _position ?? defaultPos;
    final maxX = (screenSize.width - _cardWidth - 8).clamp(8.0, double.infinity);
    final maxY =
        (screenSize.height - _cardHeight - bottomPadding - 8).clamp(40.0, double.infinity);
    final clampedX = currentPos.dx.clamp(8.0, maxX);
    final clampedY = currentPos.dy.clamp(topPadding + 8, maxY);

    final roomTitle = session.isInBreakoutRoom
        ? (session.activeBreakoutRoomName ?? 'Breakout')
        : (session.roomName.isNotEmpty ? session.roomName : 'ALIVE Meet');

    final screenShareWidget = gateway.buildScreenShareVideoWidget();
    final featured = _pickFeaturedParticipant(session);
    final featuredVideo = (screenShareWidget == null &&
            featured != null &&
            !featured.isVideoMuted)
        ? gateway.buildParticipantVideoWidget(
            featured.identity,
            mirror: featured.isLocal,
          )
        : null;
    final featuredName = featured?.name.isNotEmpty == true
        ? featured!.name
        : roomTitle;
    final initial =
        featuredName.isNotEmpty ? featuredName[0].toUpperCase() : 'A';

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
          elevation: 12,
          borderRadius: BorderRadius.circular(18),
          color: Colors.transparent,
          child: Container(
            width: _cardWidth,
            height: _cardHeight,
            decoration: BoxDecoration(
              color: const Color(0xFF141A28),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFD49B28).withValues(alpha: 0.75),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.5),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (screenShareWidget != null)
                    Container(
                      color: Colors.black,
                      child: Center(child: screenShareWidget),
                    )
                  else if (featuredVideo != null)
                    featuredVideo
                  else
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1A2538), Color(0xFF0E1420)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: const Color(0xFF0F9A07)
                                  .withValues(alpha: 0.25),
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                featuredName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Top Live badge + participant count
                  Positioned(
                    top: 6,
                    left: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              roomTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Bottom compact Mic + Expand controls
                  Positioned(
                    left: 6,
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () async {
                              try {
                                await gateway.toggleAudio();
                              } catch (_) {}
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Icon(
                              session.isAudioMuted ? Icons.mic_off : Icons.mic,
                              size: 16,
                              color: session.isAudioMuted
                                  ? Colors.redAccent
                                  : Colors.greenAccent,
                            ),
                          ),
                          Text(
                            '${session.participants.length}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          InkWell(
                            onTap: () => _expandMeeting(context, session),
                            borderRadius: BorderRadius.circular(12),
                            child: const Icon(
                              Icons.open_in_full_rounded,
                              size: 16,
                              color: Color(0xFFD49B28),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
