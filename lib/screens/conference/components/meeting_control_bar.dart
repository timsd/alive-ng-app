import 'package:flutter/material.dart';

import '../../../models/meeting_models.dart';
import '../../../services/ports/meeting_gateway.dart';

/// Docked bottom action bar matching the Gallery View control bar design.
class MeetingControlBar extends StatefulWidget {
  final MeetingSession session;
  final MeetingGateway gateway;
  final bool isLeader;
  final bool canShareScreen;
  final bool isAudioMuted;
  final bool isVideoMuted;
  final int unreadChatCount;
  final VoidCallback onToggleAudio;
  final VoidCallback onToggleVideo;
  final VoidCallback onToggleScreenShare;
  final VoidCallback onOpenChat;
  final VoidCallback onToggleHand;
  final bool isGalleryView;
  final VoidCallback? onToggleViewMode;
  final VoidCallback? onOpenBreakoutRooms;
  final bool isScribeRecording;
  final VoidCallback? onToggleScribe;
  final VoidCallback onOpenMore;
  final VoidCallback onLeaveOrEnd;

  const MeetingControlBar({
    super.key,
    required this.session,
    required this.gateway,
    required this.isLeader,
    required this.canShareScreen,
    required this.isAudioMuted,
    required this.isVideoMuted,
    required this.unreadChatCount,
    this.isGalleryView = false,
    this.onToggleViewMode,
    this.onOpenBreakoutRooms,
    this.isScribeRecording = false,
    this.onToggleScribe,
    required this.onToggleAudio,
    required this.onToggleVideo,
    required this.onToggleScreenShare,
    required this.onOpenChat,
    required this.onToggleHand,
    required this.onOpenMore,
    required this.onLeaveOrEnd,
  });

  @override
  State<MeetingControlBar> createState() => _MeetingControlBarState();
}

class _MeetingControlBarState extends State<MeetingControlBar> {
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

  @override
  void didUpdateWidget(covariant MeetingControlBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isGalleryView != widget.isGalleryView) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _checkScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final canLeft = currentScroll > 8;
    final canRight = currentScroll < (maxScroll - 8);
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      if (mounted) {
        setState(() {
          _canScrollLeft = canLeft;
          _canScrollRight = canRight;
        });
      }
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
                          color: (activeColor ?? Colors.red)
                              .withValues(alpha: 0.35),
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
    return Container(
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
                    widget.isAudioMuted
                        ? Icons.mic_off_rounded
                        : Icons.mic_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  label: widget.isAudioMuted ? 'Unmute' : 'Mute',
                  activeColor: widget.isAudioMuted
                      ? Colors.red.shade700
                      : Colors.green.shade700,
                  onTap: widget.onToggleAudio,
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
                    label: widget.session.isScreenShareEnabled
                        ? 'Stop Share'
                        : 'Share',
                    activeColor: widget.session.isScreenShareEnabled
                        ? Colors.teal.shade700
                        : null,
                    onTap: widget.onToggleScreenShare,
                  ),

                // 3. More (Primary Visible)
                _buildControlButton(
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  label: 'More',
                  onTap: widget.onOpenMore,
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
                  onTap: widget.onLeaveOrEnd,
                ),

                // 5. Camera (Slideable)
                _buildControlButton(
                  icon: Icon(
                    widget.isVideoMuted
                        ? Icons.videocam_off_rounded
                        : Icons.videocam_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  label: widget.isVideoMuted ? 'Camera Off' : 'Camera On',
                  activeColor: widget.isVideoMuted
                      ? Colors.red.shade700
                      : const Color(0xFF2563EB),
                  onTap: widget.onToggleVideo,
                ),

                // 6. Gallery / List View Switch (Slideable)
                if (widget.onToggleViewMode != null)
                  _buildControlButton(
                    icon: Icon(
                      widget.isGalleryView
                          ? Icons.view_list_rounded
                          : Icons.grid_view_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    label: widget.isGalleryView ? 'List View' : 'Gallery View',
                    onTap: widget.onToggleViewMode!,
                  ),

                // 7. Breakout Rooms (Slideable)
                if (widget.onOpenBreakoutRooms != null &&
                    (widget.isLeader || widget.session.isBreakoutActive))
                  _buildControlButton(
                    icon: const Icon(
                      Icons.workspaces_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    label: 'Breakout',
                    activeColor: widget.session.isBreakoutActive
                        ? Colors.teal.shade700
                        : null,
                    onTap: widget.onOpenBreakoutRooms!,
                  ),

                // 8. In-Meeting Chat (Slideable)
                _buildControlButton(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      if (widget.unreadChatCount > 0)
                        Positioned(
                          right: -6,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              widget.unreadChatCount > 9
                                  ? '9+'
                                  : '${widget.unreadChatCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  label: 'Chat',
                  onTap: widget.onOpenChat,
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
                  label:
                      widget.session.isHandRaised ? 'Lower Hand' : 'Raise Hand',
                  activeColor: widget.session.isHandRaised
                      ? const Color(0xFFD49B28)
                      : null,
                  onTap: widget.onToggleHand,
                ),

                // 10. ALIVE Scribe Record Button (Slideable)
                if (widget.onToggleScribe != null)
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
                    activeColor:
                        widget.isScribeRecording ? Colors.red.shade700 : null,
                    onTap: widget.onToggleScribe!,
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

          // Right scroll chevron with Blue Dot indicator
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
    );
  }
}
