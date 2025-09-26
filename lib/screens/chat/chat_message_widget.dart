import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import '../../models/chat_models.dart';
import '../../widgets/custom_image.dart';
import '../../widgets/tag_chip.dart';
import '../../utils/logger.dart';
import 'package:timeago/timeago.dart' as timeago;

class ChatMessageWidget extends StatefulWidget {
  final ChatMessage message;
  final bool isConsecutive;
  final Function(ChatMessage)? onReply;
  final Function(ChatMessage)? onEdit;
  final Function(ChatMessage)? onDelete;

  const ChatMessageWidget({
    super.key,
    required this.message,
    this.isConsecutive = false,
    this.onReply,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<ChatMessageWidget> createState() => _ChatMessageWidgetState();
}

class _ChatMessageWidgetState extends State<ChatMessageWidget> {
  bool _isHovered = false;
  bool _showActions = false;
  final Logger _logger = Logger('ChatMessageWidget');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onLongPress: () => setState(() => _showActions = !_showActions),
        child: Container(
          margin: EdgeInsets.only(
            bottom: widget.isConsecutive ? 2 : 12,
            top: widget.isConsecutive ? 0 : 4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Message header (only show if not consecutive)
              if (!widget.isConsecutive) _buildMessageHeader(theme),

              // Message content
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar space (only show if not consecutive)
                  SizedBox(
                    width: widget.isConsecutive ? 40 : 0,
                  ),

                  // Message bubble
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _isHovered
                            ? theme.colorScheme.surface.withValues(alpha: 0.5)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Reply indicator
                          if (widget.message.replyToId != null)
                            _buildReplyIndicator(theme),

                          // Message content with tags
                          _buildMessageContent(theme),

                          // Attachments
                          if (widget.message.attachments.isNotEmpty)
                            _buildAttachments(theme),

                          // Message footer
                          _buildMessageFooter(theme),
                        ],
                      ),
                    ),
                  ),

