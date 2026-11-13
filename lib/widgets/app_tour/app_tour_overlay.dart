import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/language_provider.dart';
import 'app_tour_models.dart';

/// Fullscreen interactive guided tour overlay with target spotlighting,
/// smooth animated cutouts, and localized step cards matching real app elements.
class AppTourOverlay extends ConsumerStatefulWidget {
  final VoidCallback onDismiss;

  const AppTourOverlay({
    super.key,
    required this.onDismiss,
  });

  @override
  ConsumerState<AppTourOverlay> createState() => _AppTourOverlayState();
}

class _AppTourOverlayState extends ConsumerState<AppTourOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _glowAnimation;
  late final Animation<double> _scaleAnimation;

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.35, end: 0.95).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _nextStep(int totalSteps) {
    if (_currentIndex < totalSteps - 1) {
      setState(() => _currentIndex++);
    } else {
      widget.onDismiss();
    }
  }

  void _previousStep() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  void _exploreRoute(String? route) {
    widget.onDismiss();
    if (route != null && mounted) {
      try {
        context.go(route);
      } catch (_) {}
    }
  }

  Offset _getTargetCenter(String targetArea, Size screenSize, double topPadding, double bottomPadding) {
    final width = screenSize.width;
    final height = screenSize.height;

    // Center Y coordinate of bottom navigation bar items:
    // In Flutter, BottomNavigationBar height is 56.0, situated directly above the bottom system inset.
    // Centering at height - bottomPadding - 32.0 perfectly frames both the icon and its label.
    final bottomNavY = height - bottomPadding - (bottomPadding > 0 ? 32.0 : 28.0);

    // Center Y coordinate of top app bar action icons:
    // The AppBar sits directly below the status bar / system top inset.
    // Action icons are centered vertically within the toolbar (kToolbarHeight = 56).
    final topBarY = topPadding + kToolbarHeight / 2;

    switch (targetArea) {
      case 'home':
        return Offset(width * 0.10, bottomNavY);
      case 'study':
        return Offset(width * 0.30, bottomNavY);
      case 'prayer':
        return Offset(width * 0.50, bottomNavY);
      case 'health':
        return Offset(width * 0.70, bottomNavY);
      case 'more':
      case 'conference':
        return Offset(width * 0.90, bottomNavY);
      case 'donations':
        // CompactDonationButton is the rightmost action (center at width - 24)
        return Offset(width - 24, topBarY);
      case 'language':
        // Language toggle is second from right (center at width - 72)
        return Offset(width - 72, topBarY);
      case 'theme':
        // Theme toggle is third from right (center at width - 120)
        return Offset(width - 120, topBarY);
      case 'news_feed':
        // News Feed bell/newspaper icon with unread badge (center at width - 168)
        return Offset(width - 168, topBarY);
      case 'my_study':
        // My Study bookmarks icon on Home header (center at width - 216)
        return Offset(width - 216, topBarY);
      case 'profile':
        // Profile pill with curved chevron on the top right of the Greeting Header.
        // Position: below app bar, inside the scrollable body content.
        // Y = top inset + app bar + body padding(16) + card padding(18) + date row(20) + spacer(14) + half name row(15)
        final profileY = topPadding + kToolbarHeight + 83.0;
        final profileX = width - 66.0;
        return Offset(profileX, profileY);
      default:
        return Offset(width * 0.10, bottomNavY);
    }
  }

  double _getTargetRadius(String targetArea) {
    switch (targetArea) {
      case 'donations':
      case 'language':
      case 'theme':
      case 'news_feed':
      case 'my_study':
        return 22.0;
      case 'profile':
        return 40.0;
      default:
        return 28.0; // Bottom nav tab circle spotlight
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final viewPadding = mediaQuery.viewPadding;
    final padding = mediaQuery.padding;

    // Safely query the native FlutterView insets directly from the engine.
    // Dialog and modal routes frequently strip MediaQuery padding, which would
    // miscalculate bottom navigation positions by up to 48px on Android devices.
    double windowBottomInset = 0.0;
    double windowTopInset = 0.0;
    try {
      final flutterView = View.of(context);
      final dpr = flutterView.devicePixelRatio;
      if (dpr > 0) {
        windowBottomInset = flutterView.padding.bottom / dpr;
        windowTopInset = flutterView.padding.top / dpr;
      }
    } catch (_) {}

    final effectiveTopPadding = [
      viewPadding.top,
      padding.top,
      windowTopInset,
    ].reduce((a, b) => a > b ? a : b);

    final effectiveBottomPadding = [
      viewPadding.bottom,
      padding.bottom,
      windowBottomInset,
    ].reduce((a, b) => a > b ? a : b);

    final locale = ref.watch(localeProvider);
    final langCode = locale.languageCode;

    final steps = AppTourSteps.getTourStepsForLanguage(langCode);
    final step = steps[_currentIndex];

    final targetCenter = _getTargetCenter(
      step.targetArea,
      screenSize,
      effectiveTopPadding,
      effectiveBottomPadding,
    );
    final targetRadius = _getTargetRadius(step.targetArea);
    final isProfileTarget = step.targetArea == 'profile';
    final isTopTarget = (step.targetArea == 'donations' ||
            step.targetArea == 'language' ||
            step.targetArea == 'theme' ||
            step.targetArea == 'news_feed' ||
            step.targetArea == 'my_study') &&
        !isProfileTarget;

    // Localized UI labels
    final skipLabel = {'yo': 'Kọjá', 'ha': 'Tsallake', 'ig': 'Gbanahụ'}[langCode] ?? 'Skip tour';
    final backLabel = {'yo': 'Ṣaájú', 'ha': 'Baya', 'ig': 'Azu'}[langCode] ?? 'Back';
    final nextLabel = _currentIndex == steps.length - 1
        ? ({'yo': 'Bẹ̀rẹ̀', 'ha': 'Fara', 'ig': 'Bido'}[langCode] ?? 'Get Started')
        : ({'yo': 'Tókàn', 'ha': 'Na gaba', 'ig': 'Osote'}[langCode] ?? 'Next');
    final stepBadgeText = {'yo': 'ÌGBÉSẸ̀', 'ha': 'MATAKI', 'ig': 'NZỌỤKWỤ'}[langCode] ?? 'STEP';
    final ofText = {'yo': 'NÍNÚ', 'ha': 'CIKIN', 'ig': 'NKE'}[langCode] ?? 'OF';

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 1. Dark Backdrop with Cutout Spotlight Hole over Target
          // Full-screen Spotlight Painter with high-contrast dual-theme visibility & interior illumination
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              return CustomPaint(
                size: screenSize,
                painter: _SpotlightPainter(
                  targetCenter: targetCenter,
                  targetRadius: targetRadius,
                  pulseScale: _scaleAnimation.value,
                  glowOpacity: _glowAnimation.value,
                  accentColor: step.accentColor,
                  isDark: Theme.of(context).brightness == Brightness.dark,
                ),
              );
            },
          ),

          // 2. Anchored Tour Modal Dialog (shifts down below profile spotlight so it is never obscured)
          Positioned(
            left: 16,
            right: 16,
            top: isProfileTarget
                ? (targetCenter.dy + targetRadius + 20)
                : (isTopTarget ? (effectiveTopPadding + kToolbarHeight + 12) : null),
            bottom: !isTopTarget && !isProfileTarget ? (effectiveBottomPadding + 68) : null,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: _buildTourModal(
                  context: context,
                  step: step,
                  currentIndex: _currentIndex,
                  totalSteps: steps.length,
                  skipLabel: skipLabel,
                  backLabel: backLabel,
                  nextLabel: nextLabel,
                  stepBadgeText: stepBadgeText,
                  ofText: ofText,
                  isTopTarget: isTopTarget,
                  onSkip: widget.onDismiss,
                  onBack: _previousStep,
                  onNext: () => _nextStep(steps.length),
                  onExplore: () => _exploreRoute(step.route),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTourModal({
    required BuildContext context,
    required AppTourStep step,
    required int currentIndex,
    required int totalSteps,
    required String skipLabel,
    required String backLabel,
    required String nextLabel,
    required String stepBadgeText,
    required String ofText,
    required bool isTopTarget,
    required VoidCallback onSkip,
    required VoidCallback onBack,
    required VoidCallback onNext,
    required VoidCallback onExplore,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141F2D), // Sleek dark slate
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: step.accentColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: step.accentColor.withValues(alpha: 0.2),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Accent Progress Strip
            ClipRRect(
              child: SizedBox(
                height: 3.5,
                child: LinearProgressIndicator(
                  value: (currentIndex + 1) / totalSteps,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(step.accentColor),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step Header Badge Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: step.accentColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: step.accentColor.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '$stepBadgeText ${currentIndex + 1} $ofText $totalSteps',
                          style: TextStyle(
                            color: step.accentColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      // Target Icon Badge
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: step.accentColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: step.buildIcon(
                            size: 16,
                            color: step.accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Title
                  Text(
                    step.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),

                  if (step.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      step.subtitle,
                      style: TextStyle(
                        color: step.accentColor.withValues(alpha: 0.95),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Description
                  Text(
                    step.description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),

                  // Highlights / Key capabilities
                  if (step.highlights.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: step.highlights.map((h) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.5),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Icon(
                                    Icons.check_circle_rounded,
                                    size: 13,
                                    color: step.accentColor,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    h,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.88),
                                      fontSize: 11.5,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Action Footer
                  Row(
                    children: [
                      // Skip Tour Text Button
                      TextButton(
                        onPressed: onSkip,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white60,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          skipLabel,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                        ),
                      ),

                      const Spacer(),

                      // Back Button (hidden on step 1)
                      if (currentIndex > 0) ...[
                        OutlinedButton(
                          onPressed: onBack,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            backLabel,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Next / Get Started Primary Button
                      FilledButton(
                        onPressed: onNext,
                        style: FilledButton.styleFrom(
                          backgroundColor: step.accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          nextLabel,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
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

/// Custom painter that creates a smooth dark backdrop over the screen while
/// carving out a crisp, illuminated spotlight hole with dual-theme contrast rings.
class _SpotlightPainter extends CustomPainter {
  final Offset targetCenter;
  final double targetRadius;
  final double pulseScale;
  final double glowOpacity;
  final Color accentColor;
  final bool isDark;

  _SpotlightPainter({
    required this.targetCenter,
    required this.targetRadius,
    required this.pulseScale,
    required this.glowOpacity,
    required this.accentColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final holeRadius = targetRadius * pulseScale;

    // 1. Vector difference cutout: punches out the circle from the background overlay.
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()
      ..addOval(Rect.fromCircle(center: targetCenter, radius: holeRadius));
    final cutoutPath =
        Path.combine(PathOperation.difference, backgroundPath, holePath);

    // Dark backdrop overlay: 88% opacity dark navy slate
    canvas.drawPath(
      cutoutPath,
      Paint()..color = const Color(0xE0060A10),
    );

    // 2. Interior Spotlight Illumination (Lens Beam):
    // In Dark Mode: Casts a radiant soft-white & accent beam from behind the icon so
    // dark icons are brightly lit, crisp, and 100% visible instead of being dark-on-dark.
    // In Light Mode: Casts a soft accent wash so the circular target stage stands out
    // clearly against light/white surfaces.
    final lensGradient = RadialGradient(
      colors: isDark
          ? [
              Colors.white.withValues(alpha: 0.35),
              accentColor.withValues(alpha: 0.22),
              Colors.transparent,
            ]
          : [
              accentColor.withValues(alpha: 0.24),
              accentColor.withValues(alpha: 0.10),
              Colors.transparent,
            ],
      stops: const [0.0, 0.72, 1.0],
    );
    final lensPaint = Paint()
      ..shader = lensGradient.createShader(
        Rect.fromCircle(center: targetCenter, radius: holeRadius),
      );
    canvas.drawCircle(targetCenter, holeRadius, lensPaint);

    // 3. Animated Expanding Ripple / Pulse Wave
    final pulseDelta = (pulseScale - 1.0).clamp(0.0, 0.15);
    final waveProgress = (pulseDelta / 0.08).clamp(0.0, 1.0);
    final pulseWaveRadius = holeRadius + (waveProgress * 18.0);
    final pulseWavePaint = Paint()
      ..color = accentColor.withValues(alpha: (1.0 - waveProgress) * 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(targetCenter, pulseWaveRadius, pulseWavePaint);

    // 4. Dark Drop-Shadow Underlay Stroke (Dual-Theme Contrast Anchor):
    // In Light Mode on white app bars, white borders disappear without this.
    // This dark stroke ensures the spotlight boundary is razor-sharp on white, dark, or colored backgrounds!
    final contrastShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: isDark ? 0.75 : 0.60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.2;
    canvas.drawCircle(targetCenter, holeRadius, contrastShadowPaint);

    // 5. Exterior Accent Glow
    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: glowOpacity * 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(targetCenter, holeRadius + 1.0, glowPaint);

    // 6. Vibrant Accent Color Ring
    final accentRingPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(targetCenter, holeRadius, accentRingPaint);

    // 7. Crisp High-Contrast Inner Edge
    final innerHighlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(targetCenter, holeRadius - 1.0, innerHighlightPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.targetCenter != targetCenter ||
        oldDelegate.targetRadius != targetRadius ||
        oldDelegate.pulseScale != pulseScale ||
        oldDelegate.glowOpacity != glowOpacity ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isDark != isDark;
  }
}
