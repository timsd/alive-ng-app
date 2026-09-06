import 'package:flutter/material.dart';

class DonationTypeCard extends StatelessWidget {
  const DonationTypeCard({
    super.key,
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = isSelected ? colors.onPrimary : colors.onSurface;
    return Semantics(
      selected: isSelected,
      button: true,
      child: Material(
        color: isSelected ? colors.primary : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
              color: isSelected ? colors.primary : colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: foreground, size: 24),
                const SizedBox(height: 6),
                Text(title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: foreground)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
