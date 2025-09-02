import 'package:flutter/material.dart';
import 'custom_button.dart';

class CustomBottomSheet extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final Widget child;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final bool showDragHandle;
  final bool isDismissible;
  final bool enableDrag;
  final Color? backgroundColor;
  final ShapeBorder? shape;
  final Clip? clipBehavior;
  final BoxConstraints? constraints;
  final bool isScrollControlled;
  final bool useRootNavigator;
  final RouteSettings? routeSettings;
  final AnimationController? transitionAnimationController;
  
  const CustomBottomSheet({
    super.key,
    this.title,
    this.titleWidget,
    required this.child,
    this.actions,
    this.padding,
    this.height,
    this.showDragHandle = true,
    this.isDismissible = true,
    this.enableDrag = true,
    this.backgroundColor,
    this.shape,
    this.clipBehavior,
    this.constraints,
    this.isScrollControlled = false,
    this.useRootNavigator = false,
    this.routeSettings,
    this.transitionAnimationController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectivePadding = padding ?? const EdgeInsets.all(16);
    
    return Container(
      height: height,
      constraints: constraints,
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDragHandle)
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          if (title != null || titleWidget != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                effectivePadding.horizontal / 2,
                showDragHandle ? 8 : effectivePadding.vertical / 2,
                effectivePadding.horizontal / 2,
                8,
              ),
              child: titleWidget ?? Text(
                title!,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Flexible(
            child: Padding(
              padding: effectivePadding,
              child: child,
            ),
          ),
          if (actions != null && actions!.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                effectivePadding.horizontal / 2,
                8,
                effectivePadding.horizontal / 2,
                effectivePadding.vertical / 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions!,
              ),
            ),
        ],
      ),
    );
  }

  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    Widget? titleWidget,
    required Widget child,
    List<Widget>? actions,
    EdgeInsetsGeometry? padding,
    double? height,
    bool showDragHandle = true,
    bool isDismissible = true,
    bool enableDrag = true,
    Color? backgroundColor,
    ShapeBorder? shape,
    Clip? clipBehavior,
    BoxConstraints? constraints,
    bool isScrollControlled = false,
    bool useRootNavigator = false,
    RouteSettings? routeSettings,
    AnimationController? transitionAnimationController,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      shape: shape,
      clipBehavior: clipBehavior,
      constraints: constraints,
      isScrollControlled: isScrollControlled,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
      transitionAnimationController: transitionAnimationController,
      builder: (context) => CustomBottomSheet(
        title: title,
        titleWidget: titleWidget,
        actions: actions,
        padding: padding,
        height: height,
        showDragHandle: showDragHandle,
        isDismissible: isDismissible,
        enableDrag: enableDrag,
        backgroundColor: backgroundColor,
        shape: shape,
        clipBehavior: clipBehavior,
        constraints: constraints,
        isScrollControlled: isScrollControlled,
        useRootNavigator: useRootNavigator,
        routeSettings: routeSettings,
        transitionAnimationController: transitionAnimationController,
        child: child,
      ),
    );
  }
}

class ActionBottomSheet extends StatelessWidget {
  final String? title;
  final String? message;
  final List<BottomSheetAction> actions;
  final BottomSheetAction? cancelAction;
  final bool showDragHandle;
  final EdgeInsetsGeometry? padding;
  
