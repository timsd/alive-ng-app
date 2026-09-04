import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/tag_visibility_checker.dart';

/// A widget that displays individual tags in messages
/// Supports different tag types with appropriate styling and interactions
class TagChip extends StatefulWidget {
  final MessageTag tag;
  final String currentUserId;
  final List<String> userRoles;
  final VoidCallback? onTap;
  final bool isClickable;
  final bool showTooltip;
  final TagChipSize size;

  const TagChip({
    super.key,
    required this.tag,
    required this.currentUserId,
    required this.userRoles,
    this.onTap,
    this.isClickable = true,
    this.showTooltip = true,
    this.size = TagChipSize.medium,
  });

  @override
  State<TagChip> createState() => _TagChipState();
}

class _TagChipState extends State<TagChip> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;
  bool _canSeeTag = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _checkTagVisibility();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkTagVisibility() async {
    final canSee = await TagVisibilityChecker.canUserSeeTag(
      widget.currentUserId,
      widget.tag,
    );
    
    if (mounted) {
      setState(() {
        _canSeeTag = canSee;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canSeeTag) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final chipData = _getChipData(theme);

    Widget chip = AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            padding: _getPadding(),
            decoration: BoxDecoration(
              color: _isHovered 
                ? chipData.backgroundColor.withValues(alpha: 0.2)
                : chipData.backgroundColor,
              borderRadius: BorderRadius.circular(_getBorderRadius()),
              border: Border.all(
                color: chipData.borderColor,
                width: _getBorderWidth(),
              ),
              boxShadow: _isHovered ? [
                BoxShadow(
                  color: chipData.shadowColor.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tag icon
                Icon(
                  chipData.icon,
                  size: _getIconSize(),
                  color: chipData.iconColor,
                ),
                SizedBox(width: _getSpacing()),
                
                // Tag text
                Text(
                  widget.tag.displayName ?? widget.tag.fullTag,
                  style: _getTextStyle(theme, chipData),
                ),
                
                // Additional info for special tags
                if (widget.tag.type == TagType.special && _shouldShowCount())
                  ...[
                    SizedBox(width: _getSpacing()),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: chipData.iconColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getSpecialTagCount(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: chipData.iconColor,
                        ),
                      ),
                    ),
                  ],
              ],
            ),
          ),
        );
      },
    );

    // Add interaction handling
    if (widget.isClickable) {
      chip = MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: (_) => _animationController.forward(),
          onTapUp: (_) => _animationController.reverse(),
          onTapCancel: () => _animationController.reverse(),
          onTap: widget.onTap,
          child: chip,
        ),
      );
    }

    // Add tooltip if enabled
    if (widget.showTooltip) {
      chip = Tooltip(
        message: _getTooltipMessage(),
        child: chip,
      );
    }

    return chip;
  }

  TagChipData _getChipData(ThemeData theme) {
    switch (widget.tag.type) {
      case TagType.user:
        return TagChipData(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderColor: theme.colorScheme.primary.withValues(alpha: 0.3),
          iconColor: theme.colorScheme.primary,
          textColor: theme.colorScheme.primary,
          shadowColor: theme.colorScheme.primary,
          icon: Icons.person,
        );
      
      case TagType.role:
        return TagChipData(
          backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.1),
          borderColor: theme.colorScheme.secondary.withValues(alpha: 0.3),
          iconColor: theme.colorScheme.secondary,
          textColor: theme.colorScheme.secondary,
          shadowColor: theme.colorScheme.secondary,
          icon: Icons.group,
        );
      
      case TagType.group:
        return TagChipData(
          backgroundColor: theme.colorScheme.tertiary.withValues(alpha: 0.1),
          borderColor: theme.colorScheme.tertiary.withValues(alpha: 0.3),
          iconColor: theme.colorScheme.tertiary,
          textColor: theme.colorScheme.tertiary,
          shadowColor: theme.colorScheme.tertiary,
          icon: Icons.groups,
        );
      
      case TagType.special:
        return TagChipData(
          backgroundColor: Colors.orange.withValues(alpha: 0.1),
          borderColor: Colors.orange.withValues(alpha: 0.3),
          iconColor: Colors.orange,
          textColor: Colors.orange,
          shadowColor: Colors.orange,
          icon: _getSpecialTagIcon(),
        );
    }
  }

  IconData _getSpecialTagIcon() {
    switch (widget.tag.value.toLowerCase()) {
      case 'all':
        return Icons.campaign;
      case 'online':
        return Icons.circle;
      case 'active':
        return Icons.flash_on;
      case 'new':
        return Icons.new_releases;
      case 'meeting':
        return Icons.meeting_room;
      case 'conference':
        return Icons.event;
      case 'training':
        return Icons.school;
      default:
        return Icons.star;
    }
  }

  EdgeInsets _getPadding() {
    switch (widget.size) {
      case TagChipSize.small:
        return const EdgeInsets.symmetric(horizontal: 6, vertical: 2);
      case TagChipSize.medium:
        return const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
      case TagChipSize.large:
        return const EdgeInsets.symmetric(horizontal: 10, vertical: 6);
    }
  }

  double _getBorderRadius() {
    switch (widget.size) {
      case TagChipSize.small:
        return 10;
      case TagChipSize.medium:
        return 12;
      case TagChipSize.large:
        return 14;
    }
  }

  double _getBorderWidth() {
    return _isHovered ? 1.5 : 1.0;
  }

  double _getIconSize() {
    switch (widget.size) {
      case TagChipSize.small:
        return 12;
      case TagChipSize.medium:
        return 14;
      case TagChipSize.large:
        return 16;
    }
  }

  double _getSpacing() {
    switch (widget.size) {
      case TagChipSize.small:
        return 4;
      case TagChipSize.medium:
        return 6;
      case TagChipSize.large:
        return 8;
    }
  }

  TextStyle? _getTextStyle(ThemeData theme, TagChipData chipData) {
    final baseStyle = switch (widget.size) {
      TagChipSize.small => theme.textTheme.bodySmall,
      TagChipSize.medium => theme.textTheme.bodyMedium,
      TagChipSize.large => theme.textTheme.bodyLarge,
    };

    return baseStyle?.copyWith(
      color: chipData.textColor,
      fontWeight: FontWeight.w500,
      fontSize: switch (widget.size) {
        TagChipSize.small => 11,
        TagChipSize.medium => 12,
        TagChipSize.large => 14,
      },
    );
  }

  bool _shouldShowCount() {
    return ['all', 'online', 'active', 'new'].contains(widget.tag.value.toLowerCase());
  }

  String _getSpecialTagCount() {
    // This would typically come from a service or state management
    // For now, return placeholder counts
    switch (widget.tag.value.toLowerCase()) {
      case 'all':
        return '∞';
      case 'online':
        return '12';
      case 'active':
        return '8';
      case 'new':
        return '3';
      default:
        return '';
    }
  }

  String _getTooltipMessage() {
    switch (widget.tag.type) {
      case TagType.user:
        return 'User: ${widget.tag.displayName ?? widget.tag.value}';
      case TagType.role:
        return 'Role: ${widget.tag.displayName ?? widget.tag.value}';
      case TagType.group:
        return 'Group: ${widget.tag.displayName ?? widget.tag.value}';
      case TagType.special:
        return 'Special Tag: ${_getSpecialTagDescription()}';
    }
  }

  String _getSpecialTagDescription() {
    switch (widget.tag.value.toLowerCase()) {
      case 'all':
        return 'All members';
      case 'online':
        return 'Currently online members';
      case 'active':
        return 'Recently active members';
      case 'new':
        return 'New members';
      case 'meeting':
        return 'Meeting participants';
      case 'conference':
        return 'Conference attendees';
      case 'training':
        return 'Training participants';
      default:
        return widget.tag.value;
    }
  }
}

