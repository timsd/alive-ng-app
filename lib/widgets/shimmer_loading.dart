import 'package:flutter/material.dart';

/// A premium shimmer placeholder used app-wide to replace bare
/// `CircularProgressIndicator` instances while data loads.
///
/// Renders a rounded rectangle with a smooth, sweeping gradient animation
/// that suggests content is on its way — the industry-standard "skeleton
/// screen" pattern that communicates responsiveness.
class ShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const ShimmerLoading({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
    this.margin,
  });

  /// Convenience constructor for a circular shimmer (avatar placeholder).
  const ShimmerLoading.circle({
    super.key,
    required double size,
    this.margin,
  })  : width = size,
        height = size,
        borderRadius = 9999;

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final baseColor = isDark
        ? theme.colorScheme.surfaceContainerHigh
        : theme.colorScheme.surfaceContainerHighest;

    return FadeTransition(
      opacity: _opacityAnimation,
      child: Container(
        width: widget.width,
        height: widget.height,
        margin: widget.margin,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

/// A complete skeleton layout for the admin dashboard, shown while
/// stats are being fetched.
class AdminDashboardSkeleton extends StatelessWidget {
  const AdminDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero banner skeleton
          const ShimmerLoading(height: 100, borderRadius: 20),
          const SizedBox(height: 24),
          // Stat cards row
          Row(
            children: List.generate(
              4,
              (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                  child: const ShimmerLoading(height: 100, borderRadius: 16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Section title
          const ShimmerLoading(width: 180, height: 22, borderRadius: 6),
          const SizedBox(height: 16),
          // Action tiles
          ...List.generate(
            6,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const ShimmerLoading(width: 44, height: 44, borderRadius: 10),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        ShimmerLoading(height: 16, borderRadius: 4),
                        SizedBox(height: 6),
                        ShimmerLoading(height: 12, borderRadius: 4, width: 200),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A complete skeleton layout for the user home screen, shown while auth
/// or initial data is loading.
class HomeScreenSkeleton extends StatelessWidget {
  const HomeScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting header skeleton
          const ShimmerLoading(height: 140, borderRadius: 16),
          const SizedBox(height: 20),
          // Section title
          const ShimmerLoading(width: 140, height: 22, borderRadius: 6),
          const SizedBox(height: 12),
          // Daily verse card skeleton
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const ShimmerLoading(width: 36, height: 36, borderRadius: 8),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        ShimmerLoading(width: 100, height: 16, borderRadius: 4),
                        SizedBox(height: 4),
                        ShimmerLoading(width: 150, height: 12, borderRadius: 4),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const ShimmerLoading(height: 16, borderRadius: 4),
                const SizedBox(height: 8),
                const ShimmerLoading(height: 16, borderRadius: 4),
                const SizedBox(height: 8),
                const ShimmerLoading(width: 220, height: 16, borderRadius: 4),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: const [
                    ShimmerLoading(width: 36, height: 36, borderRadius: 18),
                    SizedBox(width: 8),
                    ShimmerLoading(width: 36, height: 36, borderRadius: 18),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Quick actions title
          const ShimmerLoading(width: 130, height: 22, borderRadius: 6),
          const SizedBox(height: 12),
          // Quick actions 2x2 grid skeleton
          Row(
            children: const [
              Expanded(child: ShimmerLoading(height: 100, borderRadius: 16)),
              SizedBox(width: 12),
              Expanded(child: ShimmerLoading(height: 100, borderRadius: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(child: ShimmerLoading(height: 100, borderRadius: 16)),
              SizedBox(width: 12),
              Expanded(child: ShimmerLoading(height: 100, borderRadius: 16)),
            ],
          ),
        ],
      ),
    );
  }
}
