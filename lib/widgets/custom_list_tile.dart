import 'package:flutter/material.dart';

class CustomListTile extends StatelessWidget {
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final bool isThreeLine;
  final bool? dense;
  final VisualDensity? visualDensity;
  final ShapeBorder? shape;
  final Color? selectedColor;
  final Color? iconColor;
  final Color? textColor;
  final EdgeInsetsGeometry? contentPadding;
  final bool enabled;
  final GestureTapCallback? onTap;
  final GestureLongPressCallback? onLongPress;
  final ValueChanged<bool>? onFocusChange;
  final MouseCursor? mouseCursor;
  final bool selected;
  final Color? focusColor;
  final Color? hoverColor;
  final Color? splashColor;
  final FocusNode? focusNode;
  final bool autofocus;
  final Color? tileColor;
  final Color? selectedTileColor;
  final bool? enableFeedback;
  final double? horizontalTitleGap;
  final double? minVerticalPadding;
  final double? minLeadingWidth;
  final BorderRadius? borderRadius;
  final bool showDivider;
  final Color? dividerColor;
  final double? dividerIndent;
  final double? dividerEndIndent;

  const CustomListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.isThreeLine = false,
    this.dense,
    this.visualDensity,
    this.shape,
    this.selectedColor,
    this.iconColor,
    this.textColor,
    this.contentPadding,
    this.enabled = true,
    this.onTap,
    this.onLongPress,
    this.onFocusChange,
    this.mouseCursor,
    this.selected = false,
    this.focusColor,
    this.hoverColor,
    this.splashColor,
    this.focusNode,
    this.autofocus = false,
    this.tileColor,
    this.selectedTileColor,
    this.enableFeedback,
    this.horizontalTitleGap,
    this.minVerticalPadding,
    this.minLeadingWidth,
    this.borderRadius,
    this.showDivider = false,
    this.dividerColor,
    this.dividerIndent,
    this.dividerEndIndent,
  });

  @override
  Widget build(BuildContext context) {
    Widget listTile = ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      isThreeLine: isThreeLine,
      dense: dense,
      visualDensity: visualDensity,
      shape: shape ??
          (borderRadius != null
              ? RoundedRectangleBorder(
                  borderRadius: borderRadius!,
                )
              : null),
      selectedColor: selectedColor,
      iconColor: iconColor,
      textColor: textColor,
      contentPadding: contentPadding,
      enabled: enabled,
      onTap: onTap,
      onLongPress: onLongPress,
      onFocusChange: onFocusChange,
      mouseCursor: mouseCursor,
      selected: selected,
      focusColor: focusColor,
      hoverColor: hoverColor,
      splashColor: splashColor,
      focusNode: focusNode,
      autofocus: autofocus,
      tileColor: tileColor,
      selectedTileColor: selectedTileColor,
      enableFeedback: enableFeedback,
      horizontalTitleGap: horizontalTitleGap,
      minVerticalPadding: minVerticalPadding,
      minLeadingWidth: minLeadingWidth,
    );

    if (showDivider) {
      return Column(
        children: [
          listTile,
          Divider(
            height: 1,
            color: dividerColor ??
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            indent: dividerIndent,
            endIndent: dividerEndIndent,
          ),
        ],
      );
    }

    return listTile;
  }
}

class IconListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? iconColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final EdgeInsetsGeometry? contentPadding;
  final bool showDivider;
  final BorderRadius? borderRadius;
  final double? iconSize;

  const IconListTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.iconColor,
    this.backgroundColor,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.contentPadding,
    this.showDivider = false,
    this.borderRadius,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: backgroundColor ??
              (iconColor ?? theme.colorScheme.primary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: iconColor ?? theme.colorScheme.primary,
          size: iconSize ?? 20,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
      onLongPress: onLongPress,
      selected: selected,
      contentPadding: contentPadding,
      showDivider: showDivider,
      borderRadius: borderRadius,
    );
  }
}

