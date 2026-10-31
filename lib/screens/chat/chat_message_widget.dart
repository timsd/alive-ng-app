import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

import '../../models/chat_models.dart';
import '../../services/auth_service.dart';
import '../../services/role_access_service.dart';
import '../../utils/logger.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/custom_image.dart';
import '../../widgets/tag_chip.dart';

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
            bottom: widget.isConsecutive ? ResponsiveUtils.getResponsiveValue(context: context, mobile: 2.0, tablet: 3.0, desktop: 4.0) : ResponsiveUtils.getResponsiveValue(context: context, mobile: 12.0, tablet: 14.0, desktop: 16.0),
            top: widget.isConsecutive ? 0 : ResponsiveUtils.getResponsiveValue(context: context, mobile: 4.0, tablet: 5.0, desktop: 6.0),
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
                    width: widget.isConsecutive ? ResponsiveUtils.getResponsiveValue(context: context, mobile: 40.0, tablet: 44.0, desktop: 48.0) : 0,
                  ),

                  // Message bubble
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12.0, tablet: 14.0, desktop: 16.0),
                        vertical: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8.0, tablet: 10.0, desktop: 12.0),
                      ),
                      decoration: BoxDecoration(
                        color: _isHovered
                            ? theme.colorScheme.surface.withValues(alpha: 0.5)
                            : Colors.transparent,
                        borderRadius: context.responsiveBorderRadius,
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
      padding: EdgeInsets.only(
        left: ResponsiveUtils.getResponsiveValue(context: context, mobile: 40.0, tablet: 44.0, desktop: 48.0), 
        bottom: ResponsiveUtils.getResponsiveValue(context: context, mobile: 4.0, tablet: 5.0, desktop: 6.0)
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: ResponsiveUtils.getResponsiveValue(context: context, mobile: 32.0, tablet: 36.0, desktop: 40.0),
            height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 32.0, tablet: 36.0, desktop: 40.0),
            margin: EdgeInsets.only(right: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8.0, tablet: 10.0, desktop: 12.0)),
            child: CustomImage(
              imageUrl: widget.message.senderAvatar,
              width: ResponsiveUtils.getResponsiveValue(context: context, mobile: 32.0, tablet: 36.0, desktop: 40.0),
              height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 32.0, tablet: 36.0, desktop: 40.0),
              borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(context: context, mobile: 16.0, tablet: 18.0, desktop: 20.0)),
              placeholder: CircleAvatar(
                radius: ResponsiveUtils.getResponsiveValue(context: context, mobile: 16.0, tablet: 18.0, desktop: 20.0),
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

          SizedBox(width: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8.0, tablet: 10.0, desktop: 12.0)),

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
              padding: EdgeInsets.only(left: ResponsiveUtils.getResponsiveValue(context: context, mobile: 4.0, tablet: 5.0, desktop: 6.0)),
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
      margin: EdgeInsets.only(bottom: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8.0, tablet: 10.0, desktop: 12.0)),
      padding: context.responsivePadding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: context.responsiveBorderRadius,
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.primary,
            width: ResponsiveUtils.getResponsiveValue(context: context, mobile: 3.0, tablet: 3.5, desktop: 4.0),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.reply,
            size: context.responsiveIconSize(16),
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          SizedBox(width: ResponsiveUtils.getResponsiveValue(context: context, mobile: 4.0, tablet: 5.0, desktop: 6.0)),
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
          SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8.0, tablet: 10.0, desktop: 12.0)),
          TagChipGroup(
            tags: [
              ...widget.message.taggedUsers.map((userId) => MessageTag(
                type: TagType.user,
                value: userId,
                displayName: '@${userId.replaceAll('_', ' ')}',
                userId: userId,
              )),
              ...widget.message.taggedGroups.map((groupId) => MessageTag(
                type: TagType.group,
                value: groupId,
              )),
            ],
            currentUserId: AuthService.instance.currentUser?.uid ?? 'anonymous',
            userRoles: RoleAccessService.instance.getCurrentUserRole() != null 
                ? [RoleAccessService.instance.getCurrentUserRole()!] 
                : [],
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

      final displayMatchText = matchText.startsWith('@')
          ? matchText.replaceAll('_', ' ')
          : matchText;
      spans.add(TextSpan(
        text: displayMatchText,
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
      margin: EdgeInsets.only(top: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8.0, tablet: 10.0, desktop: 12.0)),
      child: Wrap(
        spacing: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8.0, tablet: 10.0, desktop: 12.0),
        runSpacing: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8.0, tablet: 10.0, desktop: 12.0),
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
        borderRadius: context.responsiveBorderRadius,
        child: CustomImage(
          imageUrl: attachment,
          width: ResponsiveUtils.getResponsiveValue(context: context, mobile: 200.0, tablet: 220.0, desktop: 240.0),
          height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 150.0, tablet: 165.0, desktop: 180.0),
          fit: BoxFit.cover,
        ),
      );
    } else {
      return Container(
        padding: context.responsivePadding,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: context.responsiveBorderRadius,
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.attach_file,
              size: context.responsiveIconSize(20),
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            SizedBox(width: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8.0, tablet: 10.0, desktop: 12.0)),
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
      margin: EdgeInsets.only(top: ResponsiveUtils.getResponsiveValue(context: context, mobile: 4.0, tablet: 5.0, desktop: 6.0)),
      child: Wrap(
        spacing: ResponsiveUtils.getResponsiveValue(context: context, mobile: 4.0, tablet: 5.0, desktop: 6.0),
        runSpacing: ResponsiveUtils.getResponsiveValue(context: context, mobile: 4.0, tablet: 5.0, desktop: 6.0),
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
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getResponsiveValue(context: context, mobile: 6.0, tablet: 7.0, desktop: 8.0), 
        vertical: ResponsiveUtils.getResponsiveValue(context: context, mobile: 2.0, tablet: 3.0, desktop: 4.0)
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(context: context, mobile: 12.0, tablet: 14.0, desktop: 16.0)),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: context.responsiveFontSize(12),
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    final currentUserId = AuthService.instance.currentUser?.uid;

    return Container(
      margin: EdgeInsets.only(
        left: ResponsiveUtils.getResponsiveValue(
          context: context,
          mobile: 8.0,
          tablet: 10.0,
          desktop: 12.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.reply, size: context.responsiveIconSize(18)),
            onPressed: () => widget.onReply?.call(widget.message),
            tooltip: 'Reply',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: Icon(Icons.content_copy, size: context.responsiveIconSize(18)),
            onPressed: () => _copyMessage(),
            tooltip: 'Copy',
            visualDensity: VisualDensity.compact,
          ),
          if (currentUserId != null &&
              widget.message.senderId == currentUserId) ...[
            IconButton(
              icon: Icon(Icons.edit, size: context.responsiveIconSize(18)),
              onPressed: () => widget.onEdit?.call(widget.message),
              tooltip: 'Edit',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: Icon(Icons.delete, size: context.responsiveIconSize(18)),
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

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}




