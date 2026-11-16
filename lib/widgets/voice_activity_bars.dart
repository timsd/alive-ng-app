import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Google Meet-style animated vertical voice activity bars.
///
/// * When [isActive] is `true`, the bars animate smoothly in proportion to
///   [level] (`0.0` to `1.0`, e.g. from `onSoundLevelChange` or VAD). When
///   [level] is `null`, an expressive speaking cadence is used.
/// * When [isActive] is `false` (silent or muted), the bars settle cleanly to
///   a flat baseline so it is immediately obvious no voice is being detected.
class VoiceActivityBars extends StatefulWidget {
  final bool isActive;
  final double? level;
  final int barCount;
  final Color? activeColor;
  final Color? inactiveColor;
  final double maxHeight;
  final double barWidth;
  final double spacing;

  const VoiceActivityBars({
    super.key,
    required this.isActive,
    this.level,
    this.barCount = 3,
    this.activeColor,
    this.inactiveColor,
    this.maxHeight = 16.0,
    this.barWidth = 3.0,
    this.spacing = 2.5,
  });

  @override
  State<VoiceActivityBars> createState() => _VoiceActivityBarsState();
}

class _VoiceActivityBarsState extends State<VoiceActivityBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant VoiceActivityBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = widget.activeColor ?? theme.colorScheme.primary;
    final inactiveColor = widget.inactiveColor ??
        theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45);
    final minHeight =
        math.max(widget.barWidth * 1.8, widget.maxHeight * 0.38);

    return SizedBox(
      height: widget.maxHeight,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value * 2 * math.pi;
          final amplitude = widget.level != null
              ? widget.level!.clamp(0.28, 1.0)
              : (widget.isActive ? 0.9 : 0.0);

          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(widget.barCount, (i) {
              // Symmetric Google Meet wave: center bars peak higher than edges.
              final center = (widget.barCount - 1) / 2.0;
              final distFromCenter = (i - center).abs();
              final centerWeight =
                  1.0 - (distFromCenter / (center + 1.0)) * 0.35;

              final wave = widget.isActive
                  ? (0.45 + 0.55 * ((math.sin(t + i * 1.35) + 1) / 2))
                  : 0.0;
              final targetFactor = widget.isActive
                  ? (wave * amplitude * centerWeight).clamp(0.18, 1.0)
                  : (0.25 * centerWeight);
              final height =
                  minHeight + (widget.maxHeight - minHeight) * targetFactor;

              return Padding(
                padding: EdgeInsets.only(
                  right: i == widget.barCount - 1 ? 0 : widget.spacing,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 90),
                  curve: Curves.easeOut,
                  width: widget.barWidth,
                  height: height,
                  decoration: BoxDecoration(
                    color: widget.isActive ? activeColor : inactiveColor,
                    borderRadius: BorderRadius.circular(widget.barWidth / 2),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
