import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';

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

  late Animation<double> _glowAnimation;
  late Animation<double> _zoomAnimation;
  late Animation<double> _fadeAnimation;

  Timer? _animationTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimationSequence();
  }

  void _initializeAnimations() {
    // Glow animation controller
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Zoom animation controller
    _zoomController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Fade animation controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
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

    // Zoom animation (scale up then scale down)
    _zoomAnimation = Tween<double>(
      begin: 0.5,
      end: 3.0,
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
  }

  void _startAnimationSequence() {
    // Start glow animation immediately
    _glowController.repeat(reverse: true);

    // Start zoom animation after 1 second
    _animationTimer = Timer(const Duration(milliseconds: 1000), () {
      _zoomController.forward();

      // Start fade animation when zoom is almost complete
      Timer(const Duration(milliseconds: 1500), () {
        _fadeController.forward().then((_) {
          widget.onAnimationComplete();
        });
      });
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _zoomController.dispose();
    _fadeController.dispose();
    _animationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _glowAnimation,
          _zoomAnimation,
          _fadeAnimation,
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
                    // Animated Logo
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green
                                .withValues(alpha: _glowAnimation.value * 0.6),
                            blurRadius: 20 * _glowAnimation.value,
                            spreadRadius: 5 * _glowAnimation.value,
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          SvgPicture.asset(
                            'assets/images/alive_logo.svg',
                            width: 150,
                            height: 150,
                            colorFilter: ColorFilter.mode(
                              Colors.green.withValues(alpha: _glowAnimation.value),
                              BlendMode.modulate,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // App Title
                    Text(
                      'ALIVE',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.green
                            .withValues(alpha: _glowAnimation.value),
                        letterSpacing: 4,
                        shadows: [
                          Shadow(
                            color: Colors.green
                                .withValues(alpha: _glowAnimation.value * 0.5),
                            blurRadius: 10 * _glowAnimation.value,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Subtitle
                    Text(
                      'Africans Living In View of Eternity',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            Colors.grey.withValues(alpha: _glowAnimation.value),
                        letterSpacing: 1,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 40),

                    // Loading indicator
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.green.withValues(alpha: _glowAnimation.value),
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




