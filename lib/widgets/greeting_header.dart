import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/appwrite_auth_provider.dart';

import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../utils/text_formatter.dart';
import '../utils/layout_fix_utils.dart';
import '../constants/app_constants.dart';
import 'custom_image.dart';

/// Clean, human-centered Greeting Header for ALIVE Nigeria.
/// Grounded in ministry brand colors, warm editorial typography,
/// and accessible layout without artificial decorative AI orbs.
class GreetingHeader extends ConsumerWidget {
  const GreetingHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final userProfile = ref.watch(currentUserProfileProvider).value;
    final avatarOverride = ref.watch(uploadedAvatarUrlProvider);
    final avatarUrl = avatarOverride != null
        ? (avatarOverride.trim().isEmpty ? null : avatarOverride.trim())
        : ((userProfile?.avatarUrl != null &&
                userProfile!.avatarUrl!.trim().isNotEmpty)
            ? userProfile.avatarUrl!.trim()
            : ((userProfile?.photoUrl != null &&
                    userProfile!.photoUrl!.trim().isNotEmpty)
                ? userProfile.photoUrl!.trim()
                : ((currentUser?.photoUrl != null &&
                        currentUser!.photoUrl!.trim().isNotEmpty)
                    ? currentUser.photoUrl!.trim()
                    : null)));
    final translate = ref.watch(translationProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hour = DateTime.now().hour;
    final greeting = _getGreeting(hour);
    final timeIcon = _getTimeIcon(hour);
    final userName = (userProfile?.fullName != null &&
            userProfile!.fullName!.trim().isNotEmpty)
        ? userProfile.fullName!.trim()
        : (currentUser?.displayName ??
            (currentUser?.email.split('@').first ?? ''));
    final initialLetter =
        userName.isNotEmpty ? userName[0].toUpperCase() : 'M';
    final formattedDate =
        DateFormat('EEEE, MMMM d').format(DateTime.now());

    // Authentic ALIVE brand colors
    final cardBg = isDark
        ? const Color(0xFF141F2D) // Deep elevated slate
        : Colors.white; // Clean warm white for light mode
    final onCard = isDark ? Colors.white : const Color(0xFF17263B);
    final secondaryText = isDark
        ? Colors.white.withValues(alpha: 0.75)
        : const Color(0xFF5B6B82);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE7E0D1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Date + Sign In (if guest)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      timeIcon,
                      size: 14,
                      color: const Color(0xFFD49B28), // Warm Gold
                    ),
                    const SizedBox(width: 6),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                if (currentUser == null)
                  InkWell(
                    onTap: () => context.push(AppConstants.authRoute),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.login_rounded,
                            size: 13,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Sign In",
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),

