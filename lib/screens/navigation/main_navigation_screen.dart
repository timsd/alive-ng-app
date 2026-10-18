import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:alive_flutter_app/constants/app_constants.dart';
import 'package:alive_flutter_app/models/app_models.dart';
import 'package:alive_flutter_app/services/role_access_service.dart';
import 'package:alive_flutter_app/services/auth_service.dart';
import 'package:alive_flutter_app/widgets/custom_app_bar.dart';
import 'package:alive_flutter_app/config/appwrite_backend_config.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers/language_provider.dart';

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
    final l10n = AppLocalizations.of(context);
    final translate = ref.watch(translationProvider);

    return Scaffold(
      key: _scaffoldKey,
      appBar: CustomAppBar(
        title: _routeTitle(currentLocation, l10n, translate),
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
      bottomNavigationBar: _buildCustomBottomNavigationBar(
        context,
        _getCurrentIndex(currentLocation),
        l10n,
        translate,
      ),
    );
  }

  String _routeTitle(String location, AppLocalizations? l10n, String Function(String) translate) {
    switch (location) {
      case AppConstants.homeRoute:
        return l10n?.home ?? 'Home';
      case AppConstants.prayerRoute:
      case AppConstants.prayerWallRoute:
      case AppConstants.privatePrayerRoomRoute:
        return l10n?.prayer ?? 'Prayer';
      case AppConstants.bibleGameRoute:
        return translate('bible_game');
      case AppConstants.chaptersRoute:
        return translate('chapters');
      case AppConstants.dailyRoute:
        return l10n?.daily ?? 'Daily';
      case AppConstants.studyRoute:
        return l10n?.study ?? 'Study';
      case AppConstants.resourcesRoute:
        return translate('resources');
      case AppConstants.testimoniesRoute:
        return translate('testimonies');
      case AppConstants.donationRoute:
        return translate('donation');
      default:
        return 'ALIVE Nigeria';
    }
  }

  Widget _buildMoreGrid(BuildContext context) {
    final roleService = RoleAccessService.instance;
    final role = roleService.getCurrentUserRole() ?? 'member';
    final signedIn = _authService.currentUser != null;
    // Admin self-claim removed: any client-toggled "Claim Admin" button can be
    // abused (a user only needs to set this email locally to gain admin UI).
    // Admin rights come ONLY from Appwrite server-side truth:
    // 1) membership in the admin team (verifyAndSyncAdminRights on sign-in), or
    // 2) role == 'admin' set in the users table by an existing admin via the
    //    Admin Approval screen (/admin-approval). No client button needed.
    final canSeeAdmin =
        signedIn && (roleService.canAccessAdmin() || role != 'member');
    const bodRoles = {'admin', 'bod', 'trustee'};
    final canSeeBod = bodRoles.contains(role);

    final items = <_MoreItem>[
      const _MoreItem('Daily Verse', Icons.wb_sunny_rounded, AppConstants.dailyRoute, color: Color(0xFFF59E0B)),
      const _MoreItem('Bible Reader', Icons.menu_book_rounded, AppConstants.bibleRoute, color: Color(0xFF6366F1)),
      const _MoreItem('Bible Game', Icons.sports_esports_rounded, AppConstants.bibleGameRoute, color: Color(0xFF2563EB)),
      const _MoreItem('Study Guides', Icons.school_rounded, AppConstants.studyRoute, color: Color(0xFF4F46E5)),
      const _MoreItem('Lessons', Icons.menu_book_outlined, AppConstants.interactiveLessonsRoute, color: Color(0xFF8B5CF6)),
      const _MoreItem('Discipleship', Icons.trending_up_rounded, AppConstants.discipleshipTrackerRoute, color: Color(0xFF10B981)),
      const _MoreItem('Missions', Icons.public_rounded, AppConstants.missionsRoute, color: Color(0xFF0EA5E9)),
      const _MoreItem('Kids Missions', Icons.child_care_rounded, AppConstants.kidsMissionRoute, color: Color(0xFFF43F5E)),
      const _MoreItem('Kids Stories', Icons.auto_stories_rounded, AppConstants.kidsStoriesRoute, color: Color(0xFFFB7185)),
      const _MoreItem('Health+', Icons.medical_services_rounded, AppConstants.enhancedHealthRoute, color: Color(0xFF059669)),
      const _MoreItem('Prayer Wall', Icons.favorite_rounded, AppConstants.prayerWallRoute, color: Color(0xFFEC4899)),
      const _MoreItem('Testimonies', Icons.record_voice_over_rounded, AppConstants.testimoniesRoute, color: Color(0xFF8B5CF6)),
      const _MoreItem('Chapters', Icons.location_city_rounded, AppConstants.chaptersRoute, color: Color(0xFF3B82F6)),
      const _MoreItem('Community Chat', Icons.forum_rounded, AppConstants.chatRoute, color: Color(0xFF0284C7)),
      const _MoreItem('Events', Icons.event_rounded, AppConstants.eventsRoute, color: Color(0xFF7C3AED)),
      const _MoreItem('Resources', Icons.folder_rounded, AppConstants.resourcesRoute, color: Color(0xFF0EA5E9)),
      const _MoreItem('Library', Icons.local_library_rounded, AppConstants.libraryRoute, color: Color(0xFF14B8A6)),
      const _MoreItem('Podcasts', Icons.podcasts_rounded, AppConstants.podcastsRoute, color: Color(0xFFD946EF)),
      const _MoreItem('Books & Tracts', Icons.book_online_rounded, AppConstants.booksTractsRoute, color: Color(0xFFF97316)),
      const _MoreItem('ALIVE Meet', Icons.video_call_rounded, AppConstants.conferenceRoute, color: Color(0xFF06B6D4)),
      const _MoreItem('Support ALIVE', Icons.volunteer_activism_rounded, AppConstants.donationRoute, color: Color(0xFF10B981)),
      const _MoreItem('Profile', Icons.account_circle_rounded, AppConstants.profileRoute, color: Color(0xFF3B82F6)),
      const _MoreItem('Help & Support', Icons.help_rounded, AppConstants.helpSupportRoute, color: Color(0xFF64748B)),
      const _MoreItem('Notifications', Icons.notifications_rounded, AppConstants.notificationSettingsRoute, color: Color(0xFFEAB308)),
      const _MoreItem('About App', Icons.info_rounded, AppConstants.aboutAppRoute, color: Color(0xFF6B7280)),
      const _MoreItem('About ALIVE', Icons.church_rounded, AppConstants.aboutAliveRoute, color: Color(0xFF16A34A)),
    ];
    // Leadership Archive: visible to all signed-in users
    if (signedIn) {
      items.add(const _MoreItem('Leadership Archive', Icons.folder_special_rounded, AppConstants.leadershipArchiveRoute, color: Color(0xFF6366F1)));
    }

    // Private Prayer Rooms: visible to leaders, directors, BOD, trustees, admins
    const privatePrayerRoles = {
      'admin',
      'bod',
      'trustee',
      'chapter_leader',
      'director'
    };
    if (signedIn && privatePrayerRoles.contains(role.toLowerCase())) {
      items.add(const _MoreItem('Private Prayer', Icons.lock_person_rounded, AppConstants.privatePrayerRoomRoute, color: Color(0xFF9333EA)));
    }


    // Role-based items for Admin
    if (canSeeAdmin) {
      items.insertAll(0, const [
        _MoreItem('Admin Portal', Icons.admin_panel_settings_rounded, AppConstants.adminRoute, color: Color(0xFFDC2626)),
        _MoreItem('Approvals', Icons.how_to_reg_rounded, AppConstants.adminApprovalRoute, color: Color(0xFFEA580C)),
        _MoreItem('Donations Report', Icons.analytics_rounded, AppConstants.adminDonationsReportRoute, color: Color(0xFFB91C1C)),
        _MoreItem('Manage Users', Icons.manage_accounts_rounded, AppConstants.roleManagementRoute, color: Color(0xFFC026D3)),
        _MoreItem('Content Admin', Icons.post_add_rounded, AppConstants.contentManagementRoute, color: Color(0xFF7C3AED)),
        _MoreItem('Media Admin', Icons.library_add_rounded, AppConstants.tractPodcastAdminRoute, color: Color(0xFF2563EB)),
        _MoreItem('User Archive', Icons.archive_rounded, AppConstants.userArchiveRoute, color: Color(0xFF64748B)),
      ]);
    }

    // Role-based items for Board of Trustees (BOD)
    if (canSeeBod) {
      items.insertAll(canSeeAdmin ? 7 : 0, const [
        _MoreItem('BOD Trustees', Icons.groups_rounded, AppConstants.bodTrusteesRoute, color: Color(0xFF4F46E5)),
      ]);
    }

    // If the user has guest role (non-member), only show guest-accessible areas
    if (role == 'guest') {
      const guestRoutes = {
        AppConstants.dailyRoute,
        AppConstants.bibleRoute,
        AppConstants.bibleGameRoute,
        AppConstants.studyRoute,
        AppConstants.interactiveLessonsRoute,
        AppConstants.kidsMissionRoute,
        AppConstants.kidsStoriesRoute,
        AppConstants.enhancedHealthRoute,
        AppConstants.testimoniesRoute,
        AppConstants.resourcesRoute,
        AppConstants.libraryRoute,
        AppConstants.podcastsRoute,
        AppConstants.booksTractsRoute,
        AppConstants.donationRoute,
        AppConstants.profileRoute,
        AppConstants.helpSupportRoute,
        AppConstants.aboutAppRoute,
        AppConstants.aboutAliveRoute,
      };
      items.retainWhere((item) => item.route == null || guestRoutes.contains(item.route));
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
  /// Status is loaded from the fresh Appwrite profile (never hardcoded):
  /// pending -> amber hourglass, approved -> green verified, rejected -> red.
  Widget _buildUserStatusCard(BuildContext context) {
    final roleService = RoleAccessService.instance;
    final userRole = roleService.getCurrentUserRole();
    final theme = Theme.of(context);

    return FutureBuilder<UserProfile?>(
      future: roleService.getCurrentUserProfile(),
      builder: (context, snapshot) {
        final userProfile = snapshot.data;
        final isAdmin = userRole == 'admin' ||
            userRole == 'staff' ||
            AppwriteBackendConfig.isSuperAdminEmail(userProfile?.email);
        final approvalStatus =
            isAdmin ? 'approved' : userProfile?.approvalStatus;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        Color statusColor;
        IconData statusIcon;
        String statusText;

        if (userRole == null) {
          statusColor = theme.colorScheme.outline;
          statusIcon = Icons.person_outline;
          statusText = 'Not Signed In';
        } else if (userRole == 'guest') {
          statusColor = Colors.blue.shade700;
          statusIcon = Icons.visibility_outlined;
          statusText = 'Guest (Non-Member)';
        } else if (isLoading || approvalStatus == null) {
          statusColor = theme.colorScheme.outline;
          statusIcon = Icons.sync;
          statusText = 'Checking…';
        } else {
          switch (approvalStatus) {
            case 'pending':
              statusColor = Colors.amber.shade700;
              statusIcon = Icons.hourglass_bottom;
              statusText = 'Pending Approval';
              break;
            case 'rejected':
              statusColor = theme.colorScheme.error;
              statusIcon = Icons.cancel_outlined;
              statusText = 'Rejected';
              break;
            case 'approved':
            default:
              statusColor = Colors.green.shade700;
              statusIcon = Icons.verified_user;
              statusText = isAdmin ? 'Admin (Approved)' : 'Approved';
              break;
          }
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
      },
    );
  }

  Widget _buildCustomBottomNavigationBar(
    BuildContext context,
    int currentIndex,
    AppLocalizations? l10n,
    String Function(String) translate,
  ) {
    final theme = Theme.of(context);

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        HapticFeedback.selectionClick();
        _onItemTapped(context, index);
      },
      backgroundColor: theme.colorScheme.surface,
      indicatorColor: theme.colorScheme.primaryContainer,
      elevation: 2,
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home, color: theme.colorScheme.onPrimaryContainer),
          label: l10n?.home ?? 'Home',
        ),
        NavigationDestination(
          icon: const Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book, color: theme.colorScheme.onPrimaryContainer),
          label: l10n?.study ?? 'Study',
        ),
        NavigationDestination(
          icon: const Icon(Icons.volunteer_activism_outlined),
          selectedIcon: Icon(Icons.volunteer_activism, color: theme.colorScheme.onPrimaryContainer),
          label: l10n?.prayer ?? 'Prayer',
        ),
        NavigationDestination(
          icon: const Icon(Icons.health_and_safety_outlined),
          selectedIcon: Icon(Icons.health_and_safety, color: theme.colorScheme.onPrimaryContainer),
          label: translate('health'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.grid_view_outlined),
          selectedIcon: Icon(Icons.grid_view_rounded, color: theme.colorScheme.onPrimaryContainer),
          label: translate('more'),
        ),
      ],
    );
  }
}

class _MoreItem {
  final String label;
  final IconData icon;
  final String? route;
  final Color? color;

  const _MoreItem(this.label, this.icon, this.route, {this.color});
}


