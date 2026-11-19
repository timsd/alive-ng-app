import 'dart:math' as math;
import 'package:flutter/material.dart';

class StarAnimationWidget extends StatefulWidget {
  final bool showAnimation;
  final VoidCallback? onAnimationComplete;
  final int starCount;
  final Duration duration;
  final Color starColor;
  final double starSize;

  const StarAnimationWidget({
    super.key,
    required this.showAnimation,
    this.onAnimationComplete,
    this.starCount = 5,
    this.duration = const Duration(milliseconds: 2000),
    this.starColor = Colors.amber,
    this.starSize = 30.0,
  });

  @override
  State<StarAnimationWidget> createState() => _StarAnimationWidgetState();
}

class _StarAnimationWidgetState extends State<StarAnimationWidget>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _scaleAnimations;
  late List<Animation<double>> _opacityAnimations;
  late List<Animation<Offset>> _positionAnimations;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _controllers = List.generate(
      widget.starCount,
      (index) => AnimationController(
        duration: widget.duration,
        vsync: this,
      ),
    );

    _scaleAnimations = _controllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
        ),
      );
    }).toList();

    _opacityAnimations = _controllers.map((controller) {
      return Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
        ),
      );
    }).toList();

    _positionAnimations = _controllers.asMap().entries.map((entry) {
      final index = entry.key;
      final controller = entry.value;
      // final angle = (index * 2 * 3.14159) / widget.starCount; // Unused variable removed
      return Tween<Offset>(
        begin: Offset.zero,
        end: Offset(
          50 * (index % 2 == 0 ? 1 : -1) * (index + 1) / widget.starCount,
          -50 * (index + 1) / widget.starCount,
        ),
      ).animate(
        CurvedAnimation(
          parent: controller,
          curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
        ),
      );
    }).toList();

    // Add listener to the last controller to trigger completion callback
    if (_controllers.isNotEmpty) {
      _controllers.last.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onAnimationComplete?.call();
        }
      });
    }
  }

  @override
  void didUpdateWidget(StarAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showAnimation && !oldWidget.showAnimation) {
      _startAnimation();
    } else if (!widget.showAnimation && oldWidget.showAnimation) {
      _resetAnimation();
    }
  }

  void _startAnimation() {
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (mounted) {
          _controllers[i].forward();
        }
      });
    }
  }

  void _resetAnimation() {
    for (final controller in _controllers) {
      controller.reset();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showAnimation) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          alignment: Alignment.center,
          children: List.generate(widget.starCount, (index) {
            return AnimatedBuilder(
              animation: _controllers[index],
              builder: (context, child) {
                return Transform.translate(
                  offset: _positionAnimations[index].value,
                  child: Transform.scale(
                    scale: _scaleAnimations[index].value,
                    child: Opacity(
                      opacity: _opacityAnimations[index].value,
                      child: Icon(
                        Icons.star,
                        size: widget.starSize,
                        color: widget.starColor,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}

// Celebration overlay widget for instant, crisp, celebratory feedback
class CelebrationOverlay extends StatefulWidget {
  final bool show;
  final VoidCallback? onComplete;
  final String? message;

  const CelebrationOverlay({
    super.key,
    required this.show,
    this.onComplete,
    this.message,
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _inOpacityAnimation;
  late Animation<double> _outOpacityAnimation;

  @override
  void initState() {
    super.initState();
    // Fast, snappy duration (1050ms total) so it never collides with the next action
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1050),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.2, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.85)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_controller);

    _inOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.15, curve: Curves.easeOut),
      ),
    );

    _outOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.78, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });

    if (widget.show) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(CelebrationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show && !oldWidget.show) {
      _controller.forward(from: 0.0);
    } else if (!widget.show && oldWidget.show) {
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.show) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final opacity =
              _inOpacityAnimation.value * _outOpacityAnimation.value;
          final progress = _controller.value;

          return IgnorePointer(
            child: Container(
              color: Colors.black.withValues(alpha: 0.35 * opacity),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Fast radial burst sparkles around the badge
                  ...List.generate(10, (index) {
                    final angle = (index * 2 * 3.14159) / 10;
                    final distance = 70.0 + 85.0 * progress;
                    final dx = distance * math.cos(angle);
                    final dy = distance * math.sin(angle);
                    final starScale = (1.0 - progress).clamp(0.0, 1.0);

                    return Transform.translate(
                      offset: Offset(dx, dy),
                      child: Opacity(
                        opacity: (opacity * (1.0 - progress)).clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: starScale,
                          child: Icon(
                            index % 2 == 0
                                ? Icons.star_rounded
                                : Icons.auto_awesome,
                            color: [
                              const Color(0xFFFFD700),
                              const Color(0xFF69F0AE),
                              const Color(0xFFFFE082),
                            ][index % 3],
                            size: 20.0 + (index % 3) * 6,
                          ),
                        ),
                      ),
                    );
                  }),

                  // Central Hero Celebration Badge
                  Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 28),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 22),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF0F2618),
                              Color(0xFF1B3D2A),
                              Color(0xFF142E1F),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: const Color(0xFFFFD700),
                            width: 2.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD700)
                                  .withValues(alpha: 0.45 * opacity),
                              blurRadius: 28,
                              spreadRadius: 4,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 3 Shimmering Stars Header
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  color: const Color(0xFFFFD700)
                                      .withValues(alpha: 0.85),
                                  size: 26,
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFFFD700),
                                  size: 38,
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.star_rounded,
                                  color: const Color(0xFFFFD700)
                                      .withValues(alpha: 0.85),
                                  size: 26,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Word Perfect Text
                            const Text(
                              'WORD PERFECT!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFFD700),
                                letterSpacing: 1.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black87,
                                    offset: Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Pill Badge for Well Done / Points
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF10B981),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF69F0AE),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.message?.replaceAll('\n', ' • ') ??
                                        'Well Done!',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFE8F5E9),
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}



