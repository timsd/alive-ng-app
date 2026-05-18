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
              ..._buildMoreItems(context),
            ],
          ),
        ),
      ),
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _getCurrentIndex(currentLocation),
        onTap: (index) => _onItemTapped(context, index),
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context)
            .colorScheme
            .onSurface
            .withValues(alpha: 153 / 255.0),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.volunteer_activism_outlined),
            activeIcon: Icon(Icons.volunteer_activism),
            label: 'Prayer',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.games_outlined),
            activeIcon: Icon(Icons.games),
            label: 'Bible Game',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Chapters',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            activeIcon: Icon(Icons.more_horiz),
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

  List<Widget> _buildMoreItems(BuildContext context) {
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
      const _MoreItem(
          'Update Profile', Icons.person, AppConstants.profileRoute),
      const _MoreItem('Study', Icons.school, AppConstants.studyRoute),
      const _MoreItem('Home Remedies & Food', Icons.health_and_safety,
          AppConstants.enhancedHealthRoute),
      const _MoreItem(
          'Prayer Wall', Icons.favorite, AppConstants.prayerWallRoute),
      const _MoreItem(
          'Testimonies', Icons.campaign, AppConstants.testimoniesRoute),
      const _MoreItem('Resources', Icons.folder, AppConstants.resourcesRoute),
      const _MoreItem(
          'Library', Icons.local_library, AppConstants.libraryRoute),
      const _MoreItem('Podcasts', Icons.podcasts, AppConstants.podcastsRoute),
      const _MoreItem(
          'Books & Tracts', Icons.menu_book, AppConstants.booksTractsRoute),
      const _MoreItem(
          'Kids Stories', Icons.auto_stories, AppConstants.kidsStoriesRoute),
      const _MoreItem(
          'Conference', Icons.video_call, AppConstants.conferenceRoute),
      const _MoreItem(
          'Donation', Icons.volunteer_activism, AppConstants.donationRoute),
      const _MoreItem(
          'Help & Support', Icons.help, AppConstants.helpSupportRoute),
      const _MoreItem('Notification Settings', Icons.notifications,
          AppConstants.notificationSettingsRoute),
      const _MoreItem(
          'Privacy Policy', Icons.privacy_tip, AppConstants.privacyPolicyRoute),
      const _MoreItem(
          'Terms & Conditions', Icons.gavel, AppConstants.termsConditionsRoute),
      const _MoreItem(
          'About App', Icons.info_outline, AppConstants.aboutAppRoute),
      const _MoreItem('About ALIVE', Icons.info, AppConstants.aboutAliveRoute),
      const _MoreItem('Sign Out', Icons.logout, null),
      _MoreItem('Delete Account', Icons.delete_forever, null,
          action: () => _handleDeleteAccount(context)),
    ];

    if (canSeeAdmin) {
      items.add(const _MoreItem(
          'Admin', Icons.admin_panel_settings, AppConstants.adminRoute));
    }
    if (canClaimAdmin) {
      items.add(
        _MoreItem(
          'Claim Admin Role (Temp)',
          Icons.verified_user,
          null,
          action: () => _handleClaimAdminRole(context),
        ),
      );
    }
    if (canSeeBod) {
      items.add(
          const _MoreItem('BOD', Icons.groups, AppConstants.bodTrusteesRoute));
    }

    return items
        .map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
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
                  if (item.label == 'Sign Out') {
                    _handleSignOut(context);
                  }
                },
                child: Ink(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.9),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .shadow
                            .withValues(alpha: 0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        item.icon,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(
                      item.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    trailing: Icon(
                      item.label == 'Sign Out' || item.label == 'Delete Account'
                          ? Icons.arrow_forward
                          : Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        )
        .toList();
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
      case AppConstants.prayerRoute:
      case AppConstants.prayerWallRoute:
        return 0;
      case AppConstants.bibleGameRoute:
        return 1;
      case AppConstants.homeRoute:
        return 2;
      case AppConstants.chaptersRoute:
        return 3;
      default:
        return 2;
    }
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppConstants.prayerRoute);
        break;
      case 1:
        context.go(AppConstants.bibleGameRoute);
        break;
      case 2:
        context.go(AppConstants.homeRoute);
        break;
      case 3:
        context.go(AppConstants.chaptersRoute);
        break;
      case 4:
        _scaffoldKey.currentState?.openDrawer();
        break;
    }
  }

  Future<void> _handleSignOut(BuildContext context) async {
    await _authService.signOut();
    if (context.mounted) {
      context.go(AppConstants.authRoute);
    }
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _authService.deleteAccount();
      if (context.mounted) {
        context.go(AppConstants.authRoute);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delete failed. Re-login and try again.'),
          ),
        );
      }
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
