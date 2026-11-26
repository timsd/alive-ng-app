import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/meeting_models.dart';
import '../../../providers/meeting_provider.dart';
import '../../../services/meeting_pip_service.dart';
import '../../../services/ports/meeting_gateway.dart';
import '../../../utils/navigation_keys.dart';
import '../livekit_meeting_screen.dart';
import 'meeting_stage_view.dart';

/// Compact Zoom / Google Meet style view rendered inside the OS
/// Picture-in-Picture (PiP) window when the app is minimized during an active
/// ALIVE Meet conference session.
class MeetingPipOverlay extends ConsumerStatefulWidget {
  const MeetingPipOverlay({super.key});

  @override
  ConsumerState<MeetingPipOverlay> createState() => _MeetingPipOverlayState();
}

class _MeetingPipOverlayState extends ConsumerState<MeetingPipOverlay> {
  bool _wasInPipMode = false;

  @override
  void initState() {
    super.initState();
    MeetingPipService.instance.init(
      (isInPipMode) {
        if (!mounted) return;
        final exitedPip = _wasInPipMode && !isInPipMode;
        _wasInPipMode = isInPipMode;
        ref.read(isMeetingPipModeProvider.notifier).state = isInPipMode;

        if (exitedPip) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            // Only expand when the user tapped the PiP overlay to resume the
            // app (not when they dismissed/closed the PiP window).
            if (WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed) {
              return;
            }
            final gateway = ref.read(meetingGatewayProvider);
            final session = gateway.currentSession;
            if (!session.isConnected) return;
            if (ref.read(isMeetingMinimizedProvider)) {
              ref.read(isMeetingMinimizedProvider.notifier).state = false;
              rootNavigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (_) => LiveKitMeetingScreen(
                    customRoomName: session.roomName,
                  ),
                ),
              );
            }
          });
        }
      },
      onPipAction: (action) async {
        if (!mounted) return;
        final gateway = ref.read(meetingGatewayProvider);
        if (action == 'toggle_mic') {
          await gateway.toggleAudio();
        } else if (action == 'leave_meeting') {
          LiveKitMeetingScreen.disposeGlobalRetainedScribe();
          await gateway.leaveMeeting();
        }
      },
    );
  }

  ParticipantInfo? _pickFeaturedParticipant(MeetingSession session) {
    final participants = session.participants;
    if (participants.isEmpty) return null;

    // 1. Active speaker with camera on
    for (final p in participants) {
      if (p.isSpeaking && !p.isVideoMuted) return p;
    }
    // 2. Any remote participant with camera on
    for (final p in participants) {
      if (!p.isLocal && !p.isVideoMuted) return p;
    }
    // 3. Any active speaker (audio-only)
    for (final p in participants) {
      if (p.isSpeaking) return p;
    }
    // 4. Local participant with camera on
    for (final p in participants) {
      if (p.isLocal && !p.isVideoMuted) return p;
    }
    // 5. First remote participant or local fallback
    for (final p in participants) {
      if (!p.isLocal) return p;
    }
    return participants.first;
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(meetingSessionStreamProvider);
    final isPipMode = ref.watch(isMeetingPipModeProvider);

    final session = sessionAsync.value;
    final isConnected = session?.isConnected ?? false;

    // Keep native Android PiP auto-enter state and RemoteActions in sync.
    MeetingPipService.instance.setMeetingActive(
      isConnected,
      isMuted: session?.isAudioMuted,
    );

    if (!isPipMode || !isConnected || session == null) {
      return const SizedBox.shrink();
    }

    final gateway = ref.read(meetingGatewayProvider);
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

    final roomTitle = session.isInBreakoutRoom
        ? (session.activeBreakoutRoomName ?? 'Breakout')
        : (session.roomName.isNotEmpty ? session.roomName : 'ALIVE Meet');
    final featuredName =
        featured != null ? formatMeetingParticipantName(featured) : roomTitle;

    return Positioned.fill(
      child: Material(
        color: const Color(0xFF141A28),
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
              _AudioOnlyPipStage(
                featured: featured,
                featuredName: featuredName,
                roomTitle: roomTitle,
              ),

            // Top-left compact Live + Room + Participant Count pill
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
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
                          Flexible(
                            child: Text(
                              roomTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '• ${session.participants.length}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom bar: speaker/presenter label + local mic/cam status
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (screenShareWidget != null || featuredVideo != null)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          screenShareWidget != null
                              ? '${session.activeScreenShareName ?? 'Presenter'} presenting'
                              : featuredName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  _LocalMediaStatusPills(gateway: gateway),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioOnlyPipStage extends StatelessWidget {
  final ParticipantInfo? featured;
  final String featuredName;
  final String roomTitle;

  const _AudioOnlyPipStage({
    required this.featured,
    required this.featuredName,
    required this.roomTitle,
  });

  @override
  Widget build(BuildContext context) {
    final isSpeaking = featured?.isSpeaking ?? false;
    final avatarUrl = featured?.avatarUrl;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF141A28), Color(0xFF0E131F)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSpeaking
                        ? Colors.greenAccent
                        : const Color(0xFFD49B28).withValues(alpha: 0.7),
                    width: isSpeaking ? 2.5 : 1.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF1E3A8A),
                  backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                  onBackgroundImageError: hasAvatar ? (_, __) {} : null,
                  child: hasAvatar
                      ? null
                      : Text(
                          featuredName.isNotEmpty
                              ? featuredName[0].toUpperCase()
                              : 'A',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
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
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalMediaStatusPills extends StatelessWidget {
  final MeetingGateway gateway;

  const _LocalMediaStatusPills({required this.gateway});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            gateway.isAudioMuted ? Icons.mic_off : Icons.mic,
            size: 12,
            color: gateway.isAudioMuted ? Colors.redAccent : Colors.greenAccent,
          ),
          const SizedBox(width: 4),
          Icon(
            gateway.isVideoMuted ? Icons.videocam_off : Icons.videocam,
            size: 12,
            color: gateway.isVideoMuted ? Colors.white60 : Colors.greenAccent,
          ),
        ],
      ),
    );
  }
}
