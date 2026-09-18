import 'package:flutter/material.dart';

/// Persistent, accessible cues for horizontally paged profile forms.
class ProfilePageCues extends StatelessWidget {
  const ProfilePageCues({super.key, required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: 'Step ${index + 1} of $count',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(count, (page) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: page == index ? 24 : 10,
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: page == index ? colors.primary : colors.outline,
                ),
              )),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.swipe, color: colors.onSurfaceVariant, size: 20),
              const SizedBox(width: 8),
              Flexible(child: Text(
                index < count - 1 ? 'Swipe to next or tap Next' : 'Swipe back to review',
                style: TextStyle(color: colors.onSurfaceVariant),
              )),
            ],
          ),
        ],
      ),
    );
  }
}
