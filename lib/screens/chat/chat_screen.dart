import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/chat_models.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart';
import 'chat_message_widget.dart';
import 'chat_input_widget.dart';
import 'channel_list_widget.dart';
import '../../providers/appwrite_auth_provider.dart';
import '../../services/role_access_service.dart';
import '../../services/tag_parser.dart';
import '../conference/livekit_meeting_screen.dart';
import '../../config/appwrite_backend_config.dart';
import '../../services/channel_membership_sync_service.dart';
import '../../utils/text_formatter.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String? channelId;

  const ChatScreen({super.key, this.channelId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _messageController = TextEditingController();
  bool _channelsExpanded = true;

  List<ChatChannel> _channels = [];
  List<ChatMessage> _messages = [];
  bool _onlyMentions = false;
  ChatMessage? _replyingTo;
  ChatChannel? _selectedChannel;
  bool _isLoading = true;
  bool _isLoadingMessages = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChannels();
    if (widget.channelId != null) {
      _selectChannelById(widget.channelId!);
    }
  }

  Future<void> _handleDeleteMessage(ChatMessage message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text(
          'Are you sure you want to delete this message? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _chatService.deleteMessage(message.id);
        setState(() {
          _messages.removeWhere((m) => m.id == message.id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message deleted')),
          );
        }
      } catch (e) {
        _showError('Failed to delete message: $e');
      }
    }
  }

  Future<void> _handleEditMessage(ChatMessage message) async {
    final editController = TextEditingController(text: message.content);
    final newText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter updated message',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(editController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newText != null &&
        newText.isNotEmpty &&
        newText != message.content &&
        mounted) {
      try {
        final updated = await _chatService.editMessage(message.id, newText);
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == message.id);
          if (idx != -1) {
            _messages[idx] = updated;
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message updated')),
          );
        }
      } catch (e) {
        _showError('Failed to edit message: $e');
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadChannels() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final userId = AuthService.instance.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _channels = [];
          _isLoading = false;
        });
        return;
      }

      // Ensure user profile membership is synced across system channels
      try {
        final profile = ref.read(currentUserProfileProvider).value;
        if (profile != null) {
          await ChannelMembershipSyncService.instance.syncUserChannels(profile);
        }
      } catch (syncErr) {
        debugPrint('Auto sync channels note: $syncErr');
      }

      final channels = await _chatService.getUserChannels(userId);

      setState(() {
        _channels = channels;
        _isLoading = false;

        // Select first channel if none selected
        if (_selectedChannel == null && channels.isNotEmpty) {
          _selectedChannel = channels.first;
          _loadMessages();
        }
      });
    } catch (e) {
      setState(() {
        _error =
            'We could not load conversations. Check your connection and try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectChannelById(String channelId) async {
    if (_channels.isEmpty) return;
    final channel = _channels.firstWhere(
      (c) => c.id == channelId,
      orElse: () => _channels.first,
    );
    _selectChannel(channel);
  }

  void _selectChannel(ChatChannel channel) {
    setState(() {
      _selectedChannel = channel;
      _messages = [];
    });
    _loadMessages();
    _markMessagesAsRead();
  }

  Future<void> _loadMessages() async {
    if (_selectedChannel == null) return;

    try {
      setState(() {
        _isLoadingMessages = true;
      });

      final messages =
          await _chatService.getChannelMessages(_selectedChannel!.id);

      setState(() {
        _messages = messages;
        _isLoadingMessages = false;
      });

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingMessages = false;
      });
      _showError('Messages could not be loaded. Please try again.');
    }
  }

  Future<void> _sendMessage(String content, {String? replyToId}) async {
    if (_selectedChannel == null || content.trim().isEmpty) return;

    // Check if user is authenticated
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) {
      _showError(
          'You must be signed in to send messages. Please sign in to continue.');
      return;
    }

    try {
      final message = await _chatService.sendMessage(
        channelId: _selectedChannel!.id,
        content: content.trim(),
        replyToId: replyToId ?? _replyingTo?.id,
        tags: TagParser.parseUniqueMessage(content),
      );

      setState(() {
        _messages.add(message);
        _replyingTo = null;
      });

      _messageController.clear();

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint('Failed to send message: $e');
      _showError('Your message could not be sent. Please try again.');
    }
  }

  Future<void> _sendMessageWithAttachments(
    String content,
    MessageType type,
    List<String> attachments,
  ) async {
    if (_selectedChannel == null || content.trim().isEmpty) return;

    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) {
      _showError(
          'You must be signed in to send messages. Please sign in to continue.');
      return;
    }

    try {
      final message = await _chatService.sendMessage(
        channelId: _selectedChannel!.id,
        content: content.trim(),
        type: type,
        attachments: attachments,
        tags: TagParser.parseUniqueMessage(content),
      );

      setState(() {
        _messages.add(message);
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint('Failed to send attachment: $e');
      _showError('Your attachment could not be sent. Please try again.');
    }
  }

  Future<void> _markMessagesAsRead() async {
    if (_selectedChannel == null) return;

    try {
      await _chatService.markMessagesAsRead(_selectedChannel!.id);
    } catch (e) {
      // Silently handle error
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startDirectMessage({
    required String targetUserId,
    required String targetUserName,
  }) async {
    final currentUserId = AuthService.instance.currentUser?.uid;
    if (currentUserId == null) {
      _showError('You must be signed in to send direct messages.');
      return;
    }
    if (currentUserId == targetUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot message yourself directly.')),
      );
      return;
    }

    try {
      // Find existing DM channel with target user
      ChatChannel? existingDm;
      for (final channel in _channels) {
        if (channel.type == ChannelType.direct &&
            channel.members.contains(targetUserId) &&
            channel.members.contains(currentUserId)) {
          existingDm = channel;
          break;
        }
      }

      if (existingDm != null) {
        _selectChannel(existingDm);
        return;
      }

      // Create new direct message channel
      final cleanName = targetUserName.trim().isNotEmpty
          ? targetUserName.trim()
          : 'Direct Message';
      final newChannel = await _chatService.createChannel(
        name: cleanName,
        description: 'Direct message with $cleanName',
        type: ChannelType.direct,
        members: [targetUserId, currentUserId],
        admins: [targetUserId, currentUserId],
      );

      setState(() {
        _channels.insert(0, newChannel);
        _selectedChannel = newChannel;
        _messages = [];
      });
      _loadMessages();
    } catch (e) {
      _showError('Could not open direct message: $e');
    }
  }

  void _showCreateChannelDialog() {
    final profile = ref.read(currentUserProfileProvider).value;
    if (profile != null) {
      RoleAccessService.instance.updateCachedUserProfile(profile);
    }
    final role = (profile?.role ?? '').toLowerCase();
    final isAdmin = ['admin', 'bod', 'director', 'trustee'].contains(role) ||
        RoleAccessService.instance.canAccessAdmin() ||
        (profile != null && AppwriteBackendConfig.isSuperAdminEmail(profile.email));

    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Only admins can create channels'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _CreateChannelDialog(
        currentUserId: AuthService.instance.currentUser?.uid,
        isAdmin: true,
        onChannelCreated: (channel) {
          setState(() {
            _channels.insert(0, channel);
            _selectedChannel = channel;
            _messages = [];
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    bool canStartGeneral = false;
    bool isModerator = false;
    bool canCreateChannel = false;
    if (userProfileAsync.hasValue && userProfileAsync.value != null) {
      final profile = userProfileAsync.value!;
      final role = (profile.role).toLowerCase();
      const allowedRoles = [
        'super_admin',
        'superadmin',
        'admin',
        'bod',
        'director',
        'chapter_leader',
        'chapter_coordinator',
        'chap_coor',
        'coordinator',
        'moderator',
        'leader',
        'trustee',
      ];
      const moderatorRoles = [
        'super_admin',
        'superadmin',
        'admin',
        'bod',
        'director',
        'trustee',
      ];
      canStartGeneral = allowedRoles.contains(role);
      isModerator = moderatorRoles.contains(role);
      canCreateChannel = allowedRoles.contains(role) ||
          RoleAccessService.instance.canStartConferencing() ||
          RoleAccessService.instance.canAccessAdmin() ||
          AppwriteBackendConfig.isSuperAdminEmail(profile.email);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        return Scaffold(
          key: _scaffoldKey,
          drawer: isWide
              ? null
              : Drawer(
                  width: 300,
                  child: SafeArea(
                    child: ChannelListWidget(
                      channels: _channels,
                      selectedChannel: _selectedChannel,
                      onChannelSelected: (channel) {
                        _selectChannel(channel);
                        Navigator.of(context).pop();
                      },
                      onRefresh: _loadChannels,
                      onCollapse: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
          appBar: CustomAppBar(
            showBackButton: true,
            titleWidget: InkWell(
              onTap: isWide
                  ? null
                  : () => _scaffoldKey.currentState?.openDrawer(),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tag_rounded, size: 20),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _selectedChannel?.name ?? 'Chat',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isWide) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              if (isWide)
                IconButton(
                  icon: Icon(_channelsExpanded
                      ? Icons.menu_open_rounded
                      : Icons.menu_rounded),
                  tooltip: _channelsExpanded
                      ? 'Collapse Channels'
                      : 'Expand Channels',
                  onPressed: () =>
                      setState(() => _channelsExpanded = !_channelsExpanded),
                )
              else
                IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  tooltip: 'Channels',
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
              if (canCreateChannel)
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _showCreateChannelDialog,
                  tooltip: 'Create Channel',
                ),
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: _selectedChannel != null ? _showChannelInfo : null,
                tooltip: 'Channel Info',
              ),
            ],
          ),
          body: _isLoading
              ? const LoadingWidget()
              : _error != null
                  ? AppErrorWidget(
                      message: _error!,
                      onAction: _loadChannels,
                    )
                  : Row(
                      children: [
                        if (isWide)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeInOutCubic,
                            width: _channelsExpanded ? 280 : 68,
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                  color: Theme.of(context).dividerColor,
                                ),
                              ),
                            ),
                            child: _channelsExpanded
                                ? ChannelListWidget(
                                    channels: _channels,
                                    selectedChannel: _selectedChannel,
                                    onChannelSelected: _selectChannel,
                                    onRefresh: _loadChannels,
                                    onCollapse: () => setState(
                                        () => _channelsExpanded = false),
                                  )
                                : _buildDiscordMiniRail(context, canCreateChannel),
                          ),
                        Expanded(
                          child: _buildChatPane(
                            context,
                            canStartGeneral,
                            isModerator,
                          ),
                        ),
                      ],
                    ),
        );
      },
    );
  }

  Widget _buildDiscordMiniRail(BuildContext context, bool canCreateChannel) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      width: 68,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        border: Border(
          right: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Tooltip(
            message: 'Expand channels',
            child: IconButton(
              icon: const Icon(Icons.menu_open_rounded),
              onPressed: () => setState(() => _channelsExpanded = true),
              style: IconButton.styleFrom(
                foregroundColor: cs.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Divider(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _channels.length,
              itemBuilder: (context, index) {
                final channel = _channels[index];
                final isSelected = _selectedChannel?.id == channel.id;
                final initials = channel.name.trim().isNotEmpty
                    ? (channel.name.trim().length >= 2
                        ? channel.name.trim().substring(0, 2).toUpperCase()
                        : channel.name.trim().toUpperCase())
                    : '#';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Tooltip(
                    message: '# ${channel.name}',
                    preferBelow: false,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 4,
                          height: isSelected ? 28 : 0,
                          decoration: BoxDecoration(
                            color: isSelected ? cs.primary : Colors.transparent,
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(4),
                            ),
                          ),
                        ),
                        Center(
                          child: InkWell(
                            onTap: () => _selectChannel(channel),
                            borderRadius:
                                BorderRadius.circular(isSelected ? 12 : 20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? cs.primary
                                    : cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(
                                  isSelected ? 12 : 20,
                                ),
                                border: Border.all(
                                  color: isSelected
                                      ? cs.primary
                                      : cs.outlineVariant.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  initials,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? cs.onPrimary
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (canCreateChannel)
            Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 4),
              child: Tooltip(
                message: 'Create Channel',
                child: IconButton.filledTonal(
                  icon: const Icon(Icons.add_rounded, size: 20),
                  onPressed: _showCreateChannelDialog,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChatPane(
      BuildContext context, bool canStartGeneral, bool isModerator) {
    if (_selectedChannel == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _channels.isEmpty
                ? 'No channels yet. Create the first channel.'
                : 'Select a channel to start chatting',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark
          ? const Color(0xFF313338)
          : Theme.of(context).colorScheme.surface,
      child: Column(
                              children: [
                                // Filter bar
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 12, 16, 0),
                                  child: Row(
                                    children: [
                                      FilterChip(
                                        selected: _onlyMentions,
                                        label: const Text('Mentions'),
                                        onSelected: (val) {
                                          setState(() => _onlyMentions = val);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                if (_selectedChannel?.type ==
                                        ChannelType.general &&
                                    canStartGeneral)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 8, 16, 8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primaryContainer
                                            .withValues(alpha: 0.35),
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withValues(alpha: 0.15),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.videocam_rounded,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  '${_selectedChannel?.name ?? 'General'} Meeting',
                                                  style: TextStyle(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                Text(
                                                  'Live Video Fellowship Room',
                                                  style: TextStyle(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          FilledButton.icon(
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      LiveKitMeetingScreen(
                                                    customRoomName:
                                                        _selectedChannel!.id,
                                                    isModerator: isModerator,
                                                  ),
                                                ),
                                              );
                                            },
                                            icon: const Icon(
                                                Icons.play_arrow_rounded,
                                                size: 18),
                                            label: const Text('Join'),
                                            style: FilledButton.styleFrom(
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 14,
                                                  vertical: 8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                // Messages area
                                Expanded(
                                  child: _isLoadingMessages
                                      ? const LoadingWidget()
                                      : ListView.builder(
                                          controller: _scrollController,
                                          padding: const EdgeInsets.all(16),
                                          itemCount: (_onlyMentions
                                                  ? _filterMentions(_messages)
                                                  : _messages)
                                              .length,
                                          itemBuilder: (context, index) {
                                            final display = _onlyMentions
                                                ? _filterMentions(_messages)
                                                : _messages;
                                            final message = display[index];
                                            final isConsecutive = index > 0 &&
                                                display[index - 1].senderId ==
                                                    message.senderId &&
                                                message.timestamp
                                                        .difference(
                                                            display[index - 1]
                                                                .timestamp)
                                                        .inMinutes <
                                                    5;

                                            final repliedMessage = message.replyToId != null
                                                ? _messages.cast<ChatMessage?>().firstWhere(
                                                      (m) => m?.id == message.replyToId,
                                                      orElse: () => null,
                                                    )
                                                : null;

                                            return ChatMessageWidget(
                                              message: message,
                                              repliedMessage: repliedMessage,
                                              isConsecutive: isConsecutive,
                                              onReply: (replyMessage) {
                                                setState(() {
                                                  _replyingTo = replyMessage;
                                                });
                                              },
                                              onEdit: (editMsg) =>
                                                  _handleEditMessage(editMsg),
                                              onDelete: (delMsg) =>
                                                  _handleDeleteMessage(delMsg),
                                              onDirectMessage:
                                                  (senderId, senderName) =>
                                                      _startDirectMessage(
                                                targetUserId: senderId,
                                                targetUserName: senderName,
                                              ),
                                              onMention: (mentionName) {
                                                final current =
                                                    _messageController.text;
                                                final prefix = current.isEmpty ||
                                                        current.endsWith(' ')
                                                    ? ''
                                                    : ' ';
                                                _messageController.text =
                                                    '$current$prefix@$mentionName ';
                                                _messageController.selection =
                                                    TextSelection.fromPosition(
                                                  TextPosition(
                                                      offset: _messageController
                                                          .text.length),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                ),
                                // Reply preview banner
                                if (_replyingTo != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      border: Border(
                                        top: BorderSide(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outlineVariant
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.reply_rounded,
                                            size: 18,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Replying to ${_replyingTo!.senderName}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                ),
                                              ),
                                              Text(
                                                _replyingTo!.content,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close,
                                              size: 18),
                                          onPressed: () => setState(
                                              () => _replyingTo = null),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ),
                                  ),
                                // Message input
                                ChatInputWidget(
                                  controller: _messageController,
                                  onSendMessage: _sendMessage,
                                  onSendMessageWithAttachments:
                                      _sendMessageWithAttachments,
                                  onTagSearch: _chatService.getTaggableEntities,
                                ),
                              ],
                            ),
    );
  }

  List<ChatMessage> _filterMentions(List<ChatMessage> input) {
    final currentUser = AuthService.instance.currentUser;
    final currentUserId = currentUser?.uid;
    final currentNameToken = currentUser?.displayName != null &&
            currentUser!.displayName!.trim().isNotEmpty
        ? currentUser.displayName!
            .trim()
            .replaceAll(RegExp(r'\s+'), '_')
            .toLowerCase()
        : null;
    final currentRole = RoleAccessService.instance.getCurrentUserRole();
    if (currentUserId == null && currentRole == null && currentNameToken == null) {
      return input;
    }
    return input.where((m) {
      final lowerUsers = m.taggedUsers.map((u) => u.toLowerCase()).toSet();
      final mentionsUser =
          (currentUserId != null && lowerUsers.contains(currentUserId.toLowerCase())) ||
          (currentNameToken != null && lowerUsers.contains(currentNameToken));
      final mentionsRole =
          currentRole != null && m.taggedGroups.contains(currentRole);
      return mentionsUser || mentionsRole;
    }).toList();
  }

  void _showChannelInfo() {
    if (_selectedChannel == null) return;

    final profile = ref.read(currentUserProfileProvider).value;
    final role = profile?.role.toLowerCase() ?? '';
    final isGlobalAdmin = ['admin', 'bod', 'director', 'trustee'].contains(role) ||
        AppwriteBackendConfig.isSuperAdminEmail(
            AuthService.instance.currentUser?.email);
    final isChannelAdmin = isGlobalAdmin ||
        _selectedChannel!.admins
            .contains(AuthService.instance.currentUser?.uid);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _selectedChannel!.type == ChannelType.direct
                    ? Icons.person_rounded
                    : Icons.tag_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedChannel!.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedChannel!.description.isNotEmpty) ...[
              Text(
                _selectedChannel!.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _selectedChannel!.type.name.toUpperCase(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_alt_rounded,
                          size: 14, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        '${_selectedChannel!.members.length} members',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Created: ${_selectedChannel!.createdAt.toString().split(' ')[0]}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (isChannelAdmin) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _showManageMembersDialog(_selectedChannel!);
                  },
                  icon: const Icon(Icons.manage_accounts_rounded, size: 18),
                  label: const Text('Manage Members (Add / Remove)'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showManageMembersDialog(ChatChannel channel) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ManageMembersDialog(
        channel: channel,
        chatService: _chatService,
        currentUserId: AuthService.instance.currentUser?.uid,
        onMembersUpdated: (updatedMemberIds) {
          setState(() {
            _selectedChannel = _selectedChannel?.copyWith(members: updatedMemberIds);
          });
        },
      ),
    );
  }
}

class _ManageMembersDialog extends StatefulWidget {
  final ChatChannel channel;
  final ChatService chatService;
  final String? currentUserId;
  final Function(List<String> updatedMembers) onMembersUpdated;

  const _ManageMembersDialog({
    required this.channel,
    required this.chatService,
    required this.currentUserId,
    required this.onMembersUpdated,
  });

  @override
  State<_ManageMembersDialog> createState() => _ManageMembersDialogState();
}

class _ManageMembersDialogState extends State<_ManageMembersDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<ChatUser> _channelMembers = [];
  List<ChatUser> _nonMembers = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final allUsers = await widget.chatService.getAllCommunityUsers(limit: 200);
      final memberSet = widget.channel.members.toSet();

      final members = <ChatUser>[];
      final nonMembers = <ChatUser>[];

      for (final user in allUsers) {
        if (memberSet.contains(user.id)) {
          members.add(user);
        } else {
          nonMembers.add(user);
        }
      }

      // Add placeholder for any channel member IDs not in loaded user list
      for (final memberId in widget.channel.members) {
        if (!members.any((u) => u.id == memberId)) {
          members.add(ChatUser(
            id: memberId,
            name: 'Member (${memberId.substring(0, memberId.length.clamp(0, 6))}...)',
            email: '',
            role: UserRole.member,
          ));
        }
      }

      if (mounted) {
        setState(() {
          _channelMembers = members;
          _nonMembers = nonMembers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: $e')),
        );
      }
    }
  }

  Future<void> _addMember(ChatUser user) async {
    try {
      await widget.chatService.addMemberToChannel(widget.channel.id, user.id);
      setState(() {
        _nonMembers.removeWhere((u) => u.id == user.id);
        _channelMembers.add(user);
      });
      widget.onMembersUpdated(_channelMembers.map((u) => u.id).toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} added to #${widget.channel.name}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding member: $e')),
        );
      }
    }
  }

  Future<void> _removeMember(ChatUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
            'Are you sure you want to remove "${user.name}" from #${widget.channel.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await widget.chatService.removeMemberFromChannel(widget.channel.id, user.id);
      setState(() {
        _channelMembers.removeWhere((u) => u.id == user.id);
        _nonMembers.add(user);
      });
      widget.onMembersUpdated(_channelMembers.map((u) => u.id).toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} removed from #${widget.channel.name}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing member: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final filteredNonMembers = _searchQuery.isEmpty
        ? _nonMembers
        : _nonMembers.where((u) {
            final query = _searchQuery.toLowerCase();
            return u.name.toLowerCase().contains(query) ||
                u.email.toLowerCase().contains(query);
          }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dialog Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.manage_accounts_rounded,
                        color: colorScheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Manage Channel Members',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '#${widget.channel.name}',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tab Bar
            TabBar(
              controller: _tabController,
              labelColor: colorScheme.primary,
              indicatorColor: colorScheme.primary,
              tabs: [
                Tab(
                  icon: const Icon(Icons.people_alt_rounded, size: 18),
                  text: 'Current (${_channelMembers.length})',
                ),
                Tab(
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  text: 'Add Member (${_nonMembers.length})',
                ),
              ],
            ),

            // Tab Views
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 1: Current Members
                        _channelMembers.isEmpty
                            ? Center(
                                child: Text(
                                  'No members in this channel yet.',
                                  style: TextStyle(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                itemCount: _channelMembers.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final member = _channelMembers[index];
                                  final isSelf =
                                      widget.currentUserId != null &&
                                          member.id == widget.currentUserId;

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    leading: CircleAvatar(
                                      backgroundColor: colorScheme.primary
                                          .withValues(alpha: 0.15),
                                      child: Text(
                                        member.name.isNotEmpty
                                            ? member.name[0].toUpperCase()
                                            : 'U',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            member.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isSelf) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: colorScheme.primary
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'YOU',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    subtitle: member.email.isNotEmpty
                                        ? Text(
                                            member.email,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: colorScheme.onSurface
                                                  .withValues(alpha: 0.6),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        : null,
                                    trailing: isSelf
                                        ? null
                                        : IconButton(
                                            icon: Icon(
                                              Icons.person_remove_rounded,
                                              color: colorScheme.error,
                                              size: 20,
                                            ),
                                            tooltip: 'Remove from channel',
                                            onPressed: () =>
                                                _removeMember(member),
                                          ),
                                  );
                                },
                              ),

                        // Tab 2: Add Members
                        Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search members by name or email...',
                                  prefixIcon:
                                      const Icon(Icons.search, size: 20),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear,
                                              size: 18),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() => _searchQuery = '');
                                          },
                                        )
                                      : null,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onChanged: (val) {
                                  setState(() => _searchQuery = val.trim());
                                },
                              ),
                            ),
                            Expanded(
                              child: filteredNonMembers.isEmpty
                                  ? Center(
                                      child: Text(
                                        _searchQuery.isEmpty
                                            ? 'All community members are already in this channel!'
                                            : 'No matching users found.',
                                        style: TextStyle(
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.6),
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      itemCount: filteredNonMembers.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final user = filteredNonMembers[index];

                                        return ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 4),
                                          leading: CircleAvatar(
                                            backgroundColor: colorScheme
                                                .secondary
                                                .withValues(alpha: 0.15),
                                            child: Text(
                                              user.name.isNotEmpty
                                                  ? user.name[0].toUpperCase()
                                                  : 'U',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.secondary,
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            user.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: user.email.isNotEmpty
                                              ? Text(
                                                  user.email,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: colorScheme.onSurface
                                                        .withValues(alpha: 0.6),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                )
                                              : null,
                                          trailing: ElevatedButton.icon(
                                            onPressed: () => _addMember(user),
                                            icon: const Icon(
                                                Icons.person_add_rounded,
                                                size: 16),
                                            label: const Text('Add'),
                                            style: ElevatedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 6),
                                              visualDensity:
                                                  VisualDensity.compact,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateChannelDialog extends StatefulWidget {
  final Function(ChatChannel) onChannelCreated;
  final String? currentUserId;
  final bool isAdmin;

  const _CreateChannelDialog({
    required this.onChannelCreated,
    required this.currentUserId,
    this.isAdmin = false,
  });

  @override
  State<_CreateChannelDialog> createState() => _CreateChannelDialogState();
}

class _CreateChannelDialogState extends State<_CreateChannelDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  ChannelType _selectedType = ChannelType.general;
  bool _excludeLeadership = false;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createChannel() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isCreating = true;
    });

    try {
      final isAdmin = widget.isAdmin ||
          RoleAccessService.instance.canAccessAdmin() ||
          AppwriteBackendConfig.isSuperAdminEmail(AuthService.instance.currentUser?.email);
      if (!isAdmin) {
        throw Exception('Only admins can create channels');
      }
      final userId = widget.currentUserId;
      if (userId == null || userId.isEmpty) {
        throw Exception('Please sign in as an admin to create a channel.');
      }
      final channel = await ChatService().createChannel(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        members: [userId],
        admins: [userId],
        excludeLeadership: _excludeLeadership,
      );

      widget.onChannelCreated(channel);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyChannelError(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  String _friendlyChannelError(Object e) {
    final text = e.toString().toLowerCase();
    if (text.contains('only admins can create channels')) {
      return 'Only admins can create channels';
    }
    if (text.contains('not authenticated') || text.contains('sign in')) {
      return 'Please sign in as an admin to create a channel.';
    }
    if (text.contains('permission') || text.contains('unauthorized') || text.contains('403')) {
      return 'Only admins can create channels';
    }
    return 'Channel could not be created. Check your connection and try again.';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Channel'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Channel Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a channel name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ChannelType>(
              initialValue: _selectedType,
              borderRadius: BorderRadius.circular(12),
              dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              icon: const Icon(Icons.arrow_drop_down_rounded),
              decoration: const InputDecoration(
                labelText: 'Channel Type',
                border: OutlineInputBorder(),
              ),
              items: ChannelType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(TextFormatter.formatText(type.name)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Private / Secluded Channel',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Exclude general leadership (Admins, BOD, Directors) from auto-enrollment',
                style: TextStyle(fontSize: 12),
              ),
              value: _excludeLeadership,
              onChanged: (val) => setState(() => _excludeLeadership = val),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createChannel,
          child: _isCreating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
