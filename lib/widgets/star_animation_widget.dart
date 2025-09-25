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

// Celebration overlay widget for full-screen star burst
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
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });
  }

  @override
  void didUpdateWidget(CelebrationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show && !oldWidget.show) {
      _controller.forward();
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
          return Container(
            color: Colors.black.withValues(alpha: 0.3 * _fadeAnimation.value),
            child: Stack(
              children: [
                // Multiple star animations at different positions
                ...List.generate(15, (index) {
                  final random = (index * 37) % 100; // Pseudo-random positioning
                  return Positioned(
                    left: (random % 80 + 10).toDouble() * MediaQuery.of(context).size.width / 100,
                    top: ((random * 7) % 60 + 20).toDouble() * MediaQuery.of(context).size.height / 100,
                    child: StarAnimationWidget(
                      showAnimation: widget.show,
                      starCount: 1,
                      duration: Duration(milliseconds: 1500 + (index * 100)),
                      starColor: [Colors.amber, Colors.yellow, Colors.orange][index % 3],
                      starSize: 20.0 + (index % 3) * 10,
                    ),
                  );
                }),
                // Congratulations message
                if (widget.message != null)
                  Center(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.celebration,
                              size: 50,
                              color: Colors.amber,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.message!,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}