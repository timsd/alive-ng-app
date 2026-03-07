import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../utils/text_formatter.dart';
import '../utils/layout_fix_utils.dart';
import '../constants/app_constants.dart';

class GreetingHeader extends ConsumerWidget {
  const GreetingHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final translate = ref.watch(translationProvider);

    final greeting = _getGreeting(translate);
    final userName = currentUser?.displayName ??
        currentUser?.email?.split('@').first ??
        'Friend';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutFixUtils.responsiveText(
                      greeting,
                      context: context,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9),
                          ),
                    ),
                    const SizedBox(height: 4),
                    LayoutFixUtils.responsiveText(
                      currentUser != null ? userName : TextFormatter.formatText('welcome'),
                      context: context,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getTimeBasedIcon(),
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutFixUtils.responsiveText(
            translate('continue_spiritual_journey'),
            context: context,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8),
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: currentUser == null
                ? () {
                    context.go(AppConstants.authRoute);
                  }
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.group_add,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  LayoutFixUtils.responsiveText(
                    TextFormatter.formatText('join_us_in_spiritual_growth'),
                    context: context,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: LayoutFixUtils.responsiveText(
                      currentUser == null ? 'Join' : 'Member',
                      context: context,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSecondary,
                        fontWeight: FontWeight.bold,
                      ),
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

  String _getGreeting(String Function(String) translate) {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return TextFormatter.formatText('good_morning');
    } else if (hour < 17) {
      return TextFormatter.formatText('good_afternoon');
    } else {
      return TextFormatter.formatText('good_evening');
    }
  }

  IconData _getTimeBasedIcon() {
    final hour = DateTime.now().hour;

    if (hour >= 6 && hour < 18) {
      // Daytime: 6 AM to 6 PM - show sun
      return Icons.wb_sunny;
    } else {
      // Nighttime: 6 PM to 6 AM - show moon
      return Icons.nightlight_round;
    }
  }
}




