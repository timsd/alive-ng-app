import 'package:flutter/material.dart';
import '../../models/chat_models.dart';
import 'package:timeago/timeago.dart' as timeago;

class ChannelListWidget extends StatefulWidget {
  final List<ChatChannel> channels;
  final ChatChannel? selectedChannel;
  final Function(ChatChannel) onChannelSelected;
  final VoidCallback? onRefresh;
  final Function(ChatChannel)? onChannelLongPress;

  const ChannelListWidget({
    super.key,
    required this.channels,
    this.selectedChannel,
    required this.onChannelSelected,
    this.onRefresh,
    this.onChannelLongPress,
  });

  @override
  State<ChannelListWidget> createState() => _ChannelListWidgetState();
}

class _ChannelListWidgetState extends State<ChannelListWidget> {
  final TextEditingController _searchController = TextEditingController();
  List<ChatChannel> _filteredChannels = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _filteredChannels = widget.channels;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(ChannelListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channels != widget.channels) {
      _filterChannels();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
    _filterChannels();
  }

  void _filterChannels() {
    setState(() {
      if (_searchQuery.isEmpty) {
        _filteredChannels = widget.channels;
      } else {
        _filteredChannels = widget.channels.where((channel) {
          return channel.name.toLowerCase().contains(_searchQuery) ||
              channel.description.toLowerCase().contains(_searchQuery) ||
              channel.type.name.toLowerCase().contains(_searchQuery);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor,
                ),
              ),
            ),
            child: Column(
              children: [
                // Title and refresh button
                Row(
                  children: [
                    Text(
                      'Channels',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (widget.onRefresh != null)
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: widget.onRefresh,
                        tooltip: 'Refresh channels',
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search channels...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),

          // Channel list
          Expanded(
            child: _filteredChannels.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
                    itemCount: _filteredChannels.length,
                    itemBuilder: (context, index) {
                      final channel = _filteredChannels[index];
                      final isSelected =
                          widget.selectedChannel?.id == channel.id;

                      return _buildChannelItem(
                        channel,
                        isSelected,
                        theme,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty
                ? Icons.search_off
                : Icons.chat_bubble_outline,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No channels found'
                : 'No channels available',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Create a new channel to get started',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChannelItem(
    ChatChannel channel,
    bool isSelected,
    ThemeData theme,
  ) {
    return InkWell(
      onTap: () => widget.onChannelSelected(channel),
      onLongPress: () => widget.onChannelLongPress?.call(channel),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : null,
          border: isSelected
              ? Border(
                  right: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 3,
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            // Channel icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getChannelColor(channel.type, theme),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getChannelIcon(channel.type),
                color: Colors.white,
                size: 20,
              ),
            ),

            const SizedBox(width: 12),

            // Channel info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Channel name and unread count
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          channel.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: channel.unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color:
                                isSelected ? theme.colorScheme.primary : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Unread count badge
                      if (channel.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            channel.unreadCount > 99
                                ? '99+'
                                : channel.unreadCount.toString(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onError,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Last message or description
                  Text(
                    channel.lastMessage ?? channel.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),

                  const SizedBox(height: 2),

                  // Channel type and last message time
                  Row(
                    children: [
                      // Channel type badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getChannelColor(channel.type, theme)
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          channel.type.name.toUpperCase(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _getChannelColor(channel.type, theme),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Last message time
                      if (channel.lastMessageAt != null)
                        Text(
                          timeago.format(channel.lastMessageAt!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                            fontSize: 11,
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

  IconData _getChannelIcon(ChannelType type) {
    switch (type) {
      case ChannelType.general:
        return Icons.chat;
      case ChannelType.bod:
        return Icons.business;
      case ChannelType.directors:
        return Icons.supervisor_account;
      case ChannelType.coordinators:
        return Icons.people;
      case ChannelType.chapter:
        return Icons.group;
      case ChannelType.team:
        return Icons.groups;
      case ChannelType.direct:
        return Icons.person;
      case ChannelType.announcement:
        return Icons.campaign;
    }
  }

  Color _getChannelColor(ChannelType type, ThemeData theme) {
    switch (type) {
      case ChannelType.general:
        return theme.colorScheme.primary;
      case ChannelType.bod:
        return Colors.purple;
      case ChannelType.directors:
        return Colors.orange;
      case ChannelType.coordinators:
        return Colors.blue;
      case ChannelType.chapter:
        return Colors.green;
      case ChannelType.team:
        return Colors.teal;
      case ChannelType.direct:
        return Colors.pink;
      case ChannelType.announcement:
        return Colors.red;
    }
  }
}
