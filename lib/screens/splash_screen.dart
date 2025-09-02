import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _glow;
  late Animation<double> _zoomOut;
  late Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2500),
    );

    _glow = Tween<double>(begin: 0.0, end: 20.0).animate(
      CurvedAnimation(
          parent: _ctrl, curve: Interval(0.0, 0.5, curve: Curves.easeInOut)),
    );

    _zoomOut = Tween<double>(begin: 1.0, end: 0.6).animate(
      CurvedAnimation(
          parent: _ctrl, curve: Interval(0.5, 1.0, curve: Curves.easeInOut)),
    );

    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
          parent: _ctrl, curve: Interval(0.7, 1.0, curve: Curves.easeIn)),
    );

    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        context.go(AppConstants.homeRoute);
      }
    });

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            return Transform.scale(
              scale: _zoomOut.value,
              child: Opacity(
                opacity: _fadeOut.value,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.7),
                        blurRadius: _glow.value,
                        spreadRadius: _glow.value / 4,
                      ),
                    ],
                  ),
                  child: SvgPicture.asset(
                    'assets/images/alive_logo.svg',
                    width: 200,
                    height: 200,
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
