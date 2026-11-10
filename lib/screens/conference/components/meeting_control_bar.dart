import 'package:flutter/material.dart';

import '../../../models/meeting_models.dart';
import '../../../services/ports/meeting_gateway.dart';

/// Docked bottom action bar (Zoom / Google Meet style) for primary conference controls.
class MeetingControlBar extends StatelessWidget {
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
    required this.onToggleAudio,
    required this.onToggleVideo,
    required this.onToggleScreenShare,
    required this.onOpenChat,
    required this.onToggleHand,
    required this.onOpenMore,
    required this.onLeaveOrEnd,
  });

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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mic
                    _buildButton(
                      context: context,
                      icon: Icon(
                        isAudioMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        color: isAudioMuted ? Colors.white : (isDark ? Colors.white : Colors.black87),
                        size: 22,
                      ),
                      label: !isLeader && session.isRoomAudioLocked && isAudioMuted
                          ? 'Locked'
                          : (isAudioMuted ? 'Unmute' : 'Mute'),
                      activeColor: isAudioMuted ? Colors.red.shade700 : null,
                      onTap: onToggleAudio,
                    ),

                    // Video
                    _buildButton(
                      context: context,
                      icon: Icon(
                        isVideoMuted ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                        color: isVideoMuted ? Colors.white : (isDark ? Colors.white : Colors.black87),
                        size: 22,
                      ),
                      label: isVideoMuted ? 'Camera Off' : 'Camera On',
                      activeColor: isVideoMuted ? Colors.red.shade700 : null,
                      onTap: onToggleVideo,
                    ),

                    // Screen share
                    if (canShareScreen)
                      _buildButton(
                        context: context,
                        icon: Icon(
                          session.isScreenShareEnabled ? Icons.stop_screen_share_rounded : Icons.screen_share_rounded,
                          color: session.isScreenShareEnabled ? Colors.white : (isDark ? Colors.white : Colors.black87),
                          size: 22,
                        ),
                        label: session.isScreenShareEnabled ? 'Stop Share' : 'Share',
                        activeColor: session.isScreenShareEnabled ? Colors.teal.shade700 : null,
                        onTap: onToggleScreenShare,
                      ),

                    // Chat
                    _buildButton(
                      context: context,
                      icon: Badge(
                        isLabelVisible: unreadChatCount > 0,
                        label: Text('$unreadChatCount'),
                        child: Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: isDark ? Colors.white : Colors.black87,
                          size: 22,
                        ),
                      ),
                      label: unreadChatCount > 0 ? 'Chat ($unreadChatCount)' : 'Chat',
                      onTap: onOpenChat,
                    ),

                    // Hand
                    _buildButton(
                      context: context,
                      icon: Icon(
                        session.isHandRaised ? Icons.pan_tool_rounded : Icons.pan_tool_outlined,
                        color: session.isHandRaised ? Colors.black87 : (isDark ? Colors.white : Colors.black87),
                        size: 22,
                      ),
                      label: session.isHandRaised ? 'Lower Hand' : 'Raise Hand',
                      activeColor: session.isHandRaised ? const Color(0xFFD49B28) : null,
                      onTap: onToggleHand,
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
                      onTap: onOpenMore,
                    ),

                    // Leave / End
                    _buildButton(
                      context: context,
                      icon: const Icon(
                        Icons.call_end_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      label: isLeader ? 'Leave / End' : 'Leave',
                      isDestructive: true,
                      onTap: onLeaveOrEnd,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

