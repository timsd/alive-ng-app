import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/chat_models.dart';
import '../../services/chat_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_loading.dart';
import '../../widgets/custom_error_widget.dart';
import 'chat_message_widget.dart';
import 'chat_input_widget.dart';
import 'channel_list_widget.dart';

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

  List<ChatChannel> _channels = [];
  List<ChatMessage> _messages = [];
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

      // Get current user ID (you'll need to implement this)
      final userId = 'current-user-id'; // Replace with actual user ID
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
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectChannelById(String channelId) async {
    final channel = _channels.firstWhere(
      (c) => c.id == channelId,
      orElse: () => _channels.isNotEmpty ? _channels.first : _channels.first,
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
      _showError('Failed to load messages: $e');
    }
  }

  Future<void> _sendMessage(String content, {String? replyToId}) async {
    if (_selectedChannel == null || content.trim().isEmpty) return;

    try {
      final message = await _chatService.sendMessage(
        channelId: _selectedChannel!.id,
        content: content.trim(),
        replyToId: replyToId,
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
      _showError('Failed to send message: $e');
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
    showDialog(
      context: context,
      builder: (context) => _CreateChannelDialog(
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
    return Scaffold(
      appBar: CustomAppBar(
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
          ? const CustomLoading()
          : _error != null
              ? CustomErrorWidget(
                  message: _error!,
                  onRetry: _loadChannels,
                )
              : Row(
                  children: [
                    // Channel list sidebar
                    Container(
                      width: 300,
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                      ),
                      child: ChannelListWidget(
                        channels: _channels,
                        selectedChannel: _selectedChannel,
                        onChannelSelected: _selectChannel,
                        onRefresh: _loadChannels,
                      ),
                    ),
                    // Chat area
                    Expanded(
                      child: _selectedChannel == null
                          ? const Center(
                              child: Text(
                                'Select a channel to start chatting',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                // Messages area
                                Expanded(
                                  child: _isLoadingMessages
                                      ? const CustomLoading()
                                      : ListView.builder(
                                          controller: _scrollController,
                                          padding: const EdgeInsets.all(16),
                                          itemCount: _messages.length,
                                          itemBuilder: (context, index) {
                                            final message = _messages[index];
                                            final isConsecutive = index > 0 &&
                                                _messages[index - 1].senderId ==
                                                    message.senderId &&
                                                message.timestamp
                                                        .difference(
                                                            _messages[index - 1]
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
                                  onTagSearch: _chatService.getTaggableEntities,
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
    );
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

  const _CreateChannelDialog({required this.onChannelCreated});

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
      final channel = await ChatService().createChannel(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        members: ['current-user-id'], // Replace with actual user ID
      );

      widget.onChannelCreated(channel);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create channel: $e'),
            backgroundColor: Colors.red,
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
