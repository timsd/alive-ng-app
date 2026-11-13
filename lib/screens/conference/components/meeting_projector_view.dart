import 'package:flutter/material.dart';

import '../../../utils/error_handler.dart';
import '../../../models/meeting_models.dart';
import '../../../services/ports/meeting_gateway.dart';
import 'meeting_stage_view.dart';

/// Gallery View / Stage Display widget for video grids and stage presentations.
class MeetingGalleryView extends StatefulWidget {
  final MeetingSession session;
  final MeetingGateway gateway;
  final bool isLeader;
  final bool canShareScreen;
  final String roomTitle;
  final VoidCallback onExitProjector;
  final VoidCallback onOpenBreakoutRooms;
  final VoidCallback? onOpenMore;
  final VoidCallback? onOpenChat;
  final bool isScribeRecording;
  final VoidCallback? onToggleScribe;
  final VoidCallback onLeaveMeeting;
  final void Function(ParticipantInfo participant) onParticipantTap;
  final void Function(String message) showMessage;

  const MeetingGalleryView({
    super.key,
    required this.session,
    required this.gateway,
    required this.isLeader,
    required this.canShareScreen,
    required this.roomTitle,
    required this.onExitProjector,
    required this.onOpenBreakoutRooms,
    this.onOpenMore,
    this.onOpenChat,
    this.isScribeRecording = false,
    this.onToggleScribe,
    required this.onLeaveMeeting,
    required this.onParticipantTap,
    required this.showMessage,
  });

  @override
  State<MeetingGalleryView> createState() => _MeetingGalleryViewState();
}

/// Backward compatibility alias for MeetingGalleryView
typedef MeetingProjectorView = MeetingGalleryView;

