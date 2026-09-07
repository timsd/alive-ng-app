import 'dart:math';
import 'package:flutter/material.dart';
import 'alive_mark_data.dart';

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
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    // Warm up the parsed paths & centers
    AliveMarkData.prewarm();

    // Total animation time plus a short 350ms hold
    const totalDuration = Duration(
      milliseconds: AliveMarkConstants.totalAnimMs + 350,
    );

    _controller = AnimationController(
      vsync: this,
      duration: totalDuration,
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _finish();
      }
    });
  }

  void _finish() {
    if (_completed) return;
    _completed = true;
    if (mounted) {
      widget.onAnimationComplete();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111827) : const Color(0xFFF7F8F4);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Modestly scaled, perfectly centered animation (~48% width, max 260)
              final stageSize = min(
                constraints.maxWidth * 0.48,
                min(constraints.maxHeight * 0.45, 260.0),
              );

              return SizedBox(
                width: stageSize,
                height: stageSize,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return CustomPaint(
                      size: Size(stageSize, stageSize),
                      painter: _AliveMarkPainter(
                        animationValue: _controller.value,
                        isDark: isDark,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AliveMarkPainter extends CustomPainter {
  final double animationValue;
  final bool isDark;

  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  final Paint _glowPaint = Paint()
    ..style = PaintingStyle.fill
    ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 8.0);

  _AliveMarkPainter({
    required this.animationValue,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Stage coordinates in SVG are 3600 x 3600
    const svgSize = 3600.0;
    final scale = size.width / svgSize;

    canvas.save();
    canvas.scale(scale, scale);

    // Current time in ms relative to AliveMarkConstants.totalAnimMs
    final currentMs = animationValue * AliveMarkConstants.totalAnimMs;

    // 1. Draw Map Squares
    for (final sq in AliveMarkData.squares) {
      final elapsed = currentMs - sq.delayMs;
      if (elapsed < 0) continue;

      final progressRatio = (elapsed / sq.durationMs).clamp(0.0, 1.0);

      // Keyframes:
      // 0% -> opacity:0, scale:0.4
      // 12% -> opacity:1.0
      // 38% -> scale:1.12 with bright glow
      // 68% -> scale:0.97
      // 100% -> opacity:1.0, scale:1.0
      double opacity;
      if (progressRatio < 0.12) {
        opacity = progressRatio / 0.12;
      } else {
        opacity = 1.0;
      }

      double scaleFactor;
      if (progressRatio <= 0.38) {
        final t = progressRatio / 0.38;
        scaleFactor = 0.4 + (1.12 - 0.4) * Curves.easeOutCubic.transform(t);
      } else if (progressRatio <= 0.68) {
        final t = (progressRatio - 0.38) / 0.30;
        scaleFactor = 1.12 - (1.12 - 0.97) * Curves.easeInOut.transform(t);
      } else {
        final t = (progressRatio - 0.68) / 0.32;
        scaleFactor = 0.97 + (1.0 - 0.97) * Curves.easeOut.transform(t);
      }

      final center = sq.center;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(scaleFactor, scaleFactor);
      canvas.translate(-center.dx, -center.dy);

      _fillPaint.color = sq.color.withValues(alpha: opacity);
      canvas.drawPath(sq.path, _fillPaint);

      // Peak glow effect
      if (progressRatio > 0.15 && progressRatio < 0.65) {
        final glowT =
            1.0 - ((progressRatio - 0.38).abs() / 0.25).clamp(0.0, 1.0);
        if (glowT > 0.05) {
          _glowPaint.color = const Color(0xFF8CFF3C)
              .withValues(alpha: (0.45 * glowT * opacity).clamp(0.0, 1.0));
          canvas.drawPath(sq.path, _glowPaint);
        }
      }

      canvas.restore();
    }

    // 2. Draw ALIVE wordmark glyphs
    for (final glyph in AliveMarkData.aliveGlyphs) {
      final elapsed = currentMs - glyph.delayMs;
      if (elapsed < 0) continue;

      final progressRatio = (elapsed / glyph.durationMs).clamp(0.0, 1.0);

      double opacity;
      double translateY;
      double scaleFactor;

      if (progressRatio <= 0.55) {
        final t = progressRatio / 0.55;
        final curveT = Curves.easeOutCubic.transform(t);
        opacity = curveT;
        translateY = 14.0 - (16.0 * curveT); // 14 -> -2
        scaleFactor = 0.94 + (0.075 * curveT); // 0.94 -> 1.015
      } else {
        final t = (progressRatio - 0.55) / 0.45;
        final curveT = Curves.easeInOut.transform(t);
        opacity = 1.0;
        translateY = -2.0 + (2.0 * curveT); // -2 -> 0
        scaleFactor = 1.015 - (0.015 * curveT); // 1.015 -> 1.0
      }

      final center = glyph.center;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(scaleFactor, scaleFactor);
      canvas.translate(0, translateY);
      canvas.translate(-center.dx, -center.dy);

      _fillPaint.color = glyph.color.withValues(alpha: opacity);
      canvas.drawPath(glyph.path, _fillPaint);
      canvas.restore();
    }

    // 3. Draw Nigeria wordmark glyphs
    for (final glyph in AliveMarkData.nigeriaGlyphs) {
      final elapsed = currentMs - glyph.delayMs;
      if (elapsed < 0) continue;

      final progressRatio = (elapsed / glyph.durationMs).clamp(0.0, 1.0);
      final curveT = Curves.easeOutCubic.transform(progressRatio);
      final opacity = curveT;
      final translateY = 10.0 * (1.0 - curveT);

      final center = glyph.center;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.translate(0, translateY);
      canvas.translate(-center.dx, -center.dy);

      final color = isDark ? Colors.white : glyph.color;
      _fillPaint.color = color.withValues(alpha: opacity);
      canvas.drawPath(glyph.path, _fillPaint);
      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AliveMarkPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isDark != isDark;
  }
}
