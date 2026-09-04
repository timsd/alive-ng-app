import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:alive_flutter_app/constants/app_constants.dart';
import 'package:alive_flutter_app/services/role_access_service.dart';
import 'package:alive_flutter_app/services/auth_service.dart';
import 'package:alive_flutter_app/widgets/custom_app_bar.dart';
import 'package:alive_flutter_app/providers/auth_provider.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  final Widget child;

  const MainNavigationScreen({super.key, required this.child});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final AuthService _authService = AuthService.instance;

  @override
  Widget build(BuildContext context) {
    final currentLocation =
        GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;

    return Scaffold(
      key: _scaffoldKey,
      appBar: CustomAppBar(
        title: _routeTitle(currentLocation),
        showThemeToggle: true,
        showLanguageToggle: true,
        showDonationButton: true,
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _buildMoreHeader(context),
              const SizedBox(height: 16),
              _buildMoreGrid(context),
            ],
          ),
        ),
      ),
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _getCurrentIndex(currentLocation),
        onTap: (index) => _onItemTapped(context, index),
        selectedItemColor: Theme.of(context)
            .bottomNavigationBarTheme
            .selectedItemColor ??
            Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context)
            .bottomNavigationBarTheme
            .unselectedItemColor ??
            Theme.of(context).colorScheme.onSurfaceVariant,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Study',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.volunteer_activism_outlined),
            activeIcon: Icon(Icons.volunteer_activism),
            label: 'Prayer',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.health_and_safety_outlined),
            activeIcon: Icon(Icons.health_and_safety),
            label: 'Health',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            activeIcon: Icon(Icons.grid_view_rounded),
            label: 'More',
          ),
        ],
      ),
    );
  }

  String _routeTitle(String location) {
    switch (location) {
      case AppConstants.homeRoute:
        return 'Home';
      case AppConstants.prayerRoute:
      case AppConstants.prayerWallRoute:
        return 'Prayer';
      case AppConstants.bibleGameRoute:
        return 'Bible Game';
      case AppConstants.chaptersRoute:
        return 'Chapters';
      case AppConstants.dailyRoute:
        return 'Daily';
      case AppConstants.studyRoute:
        return 'Study';
      case AppConstants.resourcesRoute:
        return 'Resources';
      case AppConstants.testimoniesRoute:
        return 'Testimonies';
      case AppConstants.donationRoute:
        return 'Donation';
      default:
        return 'ALIVE-NG';
    }
  }

  Widget _buildMoreGrid(BuildContext context) {
    final roleService = RoleAccessService.instance;
    final role = roleService.getCurrentUserRole() ?? 'member';
    final signedIn = _authService.currentUser != null;
    final signedInEmail = _authService.currentUser?.email.toLowerCase();
    final canClaimAdmin = signedInEmail == 'alivenigeria2011@gmail.com';
    final canSeeAdmin =
        signedIn && (roleService.canAccessAdmin() || role != 'member');
    const bodRoles = {'admin', 'bod', 'trustee'};
    final canSeeBod = bodRoles.contains(role);

    final items = <_MoreItem>[
      const _MoreItem('Daily Verse', Icons.today, AppConstants.dailyRoute),
      const _MoreItem('Profile', Icons.person, AppConstants.profileRoute),
      const _MoreItem('Study Guides', Icons.school, AppConstants.studyRoute),
      const _MoreItem('Health & Wellness', Icons.health_and_safety, AppConstants.enhancedHealthRoute),
      const _MoreItem('Prayer Wall', Icons.favorite, AppConstants.prayerWallRoute),
      const _MoreItem('Testimonies', Icons.campaign, AppConstants.testimoniesRoute),
      const _MoreItem('Resources', Icons.folder, AppConstants.resourcesRoute),
      const _MoreItem('Library', Icons.local_library, AppConstants.libraryRoute),
      const _MoreItem('Podcasts', Icons.podcasts, AppConstants.podcastsRoute),
      const _MoreItem('Books & Tracts', Icons.menu_book, AppConstants.booksTractsRoute),
      const _MoreItem('Kids Stories', Icons.auto_stories, AppConstants.kidsStoriesRoute),
      const _MoreItem('ALIVE Meet', Icons.video_call, AppConstants.conferenceRoute),
      const _MoreItem('Donation', Icons.volunteer_activism, AppConstants.donationRoute),
      const _MoreItem('Help & Support', Icons.help, AppConstants.helpSupportRoute),
      const _MoreItem('Notifications', Icons.notifications, AppConstants.notificationSettingsRoute),
      const _MoreItem('About App', Icons.info_outline, AppConstants.aboutAppRoute),
      const _MoreItem('About ALIVE', Icons.info, AppConstants.aboutAliveRoute),
      const _MoreItem('Privacy Policy', Icons.privacy_tip, AppConstants.privacyPolicyRoute),
      const _MoreItem('Terms & Conditions', Icons.gavel, AppConstants.termsConditionsRoute),
    ];

    if (canSeeAdmin) {
      items.insert(0, const _MoreItem('Admin Portal', Icons.admin_panel_settings, AppConstants.adminRoute));
    }
    if (canClaimAdmin) {
      items.insert(0, _MoreItem('Claim Admin Role', Icons.verified_user, null, action: () => _handleClaimAdminRole(context)));
    }
    if (canSeeBod) {
      items.insert(0, const _MoreItem('BOD Trustees', Icons.groups, AppConstants.bodTrusteesRoute));
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.38,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final colorScheme = Theme.of(context).colorScheme;

        return Material(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.of(context).pop();
              if (item.route != null) {
                context.go(item.route!);
                return;
              }
              if (item.action != null) {
                item.action!.call();
                return;
              }
            },
            child: Ink(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        item.icon,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMoreHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'More',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Quick access to your account, ministry tools, support, and app information.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimary.withValues(alpha: 0.84),
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }

  int _getCurrentIndex(String location) {
    switch (location) {
      case AppConstants.homeRoute:
        return 0;
      case AppConstants.studyRoute:
      case AppConstants.studyGuideRoute:
      case AppConstants.chaptersRoute:
        return 1;
      case AppConstants.prayerRoute:
      case AppConstants.prayerWallRoute:
        return 2;
      case AppConstants.healthRoute:
      case AppConstants.enhancedHealthRoute:
        return 3;
      default:
        return 0;
    }
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppConstants.homeRoute);
        break;
      case 1:
        context.go(AppConstants.studyRoute);
        break;
      case 2:
        context.go(AppConstants.prayerRoute);
        break;
      case 3:
        context.go(AppConstants.healthRoute);
        break;
      case 4:
        _scaffoldKey.currentState?.openDrawer();
        break;
    }
  }



  Future<void> _handleClaimAdminRole(BuildContext context) async {
    try {
      final user = await ref.read(authServiceProvider).getCurrentUser();
      if (!context.mounted) return;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Sign in before refreshing admin access.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      RoleAccessService.instance.clearCache();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Admin access checked. If your account is in the Appwrite admin team, access will refresh now.',
          ),
          backgroundColor: Theme.of(context).colorScheme.tertiary,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not refresh admin access right now.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}

class _MoreItem {
  final String label;
  final IconData icon;
  final String? route;
  final VoidCallback? action;

  const _MoreItem(this.label, this.icon, this.route, {this.action});
}
