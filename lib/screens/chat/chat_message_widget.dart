import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/chat_models.dart';
import '../../providers/appwrite_auth_provider.dart';
import '../../services/appwrite_chat_service.dart';
import '../../services/auth_service.dart';
import '../../services/role_access_service.dart';
import '../../utils/logger.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/custom_image.dart';

/// A Discord-accurate chat message item featuring:
/// - Left circular avatar (or blank spacing for consecutive messages)
/// - Top header with Sender Name (Discord accent), Role Badge, and Timestamp
/// - Discord curved reply spine (`┌─`) with mini-avatar, `@replied_to`, and snippet
/// - Flat Discord dark/light background without artificial message bubble containers
/// - Inline blurple mention pills (`@User`) without duplicate boxed chip footers
/// - Clickable avatar/username/mentions to view user profile and Direct Message directly
class ChatMessageWidget extends ConsumerStatefulWidget {
  final ChatMessage message;
  final ChatMessage? repliedMessage;
  final bool isConsecutive;
  final Function(ChatMessage)? onReply;
  final Function(ChatMessage)? onEdit;
  final Function(ChatMessage)? onDelete;
  final Function(String senderId, String senderName)? onDirectMessage;
  final Function(String mentionName)? onMention;

  const ChatMessageWidget({
    super.key,
    required this.message,
    this.repliedMessage,
    this.isConsecutive = false,
    this.onReply,
    this.onEdit,
    this.onDelete,
    this.onDirectMessage,
    this.onMention,
  });

  @override
  ConsumerState<ChatMessageWidget> createState() => _ChatMessageWidgetState();
}

class _ChatMessageWidgetState extends ConsumerState<ChatMessageWidget> {
  static final Map<String, String> _userAvatarCache = {};
  bool _isHovered = false;
  bool _showActions = false;
  final Logger _logger = Logger('ChatMessageWidget');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasReply = widget.message.replyToId != null;

