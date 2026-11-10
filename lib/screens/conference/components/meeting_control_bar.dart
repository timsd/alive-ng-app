import 'package:flutter/material.dart';

import '../../../models/meeting_models.dart';
import '../../../services/ports/meeting_gateway.dart';

/// Docked bottom action bar (Zoom / Google Meet style) for primary conference controls.
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
  bool _canScrollRight = false;

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
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.offset;
    final canLeft = current > 8;
    final canRight = current < (max - 8);
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      if (mounted) {
        setState(() {
          _canScrollLeft = canLeft;
          _canScrollRight = canRight;
        });
      }
    }
  }

  void _scrollBy(double delta) {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + delta).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Widget _buildButton({
    required BuildContext context,
    required Widget icon,
    required String label,
    required VoidCallback onTap,
    Color? activeColor,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? Colors.red.shade700
                      : (activeColor ?? (isDark ? const Color(0xFF263245) : Colors.grey.shade200)),
                  shape: BoxShape.circle,
                ),
                child: Center(child: icon),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDestructive
                      ? Colors.red.shade400
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScroll());

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111722) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF232D3F) : Colors.grey.shade300,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Mic
                      _buildButton(
                        context: context,
                        icon: Icon(
                          widget.isAudioMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                          color: widget.isAudioMuted ? Colors.white : (isDark ? Colors.white : Colors.black87),
                          size: 22,
                        ),
                        label: !widget.isLeader && widget.session.isRoomAudioLocked && widget.isAudioMuted
                            ? 'Locked'
                            : (widget.isAudioMuted ? 'Unmute' : 'Mute'),
                        activeColor: widget.isAudioMuted ? Colors.red.shade700 : null,
                        onTap: widget.onToggleAudio,
                      ),

                      // Video
                      _buildButton(
                        context: context,
                        icon: Icon(
                          widget.isVideoMuted ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                          color: widget.isVideoMuted ? Colors.white : (isDark ? Colors.white : Colors.black87),
                          size: 22,
                        ),
                        label: widget.isVideoMuted ? 'Camera Off' : 'Camera On',
                        activeColor: widget.isVideoMuted ? Colors.red.shade700 : null,
                        onTap: widget.onToggleVideo,
                      ),

                      // Screen share
                      if (widget.canShareScreen)
                        _buildButton(
                          context: context,
                          icon: Icon(
                            widget.session.isScreenShareEnabled ? Icons.stop_screen_share_rounded : Icons.screen_share_rounded,
                            color: widget.session.isScreenShareEnabled ? Colors.white : (isDark ? Colors.white : Colors.black87),
                            size: 22,
                          ),
                          label: widget.session.isScreenShareEnabled ? 'Stop Share' : 'Share',
                          activeColor: widget.session.isScreenShareEnabled ? Colors.teal.shade700 : null,
                          onTap: widget.onToggleScreenShare,
                        ),

                      // Chat
                      _buildButton(
                        context: context,
                        icon: Badge(
                          isLabelVisible: widget.unreadChatCount > 0,
                          label: Text('${widget.unreadChatCount}'),
                          child: Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: isDark ? Colors.white : Colors.black87,
                            size: 22,
                          ),
                        ),
                        label: widget.unreadChatCount > 0 ? 'Chat (${widget.unreadChatCount})' : 'Chat',
                        onTap: widget.onOpenChat,
                      ),

                      // Hand
                      _buildButton(
                        context: context,
                        icon: Icon(
                          widget.session.isHandRaised ? Icons.pan_tool_rounded : Icons.pan_tool_outlined,
                          color: widget.session.isHandRaised ? Colors.black87 : (isDark ? Colors.white : Colors.black87),
                          size: 22,
                        ),
                        label: widget.session.isHandRaised ? 'Lower Hand' : 'Raise Hand',
                        activeColor: widget.session.isHandRaised ? const Color(0xFFD49B28) : null,
                        onTap: widget.onToggleHand,
                      ),

                      // ALIVE Scribe Record / Notes Button
                      _buildButton(
                        context: context,
                        icon: Icon(
                          widget.isScribeRecording
                              ? Icons.fiber_manual_record_rounded
                              : Icons.fiber_manual_record_outlined,
                          color: widget.isScribeRecording
                              ? Colors.white
                              : Colors.red.shade600,
                          size: 22,
                        ),
                        label: widget.isScribeRecording ? 'REC Active' : 'Record',
                        activeColor: widget.isScribeRecording ? Colors.red.shade700 : null,
                        onTap: widget.onToggleScribe ?? () {},
                      ),

                      // View Mode Toggle (Gallery vs List View)
                      if (widget.onToggleViewMode != null)
                        _buildButton(
                          context: context,
                          icon: Icon(
                            widget.isGalleryView
                                ? Icons.view_list_rounded
                                : Icons.grid_view_rounded,
                            color: isDark ? Colors.white : Colors.black87,
                            size: 22,
                          ),
                          label: widget.isGalleryView ? 'List View' : 'Gallery',
                          onTap: widget.onToggleViewMode!,
                        ),

                      // More (•••)
                      _buildButton(
                        context: context,
                        icon: Icon(
                          Icons.more_horiz_rounded,
                          color: isDark ? Colors.white : Colors.black87,
                          size: 24,
                        ),
                        label: 'More',
                        onTap: widget.onOpenMore,
                      ),

                      // Leave / End
                      _buildButton(
                        context: context,
                        icon: const Icon(
                          Icons.call_end_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        label: widget.isLeader ? 'Leave / End' : 'Leave',
                        isDestructive: true,
                        onTap: widget.onLeaveOrEnd,
                      ),
                    ],
                  ),
                ),

                // Left Scroll Affordance Arrow
                if (_canScrollLeft)
                  Positioned(
                    left: 4,
                    child: Tooltip(
                      message: 'Slide back left',
                      child: GestureDetector(
                        onTap: () => _scrollBy(-140),
                        child: Container(
                          width: 26,
                          height: 38,
                          decoration: BoxDecoration(
                            color: (isDark ? const Color(0xFF1E293B) : Colors.white).withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(1, 1),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.chevron_left_rounded,
                            size: 20,
                            color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Right Scroll Affordance Arrow (Visual sign where user circled blue dot!)
                if (_canScrollRight)
                  Positioned(
                    right: 4,
                    child: Tooltip(
                      message: 'Slide right for More tools & Leave',
                      child: GestureDetector(
                        onTap: () => _scrollBy(140),
                        child: Container(
                          width: 26,
                          height: 38,
                          decoration: BoxDecoration(
                            color: (isDark ? const Color(0xFF1E293B) : Colors.white).withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(-1, 1),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                          ),
                        ),
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
