import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../utils/responsive_utils.dart';
import '../providers/language_provider.dart';

class DonationButton extends ConsumerWidget {
  final bool isFloating;
  final bool isCompact;
  final VoidCallback? onPressed;

  const DonationButton({
    super.key,
    this.isFloating = false,
    this.isCompact = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translate = ref.watch(translationProvider);

    if (isFloating) {
      return FloatingActionButton.extended(
        onPressed: onPressed ?? () => _handleDonationTap(context),
        icon: const Icon(Icons.favorite_border),
        label: Text(
          translate('support_alive'),
          style: TextStyle(
            fontSize: ResponsiveUtils.getResponsiveFontSize(context, 14),
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      );
    }

    if (isCompact) {
      // Use IconButton to inherit AppBar's IconTheme for proper contrast
      return IconButton(
        icon: const Icon(Icons.volunteer_activism),
        tooltip: translate('support_alive'),
        onPressed: onPressed ?? () => _handleDonationTap(context),
      );
    }

    return ElevatedButton.icon(
      onPressed: onPressed ?? () => _handleDonationTap(context),
      icon: const Icon(Icons.favorite_border),
      label: Text(
        translate('support_alive'),
        style: TextStyle(
          fontSize: ResponsiveUtils.getResponsiveFontSize(context, 14),
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getResponsiveSpacing(context, 16),
          vertical: ResponsiveUtils.getResponsiveSpacing(context, 12),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.getResponsiveBorderRadiusValue(context, 8),
          ),
        ),
      ),
    );
  }

  void _handleDonationTap(BuildContext context) {
    // Navigate to donation screen
    context.go('/donation');
  }
}

class DonationFab extends ConsumerWidget {
  const DonationFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const DonationButton(isFloating: true);
  }
}

class CompactDonationButton extends ConsumerWidget {
  final VoidCallback? onPressed;

  const CompactDonationButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DonationButton(isCompact: true, onPressed: onPressed);
  }
}
