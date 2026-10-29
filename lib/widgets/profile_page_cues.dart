import 'package:flutter/material.dart';

/// Persistent, accessible cues for horizontally paged profile forms.
class ProfilePageCues extends StatelessWidget {
  const ProfilePageCues({
    super.key,
    required this.index,
    required this.count,
    this.onPageSelected,
  });

  final int index;
  final int count;
  final ValueChanged<int>? onPageSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: 'Step ${index + 1} of $count',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(count, (page) {
                final isSelected = page == index;
                return GestureDetector(
                  onTap: onPageSelected != null ? () => onPageSelected!(page) : null,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    width: isSelected ? 28 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: isSelected ? colors.primary : colors.outline.withValues(alpha: 0.4),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.swipe_rounded, color: colors.onSurfaceVariant, size: 16),
              const SizedBox(width: 6),
              Text(
                index < count - 1 ? 'Swipe or tap next' : 'Step 3: Review & save',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
