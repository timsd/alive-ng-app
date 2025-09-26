import 'package:flutter/material.dart';

enum SnackBarType {
  info,
  success,
  warning,
  error,
}

class CustomSnackBar {
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show({
    required BuildContext context,
    required String message,
    String? title,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onActionPressed,
    bool showCloseIcon = false,
    VoidCallback? onClosed,
    SnackBarBehavior? behavior,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
    double? width,
    ShapeBorder? shape,
    double? elevation,
    Color? backgroundColor,
    Color? foregroundColor,
    Animation<double>? animation,
    VoidCallback? onVisible,
    DismissDirection dismissDirection = DismissDirection.down,
    Clip clipBehavior = Clip.hardEdge,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine colors based on type
    Color effectiveBackgroundColor;
    Color effectiveForegroundColor;
    IconData icon;

    switch (type) {
      case SnackBarType.success:
        effectiveBackgroundColor = backgroundColor ?? Colors.green;
        effectiveForegroundColor = foregroundColor ?? Colors.white;
        icon = Icons.check_circle;
        break;
      case SnackBarType.warning:
        effectiveBackgroundColor = backgroundColor ?? Colors.orange;
        effectiveForegroundColor = foregroundColor ?? Colors.white;
        icon = Icons.warning;
        break;
      case SnackBarType.error:
        effectiveBackgroundColor = backgroundColor ?? colorScheme.error;
        effectiveForegroundColor = foregroundColor ?? colorScheme.onError;
        icon = Icons.error;
        break;
      case SnackBarType.info:
        effectiveBackgroundColor =
            backgroundColor ?? colorScheme.inverseSurface;
        effectiveForegroundColor =
            foregroundColor ?? colorScheme.onInverseSurface;
        icon = Icons.info;
        break;
    }

    final snackBar = SnackBar(
      content: _SnackBarContent(
        title: title,
        message: message,
        icon: icon,
        foregroundColor: effectiveForegroundColor,
      ),
      duration: duration,
      action: actionLabel != null
          ? SnackBarAction(
              label: actionLabel,
              onPressed: onActionPressed ?? () {},
              textColor: effectiveForegroundColor,
            )
          : null,
      showCloseIcon: showCloseIcon,
      closeIconColor: effectiveForegroundColor,
      onVisible: onVisible,
      behavior: behavior ?? SnackBarBehavior.floating,
      margin: margin,
      padding: padding,
      width: width,
      shape: shape ??
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
      elevation: elevation,
      backgroundColor: effectiveBackgroundColor,
      animation: animation,
      dismissDirection: dismissDirection,
      clipBehavior: clipBehavior,
    );

    final controller = ScaffoldMessenger.of(context).showSnackBar(snackBar);

    if (onClosed != null) {
      controller.closed.then((_) => onClosed());
    }

    return controller;
  }

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSuccess({
    required BuildContext context,
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onActionPressed,
    bool showCloseIcon = false,
    VoidCallback? onClosed,
  }) {
    return show(
      context: context,
      message: message,
      title: title,
      type: SnackBarType.success,
      duration: duration,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      showCloseIcon: showCloseIcon,
      onClosed: onClosed,
    );
  }

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showError({
    required BuildContext context,
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 5),
    String? actionLabel,
    VoidCallback? onActionPressed,
    bool showCloseIcon = true,
    VoidCallback? onClosed,
  }) {
    return show(
      context: context,
      message: message,
      title: title,
      type: SnackBarType.error,
      duration: duration,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      showCloseIcon: showCloseIcon,
      onClosed: onClosed,
    );
  }

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showWarning({
    required BuildContext context,
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onActionPressed,
    bool showCloseIcon = false,
    VoidCallback? onClosed,
  }) {
    return show(
      context: context,
      message: message,
      title: title,
      type: SnackBarType.warning,
      duration: duration,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      showCloseIcon: showCloseIcon,
      onClosed: onClosed,
    );
  }

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showInfo({
    required BuildContext context,
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onActionPressed,
    bool showCloseIcon = false,
    VoidCallback? onClosed,
  }) {
    return show(
      context: context,
      message: message,
      title: title,
      type: SnackBarType.info,
      duration: duration,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      showCloseIcon: showCloseIcon,
      onClosed: onClosed,
    );
  }

  static void hide(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  static void clear(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
  }
}

class _SnackBarContent extends StatelessWidget {
  final String? title;
  final String message;
  final IconData icon;
  final Color foregroundColor;

