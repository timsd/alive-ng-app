import 'package:flutter/material.dart';

class GivingMethodRow extends StatelessWidget {
  const GivingMethodRow({
    super.key,
    required this.onNonMonetary,
    required this.onGiftInKind,
    required this.onProjects,
  });

  final VoidCallback onNonMonetary;
  final VoidCallback onGiftInKind;
  final VoidCallback onProjects;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth < 320 ? 1 : 3;
      final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          SizedBox(width: width, child: _GivingMethod(
            title: 'Non-Monetary', icon: Icons.volunteer_activism, onTap: onNonMonetary)),
          SizedBox(width: width, child: _GivingMethod(
            title: 'Gift in Kind', icon: Icons.card_giftcard, onTap: onGiftInKind)),
          SizedBox(width: width, child: _GivingMethod(
            title: 'Active Projects', icon: Icons.folder_special, onTap: onProjects)),
        ],
      );
    });
  }
}

class _GivingMethod extends StatelessWidget {
  const _GivingMethod({required this.title, required this.icon, required this.onTap});
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 6),
          Text(title, textAlign: TextAlign.center, style: theme.textTheme.labelLarge),
        ],
      ),
    );
  }
}

