import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/meeting_models.dart';
import '../../../providers/appwrite_auth_provider.dart';
import '../../../services/ports/meeting_gateway.dart';

String formatMeetingParticipantName(ParticipantInfo p) {
  final raw = p.name.trim();
  if (raw.isEmpty || raw == p.identity || (raw.length > 20 && !raw.contains(' '))) {
    return p.isLocal ? 'You' : 'ALIVE Member';
  }
  return raw;
}

/// Stage rendering active screen share feed with projector canvas fallback.
class MeetingScreenShareStage extends StatelessWidget {
  final MeetingSession session;
  final MeetingGateway gateway;

  const MeetingScreenShareStage({
    super.key,
    required this.session,
    required this.gateway,
  });

  @override
  Widget build(BuildContext context) {
    final presenter = session.activeScreenShareName ?? (session.isScreenShareEnabled ? 'You' : 'Presenter');
    final screenVideoWidget = gateway.buildScreenShareVideoWidget();

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          if (screenVideoWidget != null)
            InteractiveViewer(
              minScale: 1.0,
              maxScale: 6.0,
              panEnabled: true,
              scaleEnabled: true,
              clipBehavior: Clip.none,
              child: Center(
                child: screenVideoWidget,
              ),
            )
          else
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.screen_share_rounded,
                    size: 38,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '$presenter is presenting',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Presentation feed active',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          // Google Meet style presenter pill (bottom-left)
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.screen_share_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    '$presenter is presenting',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Google Meet style zoom indicator / controls (bottom-right)
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24, width: 0.8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white70),
                  SizedBox(width: 4),
                  Text(
                    'Pinch to zoom',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Video grid displaying attendee and speaker tiles with speaking indicator borders.
class MeetingVideoGridStage extends ConsumerWidget {
  final MeetingSession session;
  final MeetingGateway gateway;
  final bool isLeader;
  final void Function(ParticipantInfo p) onParticipantTap;

  const MeetingVideoGridStage({
    super.key,
    required this.session,
    required this.gateway,
    required this.isLeader,
    required this.onParticipantTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (session.participants.isEmpty) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.meeting_room_outlined, size: 64, color: Colors.white38),
          SizedBox(height: 16),
          Text(
            'Sanctuary Stage Waiting for Attendees...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      );
    }

    final participants = session.participants;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Two per row on mobile when participants/cameras are active (matches user design)
        final crossAxisCount = constraints.maxWidth > 900
            ? 3
            : (participants.length <= 1 ? 1 : 2);

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: crossAxisCount == 1 ? (16 / 10) : (4 / 3),
          ),
          itemCount: participants.length,
          itemBuilder: (context, index) {
            final p = participants[index];
            final name = formatMeetingParticipantName(p);
            final isSpeaking = p.isSpeaking;
            final isParticipantHost = gateway.isParticipantHost(p.identity);
            final isParticipantCoHost = gateway.isParticipantCoHost(p.identity);
            final liveVideo = !p.isVideoMuted
                ? gateway.buildParticipantVideoWidget(p.identity)
                : null;

            return InkWell(
              onTap: () => onParticipantTap(p),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSpeaking
                        ? Colors.green
                        : (isParticipantHost
                            ? const Color(0xFFD49B28)
                            : (isParticipantCoHost ? Colors.teal : Colors.white24)),
                    width: isSpeaking ? 2.5 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.center,
                  children: [
                    if (liveVideo != null)
                      liveVideo
                    else
                      Builder(
                        builder: (context) {
                          final effectiveAvatar = p.isLocal
                              ? (ref.watch(currentUserAvatarUrlProvider) ?? p.avatarUrl)
                              : p.avatarUrl;
                          final hasAvatar = effectiveAvatar != null && effectiveAvatar.isNotEmpty;

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: p.isLocal
                                    ? const Color(0xFF3B82F6)
                                    : const Color(0xFF10B981),
                                backgroundImage: hasAvatar ? NetworkImage(effectiveAvatar) : null,
                                onBackgroundImageError: hasAvatar ? (_, __) {} : null,
                                child: hasAvatar
                                    ? null
                                    : Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : 'M',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                p.isVideoMuted ? 'Camera Off' : 'Starting Camera...',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                    // Top Right Audio / Hand Status
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (p.isHandRaised)
                            Container(
                              padding: const EdgeInsets.all(4),
                              margin: const EdgeInsets.only(right: 4),
                              decoration: const BoxDecoration(
                                color: Colors.amber,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.pan_tool_rounded, size: 12, color: Colors.black87),
                            ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: p.isAudioMuted ? Colors.red.shade900 : Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              p.isAudioMuted ? Icons.mic_off : Icons.mic,
                              size: 14,
                              color: p.isAudioMuted ? Colors.white : Colors.greenAccent,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bottom Pill Name Overlay
                    Positioned(
                      bottom: 8,
                      left: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            if (isParticipantHost)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.star, size: 12, color: Color(0xFFD49B28)),
                              )
                            else if (isParticipantCoHost)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.shield, size: 12, color: Colors.tealAccent),
                              ),
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (p.isLocal)
                              Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade800,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'YOU',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Horizontal scrollable thumbnail strip of participants shown during presentations in Gallery View.
class MeetingParticipantStrip extends ConsumerWidget {
  final MeetingSession session;
  final MeetingGateway gateway;
  final void Function(ParticipantInfo p) onParticipantTap;

  const MeetingParticipantStrip({
    super.key,
    required this.session,
    required this.gateway,
    required this.onParticipantTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            ),
          ];

    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      color: const Color(0xFF0F141C),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: participants.length,
        itemBuilder: (context, index) {
          final p = participants[index];
          final name = formatMeetingParticipantName(p);
          final liveVideo = !p.isVideoMuted
              ? gateway.buildParticipantVideoWidget(p.identity)
              : null;
          final effectiveAvatar = p.isLocal
              ? (ref.watch(currentUserAvatarUrlProvider) ?? p.avatarUrl)
              : p.avatarUrl;
          final hasAvatar = effectiveAvatar != null && effectiveAvatar.isNotEmpty;

          return InkWell(
            onTap: () => onParticipantTap(p),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 104,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: p.isSpeaking
                      ? Colors.green
                      : Colors.white24,
                  width: p.isSpeaking ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (liveVideo != null)
                    liveVideo
                  else
                    Center(
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: p.isLocal
                            ? const Color(0xFF3B82F6)
                            : const Color(0xFF10B981),
                        backgroundImage: hasAvatar ? NetworkImage(effectiveAvatar) : null,
                        onBackgroundImageError: hasAvatar ? (_, __) {} : null,
                        child: hasAvatar
                            ? null
                            : Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'M',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  // Name and status overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      color: Colors.black87,
                      child: Row(
                        children: [
                          Icon(
                            p.isAudioMuted ? Icons.mic_off : Icons.mic,
                            size: 10,
                            color: p.isAudioMuted ? Colors.red : Colors.green,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