  const _SnackBarContent({
    this.title,
    required this.message,
    required this.icon,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          color: foregroundColor,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null) ...[
                Text(
                  title!,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: foregroundColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CustomBanner {
  static ScaffoldFeatureController<MaterialBanner, MaterialBannerClosedReason>
      show({
    required BuildContext context,
    required String message,
    String? title,
    SnackBarType type = SnackBarType.info,
    List<Widget>? actions,
    Widget? leading,
    Color? backgroundColor,
    Color? surfaceTintColor,
    Color? shadowColor,
    Color? dividerColor,
    EdgeInsetsGeometry? contentTextStyle,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    bool forceActionsBelow = false,
    OverflowBarAlignment overflowAlignment = OverflowBarAlignment.end,
    Animation<double>? animation,
    VoidCallback? onVisible,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine colors and icon based on type
    Color effectiveBackgroundColor;
    IconData icon;

    switch (type) {
      case SnackBarType.success:
        effectiveBackgroundColor =
            backgroundColor ?? Colors.green.withValues(alpha: 0.1);
        icon = Icons.check_circle;
        break;
      case SnackBarType.warning:
        effectiveBackgroundColor =
            backgroundColor ?? Colors.orange.withValues(alpha: 0.1);
        icon = Icons.warning;
        break;
      case SnackBarType.error:
        effectiveBackgroundColor =
            backgroundColor ?? colorScheme.errorContainer;
        icon = Icons.error;
        break;
      case SnackBarType.info:
        effectiveBackgroundColor =
            backgroundColor ?? colorScheme.surfaceContainerHighest;
        icon = Icons.info;
        break;
    }

    Widget? effectiveLeading = leading;
    if (effectiveLeading == null) {
      Color iconColor;
      switch (type) {
        case SnackBarType.success:
          iconColor = Colors.green;
          break;
        case SnackBarType.warning:
          iconColor = Colors.orange;
          break;
        case SnackBarType.error:
          iconColor = colorScheme.error;
          break;
        case SnackBarType.info:
          iconColor = colorScheme.primary;
          break;
      }

      effectiveLeading = Icon(
        icon,
        color: iconColor,
      );
    }

    final banner = MaterialBanner(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            message,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
      actions: actions ??
          [
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              },
              child: const Text('Dismiss'),
            ),
          ],
      leading: effectiveLeading,
      backgroundColor: effectiveBackgroundColor,
      surfaceTintColor: surfaceTintColor,
      shadowColor: shadowColor,
      dividerColor: dividerColor,
      padding: padding,
      margin: margin,
      forceActionsBelow: forceActionsBelow,
      overflowAlignment: overflowAlignment,
      animation: animation,
      onVisible: onVisible,
    );

    return ScaffoldMessenger.of(context).showMaterialBanner(banner);
  }

  static ScaffoldFeatureController<MaterialBanner, MaterialBannerClosedReason>
      showSuccess({
    required BuildContext context,
    required String message,
    String? title,
    List<Widget>? actions,
    Widget? leading,
  }) {
    return show(
      context: context,
      message: message,
      title: title,
      type: SnackBarType.success,
      actions: actions,
      leading: leading,
    );
  }

  static ScaffoldFeatureController<MaterialBanner, MaterialBannerClosedReason>
      showError({
    required BuildContext context,
    required String message,
    String? title,
    List<Widget>? actions,
    Widget? leading,
  }) {
    return show(
      context: context,
      message: message,
      title: title,
      type: SnackBarType.error,
      actions: actions,
      leading: leading,
    );
  }

  static ScaffoldFeatureController<MaterialBanner, MaterialBannerClosedReason>
      showWarning({
    required BuildContext context,
    required String message,
    String? title,
    List<Widget>? actions,
    Widget? leading,
  }) {
    return show(
      context: context,
      message: message,
      title: title,
      type: SnackBarType.warning,
      actions: actions,
      leading: leading,
    );
  }

  static ScaffoldFeatureController<MaterialBanner, MaterialBannerClosedReason>
      showInfo({
    required BuildContext context,
    required String message,
    String? title,
    List<Widget>? actions,
    Widget? leading,
  }) {
    return show(
      context: context,
      message: message,
      title: title,
      type: SnackBarType.info,
      actions: actions,
      leading: leading,
    );
  }

  static void hide(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
  }

  static void clear(BuildContext context) {
    ScaffoldMessenger.of(context).clearMaterialBanners();
  }
}

class ToastNotification {
  static OverlayEntry? _currentToast;

  static void show({
    required BuildContext context,
    required String message,
    String? title,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
    ToastPosition position = ToastPosition.bottom,
    EdgeInsetsGeometry? margin,
    double? width,
    BorderRadius? borderRadius,
    Color? backgroundColor,
    Color? foregroundColor,
    double? elevation,
  }) {
    // Remove any existing toast
    hide();

    final overlay = Overlay.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine colors based on type
    Color effectiveBackgroundColor;
    Color effectiveForegroundColor;
    IconData icon;

    switch (type) {
      case SnackBarType.success:
        effectiveBackgroundColor = backgroundColor ?? Colors.green;
        effectiveForegroundColor = foregroundColor ?? Colors.white;
        icon = Icons.check_circle;
        break;
      case SnackBarType.warning:
        effectiveBackgroundColor = backgroundColor ?? Colors.orange;
        effectiveForegroundColor = foregroundColor ?? Colors.white;
        icon = Icons.warning;
        break;
      case SnackBarType.error:
        effectiveBackgroundColor = backgroundColor ?? colorScheme.error;
        effectiveForegroundColor = foregroundColor ?? colorScheme.onError;
        icon = Icons.error;
        break;
      case SnackBarType.info:
        effectiveBackgroundColor =
            backgroundColor ?? colorScheme.inverseSurface;
        effectiveForegroundColor =
            foregroundColor ?? colorScheme.onInverseSurface;
        icon = Icons.info;
        break;
    }

    _currentToast = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        title: title,
        icon: icon,
        position: position,
        margin: margin,
        width: width,
        borderRadius: borderRadius,
        backgroundColor: effectiveBackgroundColor,
        foregroundColor: effectiveForegroundColor,
        elevation: elevation,
      ),
    );

    overlay.insert(_currentToast!);

    // Auto-hide after duration
    Future.delayed(duration, () {
      hide();
    });
  }

  static void showSuccess({
    required BuildContext context,
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 2),
    ToastPosition position = ToastPosition.bottom,
  }) {
    show(
      context: context,
      message: message,
      title: title,
      type: SnackBarType.success,
      duration: duration,
      position: position,
    );
  }

