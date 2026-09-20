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

class ChatScreen extends ConsumerStatefulWidget {
  final String? channelId;

  const ChatScreen({super.key, this.channelId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  bool _channelsExpanded = true;

  List<ChatChannel> _channels = [];
  List<ChatMessage> _messages = [];
  bool _onlyMentions = false;
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
        replyToId: replyToId,
        tags: TagParser.parseUniqueMessage(content),
      );

      setState(() {
        _messages.add(message);
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

  void _showCreateChannelDialog() {
    final isAdmin = RoleAccessService.instance.canAccessAdmin();
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
    if (userProfileAsync.hasValue && userProfileAsync.value != null) {
      final role = (userProfileAsync.value!.role).toLowerCase();
      const allowedRoles = [
        'admin',
        'bod',
        'director',
        'chapter_leader',
        'moderator',
        'leader',
      ];
      const moderatorRoles = [
        'admin',
        'bod',
        'director',
      ];
      canStartGeneral = allowedRoles.contains(role);
      isModerator = moderatorRoles.contains(role);
    }

    return Scaffold(
      appBar: CustomAppBar(
        showBackButton: true,
        title: _selectedChannel?.name ?? 'Chat',
        actions: [
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
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 720;
                    final channelPane = _channelsExpanded
                        ? ChannelListWidget(
                            channels: _channels,
                            selectedChannel: _selectedChannel,
                            onChannelSelected: (channel) {
                              _selectChannel(channel);
                              if (!isWide) {
                                setState(() => _channelsExpanded = false);
                              }
                            },
                            onRefresh: _loadChannels,
                          )
                        : const SizedBox.shrink();
                    if (!isWide) {
                      return Column(
                        children: [
                          ListTile(
                            leading: Icon(_channelsExpanded ? Icons.expand_less : Icons.expand_more),
                            title: Text(
                              _selectedChannel?.name ?? 'Channels (${_channels.length})',
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: TextButton.icon(
                              onPressed: () => setState(() => _channelsExpanded = !_channelsExpanded),
                              icon: Icon(_channelsExpanded ? Icons.visibility_off : Icons.forum),
                              label: Text(_channelsExpanded ? 'Hide' : 'Show'),
                            ),
                            onTap: () => setState(() => _channelsExpanded = !_channelsExpanded),
                          ),
                          const Divider(height: 1),
                          if (_channelsExpanded)
                            Expanded(child: channelPane)
                          else
                            Expanded(child: _buildChatPane(context, canStartGeneral, isModerator)),
                          if (_channelsExpanded)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _selectedChannel == null
                                      ? null
                                      : () => setState(() => _channelsExpanded = false),
                                  icon: const Icon(Icons.chat),
                                  label: Text(_selectedChannel == null ? 'Select a channel above' : 'Open ${_selectedChannel!.name}'),
                                ),
                              ),
                            ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: _channelsExpanded ? 300 : 56,
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(color: Theme.of(context).dividerColor),
                            ),
                          ),
                          child: _channelsExpanded
                              ? channelPane
                              : Column(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.chevron_right),
                                      tooltip: 'Show channels',
                                      onPressed: () => setState(() => _channelsExpanded = true),
                                    ),
                                  ],
                                ),
                        ),
                        Expanded(child: _buildChatPane(context, canStartGeneral, isModerator)),
                      ],
                    );
                  },
                ),
    );
  }

  Widget _buildChatPane(BuildContext context, bool canStartGeneral, bool isModerator) {
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
    return Column(
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
                                        16, 16, 16, 0),
                                    child: Card(
                                      color: Theme.of(context)
                                          .primaryColor
                                          .withValues(alpha: 0.08),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Row(
                                          children: [
                                            Icon(Icons.video_call,
                                                color: Theme.of(context)
                                                    .primaryColor),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'General Meeting is available',
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .primaryColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            ElevatedButton.icon(
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
                                              icon:
                                                  const Icon(Icons.play_arrow),
                                              label: const Text('Join'),
                                            ),
                                          ],
                                        ),
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

                                            return ChatMessageWidget(
                                              message: message,
                                              isConsecutive: isConsecutive,
                                              onReply: (replyMessage) {
                                                // Handle reply
                                              },
                                            );
                                          },
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
    );
  }

  List<ChatMessage> _filterMentions(List<ChatMessage> input) {
    final currentUserId = AuthService.instance.currentUser?.uid;
    final currentRole = RoleAccessService.instance.getCurrentUserRole();
    if (currentUserId == null && currentRole == null) return input;
    return input.where((m) {
      final mentionsUser =
          currentUserId != null && m.taggedUsers.contains(currentUserId);
      final mentionsRole =
          currentRole != null && m.taggedGroups.contains(currentRole);
      return mentionsUser || mentionsRole;
    }).toList();
  }

  void _showChannelInfo() {
    if (_selectedChannel == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_selectedChannel!.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Description: ${_selectedChannel!.description}'),
            const SizedBox(height: 8),
            Text('Type: ${_selectedChannel!.type.name.toUpperCase()}'),
            const SizedBox(height: 8),
            Text('Members: ${_selectedChannel!.members.length}'),
            const SizedBox(height: 8),
            Text(
                'Created: ${_selectedChannel!.createdAt.toString().split(' ')[0]}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _CreateChannelDialog extends StatefulWidget {
  final Function(ChatChannel) onChannelCreated;
  final String? currentUserId;

  const _CreateChannelDialog({
    required this.onChannelCreated,
    required this.currentUserId,
  });

  @override
  State<_CreateChannelDialog> createState() => _CreateChannelDialogState();
}

class _CreateChannelDialogState extends State<_CreateChannelDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  ChannelType _selectedType = ChannelType.general;
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
      final isAdmin = RoleAccessService.instance.canAccessAdmin();
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
              decoration: const InputDecoration(
                labelText: 'Channel Type',
                border: OutlineInputBorder(),
              ),
              items: ChannelType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.name.toUpperCase()),
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
