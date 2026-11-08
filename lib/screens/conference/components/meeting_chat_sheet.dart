import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/meeting_models.dart';
import '../../../services/ports/meeting_gateway.dart';

/// Modal bottom sheet widget for in-meeting chatting and host moderation.
class MeetingChatSheet extends StatefulWidget {
  final MeetingGateway gateway;
  final List<InMeetingChatMessage> messages;
  final TextEditingController chatController;
  final ScrollController scrollController;
  final bool isChatLockedByHost;
  final bool isLeader;
  final String currentUserId;
  final ValueChanged<bool> onToggleLock;
  final VoidCallback onClearChat;
  final VoidCallback onSendMessage;

  const MeetingChatSheet({
    super.key,
    required this.gateway,
    required this.messages,
    required this.chatController,
    required this.scrollController,
    required this.isChatLockedByHost,
    required this.isLeader,
    required this.currentUserId,
    required this.onToggleLock,
    required this.onClearChat,
    required this.onSendMessage,
  });

  static Future<void> show({
    required BuildContext context,
    required MeetingGateway gateway,
    required List<InMeetingChatMessage> messages,
    required TextEditingController chatController,
    required ScrollController scrollController,
    required bool isChatLockedByHost,
    required bool isLeader,
    required String currentUserId,
    required ValueChanged<bool> onToggleLock,
    required VoidCallback onClearChat,
    required VoidCallback onSendMessage,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => MeetingChatSheet(
        gateway: gateway,
        messages: messages,
        chatController: chatController,
        scrollController: scrollController,
        isChatLockedByHost: isChatLockedByHost,
        isLeader: isLeader,
        currentUserId: currentUserId,
        onToggleLock: onToggleLock,
        onClearChat: onClearChat,
        onSendMessage: onSendMessage,
      ),
    );
  }

  @override
  State<MeetingChatSheet> createState() => _MeetingChatSheetState();
}

class _MeetingChatSheetState extends State<MeetingChatSheet> {
  late bool _locked;

  @override
  void initState() {
    super.initState();
    _locked = widget.isChatLockedByHost;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final myUid = widget.currentUserId;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFD49B28)),
                const SizedBox(width: 8),
                Text(
                  'In-Meeting Chat',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (_locked) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Locked',
                      style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                const Spacer(),
                if (widget.isLeader) ...[
                  IconButton(
                    icon: Icon(
                      _locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                      color: _locked ? Colors.red : null,
                      size: 20,
                    ),
                    tooltip: _locked ? 'Unlock Chat for Attendees' : 'Lock Chat (Host Only)',
                    onPressed: () {
                      final newLock = !_locked;
                      setState(() => _locked = newLock);
                      widget.onToggleLock(newLock);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                    tooltip: 'Clear Chat Transcript',
                    onPressed: () {
                      widget.onClearChat();
                      setState(() {});
                    },
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Message list
          Expanded(
            child: widget.messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.mark_chat_unread_outlined,
                            size: 48,
                            color: theme.hintColor.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No messages yet',
                            style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Send a message to everyone in the meeting room.',
                            style: TextStyle(color: theme.hintColor, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: widget.scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: widget.messages.length,
                    itemBuilder: (ctx, idx) {
                      final msg = widget.messages[idx];
                      final isMe = msg.isLocal || (myUid.isNotEmpty && msg.senderId == myUid);
                      final timeStr = DateFormat.jm().format(msg.timestamp);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMe) ...[
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: theme.colorScheme.primaryContainer,
                                backgroundImage: (msg.senderAvatar != null && msg.senderAvatar!.isNotEmpty)
                                    ? NetworkImage(msg.senderAvatar!)
                                    : null,
                                child: (msg.senderAvatar != null && msg.senderAvatar!.isNotEmpty)
                                    ? null
                                    : Text(
                                        msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : 'M',
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? theme.colorScheme.primary
                                      : (theme.brightness == Brightness.dark
                                          ? const Color(0xFF2D3748)
                                          : Colors.grey.shade200),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(14),
                                    topRight: const Radius.circular(14),
                                    bottomLeft: isMe ? const Radius.circular(14) : Radius.zero,
                                    bottomRight: isMe ? Radius.zero : const Radius.circular(14),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe)
                                      Text(
                                        msg.senderName,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    Text(
                                      msg.text,
                                      style: TextStyle(
                                        color: isMe
                                            ? theme.colorScheme.onPrimary
                                            : (theme.brightness == Brightness.dark ? Colors.white : Colors.black87),
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      timeStr,
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: isMe
                                            ? theme.colorScheme.onPrimary.withValues(alpha: 0.7)
                                            : theme.hintColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isMe) const SizedBox(width: 4),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),

          // Chat Input bar
          if (_locked && !widget.isLeader)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 16, color: theme.hintColor),
                  const SizedBox(width: 8),
                  Text(
                    'Chat has been locked by the meeting host.',
                    style: TextStyle(
                      color: theme.hintColor,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.chatController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type a message to everyone...',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: theme.dividerColor),
                        ),
                      ),
                      onSubmitted: (_) {
                        widget.onSendMessage();
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () {
                      widget.onSendMessage();
                      setState(() {});
                    },
                    icon: const Icon(Icons.send_rounded, size: 20),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