                  // Action buttons
                  if (_isHovered || _showActions) _buildActionButtons(theme),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 40, bottom: 4),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8),
            child: CustomImage(
              imageUrl: widget.message.senderAvatar,
              width: 32,
              height: 32,
              borderRadius: BorderRadius.circular(16),
              placeholder: CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  widget.message.senderName.isNotEmpty
                      ? widget.message.senderName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // Sender name
          Text(
            widget.message.senderName,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),

          const SizedBox(width: 8),

          // Timestamp
          Text(
            timeago.format(widget.message.timestamp),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),

          // Edited indicator
          if (widget.message.isEdited)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '(edited)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReplyIndicator(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.reply,
            size: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 4),
          Text(
            'Replying to message',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Message text with enhanced tag styling
        RichText(
          text: _buildStyledText(widget.message.content, theme),
        ),
        
        // Display message tags if available (from tagged users and groups)
        if (widget.message.taggedUsers.isNotEmpty || widget.message.taggedGroups.isNotEmpty) ...[
          const SizedBox(height: 8),
          TagChipGroup(
            tags: [
              ...widget.message.taggedUsers.map((userId) => MessageTag(
                type: TagType.user,
                value: userId,
                userId: userId,
              )),
              ...widget.message.taggedGroups.map((groupId) => MessageTag(
                type: TagType.group,
                value: groupId,
              )),
            ],
            currentUserId: 'current_user_id', // TODO: Get from auth service
            userRoles: const [], // TODO: Get user roles
            size: TagChipSize.small,
            onTagTap: (tag) {
              // Handle tag tap - could show user profile, filter messages, etc.
              _handleTagTap(tag);
            },
          ),
        ],
      ],
    );
  }

  TextSpan _buildStyledText(String content, ThemeData theme) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'(@\w+|#\w+|!\w+|\bhttps?://\S+)');
    int lastEnd = 0;

    for (final match in regex.allMatches(content)) {
      // Add text before the match
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: content.substring(lastEnd, match.start),
          style: theme.textTheme.bodyMedium,
        ));
      }

      final matchText = match.group(0)!;
      Color? color;
      FontWeight? fontWeight;

      if (matchText.startsWith('@')) {
        // User mention
        color = theme.colorScheme.primary;
        fontWeight = FontWeight.w600;
      } else if (matchText.startsWith('#')) {
        // Group/role mention
        color = theme.colorScheme.secondary;
        fontWeight = FontWeight.w600;
      } else if (matchText.startsWith('!')) {
        // Special tag mention
        color = theme.colorScheme.tertiary;
        fontWeight = FontWeight.w600;
      } else if (matchText.startsWith('http')) {
        // URL
        color = theme.colorScheme.primary;
      }

      spans.add(TextSpan(
        text: matchText,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: color,
          fontWeight: fontWeight,
          decoration:
              matchText.startsWith('http') ? TextDecoration.underline : null,
        ),
        recognizer: matchText.startsWith('http')
            ? (TapGestureRecognizer()..onTap = () => _launchUrl(matchText))
            : (matchText.startsWith('@') || matchText.startsWith('#') || matchText.startsWith('!'))
                ? (TapGestureRecognizer()..onTap = () => _handleInlineTagTap(matchText))
                : null,
      ));

      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastEnd),
        style: theme.textTheme.bodyMedium,
      ));
    }

    return TextSpan(children: spans);
  }

  void _handleTagTap(MessageTag tag) {
    // Handle tag chip tap
    switch (tag.type) {
      case TagType.user:
        // Show user profile or start direct message
        _showUserProfile(tag.userId);
        break;
      case TagType.role:
      case TagType.group:
        // Filter messages by role/group
        _filterMessagesByTag(tag);
        break;
      case TagType.special:
        // Handle special tag actions
        _handleSpecialTag(tag);
        break;
    }
  }

  void _handleInlineTagTap(String tagText) {
    // Handle inline tag tap in message content
    if (tagText.startsWith('@')) {
      // Handle user mention tap
      final username = tagText.substring(1);
      _showUserProfileByName(username);
    } else if (tagText.startsWith('#')) {
      // Handle role/group mention tap
      final tagValue = tagText.substring(1);
      _filterMessagesByTagValue(tagValue);
    } else if (tagText.startsWith('!')) {
      // Handle special tag tap
      final specialTag = tagText.substring(1);
      _handleSpecialTagByValue(specialTag);
    }
  }

  void _showUserProfile(String? userId) {
    if (userId != null) {
      // Implementation to show user profile
      _logger.info('Show user profile: $userId');
    }
  }

  void _showUserProfileByName(String username) {
    // Implementation to show user profile by username
    _logger.info('Show user profile by name: $username');
  }

  void _filterMessagesByTag(MessageTag tag) {
    // Implementation to filter messages by tag
    _logger.info('Filter messages by tag: ${tag.value}');
  }

  void _filterMessagesByTagValue(String tagValue) {
    // Implementation to filter messages by tag value
    _logger.info('Filter messages by tag value: $tagValue');
  }

  void _handleSpecialTag(MessageTag tag) {
    // Implementation to handle special tag actions
    _logger.info('Handle special tag: ${tag.value}');
  }

  void _handleSpecialTagByValue(String specialTag) {
    // Implementation to handle special tag by value
    _logger.info('Handle special tag by value: $specialTag');
  }

  Widget _buildAttachments(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: widget.message.attachments.map((attachment) {
          return _buildAttachment(attachment, theme);
        }).toList(),
      ),
    );
  }

  Widget _buildAttachment(String attachment, ThemeData theme) {
    final isImage = attachment
        .toLowerCase()
        .contains(RegExp(r'\.(jpg|jpeg|png|gif|webp)$'));

    if (isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomImage(
          imageUrl: attachment,
          width: 200,
          height: 150,
          fit: BoxFit.cover,
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.attach_file,
              size: 20,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Text(
              attachment.split('/').last,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildMessageFooter(ThemeData theme) {
    if (widget.message.taggedUsers.isEmpty &&
        widget.message.taggedGroups.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          ...widget.message.taggedUsers
              .map((user) => _buildTag('@$user', theme.colorScheme.primary)),
          ...widget.message.taggedGroups.map(
              (group) => _buildTag('#$group', theme.colorScheme.secondary)),
        ],
      ),
    );
  }

  Widget _buildTag(String tag, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.reply, size: 18),
            onPressed: () => widget.onReply?.call(widget.message),
            tooltip: 'Reply',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.content_copy, size: 18),
            onPressed: () => _copyMessage(),
            tooltip: 'Copy',
            visualDensity: VisualDensity.compact,
          ),
          if (widget.message.senderId == 'current-user-id') ...[
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => widget.onEdit?.call(widget.message),
              tooltip: 'Edit',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 18),
              onPressed: () => widget.onDelete?.call(widget.message),
              tooltip: 'Delete',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }

  void _copyMessage() {
    Clipboard.setData(ClipboardData(text: widget.message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _launchUrl(String url) {
    // Implement URL launching
    // You can use url_launcher package
  }
}




