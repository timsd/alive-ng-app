import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_models.dart';
import '../services/tag_parser.dart';
import '../services/tag_visibility_checker.dart';

/// Enhanced tag input widget for Discord-like tagging system
/// Supports role-based, individual, and special tags with visibility rules
class TagInputWidget extends StatefulWidget {
  final TextEditingController controller;
  final Function(String, List<MessageTag>) onSendMessage;
  final Future<List<TaggedEntity>> Function(String, TagType?) onTagSearch;
  final VoidCallback? onCancelReply;
  final String? replyToId;
  final String? replyToUserName;
  final String currentUserId;
  final List<String> userRoles;

  const TagInputWidget({
    super.key,
    required this.controller,
    required this.onSendMessage,
    required this.onTagSearch,
    required this.currentUserId,
    required this.userRoles,
    this.onCancelReply,
    this.replyToId,
    this.replyToUserName,
  });

  @override
  State<TagInputWidget> createState() => _TagInputWidgetState();
}

class _TagInputWidgetState extends State<TagInputWidget> {
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  
  OverlayEntry? _overlayEntry;
  List<TaggedEntity> _suggestions = [];
  List<MessageTag> _currentTags = [];
  
  int _tagStartPosition = -1;
  int _selectedSuggestionIndex = 0;
  bool _showSuggestions = false;
  TagType? _currentTagType;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _hideSuggestions();
    }
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final cursorPosition = widget.controller.selection.baseOffset;

    if (cursorPosition < 0) return;

    // Parse current tags in the message
    _currentTags = TagParser.parseMessage(text);

    // Check for active tag typing
    final beforeCursor = text.substring(0, cursorPosition);
    final tagMatch = _findActiveTag(beforeCursor);

    if (tagMatch != null) {
      final tagType = _getTagTypeFromPrefix(tagMatch['prefix']!);
      final tagQuery = tagMatch['query']!;

      setState(() {
        _tagStartPosition = tagMatch['start']!;
        _currentTagType = tagType;
        _showSuggestions = true;
        _selectedSuggestionIndex = 0;
      });

      _searchTags(tagQuery, tagType);
      _showSuggestionsOverlay();
    } else {
      _hideSuggestions();
    }
  }

  Map<String, dynamic>? _findActiveTag(String text) {
    // Enhanced regex to match different tag types
    final patterns = [
      RegExp(r'@([a-zA-Z0-9_]*)$'), // User tags
      RegExp(r'#([a-zA-Z0-9_]*)$'), // Group/Role tags
      RegExp(r'!([a-zA-Z0-9_]*)$'), // Special tags
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return {
          'prefix': text[match.start],
          'query': match.group(1) ?? '',
          'start': match.start,
        };
      }
    }
    return null;
  }

  TagType _getTagTypeFromPrefix(String prefix) {
    switch (prefix) {
      case '@':
        return TagType.user;
      case '#':
        return TagType.role; // Default for # prefix
      case '!':
        return TagType.special;
      default:
        return TagType.user;
    }
  }

  Future<void> _searchTags(String query, TagType? tagType) async {
    try {
      final results = await widget.onTagSearch(query, tagType);
      
      // Filter results based on user's visibility permissions
      final visibleResults = <TaggedEntity>[];
      for (final result in results) {
        final messageTag = MessageTag(
           type: result.type,
           value: result.name,
           displayName: result.name,
         );
        
        if (await TagVisibilityChecker.canUserSeeTag(
          widget.currentUserId,
          messageTag,
        )) {
          visibleResults.add(result);
        }
      }

      setState(() {
        _suggestions = visibleResults;
        _selectedSuggestionIndex = 0;
      });
    } catch (e) {
      setState(() {
        _suggestions = [];
      });
    }
  }

  void _showSuggestionsOverlay() {
    _removeOverlay();

    if (_suggestions.isEmpty) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 320,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, -250), // Show above input
          child: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 240),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getTagIcon(_currentTagType),
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getTagTypeLabel(_currentTagType),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_suggestions.length} results',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Suggestions list
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) => _buildSuggestionItem(index),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildSuggestionItem(int index) {
    final suggestion = _suggestions[index];
    final isSelected = index == _selectedSuggestionIndex;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => _selectSuggestion(suggestion),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        ),
        child: Row(
          children: [
            // Avatar or icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
              ),
              child: suggestion.avatar != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      suggestion.avatar!,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildTagIcon(suggestion.type);
                      },
                    ),
                  )
                : _buildTagIcon(suggestion.type),
            ),
            const SizedBox(width: 12),

            // Name and details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isSelected ? theme.colorScheme.primary : null,
                    ),
                  ),
                  if (suggestion.type != TagType.user)
                    Text(
                      _getTagDescription(suggestion),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
            ),

            // Tag type indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getTagColor(suggestion.type).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getTagColor(suggestion.type).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                suggestion.type.name.toUpperCase(),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _getTagColor(suggestion.type),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagIcon(TagType type) {
    return Icon(
      _getTagIcon(type),
      size: 20,
      color: _getTagColor(type),
    );
  }

  IconData _getTagIcon(TagType? type) {
    switch (type) {
      case TagType.user:
        return Icons.person;
      case TagType.role:
        return Icons.group;
      case TagType.group:
        return Icons.groups;
      case TagType.special:
        return Icons.star;
      default:
        return Icons.tag;
    }
  }

  Color _getTagColor(TagType type) {
    final theme = Theme.of(context);
    switch (type) {
      case TagType.user:
        return theme.colorScheme.primary;
      case TagType.role:
        return theme.colorScheme.secondary;
      case TagType.group:
        return theme.colorScheme.tertiary;
      case TagType.special:
        return Colors.orange;
    }
  }

  String _getTagTypeLabel(TagType? type) {
    switch (type) {
      case TagType.user:
        return 'Mention Users';
      case TagType.role:
        return 'Tag Roles';
      case TagType.group:
        return 'Tag Groups';
      case TagType.special:
        return 'Special Tags';
      case null:
        return 'Tags';
    }
  }

  String _getTagDescription(TaggedEntity suggestion) {
    switch (suggestion.type) {
      case TagType.role:
        return 'Role • ${suggestion.name}';
      case TagType.group:
        return 'Group • ${suggestion.name}';
      case TagType.special:
        return 'Special • ${suggestion.name}';
      default:
        return suggestion.name;
    }
  }

  void _selectSuggestion(TaggedEntity suggestion) {
    final text = widget.controller.text;
    final prefix = _getTagPrefix(suggestion.type);
    final replacement = '$prefix${suggestion.name}';
    
    final newText = text.replaceRange(
      _tagStartPosition,
      widget.controller.selection.baseOffset,
      replacement,
    );

    widget.controller.text = newText;
    widget.controller.selection = TextSelection.collapsed(
      offset: _tagStartPosition + replacement.length,
    );

    _hideSuggestions();
  }

  String _getTagPrefix(TagType type) {
    switch (type) {
      case TagType.user:
        return '@';
      case TagType.role:
      case TagType.group:
        return '#';
      case TagType.special:
        return '!';
    }
  }

  void _hideSuggestions() {
    setState(() {
      _showSuggestions = false;
      _suggestions.clear();
    });
    _removeOverlay();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _handleKeyEvent(KeyEvent event) {
    if (!_showSuggestions || _suggestions.isEmpty) return;

    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowUp:
          setState(() {
            _selectedSuggestionIndex = 
              (_selectedSuggestionIndex - 1).clamp(0, _suggestions.length - 1);
          });
          break;
        case LogicalKeyboardKey.arrowDown:
          setState(() {
            _selectedSuggestionIndex = 
              (_selectedSuggestionIndex + 1).clamp(0, _suggestions.length - 1);
          });
          break;
        case LogicalKeyboardKey.tab:
        case LogicalKeyboardKey.enter:
          if (_selectedSuggestionIndex < _suggestions.length) {
            _selectSuggestion(_suggestions[_selectedSuggestionIndex]);
          }
          break;
        case LogicalKeyboardKey.escape:
          _hideSuggestions();
          break;
      }
    }
  }

  void _sendMessage() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;

    // Parse tags from the message
    final tags = TagParser.parseMessage(text);

    // Send the message with tags
    widget.onSendMessage(text, tags);

    // Clear the input
    widget.controller.clear();
    _hideSuggestions();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: theme.dividerColor,
            ),
          ),
        ),
        child: Column(
          children: [
            // Reply indicator
            if (widget.replyToId != null && widget.replyToUserName != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
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
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Replying to ${widget.replyToUserName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: widget.onCancelReply,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),

            // Current tags preview
            if (_currentTags.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _currentTags.map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getTagColor(tag.type).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getTagColor(tag.type).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getTagIcon(tag.type),
                          size: 12,
                          color: _getTagColor(tag.type),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          tag.fullTag,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _getTagColor(tag.type),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),

            // Input row
            Row(
              children: [
                // Attachment button
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: () {
                    // Handle file attachment
                  },
                  tooltip: 'Attach file',
                ),

                // Text input
                Expanded(
                  child: KeyboardListener(
                    focusNode: FocusNode(),
                    onKeyEvent: _handleKeyEvent,
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      maxLines: null,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Type a message... Use @ for users, # for roles/groups, ! for special tags',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outline.withValues(alpha: 0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outline.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Send button
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  tooltip: 'Send message',
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                ),
              ],
            ),

            // Help text
            Container(
              margin: const EdgeInsets.only(top: 8),
              child: Text(
                'Use @ for users, # for roles/groups, ! for special tags. Press Tab or Enter to accept suggestions.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