class _MeetingGalleryViewState extends State<MeetingGalleryView> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = true;
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_checkScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScroll());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_checkScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _checkScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final canLeft = currentScroll > 8;
    final canRight = currentScroll < (maxScroll - 8);
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _scroll(double delta) {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      (_scrollController.offset + delta).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _exitProjector() {
    widget.onExitProjector();
  }

  void _leaveMeeting() {
    widget.onLeaveMeeting();
  }

  Widget _buildControlButton({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
    Color? activeColor,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: activeColor ??
                        (isDestructive
                            ? Colors.red.shade900
                            : const Color(0xFF1E293B)),
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (activeColor != null || isDestructive)
                        BoxShadow(
                          color: (activeColor ?? Colors.red).withValues(alpha: 0.35),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                  child: Center(child: icon),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activePresenter = widget.session.activeScreenShareName;
    final isPresenting = widget.session.isScreenShareEnabled || activePresenter != null;

    return SafeArea(
      child: Stack(
        children: [
          // Main Stage Canvas
          Column(
            children: [
              // Projector Header Bar (Clean: duplicate buttons removed from header)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: const Color(0xFF111418),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      tooltip: 'Switch to List View',
                      onPressed: _exitProjector,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.session.isInBreakoutRoom
                            ? Colors.teal.shade800
                            : const Color(0xFF1E3A8A),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.session.isInBreakoutRoom
                                ? Icons.workspaces_rounded
                                : Icons.grid_view_rounded,
                            size: 11,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.session.isInBreakoutRoom ? 'BREAKOUT' : 'GALLERY VIEW',
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
                            widget.session.isInBreakoutRoom
                                ? (widget.session.activeBreakoutRoomName ?? 'Breakout Room')
                                : widget.roomTitle,
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
                                : 'Attendees: ${widget.session.participants.length} connected',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Central Stage Area (Optimized for Gallery View & Stage Presentations)
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFF0A0D11),
                  child: isPresenting
                      ? Column(
                          children: [
                            Expanded(
                              child: MeetingScreenShareStage(
                                session: widget.session,
                                gateway: widget.gateway,
                              ),
                            ),
                            MeetingParticipantStrip(
                              session: widget.session,
                              gateway: widget.gateway,
                              onParticipantTap: widget.onParticipantTap,
                            ),
                          ],
                        )
                      : Center(
                          child: MeetingVideoGridStage(
                            session: widget.session,
                            gateway: widget.gateway,
                            isLeader: widget.isLeader,
                            onParticipantTap: widget.onParticipantTap,
                          ),
                        ),
                ),
              ),

              // Slideable Bottom Control Bar in Stage Mode
              Container(
                color: const Color(0xFF111418),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Mic (Primary Visible)
                          _buildControlButton(
                            icon: Icon(
                              widget.session.isAudioMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            label: widget.session.isAudioMuted ? 'Unmute' : 'Mute',
                            activeColor: widget.session.isAudioMuted
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                            onTap: () async {
                              try {
                                await widget.gateway.toggleAudio();
                              } catch (e) {
                                widget.showMessage(e.toString().replaceAll('Exception: ', ''));
                              }
                            },
                          ),

                          // 2. Screen Share (Primary Visible)
                          if (widget.canShareScreen)
                            _buildControlButton(
                              icon: Icon(
                                widget.session.isScreenShareEnabled
                                    ? Icons.stop_screen_share_rounded
                                    : Icons.screen_share_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              label: widget.session.isScreenShareEnabled ? 'Stop Share' : 'Share',
                              activeColor: widget.session.isScreenShareEnabled ? Colors.teal.shade700 : null,
                              onTap: () async {
                                try {
                                  await widget.gateway.toggleScreenShare();
                                  widget.showMessage(widget.session.isScreenShareEnabled
                                      ? 'Screen sharing stopped.'
                                      : 'Screen sharing started.');
                                } catch (e) {
                                  widget.showMessage(ErrorHandler.getUserFriendlyMessage(e));
                                }
                              },
                            ),

                          // 3. More (Primary Visible)
                          _buildControlButton(
                            icon: const Icon(
                              Icons.more_horiz_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            label: 'More',
                            onTap: () {
                              if (widget.onOpenMore != null) {
                                widget.onOpenMore!();
                              }
                            },
                          ),

                          // 4. End / Leave (Primary Visible)
                          _buildControlButton(
                            icon: const Icon(
                              Icons.call_end_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            label: widget.isLeader ? 'Leave / End' : 'Leave',
                            isDestructive: true,
                            onTap: _leaveMeeting,
                          ),

                          // 5. Camera (Slideable)
                          _buildControlButton(
                            icon: Icon(
                              widget.session.isVideoMuted ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            label: widget.session.isVideoMuted ? 'Camera Off' : 'Camera On',
                            activeColor: widget.session.isVideoMuted
                                ? Colors.red.shade700
                                : const Color(0xFF2563EB),
                            onTap: () async {
                              try {
                                await widget.gateway.toggleVideo();
                              } catch (e) {
                                widget.showMessage(e.toString().replaceAll('Exception: ', ''));
                              }
                            },
                          ),

                          // 6. Switch to List View
                          _buildControlButton(
                            icon: const Icon(
                              Icons.view_list_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            label: 'List View',
                            onTap: _exitProjector,
                          ),

                          // 7. Breakout Rooms (Slideable)
                          if (widget.isLeader || widget.session.isBreakoutActive)
                            _buildControlButton(
                              icon: const Icon(
                                Icons.workspaces_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              label: 'Breakout',
                              activeColor: widget.session.isBreakoutActive ? Colors.teal.shade700 : null,
                              onTap: widget.onOpenBreakoutRooms,
                            ),

                          // 8. In-Meeting Chat (Slideable)
                          if (widget.onOpenChat != null)
                            _buildControlButton(
                              icon: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              label: 'Chat',
                              onTap: widget.onOpenChat!,
                            ),

                          // 9. Hand Raise / Lower (Slideable)
                          _buildControlButton(
                            icon: Icon(
                              widget.session.isHandRaised
                                  ? Icons.pan_tool_rounded
                                  : Icons.pan_tool_outlined,
                              color: widget.session.isHandRaised
                                  ? Colors.black87
                                  : Colors.white,
                              size: 22,
                            ),
                            label: widget.session.isHandRaised
                                ? 'Lower Hand'
                                : 'Raise Hand',
                            activeColor: widget.session.isHandRaised
                                ? const Color(0xFFD49B28)
                                : null,
                            onTap: () async {
                              final newRaised = !widget.session.isHandRaised;
                              await widget.gateway.raiseHand(raised: newRaised);
                              widget.showMessage(
                                  newRaised ? 'Hand raised' : 'Hand lowered');
                            },
                          ),

                          // 10. ALIVE Scribe Record Button (Slideable)
                          _buildControlButton(
                            icon: Icon(
                              widget.isScribeRecording
                                  ? Icons.fiber_manual_record_rounded
                                  : Icons.fiber_manual_record_outlined,
                              color: widget.isScribeRecording
                                  ? Colors.white
                                  : Colors.red.shade400,
                              size: 22,
                            ),
                            label: widget.isScribeRecording ? 'REC Active' : 'Record',
                            activeColor: widget.isScribeRecording ? Colors.red.shade700 : null,
                            onTap: widget.onToggleScribe ?? () {},
                          ),
                        ],
                      ),
                    ),

                    // Left scroll chevron
                    if (_canScrollLeft)
                      Positioned(
                        left: 4,
                        child: Tooltip(
                          message: 'Slide back left',
                          child: GestureDetector(
                            onTap: () => _scroll(-140),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.8),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white24,
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.chevron_left_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Right scroll chevron with Blue Dot indicator (matching user annotation)
                    if (_canScrollRight)
                      Positioned(
                        right: 4,
                        child: Tooltip(
                          message: 'Slide right to see more options',
                          child: GestureDetector(
                            onTap: () => _scroll(140),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.85),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF38BDF8),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: Color(0xFF38BDF8),
                              ),
                            ),
                          ),
                        ),
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
