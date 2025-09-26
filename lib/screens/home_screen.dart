import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/guest_provider.dart';
import '../providers/language_provider.dart';
import '../widgets/greeting_header.dart';
import '../widgets/quick_actions_grid.dart';
import '../widgets/role_guard.dart';
import '../constants/app_constants.dart';
import 'package:go_router/go_router.dart';
import '../utils/mobile_utils.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final isGuest = ref.watch(isGuestModeProvider);
    final translate = ref.watch(translationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(translate('home')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: authState.when(
        data: (user) => _buildHomeContent(context, ref, user, isGuest, translate),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              SizedBox(height: MobileUtils.isMobileScreen(context) ? 12 : 16),
              Text(
                'Error: $error',
                style: TextStyle(
                  fontSize: MobileUtils.getResponsiveFontSize(context, 16),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeContent(BuildContext context, WidgetRef ref, user, bool isGuest, Function translate) {
    return SingleChildScrollView(
      padding: MobileUtils.getResponsivePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting Header
          const GreetingHeader(),
          SizedBox(height: MobileUtils.isMobileScreen(context) ? 16 : 24),
          
          if (user != null && !isGuest) ...[
            // Authenticated User Content
            RoleVisibility(
              allowedRoles: ['member', 'admin', 'leader'],
              child: const QuickActionsGrid(),
            ),
          ] else ...[
            // Guest Content
            Consumer(
              builder: (context, ref, _) {
                return const QuickActionsGrid();
              },
            ),
            SizedBox(height: MobileUtils.isMobileScreen(context) ? 16 : 24),
            
            // Quick Actions for Guests
            Text(
              translate('explore'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: MobileUtils.getResponsiveFontSize(context, 20),
              ),
            ),
            SizedBox(height: MobileUtils.isMobileScreen(context) ? 12 : 16),
            _buildGuestQuickActions(context, ref),
            SizedBox(height: MobileUtils.isMobileScreen(context) ? 16 : 24),
            
            // Sign In Prompt
            if (!isGuest) ...[
              Container(
                padding: EdgeInsets.all(MobileUtils.isMobileScreen(context) ? 16 : 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.person_add,
                      size: MobileUtils.isMobileScreen(context) ? 40 : 48,
                      color: Theme.of(context).primaryColor,
                    ),
                    SizedBox(height: MobileUtils.isMobileScreen(context) ? 12 : 16),
                    Text(
                      translate('sign_in_to_continue'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: MobileUtils.getResponsiveFontSize(context, 16),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: MobileUtils.isMobileScreen(context) ? 12 : 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => context.go(AppConstants.authRoute),
                            child: Text(translate('sign_in')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context.go(AppConstants.authRoute),
                            child: Text(translate('sign_up')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildGuestQuickActions(BuildContext context, WidgetRef ref) {
    final translate = ref.watch(translationProvider);
    
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: MobileUtils.getResponsiveSpacing(context, 16),
      mainAxisSpacing: MobileUtils.getResponsiveSpacing(context, 16),
      childAspectRatio: 1.2,
      children: [
        _buildQuickActionCard(
          context,
          icon: Icons.book,
          title: translate('bible'),
          subtitle: translate('read_bible'),
          onTap: () => context.go('/bible'),
        ),
        _buildQuickActionCard(
          context,
          icon: Icons.auto_stories,
          title: translate('study'),
          subtitle: translate('bible_study'),
          onTap: () => context.go('/study'),
        ),
        _buildQuickActionCard(
          context,
          icon: Icons.favorite,
          title: translate('prayer'),
          subtitle: translate('prayer_requests'),
          onTap: () => context.go('/prayer'),
        ),
        _buildQuickActionCard(
          context,
          icon: Icons.calendar_today,
          title: translate('daily'),
          subtitle: translate('daily_devotion'),
          onTap: () => context.go('/daily'),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MobileUtils.getResponsiveBorderRadius(context, 12)),
        child: Padding(
          padding: MobileUtils.getResponsivePadding(context, 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: MobileUtils.getResponsiveIconSize(context, 32),
                color: Theme.of(context).primaryColor,
              ),
              SizedBox(height: MobileUtils.getResponsiveSpacing(context, 8)),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: MobileUtils.getResponsiveSpacing(context, 4)),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

}




