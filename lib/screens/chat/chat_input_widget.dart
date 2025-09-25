import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/chat_models.dart';

class ChatInputWidget extends StatefulWidget {
  final TextEditingController controller;
  final Function(String, {String? replyToId}) onSendMessage;
  final Future<List<TaggedEntity>> Function(String) onTagSearch;
  final ChatMessage? replyToMessage;
  final VoidCallback? onCancelReply;

  const ChatInputWidget({
    super.key,
    required this.controller,
    required this.onSendMessage,
    required this.onTagSearch,
    this.replyToMessage,
    this.onCancelReply,
  });

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  List<TaggedEntity> _suggestions = [];
  int _tagStartPosition = -1;
  bool _showSuggestions = false;
  int _selectedSuggestionIndex = 0;

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

  void _onTextChanged() {
    final text = widget.controller.text;
    final cursorPosition = widget.controller.selection.baseOffset;

    if (cursorPosition < 0) return;

    // Check for @ or # tags
    final beforeCursor = text.substring(0, cursorPosition);
    final tagMatch = RegExp(r'[@#](\w*)$').firstMatch(beforeCursor);

    if (tagMatch != null) {
      final tagText = tagMatch.group(1) ?? '';

      setState(() {
        _tagStartPosition = tagMatch.start;
        _showSuggestions = true;
        _selectedSuggestionIndex = 0;
      });

      _searchTags(tagText);
      _showSuggestionsOverlay();
    } else {
      _hideSuggestions();
    }
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _hideSuggestions();
    }
  }

  Future<void> _searchTags(String query) async {
    try {
      final suggestions = await widget.onTagSearch(query);
      if (mounted && _showSuggestions) {
        setState(() {
          _suggestions = suggestions;
        });
        _updateOverlay();
      }
    } catch (e) {
      // Handle error silently
    }
  }

  void _showSuggestionsOverlay() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 300,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, -200), // Show above input
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.3),
                ),
              ),
              child: _buildSuggestionsList(),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _hideSuggestions() {
    setState(() {
      _showSuggestions = false;
      _suggestions = [];
      _tagStartPosition = -1;
    });
    _removeOverlay();
  }

  Widget _buildSuggestionsList() {
    if (_suggestions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No suggestions found',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        final isSelected = index == _selectedSuggestionIndex;

        return InkWell(
          onTap: () => _selectSuggestion(suggestion),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : null,
            child: Row(
              children: [
                // Avatar or icon
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _getTagColor(suggestion.type),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: suggestion.avatar != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            suggestion.avatar!,
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildTagIcon(suggestion.type);
                            },
                          ),
                        )
                      : _buildTagIcon(suggestion.type),
                ),
                const SizedBox(width: 12),

                // Name and type
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggestion.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      Text(
                        suggestion.type.name.toUpperCase(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                  ),
                ),

                // Tag prefix
                Text(
                  suggestion.type == TagType.user ? '@' : '#',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: _getTagColor(suggestion.type),
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTagIcon(TagType type) {
    IconData icon;
    switch (type) {
      case TagType.user:
        icon = Icons.person;
        break;
      case TagType.group:
        icon = Icons.group;
        break;
      case TagType.role:
        icon = Icons.admin_panel_settings;
        break;
    }

    return Icon(
      icon,
      color: Colors.white,
      size: 18,
    );
  }

  Color _getTagColor(TagType type) {
    switch (type) {
      case TagType.user:
        return Theme.of(context).colorScheme.primary;
      case TagType.group:
        return Theme.of(context).colorScheme.secondary;
      case TagType.role:
        return Theme.of(context).colorScheme.tertiary;
    }
  }

  void _selectSuggestion(TaggedEntity suggestion) {
    final text = widget.controller.text;
    final prefix = suggestion.type == TagType.user ? '@' : '#';
    final replacement = '$prefix${suggestion.name} ';

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
    _focusNode.requestFocus();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (!_showSuggestions || _suggestions.isEmpty) return;

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _selectedSuggestionIndex =
              (_selectedSuggestionIndex - 1).clamp(0, _suggestions.length - 1);
        });
        _updateOverlay();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _selectedSuggestionIndex =
              (_selectedSuggestionIndex + 1).clamp(0, _suggestions.length - 1);
        });
        _updateOverlay();
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_selectedSuggestionIndex < _suggestions.length) {
          _selectSuggestion(_suggestions[_selectedSuggestionIndex]);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        _hideSuggestions();
      }
    }
  }

  void _sendMessage() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;

    widget.onSendMessage(
      text,
      replyToId: widget.replyToMessage?.id,
    );

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
            if (widget.replyToMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
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
                        'Replying to ${widget.replyToMessage!.senderName}',
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
                        hintText:
                            'Type a message... Use @ to mention users, # for groups',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.3),
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

            // Typing indicator or help text
            Container(
              margin: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Use @ to mention users, # for groups/roles. Press Tab to accept suggestions.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
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