class AvatarListTile extends StatelessWidget {
  final String? imageUrl;
  final Widget? avatar;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onAvatarTap;
  final bool selected;
  final EdgeInsetsGeometry? contentPadding;
  final bool showDivider;
  final BorderRadius? borderRadius;
  final double avatarRadius;
  final Widget? placeholder;

  const AvatarListTile({
    super.key,
    this.imageUrl,
    this.avatar,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.onAvatarTap,
    this.selected = false,
    this.contentPadding,
    this.showDivider = false,
    this.borderRadius,
    this.avatarRadius = 20,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget avatarWidget = avatar ??
        CircleAvatar(
          radius: avatarRadius,
          backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
          child: imageUrl == null
              ? (placeholder ??
                  Icon(
                    Icons.person,
                    size: avatarRadius,
                  ))
              : null,
        );

    if (onAvatarTap != null) {
      avatarWidget = GestureDetector(
        onTap: onAvatarTap,
        child: avatarWidget,
      );
    }

    return CustomListTile(
      leading: avatarWidget,
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
      onLongPress: onLongPress,
      selected: selected,
      contentPadding: contentPadding,
      showDivider: showDivider,
      borderRadius: borderRadius,
    );
  }
}

class SwitchListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? leading;
  final Color? activeColor;
  final Color? activeTrackColor;
  final Color? inactiveThumbColor;
  final Color? inactiveTrackColor;
  final EdgeInsetsGeometry? contentPadding;
  final bool showDivider;
  final BorderRadius? borderRadius;
  final bool enabled;

  const SwitchListTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.leading,
    this.activeColor,
    this.activeTrackColor,
    this.inactiveThumbColor,
    this.inactiveTrackColor,
    this.contentPadding,
    this.showDivider = false,
    this.borderRadius,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomListTile(
      leading: leading,
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: enabled
              ? null
              : theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: enabled
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            )
          : null,
      trailing: Switch(
        value: value,
        onChanged: enabled ? onChanged : null,
        activeThumbColor: activeColor,
        activeTrackColor: activeTrackColor,
        inactiveThumbColor: inactiveThumbColor,
        inactiveTrackColor: inactiveTrackColor,
      ),
      onTap: enabled ? () => onChanged?.call(!value) : null,
      contentPadding: contentPadding,
      showDivider: showDivider,
      borderRadius: borderRadius,
    );
  }
}

class CheckboxListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final Widget? leading;
  final Color? activeColor;
  final Color? checkColor;
  final bool tristate;
  final EdgeInsetsGeometry? contentPadding;
  final bool showDivider;
  final BorderRadius? borderRadius;
  final bool enabled;

  const CheckboxListTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.leading,
    this.activeColor,
    this.checkColor,
    this.tristate = false,
    this.contentPadding,
    this.showDivider = false,
    this.borderRadius,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomListTile(
      leading: leading,
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: enabled
              ? null
              : theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: enabled
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            )
          : null,
      trailing: Checkbox(
        value: value,
        onChanged: enabled ? onChanged : null,
        activeColor: activeColor,
        checkColor: checkColor,
        tristate: tristate,
      ),
      onTap: enabled
          ? () {
              if (tristate) {
                if (value == null) {
                  onChanged?.call(false);
                } else if (value == false) {
                  onChanged?.call(true);
                } else {
                  onChanged?.call(null);
                }
              } else {
                onChanged?.call(!(value ?? false));
              }
            }
          : null,
      contentPadding: contentPadding,
      showDivider: showDivider,
      borderRadius: borderRadius,
    );
  }
}

class RadioListTile<T> extends StatelessWidget {
  final String title;
  final String? subtitle;
  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;
  final Widget? leading;
  final Color? activeColor;
  final EdgeInsetsGeometry? contentPadding;
  final bool showDivider;
  final BorderRadius? borderRadius;
  final bool enabled;

  const RadioListTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.groupValue,
    this.onChanged,
    this.leading,
    this.activeColor,
    this.contentPadding,
    this.showDivider = false,
    this.borderRadius,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = value == groupValue;

