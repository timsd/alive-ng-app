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
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'More',
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 20),
                ),
              ),
            ),
            ..._buildMoreItems(context),
          ],
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
    final signedInEmail = _authService.currentUser?.email?.toLowerCase();
    final canClaimAdmin = signedInEmail == 'alivenigeria2011@gmail.com';
    final canSeeAdmin =
        signedIn && (roleService.canAccessAdmin() || role != 'member');
    const bodRoles = {'admin', 'bod', 'trustee'};
    final canSeeBod = bodRoles.contains(role);

    final items = <_MoreItem>[
      const _MoreItem('Daily Verse', Icons.today, AppConstants.dailyRoute),
      const _MoreItem('Update Profile', Icons.person, AppConstants.profileRoute),
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
      const _MoreItem('About App', Icons.info_outline, AppConstants.aboutAppRoute),
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
          (item) => ListTile(
            leading: Icon(item.icon),
            title: Text(item.label),
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
          ),
        )
        .toList();
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
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
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
      final ok = await ref.read(firebaseDatabaseServiceProvider).claimAdminRole();
      if (!context.mounted) return;
      if (ok) {
        RoleAccessService.instance.clearCache();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Admin role claim successful. Please sign out and sign in again.'),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Admin role claim failed. Check Cloud Functions deployment.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not claim admin role right now.'),
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
