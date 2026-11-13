import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/platform/app_store_helper.dart';
import 'navigation_keys.dart';
import 'error_handler.dart';

/// Toast and banner notification utility that renders reliably OVER all
/// modals, bottom sheets, dialogs, and navigation routes using the root Overlay.
class ToastUtils {
  static OverlayEntry? _activeOverlayEntry;
  static Timer? _dismissTimer;

  /// Show success message
  static void showSuccess(String message) {
    if (kDebugMode) {
      debugPrint('✅ SUCCESS: $message');
    }
    _showOverlayBanner(
      message,
      backgroundColor: const Color(0xFF065F46), // Deep Emerald
      borderColor: const Color(0xFF10B981),
      icon: Icons.check_circle_rounded,
      iconColor: const Color(0xFF34D399),
    );
  }

  /// Show user-friendly error message, automatically translating technical errors.
  /// If the error relates to a mobile-only capability, includes a Play Store download action.
  static void showError(dynamic error, [String? fallback]) {
    final friendlyMsg = ErrorHandler.getUserFriendlyMessage(error, fallback);
    if (kDebugMode) {
      debugPrint('❌ ERROR: $friendlyMsg (raw: $error)');
    }

    final isMobileNotice = AppStoreHelper.isMobileOnlyNotice(friendlyMsg) ||
        AppStoreHelper.isMobileOnlyNotice(error);

    if (isMobileNotice) {
      // Automatically redirect the user straight to the Google Play Store
      AppStoreHelper.redirectToPlayStore();
    }

    _showOverlayBanner(
      friendlyMsg,
      backgroundColor: isMobileNotice ? const Color(0xFF141A28) : const Color(0xFF7F1D1D),
      borderColor: isMobileNotice ? const Color(0xFFD49B28) : const Color(0xFFEF4444),
      icon: isMobileNotice ? Icons.shop_two_rounded : Icons.error_rounded,
      iconColor: isMobileNotice ? const Color(0xFFD49B28) : const Color(0xFFF87171),
      duration: const Duration(seconds: 4),
    );
  }

  /// Show info message
  static void showInfo(String message) {
    if (kDebugMode) {
      debugPrint('ℹ️ INFO: $message');
    }

    final isMobileNotice = AppStoreHelper.isMobileOnlyNotice(message);

    if (isMobileNotice) {
      // Automatically redirect to Google Play Store
      AppStoreHelper.redirectToPlayStore();
    }

    _showOverlayBanner(
      message,
      backgroundColor: isMobileNotice ? const Color(0xFF141A28) : const Color(0xFF1E293B),
      borderColor: isMobileNotice ? const Color(0xFFD49B28) : const Color(0xFF64748B),
      icon: isMobileNotice ? Icons.shop_two_rounded : Icons.info_rounded,
      iconColor: isMobileNotice ? const Color(0xFFD49B28) : const Color(0xFF60A5FA),
    );
  }

  /// Show warning message
  static void showWarning(String message) {
    if (kDebugMode) {
      debugPrint('⚠️ WARNING: $message');
    }
    _showOverlayBanner(
      message,
      backgroundColor: const Color(0xFF78350F), // Amber Dark
      borderColor: const Color(0xFFF59E0B),
      icon: Icons.warning_rounded,
      iconColor: const Color(0xFFFBBF24),
    );
  }

  /// Dedicated prompt for features that require the ALIVE mobile app.
  /// Displays an informative banner with an action button to open the mobile app or Play Store.
  static void showMobilePrompt(
    String message, {
    String? meetingRoom,
    VoidCallback? onOpenApp,
  }) {
    _showOverlayBanner(
      message,
      backgroundColor: const Color(0xFF141A28),
      borderColor: const Color(0xFFD49B28),
      icon: Icons.screen_share_rounded,
      iconColor: const Color(0xFFD49B28),
      actionLabel: 'Open App',
      onAction: onOpenApp ?? () => AppStoreHelper.openAppOrStore(meetingRoom: meetingRoom),
      duration: const Duration(seconds: 8),
    );
  }

  /// Dismisses any active overlay toast.
  static void dismissActive() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    try {
      _activeOverlayEntry?.remove();
    } catch (_) {}
    _activeOverlayEntry = null;
  }

  /// Renders the banner on the root overlay so it floats strictly ABOVE all
  /// modal bottom sheets, dialogs, keyboards, and scaffolds.
  static void _showOverlayBanner(
    String text, {
    required Color backgroundColor,
    required Color borderColor,
    required IconData icon,
    required Color iconColor,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    try {
      final overlayState = rootNavigatorKey.currentState?.overlay;
      if (overlayState == null) {
        // Fallback to ScaffoldMessenger if overlay is not yet mounted
        _fallbackSnackBar(text, isError: borderColor == const Color(0xFFEF4444));
        return;
      }

      dismissActive();

      late final OverlayEntry entry;
      entry = OverlayEntry(
        builder: (ctx) => _ToastOverlayWidget(
          text: text,
          backgroundColor: backgroundColor,
          borderColor: borderColor,
          icon: icon,
          iconColor: iconColor,
          actionLabel: actionLabel,
          onAction: () {
            dismissActive();
            onAction?.call();
          },
          onDismiss: dismissActive,
        ),
      );

      _activeOverlayEntry = entry;
      overlayState.insert(entry);

      _dismissTimer = Timer(duration, () {
        dismissActive();
      });
    } catch (e) {
      debugPrint('[ToastUtils] Error rendering overlay banner: $e');
      _fallbackSnackBar(text, isError: borderColor == const Color(0xFFEF4444));
    }
  }

  static void _fallbackSnackBar(String text, {required bool isError}) {
    try {
      final messenger = rootScaffoldMessengerKey.currentState;
      if (messenger == null) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor:
              isError ? const Color(0xFFDC2626) : const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (_) {}
  }
}

class _ToastOverlayWidget extends StatefulWidget {
  final String text;
  final Color backgroundColor;
  final Color borderColor;
  final IconData icon;
  final Color iconColor;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  const _ToastOverlayWidget({
    required this.text,
    required this.backgroundColor,
    required this.borderColor,
    required this.icon,
    required this.iconColor,
    this.actionLabel,
    this.onAction,
    required this.onDismiss,
  });

  @override
  State<_ToastOverlayWidget> createState() => _ToastOverlayWidgetState();
}

class _ToastOverlayWidgetState extends State<_ToastOverlayWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _offsetAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _offsetAnim = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;

    return Positioned(
      top: topPadding + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Material(
            color: Colors.transparent,
            child: Dismissible(
              key: const Key('toast_overlay_dismissible'),
              direction: DismissDirection.up,
              onDismissed: (_) => widget.onDismiss(),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: widget.backgroundColor.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: widget.borderColor, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(widget.icon, color: widget.iconColor, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (widget.actionLabel != null && widget.onAction != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: widget.onAction,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          widget.actionLabel!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: widget.onDismiss,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