/// Data class for tag chip styling
class TagChipData {
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final Color textColor;
  final Color shadowColor;
  final IconData icon;

  const TagChipData({
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
    required this.textColor,
    required this.shadowColor,
    required this.icon,
  });
}

/// Size variants for tag chips
enum TagChipSize {
  small,
  medium,
  large,
}

/// A widget that displays multiple tags in a wrap layout
class TagChipGroup extends StatelessWidget {
  final List<MessageTag> tags;
  final String currentUserId;
  final List<String> userRoles;
  final Function(MessageTag)? onTagTap;
  final TagChipSize size;
  final double spacing;
  final double runSpacing;
  final int? maxTags;
  final bool showOverflow;

  const TagChipGroup({
    super.key,
    required this.tags,
    required this.currentUserId,
    required this.userRoles,
    this.onTagTap,
    this.size = TagChipSize.medium,
    this.spacing = 6,
    this.runSpacing = 4,
    this.maxTags,
    this.showOverflow = true,
  });

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    final displayTags = maxTags != null && tags.length > maxTags!
        ? tags.take(maxTags!).toList()
        : tags;

    final overflowCount = maxTags != null && tags.length > maxTags!
        ? tags.length - maxTags!
        : 0;

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: [
        ...displayTags.map((tag) => TagChip(
          tag: tag,
          currentUserId: currentUserId,
          userRoles: userRoles,
          size: size,
          onTap: onTagTap != null ? () => onTagTap!(tag) : null,
        )),
        
        // Overflow indicator
        if (overflowCount > 0 && showOverflow)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              '+$overflowCount',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}



