import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/meeting_models.dart';
import '../../../services/ports/meeting_gateway.dart';

/// Modal bottom sheet widget for in-meeting chatting, 1-on-1 direct messaging,
/// and host moderation.
class MeetingChatSheet extends StatefulWidget {
  final MeetingGateway gateway;
  final List<InMeetingChatMessage> messages;
  final TextEditingController chatController;
  final ScrollController scrollController;
  final bool isChatLockedByHost;
  final bool isLeader;
  final String currentUserId;
  final List<ParticipantInfo> participants;
  final ParticipantInfo? initialRecipient;
  final ValueChanged<bool> onToggleLock;
  final VoidCallback onClearChat;
  final void Function(String text, ParticipantInfo? recipient) onSendMessage;

  const MeetingChatSheet({
    super.key,
    required this.gateway,
    required this.messages,
    required this.chatController,
    required this.scrollController,
    required this.isChatLockedByHost,
    required this.isLeader,
    required this.currentUserId,
    required this.participants,
    this.initialRecipient,
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
    required List<ParticipantInfo> participants,
    ParticipantInfo? initialRecipient,
    required ValueChanged<bool> onToggleLock,
    required VoidCallback onClearChat,
    required void Function(String text, ParticipantInfo? recipient) onSendMessage,
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
        participants: participants,
        initialRecipient: initialRecipient,
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
  StreamSubscription? _dataSub;
  ParticipantInfo? _selectedRecipient;

  @override
  void initState() {
    super.initState();
    _locked = widget.isChatLockedByHost;
    _selectedRecipient = widget.initialRecipient;

    // Real-time live data channel subscription so incoming chat messages
    // trigger an immediate re-render and auto-scroll to the bottom.
    _dataSub = widget.gateway.dataChannelMessagesStream.listen((data) {
      if (!mounted) return;
      final action = data['action'];
      if (action == 'in_meeting_chat') {
        final msg = InMeetingChatMessage.fromJson(data, isLocal: false);
        final targetId = msg.targetUserId;
        final isPublic = targetId == null || targetId.isEmpty || targetId == 'everyone';
        final isForMe = targetId == widget.currentUserId || msg.senderId == widget.currentUserId;

        if (isPublic || isForMe) {
          if (!widget.messages.any((m) => m.id == msg.id)) {
            widget.messages.add(msg);
          }
          if (mounted) {
            setState(() {});
            _scrollToBottom();
          }
        }
      } else if (action == 'in_meeting_chat_lock') {
        final isLocked = data['isLocked'] == true;
        setState(() {
          _locked = isLocked;
        });
      } else if (action == 'in_meeting_chat_clear') {
        setState(() {
          widget.messages.clear();
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.scrollController.hasClients) {
        widget.scrollController.animateTo(
          widget.scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    final text = widget.chatController.text.trim();
    if (text.isEmpty) return;
    widget.onSendMessage(text, _selectedRecipient);
    widget.chatController.clear();
    setState(() {});
    _scrollToBottom();
  }

  void _showRecipientPicker(BuildContext context) {
    final availableParticipants = widget.participants.where((p) => !p.isLocal).toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Send Message To',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFD49B28),
                  child: Icon(Icons.people_alt_rounded, color: Colors.white, size: 20),
                ),
                title: const Text('Everyone', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Public to all attendees in the meeting'),
                trailing: _selectedRecipient == null
                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFFD49B28))
                    : null,
                onTap: () {
                  setState(() => _selectedRecipient = null);
                  Navigator.of(ctx).pop();
                },
              ),
              if (availableParticipants.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Text(
                    'Direct 1-on-1 (Private)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                ),
                ...availableParticipants.map((p) {
                  final isSelected = _selectedRecipient?.identity == p.identity;
                  final name = p.name.isNotEmpty ? p.name : 'Attendee (${p.identity.substring(0, 4)})';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.shade700,
                      backgroundImage: (p.avatarUrl != null && p.avatarUrl!.isNotEmpty)
                          ? NetworkImage(p.avatarUrl!)
                          : null,
                      child: (p.avatarUrl == null || p.avatarUrl!.isEmpty)
                          ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'M',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                          : null,
                    ),
                    title: Text(name),
                    subtitle: const Text('Private message only seen by you and them'),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: Colors.teal)
                        : null,
                    onTap: () {
                      setState(() => _selectedRecipient = p);
                      Navigator.of(ctx).pop();
                    },
                  );
                }),
              ],
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final myUid = widget.currentUserId;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
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
                            'Send a public message or tap "To" to send a private direct message.',
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
                      final isPrivate = msg.isPrivate;
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
                                backgroundColor: isPrivate
                                    ? Colors.amber.shade700
                                    : theme.colorScheme.primaryContainer,
                                backgroundImage: (msg.senderAvatar != null && msg.senderAvatar!.isNotEmpty)
                                    ? NetworkImage(msg.senderAvatar!)
                                    : null,
                                child: (msg.senderAvatar != null && msg.senderAvatar!.isNotEmpty)
                                    ? null
                                    : Text(
                                        msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : 'M',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isPrivate ? Colors.white : null,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? (isPrivate
                                          ? const Color(0xFF8B5E00)
                                          : theme.colorScheme.primary)
                                      : (isPrivate
                                          ? (theme.brightness == Brightness.dark
                                              ? const Color(0xFF382D1B)
                                              : const Color(0xFFFFF7E6))
                                          : (theme.brightness == Brightness.dark
                                              ? const Color(0xFF2D3748)
                                              : Colors.grey.shade200)),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(14),
                                    topRight: const Radius.circular(14),
                                    bottomLeft: isMe ? const Radius.circular(14) : Radius.zero,
                                    bottomRight: isMe ? Radius.zero : const Radius.circular(14),
                                  ),
                                  border: isPrivate
                                      ? Border.all(
                                          color: const Color(0xFFD49B28).withValues(alpha: 0.6),
                                          width: 1,
                                        )
                                      : null,
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    if (isPrivate) ...[
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.lock_rounded,
                                            size: 11,
                                            color: isMe ? Colors.amber.shade200 : const Color(0xFFD49B28),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isMe
                                                ? 'Direct to ${msg.targetUserName ?? "Attendee"} (Private)'
                                                : 'Direct from ${msg.senderName} (Private)',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isMe ? Colors.amber.shade200 : const Color(0xFFD49B28),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                    ] else if (!isMe) ...[
                                      Text(
                                        msg.senderName,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                    ],
                                    Text(
                                      msg.text,
                                      style: TextStyle(
                                        color: isMe
                                            ? Colors.white
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
                                            ? Colors.white.withValues(alpha: 0.7)
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

          // Recipient Selector Bar
          if (!(_locked && !widget.isLeader))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              color: theme.brightness == Brightness.dark
                  ? const Color(0xFF1A202C)
                  : const Color(0xFFF7FAFC),
              child: Row(
                children: [
                  const Text(
                    'To:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _showRecipientPicker(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _selectedRecipient != null
                            ? const Color(0xFFD49B28).withValues(alpha: 0.2)
                            : theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedRecipient != null
                              ? const Color(0xFFD49B28)
                              : theme.colorScheme.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _selectedRecipient != null ? Icons.lock_rounded : Icons.people_alt_rounded,
                            size: 13,
                            color: _selectedRecipient != null
                                ? const Color(0xFFD49B28)
                                : theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _selectedRecipient != null
                                ? '${_selectedRecipient!.name} (Direct Message)'
                                : 'Everyone',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _selectedRecipient != null
                                  ? const Color(0xFFD49B28)
                                  : theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down,
                            size: 16,
                            color: _selectedRecipient != null
                                ? const Color(0xFFD49B28)
                                : theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedRecipient != null) ...[
                    const Spacer(),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => setState(() => _selectedRecipient = null),
                      child: const Text('Reset to Everyone', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ],
              ),
            ),

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
                        hintText: _selectedRecipient != null
                            ? 'Private message to ${_selectedRecipient!.name}...'
                            : 'Type a message to everyone...',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: theme.dividerColor),
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
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
