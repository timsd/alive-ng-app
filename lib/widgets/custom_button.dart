import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../utils/layout_fix_utils.dart';
import '../utils/text_formatter.dart';

enum ButtonVariant {
  primary,
  secondary,
  outline,
  text,
  danger,
  success,
}

enum ButtonSize {
  small,
  medium,
  large,
}

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color? customColor;
  final TextStyle? textStyle;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.padding,
    this.borderRadius,
    this.customColor,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Determine button colors based on variant
    Color backgroundColor;
    Color foregroundColor;
    Color? borderColor;

    switch (variant) {
      case ButtonVariant.primary:
        backgroundColor = customColor ?? colorScheme.primary;
        foregroundColor = colorScheme.onPrimary;
        break;
      case ButtonVariant.secondary:
        backgroundColor = customColor ?? colorScheme.secondary;
        foregroundColor = colorScheme.onSecondary;
        break;
      case ButtonVariant.outline:
        backgroundColor = Colors.transparent;
        foregroundColor = customColor ?? colorScheme.primary;
        borderColor = customColor ?? colorScheme.primary;
        break;
      case ButtonVariant.text:
        backgroundColor = Colors.transparent;
        foregroundColor = customColor ?? colorScheme.primary;
        break;
      case ButtonVariant.danger:
        backgroundColor = customColor ?? colorScheme.error;
        foregroundColor = colorScheme.onError;
        break;
      case ButtonVariant.success:
        backgroundColor = customColor ?? colorScheme.tertiary;
        foregroundColor = colorScheme.onTertiary;
        break;
    }

    // Determine button size
    EdgeInsetsGeometry buttonPadding;
    double fontSize;
    double iconSize;

    switch (size) {
      case ButtonSize.small:
        buttonPadding =
            padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 6);
        fontSize = 13;
        iconSize = 16;
        break;
      case ButtonSize.medium:
        buttonPadding =
            padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 8);
        fontSize = 14;
        iconSize = 18;
        break;
      case ButtonSize.large:
        buttonPadding =
            padding ?? const EdgeInsets.symmetric(horizontal: 32, vertical: 12);
        fontSize = 16;
        iconSize = 20;
        break;
    }

    Widget buttonChild = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
            ),
          )
        else if (icon != null)
          LayoutFixUtils.responsiveIcon(
            icon,
            context: context,
            baseSize: iconSize,
            color: foregroundColor,
          ),
        if ((icon != null || isLoading) && text.isNotEmpty)
          const SizedBox(width: 8),
        if (text.isNotEmpty)
          Text(
            TextFormatter.formatAction(text),
            style: textStyle?.copyWith(
                  color: foregroundColor,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ) ??
                TextStyle(
                  color: foregroundColor,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
          ),
      ],
    );

    Widget button;

    if (variant == ButtonVariant.text) {
      button = TextButton(
        onPressed: isLoading ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: foregroundColor,
          padding: buttonPadding,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius ?? BorderRadius.circular(AppTheme.radiusSm),
          ),
        ),
        child: buttonChild,
      );
    } else if (variant == ButtonVariant.outline) {
      button = OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor,
          backgroundColor: backgroundColor,
          padding: buttonPadding,
          side: BorderSide(
            color: borderColor ?? foregroundColor,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius ?? BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
        child: buttonChild,
      );
    } else {
      button = ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: buttonPadding,
          elevation: variant == ButtonVariant.primary ? 2 : 1,
          shadowColor: isDark
              ? backgroundColor.withValues(alpha: 0.22)
              : Colors.black.withValues(alpha: 0.08),
          side: BorderSide(
            color: isDark
                ? colorScheme.outline.withValues(alpha: 0.7)
                : Colors.transparent,
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius ?? BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
        child: buttonChild,
      );
    }

    if (isFullWidth) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }

    return button;
  }
}

class CustomIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final Color? backgroundColor;
  final double? size;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final bool isLoading;

  const CustomIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.color,
    this.backgroundColor,
    this.size,
    this.padding,
    this.borderRadius,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconSize = size ?? 24;

    Widget iconWidget = isLoading
        ? SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                color ?? theme.colorScheme.primary,
              ),
            ),
          )
        : LayoutFixUtils.responsiveIcon(
            icon,
            context: context,
            baseSize: iconSize,
            color: color ?? theme.colorScheme.primary,
          );

    Widget button = Material(
      color: backgroundColor ?? Colors.transparent,
      borderRadius: borderRadius ?? BorderRadius.circular(AppTheme.radiusSm),
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: borderRadius ?? BorderRadius.circular(AppTheme.radiusSm),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(8),
          child: iconWidget,
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}

class FloatingButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isExtended;
  final String? label;
  final bool isLoading;

  const FloatingButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
    this.isExtended = false,
    this.label,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isExtended && label != null) {
      return FloatingActionButton.extended(
        onPressed: isLoading ? null : onPressed,
        backgroundColor: backgroundColor ?? theme.colorScheme.primary,
        foregroundColor: foregroundColor ?? theme.colorScheme.onPrimary,
        tooltip: tooltip,
        icon: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    foregroundColor ?? theme.colorScheme.onPrimary,
                  ),
                ),
              )
            : LayoutFixUtils.responsiveIcon(icon, context: context),
        label: Text(label!),
      );
    }

    return FloatingActionButton(
      onPressed: isLoading ? null : onPressed,
      backgroundColor: backgroundColor ?? theme.colorScheme.primary,
      foregroundColor: foregroundColor ?? theme.colorScheme.onPrimary,
      tooltip: tooltip,
      child: isLoading
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  foregroundColor ?? theme.colorScheme.onPrimary,
                ),
              ),
            )
          : LayoutFixUtils.responsiveIcon(icon, context: context),
    );
  }
}

class ButtonGroup extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final double spacing;
  final bool isVertical;

  const ButtonGroup({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.spacing = AppTheme.spacingSm,
    this.isVertical = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isVertical) {
      return Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: children
            .expand((child) => [child, SizedBox(height: spacing)])
            .take(children.length * 2 - 1)
            .toList(),
      );
    }

    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: children
          .expand((child) => [child, SizedBox(width: spacing)])
          .take(children.length * 2 - 1)
          .toList(),
    );
  }
}

class ToggleButton extends StatefulWidget {
  final bool isSelected;
  final ValueChanged<bool> onChanged;
  final String text;
  final IconData? icon;
  final Color? selectedColor;
  final Color? unselectedColor;
  final ButtonSize size;

  const ToggleButton({
    super.key,
    required this.isSelected,
    required this.onChanged,
    required this.text,
    this.icon,
    this.selectedColor,
    this.unselectedColor,
    this.size = ButtonSize.medium,
  });

  @override
  State<ToggleButton> createState() => _ToggleButtonState();
}

class _ToggleButtonState extends State<ToggleButton> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomButton(
      text: widget.text,
      icon: widget.icon,
      variant:
          widget.isSelected ? ButtonVariant.primary : ButtonVariant.outline,
      size: widget.size,
      customColor: widget.isSelected
          ? (widget.selectedColor ?? theme.colorScheme.primary)
          : (widget.unselectedColor ?? theme.colorScheme.outline),
      onPressed: () => widget.onChanged(!widget.isSelected),
    );
  }
}
