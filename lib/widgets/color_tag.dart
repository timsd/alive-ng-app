import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

class ColorTag extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const ColorTag({
    super.key,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getResponsiveSpacing(context, 12),
          vertical: ResponsiveUtils.getResponsiveSpacing(context, 6),
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.getResponsiveSpacing(context, 12),
          ),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