  static void showError({
    required BuildContext context,
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 4),
    ToastPosition position = ToastPosition.bottom,
  }) {
    show(
      context: context,
      message: message,
      title: title,
      type: SnackBarType.error,
      duration: duration,
      position: position,
    );
  }

  static void showWarning({
    required BuildContext context,
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 3),
    ToastPosition position = ToastPosition.bottom,
  }) {
    show(
      context: context,
      message: message,
      title: title,
      type: SnackBarType.warning,
      duration: duration,
      position: position,
    );
  }

  static void showInfo({
    required BuildContext context,
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 2),
    ToastPosition position = ToastPosition.bottom,
  }) {
    show(
      context: context,
      message: message,
      title: title,
      type: SnackBarType.info,
      duration: duration,
      position: position,
    );
  }

  static void hide() {
    _currentToast?.remove();
    _currentToast = null;
  }
}

enum ToastPosition {
  top,
  center,
  bottom,
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final String? title;
  final IconData icon;
  final ToastPosition position;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final BorderRadius? borderRadius;
  final Color backgroundColor;
  final Color foregroundColor;
  final double? elevation;

  const _ToastWidget({
    required this.message,
    this.title,
    required this.icon,
    required this.position,
    this.margin,
    this.width,
    this.borderRadius,
    required this.backgroundColor,
    required this.foregroundColor,
    this.elevation,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    Offset beginOffset;
    switch (widget.position) {
      case ToastPosition.top:
        beginOffset = const Offset(0, -1);
        break;
      case ToastPosition.center:
        beginOffset = const Offset(0, 0);
        break;
      case ToastPosition.bottom:
        beginOffset = const Offset(0, 1);
        break;
    }

    _slideAnimation = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Alignment alignment;
    switch (widget.position) {
      case ToastPosition.top:
        alignment = Alignment.topCenter;
        break;
      case ToastPosition.center:
        alignment = Alignment.center;
        break;
      case ToastPosition.bottom:
        alignment = Alignment.bottomCenter;
        break;
    }

    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  width: widget.width,
                  margin: widget.margin ??
                      EdgeInsets.all(
                        widget.position == ToastPosition.center ? 32 : 16,
                      ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: widget.backgroundColor,
                    borderRadius:
                        widget.borderRadius ?? BorderRadius.circular(8),
                    boxShadow: widget.elevation != null
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: widget.elevation! * 2,
                              offset: Offset(0, widget.elevation!),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.icon,
                        color: widget.foregroundColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.title != null) ...[
                              Text(
                                widget.title!,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: widget.foregroundColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                            ],
                            Text(
                              widget.message,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: widget.foregroundColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}




