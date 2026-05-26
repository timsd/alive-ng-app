import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import '../../utils/responsive_utils.dart';

class AnimatedSplashScreen extends StatefulWidget {
  final VoidCallback onAnimationComplete;

  const AnimatedSplashScreen({
    super.key,
    required this.onAnimationComplete,
  });

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _zoomController;
  late AnimationController _fadeController;
  late AnimationController _progressController;

  late Animation<double> _glowAnimation;
  late Animation<double> _zoomAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _progressAnimation;

  Timer? _animationTimer;
  Timer? _fadeStartTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimationSequence();
  }

  void _initializeAnimations() {
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );

    // Glow animation controller
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _zoomController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Fade animation controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 420),
      vsync: this,
    );

    // Glow animation (pulsing effect)
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    _zoomAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _zoomController,
      curve: Curves.easeInOut,
    ));

    // Fade animation
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
  }

  void _startAnimationSequence() {
    // Start glow animation immediately
    _glowController.repeat(reverse: true);
    _progressController.forward();

    _animationTimer = Timer(const Duration(milliseconds: 180), () {
      _zoomController.forward();

      // Start fade animation when zoom is almost complete
      _fadeStartTimer = Timer(const Duration(milliseconds: 520), () {
        _fadeController.forward().then((_) {
          if (mounted) {
            widget.onAnimationComplete();
          }
        });
      });
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _zoomController.dispose();
    _fadeController.dispose();
    _progressController.dispose();
    _animationTimer?.cancel();
    _fadeStartTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _glowAnimation,
          _zoomAnimation,
          _fadeAnimation,
          _progressAnimation,
        ]),
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Center(
              child: Transform.scale(
                scale: _zoomAnimation.value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 180.0,
                        tablet: 200.0,
                        desktop: 220.0,
                      ),
                      height: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 180.0,
                        tablet: 200.0,
                        desktop: 220.0,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(double.infinity, double.infinity),
                            painter: _GreenProgressRingPainter(
                                progress: _progressAnimation.value),
                          ),
                          SvgPicture.asset(
                            'assets/images/alive_logo.svg',
                            width: ResponsiveUtils.getResponsiveValue(
                              context: context,
                              mobile: 90.0,
                              tablet: 110.0,
                              desktop: 130.0,
                            ),
                            height: ResponsiveUtils.getResponsiveValue(
                              context: context,
                              mobile: 90.0,
                              tablet: 110.0,
                              desktop: 130.0,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(
                        height: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 24.0,
                      tablet: 30.0,
                      desktop: 36.0,
                    )),

                    // App Title
                    Text(
                      'ALIVE NG',
                      style: TextStyle(
                        fontSize: context.responsiveFontSize(36),
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF22C55E)
                            .withValues(alpha: _glowAnimation.value),
                        letterSpacing: 4,
                        shadows: [
                          Shadow(
                            color: const Color(0xFF22C55E)
                                .withValues(alpha: _glowAnimation.value * 0.5),
                            blurRadius: 10 * _glowAnimation.value,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(
                        height: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 8.0,
                      tablet: 10.0,
                      desktop: 12.0,
                    )),

                    Builder(builder: (context) {
                      const totalMs = 1600;
                      final remainingMs =
                          (totalMs - (_progressAnimation.value * totalMs))
                              .clamp(0, totalMs)
                              .toInt();
                      final remainingSec = (remainingMs / 1000).ceil();
                      return Text(
                        'Opening app in ${remainingSec}s...',
                        style: TextStyle(
                          fontSize: context.responsiveFontSize(14),
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: _glowAnimation.value * 0.7),
                          letterSpacing: 1,
                        ),
                        textAlign: TextAlign.center,
                      );
                    }),

                    SizedBox(
                        height: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 32.0,
                      tablet: 40.0,
                      desktop: 48.0,
                    )),

                    SizedBox(
                      width: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 24.0,
                        tablet: 30.0,
                        desktop: 36.0,
                      ),
                      height: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 24.0,
                        tablet: 30.0,
                        desktop: 36.0,
                      ),
                      child: CircularProgressIndicator(
                        strokeWidth: ResponsiveUtils.getResponsiveValue(
                          context: context,
                          mobile: 2.5,
                          tablet: 3.0,
                          desktop: 3.5,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color(0xFF22C55E)
                              .withValues(alpha: _glowAnimation.value),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GreenProgressRingPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  _GreenProgressRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 10;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = const Color(0xFFE5F9EF);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [Color(0xFF22C55E), Color(0xFF10B981), Color(0xFF22C55E)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    // Background track
    canvas.drawCircle(center, radius, track);

    // Progress arc from -90 degrees (top)
    final sweep = (progress.clamp(0.0, 1.0)) * 2 * 3.1415926535;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.1415926535 / 2,
      sweep,
      false,
      ring,
    );
  }

  @override
  bool shouldRepaint(covariant _GreenProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