  const ActionBottomSheet({
    super.key,
    this.title,
    this.message,
    required this.actions,
    this.cancelAction,
    this.showDragHandle = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return CustomBottomSheet(
      title: title,
      showDragHandle: showDragHandle,
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message != null) ..[
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
          ...actions.map((action) => _BottomSheetActionTile(
            action: action,
            onTap: () {
              Navigator.of(context).pop(action.value);
              action.onTap?.call();
            },
          )),
          if (cancelAction != null) ..[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 8),
            _BottomSheetActionTile(
              action: cancelAction!,
              onTap: () {
                Navigator.of(context).pop(cancelAction!.value);
                cancelAction!.onTap?.call();
              },
            ),
          ],
        ],
      ),
    );
  }

  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    String? message,
    required List<BottomSheetAction> actions,
    BottomSheetAction? cancelAction,
    bool showDragHandle = true,
    EdgeInsetsGeometry? padding,
  }) {
    return CustomBottomSheet.show<T>(
      context: context,
      title: title,
      showDragHandle: showDragHandle,
      padding: padding,
      child: ActionBottomSheet(
        title: null, // Title is handled by CustomBottomSheet
        message: message,
        actions: actions,
        cancelAction: cancelAction,
        showDragHandle: false, // Handled by parent
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class BottomSheetAction<T> {
  final String title;
  final IconData? icon;
  final Color? color;
  final T? value;
  final VoidCallback? onTap;
  final bool isDestructive;
  final bool isDefault;
  
  const BottomSheetAction({
    required this.title,
    this.icon,
    this.color,
    this.value,
    this.onTap,
    this.isDestructive = false,
    this.isDefault = false,
  });
}

class _BottomSheetActionTile extends StatelessWidget {
  final BottomSheetAction action;
  final VoidCallback onTap;
  
  const _BottomSheetActionTile({
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color textColor;
    
    if (action.isDestructive) {
      textColor = action.color ?? theme.colorScheme.error;
    } else if (action.isDefault) {
      textColor = action.color ?? theme.colorScheme.primary;
    } else {
      textColor = action.color ?? theme.colorScheme.onSurface;
    }
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            if (action.icon != null) ..[
              Icon(
                action.icon,
                color: textColor,
                size: 20,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                action.title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: textColor,
                  fontWeight: action.isDefault ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FormBottomSheet extends StatefulWidget {
  final String title;
  final List<Widget> fields;
  final String submitText;
  final String cancelText;
  final VoidCallback? onSubmit;
  final VoidCallback? onCancel;
  final GlobalKey<FormState>? formKey;
  final bool showDragHandle;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final bool isScrollControlled;
  
  const FormBottomSheet({
    super.key,
    required this.title,
    required this.fields,
    this.submitText = 'Save',
    this.cancelText = 'Cancel',
    this.onSubmit,
    this.onCancel,
    this.formKey,
    this.showDragHandle = true,
    this.padding,
    this.height,
    this.isScrollControlled = true,
  });

  @override
  State<FormBottomSheet> createState() => _FormBottomSheetState();
}

class _FormBottomSheetState extends State<FormBottomSheet> {
  late GlobalKey<FormState> _formKey;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _formKey = widget.formKey ?? GlobalKey<FormState>();
  }

  void _handleSubmit() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        widget.onSubmit?.call();
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
    return CustomBottomSheet(
      title: widget.title,
      showDragHandle: widget.showDragHandle,
      padding: widget.padding,
      height: widget.height,
      isScrollControlled: widget.isScrollControlled,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...widget.fields,
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: widget.cancelText,
                    variant: ButtonVariant.outline,
                    onPressed: _isLoading ? null : () {
                      Navigator.of(context).pop(false);
                      widget.onCancel?.call();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    text: widget.submitText,
                    variant: ButtonVariant.primary,
                    isLoading: _isLoading,
                    onPressed: _isLoading ? null : _handleSubmit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required List<Widget> fields,
    String submitText = 'Save',
    String cancelText = 'Cancel',
    VoidCallback? onSubmit,
    VoidCallback? onCancel,
    GlobalKey<FormState>? formKey,
    bool showDragHandle = true,
    EdgeInsetsGeometry? padding,
    double? height,
    bool isScrollControlled = true,
  }) {
    return CustomBottomSheet.show<bool>(
      context: context,
      isScrollControlled: isScrollControlled,
      child: FormBottomSheet(
        title: title,
        fields: fields,
        submitText: submitText,
        cancelText: cancelText,
        onSubmit: onSubmit,
        onCancel: onCancel,
        formKey: formKey,
        showDragHandle: showDragHandle,
        padding: padding,
        height: height,
        isScrollControlled: isScrollControlled,
      ),
    );
  }
}

class ListBottomSheet<T> extends StatelessWidget {
  final String? title;
  final List<ListBottomSheetItem<T>> items;
  final T? selectedValue;
  final ValueChanged<T>? onItemSelected;
  final bool showDragHandle;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final bool isScrollControlled;
  final Widget Function(ListBottomSheetItem<T>)? itemBuilder;
  
  const ListBottomSheet({
    super.key,
    this.title,
    required this.items,
    this.selectedValue,
    this.onItemSelected,
    this.showDragHandle = true,
    this.padding,
    this.height,
    this.isScrollControlled = false,
    this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return CustomBottomSheet(
      title: title,
      showDragHandle: showDragHandle,
      padding: padding,
      height: height,
      isScrollControlled: isScrollControlled,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          
          if (itemBuilder != null) {
            return itemBuilder!(item);
          }
          
          return _ListBottomSheetTile<T>(
            item: item,
            isSelected: item.value == selectedValue,
            onTap: () {
              Navigator.of(context).pop(item.value);
              onItemSelected?.call(item.value);
            },
          );
        },
      ),
    );
  }

  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    required List<ListBottomSheetItem<T>> items,
    T? selectedValue,
    ValueChanged<T>? onItemSelected,
    bool showDragHandle = true,
    EdgeInsetsGeometry? padding,
    double? height,
    bool isScrollControlled = false,
    Widget Function(ListBottomSheetItem<T>)? itemBuilder,
  }) {
    return CustomBottomSheet.show<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      child: ListBottomSheet<T>(
        title: title,
        items: items,
        selectedValue: selectedValue,
        onItemSelected: onItemSelected,
        showDragHandle: showDragHandle,
        padding: padding,
        height: height,
        isScrollControlled: isScrollControlled,
        itemBuilder: itemBuilder,
      ),
    );
  }
}

class ListBottomSheetItem<T> {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final T value;
  final bool enabled;
  
  const ListBottomSheetItem({
    required this.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.trailing,
    required this.value,
    this.enabled = true,
  });
}

class _ListBottomSheetTile<T> extends StatelessWidget {
  final ListBottomSheetItem<T> item;
  final bool isSelected;
  final VoidCallback onTap;
  
  const _ListBottomSheetTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Widget? leading = item.leading;
    if (leading == null && item.icon != null) {
      leading = Icon(
        item.icon,
        color: isSelected ? theme.colorScheme.primary : null,
      );
    }
    
    Widget? trailing = item.trailing;
    if (isSelected && trailing == null) {
      trailing = Icon(
        Icons.check,
        color: theme.colorScheme.primary,
      );
    }
    
    return ListTile(
      leading: leading,
      title: Text(
        item.title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: isSelected ? theme.colorScheme.primary : null,
          fontWeight: isSelected ? FontWeight.w600 : null,
        ),
      ),
      subtitle: item.subtitle != null ? Text(
        item.subtitle!,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isSelected 
              ? theme.colorScheme.primary.withValues(alpha: 0.7)
              : theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ) : null,
      trailing: trailing,
      enabled: item.enabled,
      selected: isSelected,
      onTap: item.enabled ? onTap : null,
    );
  }
}

class ConfirmationBottomSheet extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final Color? confirmColor;
  final bool isDestructive;
  final IconData? icon;
  final Color? iconColor;
  final bool showDragHandle;
  
  const ConfirmationBottomSheet({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.onConfirm,
    this.onCancel,
    this.confirmColor,
    this.isDestructive = false,
    this.icon,
    this.iconColor,
    this.showDragHandle = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveConfirmColor = isDestructive 
        ? (confirmColor ?? theme.colorScheme.error)
        : (confirmColor ?? theme.colorScheme.primary);
    
    return CustomBottomSheet(
      title: title,
      showDragHandle: showDragHandle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ..[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (iconColor ?? effectiveConfirmColor).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor ?? effectiveConfirmColor,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            message,
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: cancelText,
                  variant: ButtonVariant.outline,
                  onPressed: () {
                    Navigator.of(context).pop(false);
                    onCancel?.call();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomButton(
                  text: confirmText,
                  variant: isDestructive ? ButtonVariant.danger : ButtonVariant.primary,
                  color: effectiveConfirmColor,
                  onPressed: () {
                    Navigator.of(context).pop(true);
                    onConfirm?.call();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    Color? confirmColor,
    bool isDestructive = false,
    IconData? icon,
    Color? iconColor,
    bool showDragHandle = true,
  }) {
    return CustomBottomSheet.show<bool>(
      context: context,
      child: ConfirmationBottomSheet(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        onConfirm: onConfirm,
        onCancel: onCancel,
        confirmColor: confirmColor,
        isDestructive: isDestructive,
        icon: icon,
        iconColor: iconColor,
        showDragHandle: showDragHandle,
      ),
    );
  }
}
