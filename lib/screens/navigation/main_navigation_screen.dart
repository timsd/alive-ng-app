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
              _buildUserStatusCard(context),
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
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
      const _MoreItem('Daily Verse', Icons.wb_sunny_rounded, AppConstants.dailyRoute, color: Color(0xFFF59E0B)),
      const _MoreItem('Profile', Icons.account_circle_rounded, AppConstants.profileRoute, color: Color(0xFF3B82F6)),
      const _MoreItem('Bible Game', Icons.sports_esports_rounded, AppConstants.bibleGameRoute, color: Color(0xFF2563EB)),
      const _MoreItem('Study Guides', Icons.school_rounded, AppConstants.studyRoute, color: Color(0xFF6366F1)),
      const _MoreItem('Health', Icons.health_and_safety_rounded, AppConstants.enhancedHealthRoute, color: Color(0xFF10B981)),
      const _MoreItem('Prayer Wall', Icons.favorite_rounded, AppConstants.prayerWallRoute, color: Color(0xFFEC4899)),
      const _MoreItem('Testimonies', Icons.record_voice_over_rounded, AppConstants.testimoniesRoute, color: Color(0xFF8B5CF6)),
      const _MoreItem('Resources', Icons.folder_rounded, AppConstants.resourcesRoute, color: Color(0xFF0EA5E9)),
      const _MoreItem('Library', Icons.local_library_rounded, AppConstants.libraryRoute, color: Color(0xFF14B8A6)),
      const _MoreItem('Podcasts', Icons.podcasts_rounded, AppConstants.podcastsRoute, color: Color(0xFFD946EF)),
      const _MoreItem('Books & Tracts', Icons.menu_book_rounded, AppConstants.booksTractsRoute, color: Color(0xFFF97316)),
      const _MoreItem('Kids Stories', Icons.auto_stories_rounded, AppConstants.kidsStoriesRoute, color: Color(0xFFF43F5E)),
      const _MoreItem('ALIVE Meet', Icons.video_call_rounded, AppConstants.conferenceRoute, color: Color(0xFF06B6D4)),
      const _MoreItem('Donation', Icons.volunteer_activism_rounded, AppConstants.donationRoute, color: Color(0xFF10B981)),
      const _MoreItem('Help & Support', Icons.help_rounded, AppConstants.helpSupportRoute, color: Color(0xFF64748B)),
      const _MoreItem('Notifications', Icons.notifications_rounded, AppConstants.notificationSettingsRoute, color: Color(0xFFEAB308)),
      const _MoreItem('About App', Icons.info_rounded, AppConstants.aboutAppRoute, color: Color(0xFF6B7280)),
      const _MoreItem('About ALIVE', Icons.church_rounded, AppConstants.aboutAliveRoute, color: Color(0xFF16A34A)),
    ];

    if (canSeeAdmin) {
      items.insert(0, const _MoreItem('Admin Portal', Icons.admin_panel_settings, AppConstants.adminRoute, color: Color(0xFFDC2626)));
    }
    if (canClaimAdmin) {
      items.insert(0, _MoreItem('Claim Admin', Icons.verified_user, null, action: () => _handleClaimAdminRole(context), color: Color(0xFF7C3AED)));
    }
    if (canSeeBod) {
      items.insert(0, const _MoreItem('BOD Trustees', Icons.groups, AppConstants.bodTrusteesRoute, color: Color(0xFF4F46E5)));
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final itemColor = item.color ?? Theme.of(context).colorScheme.primary;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: itemColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item.icon,
                      color: itemColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item.label,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
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



  /// Build a card showing the user's current role and approval status
  Widget _buildUserStatusCard(BuildContext context) {
    final roleService = RoleAccessService.instance;
    final userRole = roleService.getCurrentUserRole();
    // For now, we'll show a simple status based on role
    // The actual approval status check can be added later with a proper async approach
    final theme = Theme.of(context);

    // Determine status color and icon based on role
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (userRole == null) {
      statusColor = theme.colorScheme.outline;
      statusIcon = Icons.person_outline;
      statusText = 'Not Signed In';
    } else {
      statusColor = theme.colorScheme.primary;
      statusIcon = Icons.verified_user;
      statusText = 'Active';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  statusIcon,
                  color: statusColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Account Status',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Refresh button
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () async {
                    await roleService.forceRefreshCache();
                    if (context.mounted) {
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Status refreshed'),
                          backgroundColor: theme.colorScheme.tertiary,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  tooltip: 'Refresh status',
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Role row
            Row(
              children: [
                Icon(
                  Icons.badge_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Role: ',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  userRole?.toUpperCase() ?? 'UNKNOWN',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: userRole == 'admin'
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Approval status row
            Row(
              children: [
                Icon(
                  statusIcon,
                  size: 18,
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Status: ',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  statusText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreItem {
  final String label;
  final IconData icon;
  final String? route;
  final VoidCallback? action;
  final Color? color;

  const _MoreItem(this.label, this.icon, this.route, {this.action, this.color});
}

