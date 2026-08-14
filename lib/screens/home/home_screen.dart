import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const CustomAppBar(
        title: 'Home',
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.08),
              theme.scaffoldBackgroundColor,
              theme.colorScheme.secondary.withValues(alpha: 0.04),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: authState.when(
          data: (user) =>
              _buildHomeContent(context, ref, user, isGuest, translate),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Padding(
              padding: ResponsiveUtils.getResponsivePadding(context),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LayoutFixUtils.responsiveIcon(
                    Icons.error,
                    context: context,
                    baseSize: 64,
                    color: theme.colorScheme.error,
                  ),
                  SizedBox(height: context.isMobile ? 12 : 16),
                  Text(
                    'Error: $error',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize:
                          ResponsiveUtils.getResponsiveFontSize(context, 16),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
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
          const GreetingHeader(),
          if (kIsWeb && _WebAndroidDownloadActions.isConfigured) ...[
            SizedBox(height: context.isMobile ? 16 : 20),
            const _WebAndroidDownloadActions(),
          ],
          SizedBox(height: context.isMobile ? 16 : 24),
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
            const RoleVisibility(
              allowedRoles: ['member', 'admin', 'leader'],
              child: QuickActionsGrid(),
            ),
          ] else ...[
            Consumer(
              builder: (context, ref, _) {
                return const QuickActionsGrid();
              },
            ),
            SizedBox(height: context.isMobile ? 16 : 24),
          ],
        ],
      ),
    );
  }
}

class _WebAndroidDownloadActions extends StatelessWidget {
  const _WebAndroidDownloadActions();

  static const _apkUrl = String.fromEnvironment(
    'ANDROID_APK_URL',
    defaultValue: '',
  );
  static const _playStoreUrl = String.fromEnvironment('PLAY_STORE_URL');

  static bool get isConfigured =>
      _apkUrl.isNotEmpty || _playStoreUrl.isNotEmpty;

  Future<void> _open(String value) async {
    final uri = Uri.base.resolve(value);
    if (!await launchUrl(uri, webOnlyWindowName: '_blank')) {
      throw StateError('Could not open $uri');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Download ALIVE Nigeria for Android',
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        children: [
          if (_apkUrl.isNotEmpty)
            FilledButton.icon(
              onPressed: () => _open(_apkUrl),
              icon: const Icon(Icons.android),
              label: const Text('Download Android app'),
            ),
          if (_playStoreUrl.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () => _open(_playStoreUrl),
              icon: const Icon(Icons.shop_outlined),
              label: const Text('Get it on Google Play'),
            ),
        ],
      ),
    );
  }
}
