import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/guest_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/greeting_header.dart';
import '../../widgets/quick_actions_grid.dart';
import '../../widgets/daily_verse_card.dart';
import '../../widgets/role_guard.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/layout_fix_utils.dart';
import '../../screens/daily/daily_screen.dart';
import '../../widgets/custom_app_bar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final isGuest = ref.watch(isGuestModeProvider);
    final translate = ref.watch(translationProvider);

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Home',
        // Actions include language, theme, and support automatically
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: authState.when(
        data: (user) =>
            _buildHomeContent(context, ref, user, isGuest, translate),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LayoutFixUtils.responsiveIcon(
                Icons.error,
                context: context,
                baseSize: 64,
                color: Colors.red,
              ),
              SizedBox(height: context.isMobile ? 12 : 16),
              Text(
                'Error: $error',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, 16),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeContent(BuildContext context, WidgetRef ref, user,
      bool isGuest, Function translate) {
    final dailyVerseAsync = ref.watch(dailyVerseProvider);

    return SingleChildScrollView(
      padding: ResponsiveUtils.getResponsivePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting Header
          const GreetingHeader(),
          SizedBox(height: context.isMobile ? 16 : 24),

          // Daily Bible Verse Section
          Text(
            translate('daily_verse'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, 20),
                ),
          ),
          SizedBox(height: context.isMobile ? 12 : 16),
          dailyVerseAsync.when(
            data: (verse) => DailyVerseCard(
              verse: verse,
              isLoading: false,
            ),
            loading: () => const DailyVerseCard(
              verse: null,
              isLoading: true,
            ),
            error: (error, stack) => const DailyVerseCard(
              verse: null,
              isLoading: false,
            ),
          ),
          SizedBox(height: context.isMobile ? 20 : 28),

          if (user != null && !isGuest) ...[
            // Authenticated User Content
            const RoleVisibility(
              allowedRoles: ['member', 'admin', 'leader'],
              child: QuickActionsGrid(),
            ),
          ] else ...[
            // Guest Content
            Consumer(
              builder: (context, ref, _) {
                return const QuickActionsGrid();
              },
            ),
            SizedBox(height: context.isMobile ? 16 : 24),
            // Removed sign-in/up prompt for cleaner guest experience
          ],
        ],
      ),
    );
  }
}
