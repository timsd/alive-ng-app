import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'custom_button.dart';

class CustomDialog extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final String? content;
  final Widget? contentWidget;
  final List<Widget>? actions;
  final bool barrierDismissible;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? titlePadding;
  final EdgeInsetsGeometry? actionsPadding;
  final MainAxisAlignment? actionsAlignment;
  final Color? backgroundColor;
  final double? elevation;
  final ShapeBorder? shape;
  final bool scrollable;
  final Widget? icon;
  
  const CustomDialog({
    super.key,
    this.title,
    this.titleWidget,
    this.content,
    this.contentWidget,
    this.actions,
    this.barrierDismissible = true,
    this.contentPadding,
    this.titlePadding,
    this.actionsPadding,
    this.actionsAlignment,
    this.backgroundColor,
    this.elevation,
    this.shape,
    this.scrollable = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxWidth = MediaQuery.of(context).size.width < 720 ? 560.0 : 680.0;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          minWidth: MediaQuery.of(context).size.width < 480 ? 280 : 340,
        ),
        child: AlertDialog(
          title: titleWidget ?? (title != null ? Row(
            children: [
              if (icon != null) ...[
                icon!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title!,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ) : null),
          content: contentWidget ?? (content != null ? Text(
            content!,
            style: theme.textTheme.bodyMedium,
          ) : null),
          actions: actions,
          contentPadding: contentPadding ?? const EdgeInsets.fromLTRB(28, 20, 28, 24),
          titlePadding: titlePadding ?? const EdgeInsets.fromLTRB(28, 28, 28, 0),
          actionsPadding: actionsPadding ?? const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actionsAlignment: actionsAlignment ?? MainAxisAlignment.end,
          backgroundColor: backgroundColor,
          elevation: elevation,
          shape: shape ?? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          ),
          scrollable: scrollable,
          insetPadding: theme.dialogTheme.insetPadding,
          surfaceTintColor: Colors.transparent,
          actionsOverflowButtonSpacing: 12,
        ),
      ),
    );
  }

  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    Widget? titleWidget,
    String? content,
    Widget? contentWidget,
    List<Widget>? actions,
    bool barrierDismissible = true,
    EdgeInsetsGeometry? contentPadding,
    EdgeInsetsGeometry? titlePadding,
    EdgeInsetsGeometry? actionsPadding,
    MainAxisAlignment? actionsAlignment,
    Color? backgroundColor,
    double? elevation,
    ShapeBorder? shape,
    bool scrollable = false,
    Widget? icon,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      useSafeArea: true,
      builder: (context) => CustomDialog(
        title: title,
        titleWidget: titleWidget,
        content: content,
        contentWidget: contentWidget,
        actions: actions,
        barrierDismissible: barrierDismissible,
        contentPadding: contentPadding,
        titlePadding: titlePadding,
        actionsPadding: actionsPadding,
        actionsAlignment: actionsAlignment,
        backgroundColor: backgroundColor,
        elevation: elevation,
        shape: shape,
        scrollable: scrollable,
        icon: icon,
      ),
    );
  }
}

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmText;
  final String cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final Color? confirmColor;
  final Color? cancelColor;
  final IconData? icon;
  final Color? iconColor;
  final bool isDestructive;
  
  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.onConfirm,
    this.onCancel,
    this.confirmColor,
    this.cancelColor,
    this.icon,
    this.iconColor,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveConfirmColor = isDestructive 
        ? (confirmColor ?? theme.colorScheme.error)
        : (confirmColor ?? theme.colorScheme.primary);
    
    return CustomDialog(
      title: title,
      content: content,
      icon: icon != null ? Icon(
        icon,
        color: iconColor ?? (isDestructive ? theme.colorScheme.error : theme.colorScheme.primary),
      ) : null,
      actions: [
        CustomButton(
          text: cancelText,
          variant: ButtonVariant.text,
          customColor: cancelColor,
          onPressed: () {
            Navigator.of(context).pop(false);
            onCancel?.call();
          },
        ),
        const SizedBox(width: 8),
        CustomButton(
          text: confirmText,
          variant: isDestructive ? ButtonVariant.danger : ButtonVariant.primary,
          customColor: effectiveConfirmColor,
          onPressed: () {
            Navigator.of(context).pop(true);
            onConfirm?.call();
          },
        ),
      ],
    );
  }

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String content,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    Color? confirmColor,
    Color? cancelColor,
    IconData? icon,
    Color? iconColor,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: title,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
        onConfirm: onConfirm,
        onCancel: onCancel,
        confirmColor: confirmColor,
        cancelColor: cancelColor,
        icon: icon,
        iconColor: iconColor,
        isDestructive: isDestructive,
      ),
    );
  }
}

class InfoDialog extends StatelessWidget {
  final String title;
  final String content;
  final String buttonText;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? iconColor;
  final Color? buttonColor;
  
