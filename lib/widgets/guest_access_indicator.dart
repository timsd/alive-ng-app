import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/guest_provider.dart';
import '../constants/app_constants.dart';

/// Widget that shows prompts for guest users to encourage account creation
class GuestAccessIndicator extends ConsumerWidget {
  final String featureName;
  final String description;
  final Widget? child;
  final bool showAsCard;

  const GuestAccessIndicator({
    super.key,
    required this.featureName,
    required this.description,
    this.child,
    this.showAsCard = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(isGuestModeProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    // Don't show indicator if user is authenticated
    if (isAuthenticated) {
      return child ?? const SizedBox.shrink();
    }

    // Show indicator for guest users
    if (isGuest) {
      if (showAsCard) {
        return _buildCard(context);
      } else {
        return _buildBanner(context);
      }
    }

    return child ?? const SizedBox.shrink();
  }

  Widget _buildCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Unlock $featureName',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Continue as guest - show child if available
                    },
                    child: const Text('Continue as Guest'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      context.go(AppConstants.authRoute);
                    },
                    child: const Text('Sign Up'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sign up to unlock $featureName',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              context.go(AppConstants.authRoute);
            },
            child: const Text('Sign Up'),
          ),
        ],
      ),
    );
  }
}

/// A wrapper widget that shows guest access prompts for protected features
class GuestProtectedFeature extends ConsumerWidget {
  final Widget child;
  final String featureName;
  final String description;
  final bool allowGuestAccess;

  const GuestProtectedFeature({
    super.key,
    required this.child,
    required this.featureName,
    required this.description,
    this.allowGuestAccess = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(isGuestModeProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    // Show child if user is authenticated
    if (isAuthenticated) {
      return child;
    }

    // Show child if guest access is allowed
    if (isGuest && allowGuestAccess) {
      return child;
    }

    // Show access prompt for protected features
    return GuestAccessIndicator(
      featureName: featureName,
      description: description,
    );
  }
}