    // Discord message row styling: flat row with subtle hover highlight
    final hoverColor = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.03);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onLongPress: () => setState(() => _showActions = !_showActions),
        child: Container(
          width: double.infinity,
          color: (_isHovered || _showActions) ? hoverColor : Colors.transparent,
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 12.0,
              tablet: 16.0,
              desktop: 20.0,
            ),
            vertical: (widget.isConsecutive && !hasReply) ? 2.0 : 6.0,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Discord Curved Reply Spine & Header (shown if replying)
                  if (hasReply) _buildDiscordReplyHeader(theme, isDark),

                  // Main message row (Avatar on left, Content on right)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Avatar or Hover Timestamp
                      _buildLeftColumn(theme, isDark, hasReply),

                      const SizedBox(width: 14),

                      // Right Column: Sender Header + Content + Attachments
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!widget.isConsecutive || hasReply)
                              _buildSenderHeader(theme, isDark),

                            // Main message text with inline Discord mentions
                            _buildMessageContent(theme, isDark),

                            // Attachments (images/files)
                            if (widget.message.attachments.isNotEmpty)
                              _buildAttachments(theme),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Floating Discord Action Pill on hover/long press
              if (_isHovered || _showActions)
                Positioned(
                  top: -8,
                  right: 8,
                  child: _buildFloatingActions(theme, isDark),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String? _resolveAvatar(String senderId, String? senderAvatar) {
    if (senderAvatar != null && senderAvatar.trim().isNotEmpty) {
      _userAvatarCache[senderId] = senderAvatar.trim();
      return senderAvatar.trim();
    }
    final currentUserId = AuthService.instance.currentUser?.uid;
    if (senderId == currentUserId) {
      final myAvatar = ref.watch(currentUserAvatarUrlProvider);
      if (myAvatar != null && myAvatar.trim().isNotEmpty) {
        _userAvatarCache[senderId] = myAvatar.trim();
        return myAvatar.trim();
      }
    }
    if (_userAvatarCache.containsKey(senderId)) {
      return _userAvatarCache[senderId];
    }
    _lookupAvatar(senderId);
    return null;
  }

  void _lookupAvatar(String senderId) {
    if (senderId.isEmpty || _userAvatarCache.containsKey(senderId)) return;
    AppwriteChatService().getChatUser(senderId).then((user) {
      if (user?.avatar != null && user!.avatar!.trim().isNotEmpty && mounted) {
        setState(() {
          _userAvatarCache[senderId] = user.avatar!.trim();
        });
      }
    }).catchError((_) {});
  }

  /// Discord-style curved reply spine (`┌─`) with mini-avatar, `@target` mention, and snippet
  Widget _buildDiscordReplyHeader(ThemeData theme, bool isDark) {
    final spineColor = isDark
        ? const Color(0xFF4E5058)
        : const Color(0xFFB5BAC1);
    final replied = widget.repliedMessage;
    final repliedSender = replied?.senderName ?? 'User';
    final snippet = replied?.content.replaceAll('\n', ' ') ?? 'Original message';
    final resolvedRepliedAvatar = replied != null
        ? _resolveAvatar(replied.senderId, replied.senderAvatar)
        : null;

    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CustomPaint(
            size: const Size(28, 14),
            painter: _DiscordReplySpinePainter(color: spineColor),
          ),
          const SizedBox(width: 4),
          // Mini circular avatar
          ClipOval(
            child: SizedBox(
              width: 16,
              height: 16,
              child: resolvedRepliedAvatar != null &&
                      resolvedRepliedAvatar.trim().isNotEmpty
                  ? CustomImage(
                      imageUrl: resolvedRepliedAvatar,
                      width: 16,
                      height: 16,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: isDark ? const Color(0xFF5865F2) : const Color(0xFF4752C4),
                      alignment: Alignment.center,
                      child: Text(
                        repliedSender.isNotEmpty
                            ? repliedSender[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 6),
          // Clickable Replied Username
          InkWell(
            onTap: () {
              if (replied != null) {
                _showUserCardModal(
                  context,
                  replied.senderId,
                  replied.senderName,
                  resolvedRepliedAvatar,
                );
              }
            },
            borderRadius: BorderRadius.circular(4),
            child: Text(
              '@$repliedSender',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF58A6FF) : const Color(0xFF0969DA),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Snippet of original text
          Expanded(
            child: Text(
              snippet,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? const Color(0xFF949BA4)
                    : const Color(0xFF747F8D),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Left column: 40px avatar on non-consecutive; or blank spacing with hover timestamp on consecutive
  Widget _buildLeftColumn(ThemeData theme, bool isDark, bool hasReply) {
    if (!widget.isConsecutive || hasReply) {
      final resolvedAvatar =
          _resolveAvatar(widget.message.senderId, widget.message.senderAvatar);

      return InkWell(
        onTap: () => _showUserCardModal(
          context,
          widget.message.senderId,
          widget.message.senderName,
          resolvedAvatar,
        ),
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 40,
          height: 40,
          child: ClipOval(
            child: resolvedAvatar != null && resolvedAvatar.trim().isNotEmpty
                ? CustomImage(
                    imageUrl: resolvedAvatar,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    placeholder: _buildFallbackAvatar(theme, isDark),
                  )
                : _buildFallbackAvatar(theme, isDark),
          ),
        ),
      );
    }

    // Consecutive message: show small muted timestamp on hover, aligned with avatar column
    return SizedBox(
      width: 40,
      child: _isHovered
          ? Center(
              child: Text(
                DateFormat('h:mm').format(widget.message.timestamp.toLocal()),
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? const Color(0xFF949BA4)
                      : const Color(0xFF747F8D),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildFallbackAvatar(ThemeData theme, bool isDark) {
    final initial = widget.message.senderName.trim().isNotEmpty
        ? widget.message.senderName.trim()[0].toUpperCase()
        : '?';
    return Container(
      width: 40,
      height: 40,
      color: isDark ? const Color(0xFF5865F2) : theme.colorScheme.primary,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Top row with Sender Name (Discord accent), Role Badge, Timestamp, and Edited tag
  Widget _buildSenderHeader(ThemeData theme, bool isDark) {
    final timeStr = DateFormat('MM/dd/yyyy h:mm a')
        .format(widget.message.timestamp.toLocal());
    final roleBadge = _resolveRoleBadge();

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 2,
        children: [
          // Clickable sender name
          InkWell(
            onTap: () => _showUserCardModal(
              context,
              widget.message.senderId,
              widget.message.senderName,
              _resolveAvatar(widget.message.senderId, widget.message.senderAvatar),
            ),
            borderRadius: BorderRadius.circular(4),
            child: Text(
              widget.message.senderName,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF58A6FF) : const Color(0xFF0969DA),
              ),
            ),
          ),

          // Role Badge (e.g. [ ADMIN ], [ LEADER ], [ BOD ])
          if (roleBadge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFF5865F2).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: const Color(0xFF5865F2).withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Text(
                roleBadge.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: Color(0xFFC9CDFB),
                ),
              ),
            ),

          // Timestamp
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: isDark ? const Color(0xFF949BA4) : const Color(0xFF747F8D),
            ),
          ),

          // Edited indicator
          if (widget.message.isEdited)
            Text(
              '(edited)',
              style: TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: isDark
                    ? const Color(0xFF949BA4).withValues(alpha: 0.7)
                    : const Color(0xFF747F8D),
              ),
            ),
        ],
      ),
    );
  }

  String? _resolveRoleBadge() {
    if (widget.message.taggedGroups.isNotEmpty) {
      return widget.message.taggedGroups.first.replaceAll('_', ' ');
    }
    final nameLower = widget.message.senderName.toLowerCase();
    if (nameLower.contains('admin')) return 'Admin';
    if (nameLower.contains('pastor') || nameLower.contains('dr.')) return 'Leader';
    if (nameLower.contains('coordinator')) return 'Coordinator';
    return null;
  }

  /// Clean message text with Discord-styled inline mentions (NO duplicate boxed chips below!)
  Widget _buildMessageContent(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: RichText(
        text: _buildDiscordStyledText(widget.message.content, theme, isDark),
      ),
    );
  }

  /// Parses text into Discord styled spans:
  /// - `@username`: Discord blurple pill
  /// - `#role`: Discord role color
  /// - `!special`: Special command color
  /// - `http...`: Blue clickable link
  TextSpan _buildDiscordStyledText(String content, ThemeData theme, bool isDark) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'(@[a-zA-Z0-9_.]+|#[a-zA-Z0-9_]+|![a-zA-Z0-9_]+|\bhttps?://\S+)');
    int lastEnd = 0;

    final defaultTextColor = isDark
        ? const Color(0xFFDBDEE1)
        : const Color(0xFF2E3338);

    for (final match in regex.allMatches(content)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: content.substring(lastEnd, match.start),
          style: TextStyle(
            fontSize: 14.5,
            height: 1.35,
            color: defaultTextColor,
          ),
        ));
      }

      final matchText = match.group(0)!;

      if (matchText.startsWith('@')) {
        // Discord-style inline mention pill
        final cleanDisplay = matchText.replaceAll('_', ' ');
        final rawUserHandle = matchText.substring(1);

        final pillBg = isDark
            ? const Color(0xFF5865F2).withValues(alpha: 0.30)
            : const Color(0xFF5865F2).withValues(alpha: 0.15);
        final pillTextColor = isDark
            ? const Color(0xFFC9CDFB)
            : const Color(0xFF3730A3);

        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: InkWell(
              onTap: () {
                _showUserCardModal(
                  context,
                  rawUserHandle,
                  cleanDisplay.substring(1),
                  null,
                );
              },
              borderRadius: BorderRadius.circular(3),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 1.0),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  cleanDisplay,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: pillTextColor,
                  ),
                ),
              ),
            ),
          ),
        );
      } else if (matchText.startsWith('#')) {
        spans.add(TextSpan(
          text: matchText,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF5865F2) : const Color(0xFF3730A3),
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              _logger.info('Tapped role tag: $matchText');
            },
        ));
      } else if (matchText.startsWith('!')) {
        spans.add(TextSpan(
          text: matchText,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF57F287) : const Color(0xFF15803D), // Forest green in light, Discord green in dark
          ),
        ));
      } else if (matchText.startsWith('http')) {
        spans.add(TextSpan(
          text: matchText,
          style: const TextStyle(
            fontSize: 14.5,
            color: Color(0xFF00A8FC),
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _launchUrl(matchText),
        ));
      }

      lastEnd = match.end;
    }

    if (lastEnd < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastEnd),
        style: TextStyle(
          fontSize: 14.5,
          height: 1.35,
          color: defaultTextColor,
        ),
      ));
    }

    return TextSpan(children: spans);
  }

  /// Floating Discord-style action capsule (Reply, Direct Message, Copy, Edit, Delete)
  Widget _buildFloatingActions(ThemeData theme, bool isDark) {
    final currentUserId = AuthService.instance.currentUser?.uid;
    final isOwner = currentUserId != null && widget.message.senderId == currentUserId;
    final isLeaderOrAdmin = RoleAccessService.instance.canAccessAdmin() ||
        RoleAccessService.instance.hasRole('bod') ||
        RoleAccessService.instance.hasRole('trustee') ||
        RoleAccessService.instance.hasRole('chapter_leader') ||
        RoleAccessService.instance.hasRole('director');
    final canDelete = isOwner || isLeaderOrAdmin;
    final isWithinEditTimeframe =
        DateTime.now().difference(widget.message.timestamp).inMinutes < 15;
    final canEdit = isOwner && isWithinEditTimeframe;

    final bgColor = isDark ? const Color(0xFF313338) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF3F4147)
        : const Color(0xFFE3E5E8);

    return Material(
      color: Colors.transparent,
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Direct Message button (only for messages from other users)
            if (!isOwner && widget.onDirectMessage != null)
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Message Directly',
                onPressed: () {
                  widget.onDirectMessage?.call(
                    widget.message.senderId,
                    widget.message.senderName,
                  );
                },
              ),

            // Reply button
            IconButton(
              icon: const Icon(Icons.reply_rounded, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Reply',
              onPressed: () => widget.onReply?.call(widget.message),
            ),

            // Copy button
            IconButton(
              icon: const Icon(Icons.content_copy_rounded, size: 15),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Copy Text',
              onPressed: _copyMessage,
            ),

            // Edit button (within 15 min)
            if (canEdit)
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 15),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Edit',
                onPressed: () => widget.onEdit?.call(widget.message),
              ),

            // Delete button
            if (canDelete)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Delete',
                color: theme.colorScheme.error,
                onPressed: () => widget.onDelete?.call(widget.message),
              ),
          ],
        ),
      ),
    );
  }

  /// Attachments viewer
  Widget _buildAttachments(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: widget.message.attachments.map((attachment) {
          final isImage = attachment
              .toLowerCase()
              .contains(RegExp(r'\.(jpg|jpeg|png|gif|webp)$'));

          if (isImage) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomImage(
                imageUrl: attachment,
                width: 220,
                height: 160,
                fit: BoxFit.cover,
              ),
            );
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.attach_file, size: 18),
                const SizedBox(width: 8),
                Text(
                  attachment.split('/').last,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Opens a Discord user profile card bottom sheet allowing direct messaging
  void _showUserCardModal(
    BuildContext context,
    String userId,
    String userName,
    String? avatarUrl,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUserId = AuthService.instance.currentUser?.uid;
    final isMe = currentUserId != null && currentUserId == userId;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF2B2D31) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Modal drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF4E5058) : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Avatar
                CircleAvatar(
                  radius: 36,
                  backgroundColor: const Color(0xFF5865F2),
                  child: avatarUrl != null && avatarUrl.trim().isNotEmpty
                      ? ClipOval(
                          child: CustomImage(
                            imageUrl: avatarUrl,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),

                const SizedBox(height: 12),

                // Name
                Text(
                  userName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),

                const SizedBox(height: 4),

                // Handle / Role
                Text(
                  '@${userName.replaceAll(' ', '_')}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFF949BA4)
                        : const Color(0xFF747F8D),
                  ),
                ),

                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 20),

                // Action buttons
                if (!isMe && widget.onDirectMessage != null) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(bottomSheetContext).pop();
                        widget.onDirectMessage?.call(userId, userName);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF5865F2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                      label: const Text(
                        'Message Directly',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(bottomSheetContext).pop();
                      widget.onMention?.call(userName.replaceAll(' ', '_'));
                    },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.alternate_email_rounded, size: 18),
                    label: Text('Mention @$userName'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

/// Custom painter for the Discord curved reply spine (`┌─`)
class _DiscordReplySpinePainter extends CustomPainter {
  final Color color;

  _DiscordReplySpinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    // Starts above the avatar center (x ≈ 14), goes vertically up, curves right into horizontal line
    path.moveTo(14, size.height);
    path.lineTo(14, 8);
    path.quadraticBezierTo(14, 2, 22, 2);
    path.lineTo(size.width, 2);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DiscordReplySpinePainter oldDelegate) =>
      oldDelegate.color != color;
}