  const InfoDialog({
    super.key,
    required this.title,
    required this.content,
    this.buttonText = 'OK',
    this.onPressed,
    this.icon,
    this.iconColor,
    this.buttonColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return CustomDialog(
      title: title,
      content: content,
      icon: icon != null ? Icon(
        icon,
        color: iconColor ?? theme.colorScheme.primary,
      ) : null,
      actions: [
        CustomButton(
          text: buttonText,
          variant: ButtonVariant.primary,
          customColor: buttonColor,
          onPressed: () {
            Navigator.of(context).pop();
            onPressed?.call();
          },
        ),
      ],
    );
  }

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String content,
    String buttonText = 'OK',
    VoidCallback? onPressed,
    IconData? icon,
    Color? iconColor,
    Color? buttonColor,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => InfoDialog(
        title: title,
        content: content,
        buttonText: buttonText,
        onPressed: onPressed,
        icon: icon,
        iconColor: iconColor,
        buttonColor: buttonColor,
      ),
    );
  }
}

class LoadingDialog extends StatelessWidget {
  final String? title;
  final String? message;
  final bool barrierDismissible;
  
  const LoadingDialog({
    super.key,
    this.title,
    this.message,
    this.barrierDismissible = false,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: barrierDismissible,
      child: CustomDialog(
        title: title,
        contentWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
        barrierDismissible: barrierDismissible,
      ),
    );
  }

  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    String? message,
    bool barrierDismissible = false,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => LoadingDialog(
        title: title,
        message: message,
        barrierDismissible: barrierDismissible,
      ),
    );
  }
}

class FormDialog extends StatefulWidget {
  final String title;
  final List<Widget> fields;
  final String confirmText;
  final String cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final GlobalKey<FormState>? formKey;
  final bool scrollable;
  final EdgeInsetsGeometry? contentPadding;
  
  const FormDialog({
    super.key,
    required this.title,
    required this.fields,
    this.confirmText = 'Save',
    this.cancelText = 'Cancel',
    this.onConfirm,
    this.onCancel,
    this.formKey,
    this.scrollable = true,
    this.contentPadding,
  });

  @override
  State<FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends State<FormDialog> {
  late GlobalKey<FormState> _formKey;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _formKey = widget.formKey ?? GlobalKey<FormState>();
  }

  void _handleConfirm() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        widget.onConfirm?.call();
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomDialog(
      title: widget.title,
      contentWidget: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.fields,
        ),
      ),
      actions: [
        CustomButton(
          text: widget.cancelText,
          variant: ButtonVariant.text,
          onPressed: _isLoading ? null : () {
            Navigator.of(context).pop(false);
            widget.onCancel?.call();
          },
        ),
        const SizedBox(width: 8),
        CustomButton(
          text: widget.confirmText,
          variant: ButtonVariant.primary,
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _handleConfirm,
        ),
      ],
      scrollable: widget.scrollable,
      contentPadding: widget.contentPadding,
    );
  }


}

class BottomSheetDialog {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool isDismissible = true,
    bool enableDrag = true,
    double? height,
    EdgeInsetsGeometry? padding,
    Color? backgroundColor,
    ShapeBorder? shape,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.surface,
      useSafeArea: true,
      isScrollControlled: true,
      shape: shape ?? const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: height ?? MediaQuery.of(context).size.height * 0.88,
        maxWidth: 640,
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (enableDrag)
                Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              if (title != null) ...[
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),
              ],
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class ActionSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    String? message,
    required List<ActionSheetItem<T>> actions,
    ActionSheetItem<T>? cancelAction,
  }) {
    return BottomSheetDialog.show<T>(
      context: context,
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message != null) ...[
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
          ...actions.map((action) => _ActionSheetTile<T>(
            item: action,
            onTap: () {
              Navigator.of(context).pop(action.value);
              action.onTap?.call();
            },
          )),
          if (cancelAction != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 1,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 8),
            _ActionSheetTile<T>(
              item: cancelAction,
              onTap: () {
                Navigator.of(context).pop(cancelAction.value);
                cancelAction.onTap?.call();
              },
            ),
          ],
        ],
      ),
    );
  }
}

class ActionSheetItem<T> {
  final String title;
  final IconData? icon;
  final Color? color;
  final T? value;
  final VoidCallback? onTap;
  final bool isDestructive;
  
  const ActionSheetItem({
    required this.title,
    this.icon,
    this.color,
    this.value,
    this.onTap,
    this.isDestructive = false,
  });
}

class _ActionSheetTile<T> extends StatelessWidget {
  final ActionSheetItem<T> item;
  final VoidCallback onTap;
  
  const _ActionSheetTile({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = item.isDestructive 
        ? (item.color ?? theme.colorScheme.error)
        : (item.color ?? theme.colorScheme.onSurface);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (item.icon != null) ...[
              Icon(
                item.icon,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                item.title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: color,
                  fontWeight: item.isDestructive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}