            // Middle row: Greeting & Name on left; Profile Avatar on right (Blue Circle position)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        greeting,
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentUser != null && userName.isNotEmpty
                            ? userName
                            : 'Welcome to ALIVE Nigeria',
                        style: TextStyle(
                          color: onCard,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (currentUser != null) ...[
                  const SizedBox(width: 16),
                  _GreetingProfilePill(
                    avatarUrl: avatarUrl,
                    initialLetter: initialLetter,
                    isDark: isDark,
                    secondaryText: secondaryText,
                    onTap: () => context.push(AppConstants.profileRoute),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // Bottom row: Subtitle
            Text(
              translate('continue_spiritual_journey'),
              style: TextStyle(
                color: secondaryText,
                fontSize: 13,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Guest call-to-action
            if (currentUser == null) ...[
              const SizedBox(height: 14),
              InkWell(
                onTap: () => context.go(AppConstants.authRoute),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5B94D), // Warm gold button
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LayoutFixUtils.responsiveText(
                        TextFormatter.formatText('join_us_in_spiritual_growth'),
                        context: context,
                        style: const TextStyle(
                          color: Color(0xFF1B365D),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: Color(0xFF1B365D),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getGreeting(int hour) {
    if (hour >= 5 && hour < 12) {
      return TextFormatter.formatText('good_morning');
    } else if (hour >= 12 && hour < 17) {
      return TextFormatter.formatText('good_afternoon');
    } else {
      return TextFormatter.formatText('good_evening');
    }
  }

  IconData _getTimeIcon(int hour) {
    if (hour >= 5 && hour < 12) {
      return Icons.wb_sunny_outlined;
    } else if (hour >= 12 && hour < 17) {
      return Icons.wb_sunny_rounded;
    } else {
      return Icons.nights_stay_outlined;
    }
  }
}

class _GreetingProfilePill extends StatefulWidget {
  final String? avatarUrl;
  final String initialLetter;
  final bool isDark;
  final Color secondaryText;
  final VoidCallback onTap;

  const _GreetingProfilePill({
    required this.avatarUrl,
    required this.initialLetter,
    required this.isDark,
    required this.secondaryText,
    required this.onTap,
  });

  @override
  State<_GreetingProfilePill> createState() => _GreetingProfilePillState();
}

class _GreetingProfilePillState extends State<_GreetingProfilePill> {
  bool _isHovered = false;
  bool _isPressed = false;

  bool get _isActive => _isHovered || _isPressed;

  @override
  Widget build(BuildContext context) {
    const goldColor = Color(0xFFD49B28);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.only(
            left: 4.0,
            top: 4.0,
            bottom: 4.0,
            right: 12.0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            color: _isActive
                ? (widget.isDark
                    ? const Color(0xFF1B2432)
                    : const Color(0xFFF3EBE0))
                : Colors.transparent,
            border: Border.all(
              color: _isActive
                  ? goldColor.withValues(alpha: 0.9)
                  : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: _isActive
                ? [
                    BoxShadow(
                      color: goldColor.withValues(
                          alpha: widget.isDark ? 0.28 : 0.18),
                      blurRadius: 10,
                      spreadRadius: 0.5,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar with gold border
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: goldColor,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                          alpha: widget.isDark ? 0.35 : 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: goldColor,
                  child: widget.avatarUrl != null
                      ? ClipOval(
                          child: CustomImage(
                            key: ValueKey(widget.avatarUrl),
                            imageUrl: widget.avatarUrl!,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            backgroundColor: goldColor,
                            placeholder: Center(
                              child: Text(
                                widget.initialLetter,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Text(
                          widget.initialLetter,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 4), // 4px spacing from reference measurement
              // Curved Chevron & Cutout Arc
              CustomPaint(
                size: const Size(22, 38),
                painter: _CurvedChevronPainter(
                  color: _isActive
                      ? goldColor
                      : widget.secondaryText.withValues(alpha: 0.8),
                  arcColor: _isActive
                      ? goldColor.withValues(alpha: 0.7)
                      : widget.secondaryText.withValues(alpha: 0.4),
                  strokeWidth: _isActive ? 2.6 : 2.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurvedChevronPainter extends CustomPainter {
  final Color color;
  final Color arcColor;
  final double strokeWidth;

  _CurvedChevronPainter({
    required this.color,
    required this.arcColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;

    // 1. Crescent accent arc concentric to the avatar's circular perimeter
    final arcPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final arcPath = Path();
    arcPath.moveTo(2.0, 4.0);
    arcPath.quadraticBezierTo(6.5, midY, 2.0, size.height - 4.0);
    canvas.drawPath(arcPath, arcPaint);

    // 2. Curved chevron arrow pointing right with curved wings following the circular contour
    final chevronPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final chevronPath = Path();
    final startX = 8.5;
    final apexX = size.width - 2.5;

    chevronPath.moveTo(startX, 6.0);
    chevronPath.quadraticBezierTo(startX + 3.2, midY * 0.65, apexX, midY);
    chevronPath.quadraticBezierTo(
        startX + 3.2, midY * 1.35, startX, size.height - 6.0);
    canvas.drawPath(chevronPath, chevronPaint);
  }

  @override
  bool shouldRepaint(covariant _CurvedChevronPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.arcColor != arcColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
