import 'package:flutter/material.dart';
import '../utils/layout_fix_utils.dart';

class AppErrorWidget extends StatelessWidget {
  final String? title;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;
  final IconData? icon;
  final Color? iconColor;

  const AppErrorWidget({
    super.key,
    this.title,
    required this.message,
    this.actionText,
    this.onAction,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LayoutFixUtils.responsiveIcon(
              icon ?? Icons.error_outline,
              context: context,
              baseSize: 64,
              color: iconColor ?? Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            if (title != null) ...[
              Text(
                title!,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
              textAlign: TextAlign.center,
            ),
            if (onAction != null && actionText != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NetworkErrorWidget extends StatelessWidget {
  final VoidCallback? onRetry;
  final String? message;

  const NetworkErrorWidget({
    super.key,
    this.onRetry,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return AppErrorWidget(
      title: 'Connection Error',
      message:
          message ?? 'Please check your internet connection and try again.',
      actionText: 'Retry',
      onAction: onRetry,
      icon: Icons.wifi_off,
      iconColor: Colors.orange,
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;
  final IconData? icon;
  final Widget? illustration;

  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.message,
    this.actionText,
    this.onAction,
    this.icon,
    this.illustration,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (illustration != null)
              illustration!
            else
              LayoutFixUtils.responsiveIcon(
                icon ?? Icons.inbox_outlined,
                context: context,
                baseSize: 80,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
              ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.8),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
              textAlign: TextAlign.center,
            ),
            if (onAction != null && actionText != null) ...[
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: Text(actionText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NotFoundWidget extends StatelessWidget {
  final String? title;
  final String? message;
  final VoidCallback? onGoBack;

  const NotFoundWidget({
    super.key,
    this.title,
    this.message,
    this.onGoBack,
  });

  @override
  Widget build(BuildContext context) {
    return AppErrorWidget(
      title: title ?? 'Page Not Found',
      message: message ?? 'The page you are looking for does not exist.',
      actionText: 'Go Back',
      onAction: onGoBack ?? () => Navigator.of(context).pop(),
      icon: Icons.search_off,
      iconColor: Colors.grey,
    );
  }
}

class UnauthorizedWidget extends StatelessWidget {
  final VoidCallback? onSignIn;
  final String? message;

  const UnauthorizedWidget({
    super.key,
    this.onSignIn,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return AppErrorWidget(
      title: 'Access Denied',
      message: message ?? 'You need to sign in to access this content.',
      actionText: 'Sign In',
      onAction: onSignIn,
      icon: Icons.lock_outline,
      iconColor: Colors.amber,
    );
  }
}

class MaintenanceWidget extends StatelessWidget {
  final String? message;
  final DateTime? estimatedTime;

  const MaintenanceWidget({
    super.key,
    this.message,
    this.estimatedTime,
  });

  @override
  Widget build(BuildContext context) {
    String maintenanceMessage =
        message ?? 'We are currently performing maintenance.';

    if (estimatedTime != null) {
      final timeString =
          '${estimatedTime!.hour.toString().padLeft(2, '0')}:${estimatedTime!.minute.toString().padLeft(2, '0')}';
      maintenanceMessage += '\n\nEstimated completion: $timeString';
    }

    return AppErrorWidget(
      title: 'Under Maintenance',
      message: maintenanceMessage,
      icon: Icons.build_outlined,
      iconColor: Colors.blue,
    );
  }
}

class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace? stackTrace)? errorBuilder;
  final void Function(Object error, StackTrace? stackTrace)? onError;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
    this.onError,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(_error!, _stackTrace);
      }

      return AppErrorWidget(
        title: 'Something went wrong',
        message: 'An unexpected error occurred. Please try again.',
        actionText: 'Retry',
        onAction: () {
          setState(() {
            _error = null;
            _stackTrace = null;
          });
        },
      );
    }

    return widget.child;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Reset error state when dependencies change
    if (_error != null) {
      setState(() {
        _error = null;
        _stackTrace = null;
      });
    }
  }


}

class AsyncErrorWidget extends StatelessWidget {
  final AsyncSnapshot snapshot;
  final VoidCallback? onRetry;
  final String? customMessage;

  const AsyncErrorWidget({
    super.key,
    required this.snapshot,
    this.onRetry,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    final error = snapshot.error;
    String message = customMessage ?? 'An error occurred while loading data.';

    if (error != null) {
      message = error.toString();
    }

    return AppErrorWidget(
      title: 'Error',
      message: message,
      actionText: onRetry != null ? 'Retry' : null,
      onAction: onRetry,
    );
  }
}