    return CustomListTile(
      leading: leading,
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: enabled
              ? null
              : theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: enabled
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            )
          : null,
      trailing: Radio<T>(
        value: value,
        activeColor: activeColor,
      ),
      onTap: enabled ? () => onChanged?.call(value) : null,
      selected: isSelected,
      contentPadding: contentPadding,
      showDivider: showDivider,
      borderRadius: borderRadius,
    );
  }
}

class ExpansionListTile extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> children;
  final bool initiallyExpanded;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? childrenPadding;
  final Color? backgroundColor;
  final Color? collapsedBackgroundColor;
  final Color? textColor;
  final Color? collapsedTextColor;
  final Color? iconColor;
  final Color? collapsedIconColor;
  final bool showDivider;
  final BorderRadius? borderRadius;
  final ValueChanged<bool>? onExpansionChanged;

  const ExpansionListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.children,
    this.initiallyExpanded = false,
    this.contentPadding,
    this.childrenPadding,
    this.backgroundColor,
    this.collapsedBackgroundColor,
    this.textColor,
    this.collapsedTextColor,
    this.iconColor,
    this.collapsedIconColor,
    this.showDivider = false,
    this.borderRadius,
    this.onExpansionChanged,
  });

  @override
  State<ExpansionListTile> createState() => _ExpansionListTileState();
}

class _ExpansionListTileState extends State<ExpansionListTile> {
  void _handleExpansionChanged(bool expanded) {
    widget.onExpansionChanged?.call(expanded);
  }

  @override
  Widget build(BuildContext context) {
    Widget expansionTile = ExpansionTile(
      title: Text(
        widget.title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
      ),
      subtitle: widget.subtitle != null
          ? Text(
              widget.subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
            )
          : null,
      leading: widget.leading,
      initiallyExpanded: widget.initiallyExpanded,
      tilePadding: widget.contentPadding,
      childrenPadding: widget.childrenPadding,
      backgroundColor: widget.backgroundColor,
      collapsedBackgroundColor: widget.collapsedBackgroundColor,
      textColor: widget.textColor,
      collapsedTextColor: widget.collapsedTextColor,
      iconColor: widget.iconColor,
      collapsedIconColor: widget.collapsedIconColor,
      onExpansionChanged: _handleExpansionChanged,
      shape: widget.borderRadius != null
          ? RoundedRectangleBorder(
              borderRadius: widget.borderRadius!,
            )
          : null,
      collapsedShape: widget.borderRadius != null
          ? RoundedRectangleBorder(
              borderRadius: widget.borderRadius!,
            )
          : null,
      children: widget.children,
    );

    if (widget.showDivider) {
      return Column(
        children: [
          expansionTile,
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ],
      );
    }

    return expansionTile;
  }
}

class ActionListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final bool showArrow;
  final Widget? trailing;
  final EdgeInsetsGeometry? contentPadding;
  final bool showDivider;
  final BorderRadius? borderRadius;
  final bool enabled;
  final Color? textColor;

  const ActionListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.backgroundColor,
    this.onTap,
    this.showArrow = true,
    this.trailing,
    this.contentPadding,
    this.showDivider = false,
    this.borderRadius,
    this.enabled = true,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget? effectiveTrailing = trailing;
    if (showArrow && trailing == null && onTap != null) {
      effectiveTrailing = Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      );
    }

    return CustomListTile(
      leading: icon != null
          ? Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: backgroundColor ??
                    (iconColor ?? theme.colorScheme.primary)
                        .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: iconColor ?? theme.colorScheme.primary,
                size: 20,
              ),
            )
          : null,
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: enabled
              ? (textColor ?? theme.colorScheme.onSurface)
              : theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: enabled
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            )
          : null,
      trailing: effectiveTrailing,
      onTap: enabled ? onTap : null,
      contentPadding: contentPadding,
      showDivider: showDivider,
      borderRadius: borderRadius,
    );
  }
}




