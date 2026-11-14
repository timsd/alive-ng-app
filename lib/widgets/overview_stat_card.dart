import 'package:flutter/material.dart';

/// Shared stat overview box matching the Admin Dashboard System Overview style.
class OverviewStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool compact;
  final String? tooltip;

  const OverviewStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.compact = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double badgeSize = compact ? 26 : 32;
    final double iconSize = compact ? 14 : 16;
    final double valueFontSize = compact ? 15 : 18;
    final double titleFontSize = compact ? 8.5 : 10;

    final Widget valueText = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        value,
        style: TextStyle(
          fontSize: valueFontSize,
          fontWeight: FontWeight.w900,
          color: theme.colorScheme.onSurface,
          letterSpacing: -0.5,
          height: 1.1,
        ),
      ),
    );

    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 4, vertical: 6)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: badgeSize,
            height: badgeSize,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                icon,
                size: iconSize,
                color: color,
              ),
            ),
          ),
          SizedBox(height: compact ? 3 : 6),
          tooltip != null ? Tooltip(message: tooltip!, child: valueText) : valueText,
          SizedBox(height: compact ? 1 : 3),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
