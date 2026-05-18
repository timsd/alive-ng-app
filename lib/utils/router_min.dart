import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/appwrite_auth_service.dart';
import '../screens/navigation/main_navigation_screen.dart';

// keep minimal to avoid heavy imports on web
class MinimalHome extends StatefulWidget {
  const MinimalHome({super.key});
  @override
  State<MinimalHome> createState() => _MinimalHomeState();
}

class _MinimalHomeState extends State<MinimalHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('MinimalHome first frame');
    });
  }

  @override
  Widget build(BuildContext context) {
    scheduleMicrotask(() {
      debugPrint('MinimalHome build microtask');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('MinimalHome first frame');
    });
    final bg = Theme.of(context).brightness == Brightness.dark
        ? const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: bg),
          ),
        ),
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.85, end: 1.0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: 1.0,
                child: Transform.scale(
                  scale: scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'ALIVE-NG APP',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Preparing your web experience…',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ),
                      const SizedBox(height: 18),
                      CustomPaint(
                        size: const Size(180, 180),
                        painter: _GreenCirclePainter(),
                      ),
                      const SizedBox(height: 22),
                      const _LoadingDots(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GreenCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 8;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..shader = const SweepGradient(
        colors: [Color(0xFF22C55E), Color(0xFF10B981), Color(0xFF22C55E)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    final fill = Paint()..color = const Color(0xFFEFFDF5);
    canvas.drawCircle(center, radius - 12, fill);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -0.5,
      5.5,
      false,
      ring,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MinimalSplash extends StatefulWidget {
  const MinimalSplash({super.key});
  @override
  State<MinimalSplash> createState() => _MinimalSplashState();
}

class _MinimalSplashState extends State<MinimalSplash> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('MinimalSplash first frame');
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        try {
          GoRouter.of(context).go('/home');
        } catch (_) {}
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    scheduleMicrotask(() {
      debugPrint('MinimalSplash build microtask');
    });
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    scheme.primary.withValues(alpha: 0.08),
                    scheme.secondary.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Launching…',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MinimalAuth extends StatefulWidget {
  const MinimalAuth({super.key});
  @override
  State<MinimalAuth> createState() => _MinimalAuthState();
}

class _MinimalAuthState extends State<MinimalAuth> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('MinimalAuth first frame');
    });
  }

  @override
  Widget build(BuildContext context) {
    scheduleMicrotask(() {
      debugPrint('MinimalAuth build microtask');
    });
    return const Scaffold(
      body: Center(child: Text('Minimal Auth')),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  debugPrint('Minimal router: constructing GoRouter (with ShellRoute)');
  final router = GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      try {
        final p = state.uri.path;
        final user = ref.watch(appwriteUserProvider);
        final isAuthenticated = user != null;
        final isAuthRoute = p == '/auth';
        if (!isAuthenticated &&
            !isAuthRoute &&
            p != '/home' &&
            p != '/splash') {
          debugPrint('Minimal router: unauthenticated -> redirect to /auth');
          return '/auth';
        }
        if (isAuthenticated && isAuthRoute) {
          debugPrint('Minimal router: authenticated on /auth -> /home');
          return '/home';
        }
      } catch (_) {}
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) {
          debugPrint('Minimal router: building /splash');
          return const MinimalSplash();
        },
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) {
          debugPrint('Minimal router: building /auth');
          return const MinimalAuth();
        },
      ),
      ShellRoute(
        builder: (context, state, child) {
          debugPrint('Minimal router: ShellRoute builder -> ${state.uri.path}');
          return MainNavigationScreen(child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) {
              debugPrint('Minimal router: building /home');
              return const Scaffold(body: MinimalHome());
            },
          ),
        ],
      ),
    ],
  );
  scheduleMicrotask(() {
    debugPrint('Minimal router: constructed (microtask)');
  });
  return router;
});

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor =
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.25);
    final activeColor = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: 64,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = _c.value;
          Color dot(int i) =>
              (v * 3).floor() % 3 == i ? activeColor : baseColor;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _dot(dot(0)),
              _dot(dot(1)),
              _dot(dot(2)),
            ],
          );
        },
      ),
    );
  }

  Widget _dot(Color c) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
  }
}
