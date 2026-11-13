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
import '../../services/org_structure_service.dart';
import '../../utils/text_formatter.dart';
import 'components/create_channel_dialog.dart';
import 'components/manage_members_dialog.dart';

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
      builder: (context) => CreateChannelDialog(
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
    final profile = ref.read(currentUserProfileProvider).value;
    final userRole = (profile?.role ?? RoleAccessService.instance.getCurrentUserRole() ?? '').toLowerCase();

    final isBod = userRole == 'bod' ||
        userRole == 'board' ||
        userRole.contains('bod') ||
        userRole.contains('board') ||
        OrgStructureService.instance.isBodMemberSync(userId: currentUserId);
    final isAdmin = userRole == 'admin' ||
        userRole == 'super_admin' ||
        AppwriteBackendConfig.isSuperAdminEmail(currentUser?.email);
    final isDirector = userRole.contains('director');
    final isCoordinator = userRole.contains('coordinator') || userRole.contains('coor');

    final relevantGroups = <String>{};
    if (userRole.isNotEmpty) relevantGroups.add(userRole);
    if (isBod || isAdmin) {
      relevantGroups.addAll(['bod', 'board', 'board_of_directors', 'leadership']);
    }
    if (isDirector || isAdmin) {
      relevantGroups.addAll(['director', 'directors', 'leadership']);
    }
    if (isAdmin) {
      relevantGroups.addAll(['admin', 'super_admin', 'leadership']);
    }
    if (isCoordinator) {
      relevantGroups.addAll(['coordinator', 'coordinators', 'chap_coor']);
    }

    final nameTokens = <String>{};
    if (currentUserId != null) nameTokens.add(currentUserId.toLowerCase());
    if (profile?.fullName != null && profile!.fullName!.trim().isNotEmpty) {
      final fn = profile.fullName!.trim().toLowerCase();
      nameTokens.add(fn.replaceAll(RegExp(r'\s+'), '_'));
      nameTokens.add(fn);
      for (final part in fn.split(RegExp(r'\s+'))) {
        if (part.length > 2) nameTokens.add(part);
      }
    }
    if (currentUser?.displayName != null && currentUser!.displayName!.trim().isNotEmpty) {
      final dn = currentUser.displayName!.trim().toLowerCase();
      nameTokens.add(dn.replaceAll(RegExp(r'\s+'), '_'));
      nameTokens.add(dn);
      for (final part in dn.split(RegExp(r'\s+'))) {
        if (part.length > 2) nameTokens.add(part);
      }
    }

    if (nameTokens.isEmpty && relevantGroups.isEmpty) {
      return input;
    }

    return input.where((m) {
      final lowerUsers = m.taggedUsers.map((u) => u.toLowerCase()).toSet();
      final lowerGroups = m.taggedGroups.map((g) => g.toLowerCase()).toSet();
      final lowerContent = m.content.toLowerCase();

      final mentionsUser = nameTokens.any((t) => lowerUsers.contains(t) || lowerContent.contains('@$t'));
      final mentionsRole = relevantGroups.any((g) => lowerGroups.contains(g) || lowerContent.contains('#$g'));
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
      builder: (context) => ManageMembersDialog(
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
