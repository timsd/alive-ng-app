import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/role_guard.dart';
import '../providers/language_provider.dart';
import '../services/role_access_service.dart';

class MainNavigationScreen extends ConsumerWidget {
  final Widget child;

  const MainNavigationScreen({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocation =
        GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
    final authState = ref.watch(authStateProvider);
    final isAuthenticated = authState.when(
      data: (user) => user != null,
      loading: () => false,
      error: (_, __) => false,
    );

    return Scaffold(
      body: child,
      drawer: _buildNavigationDrawer(context, isAuthenticated),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _getCurrentIndex(currentLocation),
        onTap: (index) => _onItemTapped(context, index),
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 153 / 255.0),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_outlined),
            activeIcon: Icon(Icons.book),
            label: 'Study',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline),
            activeIcon: Icon(Icons.favorite),
            label: 'Prayer',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.health_and_safety_outlined),
            activeIcon: Icon(Icons.health_and_safety),
            label: 'Health',
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

  int _getCurrentIndex(String location) {
    switch (location) {
      case AppConstants.homeRoute:
        return 0;
      case AppConstants.studyRoute:
        return 1;
      case AppConstants.prayerRoute:
        return 2;
      case AppConstants.healthRoute:
      case AppConstants.enhancedHealthRoute:
        return 3;
      case AppConstants.profileRoute:
      case AppConstants.dailyRoute:
      case AppConstants.missionsRoute:
      case AppConstants.aboutAppRoute:
      case AppConstants.aboutAliveRoute:
      case AppConstants.adminRoute:
      case AppConstants.bodTrusteesRoute:
      case AppConstants.userArchiveRoute:
      case AppConstants.roleManagementRoute:
      case AppConstants.conferenceRoute:
      case AppConstants.bibleGameRoute:
      case AppConstants.chatRoute:
      case AppConstants.chaptersRoute:
      case AppConstants.recipesRoute:
      case AppConstants.recipeSubmissionRoute:
        return 4;
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
        _showMoreBottomSheet(context);
        break;
    }
  }

  void _showMoreBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildMoreBottomSheet(context),
    );
  }

  Widget _buildMoreBottomSheet(BuildContext context) {
    final roleService = RoleAccessService.instance;
    final canAccessRoleGated = roleService.canAccessRoleGatedFeatures();
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Adaptive height based on screen size
    final bottomSheetHeight = screenHeight < 600 
        ? screenHeight * 0.85 
        : screenHeight * 0.7;
    
    // Adaptive cross axis count based on screen width
    final crossAxisCount = screenWidth < 360 ? 2 : 3;
    
    return Container(
      height: bottomSheetHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 77 / 255.0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: 16,
            ),
            child: Text(
              'More Features',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (!canAccessRoleGated) ...[
            Container(
              margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
              padding: EdgeInsets.all(screenWidth * 0.03),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.pending_actions,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    size: screenWidth * 0.06,
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  Expanded(
                    child: Text(
                      'Account pending admin approval. Limited features available.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w500,
                        fontSize: screenWidth * 0.035,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: screenHeight * 0.02),
          ],
          Expanded(
            child: GridView.count(
              crossAxisCount: crossAxisCount,
              padding: EdgeInsets.all(screenWidth * 0.04),
              mainAxisSpacing: screenWidth * 0.04,
              crossAxisSpacing: screenWidth * 0.04,
              childAspectRatio: screenWidth < 360 ? 1.1 : 1.0,
              children: [
                if (canAccessRoleGated) ...[
                  _buildMoreItem(context, Icons.calendar_today, 'Daily', AppConstants.dailyRoute),
                  _buildMoreItem(context, Icons.volunteer_activism, 'Missions', AppConstants.missionsRoute),
                  _buildMoreItem(context, Icons.games, 'Bible Game', AppConstants.bibleGameRoute),
                  _buildMoreItem(context, Icons.chat, 'Chat', AppConstants.chatRoute),
                  _buildMoreItem(context, Icons.groups, 'Chapters', AppConstants.chaptersRoute),
                  _buildMoreItem(context, Icons.video_call, 'Conference', AppConstants.conferenceRoute),
                  _buildMoreItem(context, Icons.restaurant, 'Recipes', AppConstants.recipesRoute),
                ],
                _buildMoreItem(context, Icons.person, 'Profile', AppConstants.profileRoute),
                _buildMoreItem(context, Icons.info, 'About App', AppConstants.aboutAppRoute),
                _buildMoreItem(context, Icons.info_outline, 'About ALIVE', AppConstants.aboutAliveRoute),
                RoleVisibility(
                  allowedRoles: ['admin'],
                  child: _buildMoreItem(context, Icons.admin_panel_settings, 'Admin', AppConstants.adminRoute),
                ),
                _buildMoreItem(context, Icons.people, 'BOD Trustees', AppConstants.bodTrusteesRoute),
                _buildMoreItem(context, Icons.auto_stories, 'Kids Stories', AppConstants.kidsStoriesRoute),
                _buildMoreItem(context, Icons.library_books, 'Library', AppConstants.libraryRoute),
                _buildMoreItem(context, Icons.headset, 'Podcasts', AppConstants.podcastsRoute),
                _buildMoreItem(context, Icons.school, 'Lessons', AppConstants.interactiveLessonsRoute),
                _buildMoreItem(context, Icons.menu_book, 'Books & Tracts', AppConstants.booksTractsRoute),
                _buildMoreItem(context, Icons.child_care, 'Kids Mission', AppConstants.kidsMissionRoute),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreItem(BuildContext context, IconData icon, String label, String route) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 51 / 255.0),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: screenWidth < 360 ? 24 : 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(height: screenWidth * 0.02),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: screenWidth < 360 ? 11 : 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationDrawer(BuildContext context, bool isAuthenticated) {
    return Consumer(
      builder: (context, ref, _) {
        final roleService = RoleAccessService.instance;
        final canAccessRoleGated = roleService.canAccessRoleGatedFeatures();
        
        return Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withValues(alpha: 204 / 255.0),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      child: Icon(
                        Icons.person,
                        size: 35,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'ALIVE NG',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Grow in Faith',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 230 / 255.0),
                      ),
                    ),
                  ],
                ),
              ),
              // Show approval status for unapproved users
              if (isAuthenticated && !canAccessRoleGated) ...[                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.pending_actions,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Account pending admin approval',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              _buildDrawerSection(context, 'Main Features', [
                _buildDrawerItem(context, Icons.home, 'Home', AppConstants.homeRoute),
                if (canAccessRoleGated) ...[                  _buildDrawerItem(context, Icons.book, 'Study', AppConstants.studyRoute),
                  _buildDrawerItem(context, Icons.favorite, 'Prayer', AppConstants.prayerRoute),
                  _buildDrawerItem(context, Icons.health_and_safety, 'Health', AppConstants.healthRoute),
                  _buildDrawerItem(context, Icons.calendar_today, 'Daily', AppConstants.dailyRoute),
                ],
              ]),
              if (canAccessRoleGated) ...[                const Divider(),
                _buildDrawerSection(context, 'Community', [
                  _buildDrawerItem(context, Icons.volunteer_activism, 'Missions', AppConstants.missionsRoute),
                  _buildDrawerItem(context, Icons.chat, 'Chat', AppConstants.chatRoute),
                  _buildDrawerItem(context, Icons.groups, 'Chapters', AppConstants.chaptersRoute),
                  _buildDrawerItem(context, Icons.video_call, 'Conference', AppConstants.conferenceRoute),
                ]),
                const Divider(),
                _buildDrawerSection(context, 'Tools & Games', [
                  _buildDrawerItem(context, Icons.games, 'Bible Game', AppConstants.bibleGameRoute),
                  _buildDrawerItem(context, Icons.restaurant, 'Recipes', AppConstants.recipesRoute),
                  _buildDrawerItem(context, Icons.add_circle, 'Submit Recipe', AppConstants.recipeSubmissionRoute),
                ]),
              ],
              if (isAuthenticated && canAccessRoleGated) ...[                const Divider(),
                RoleVisibility(
                  allowedRoles: ['admin'],
                  child: _buildDrawerSection(context, 'Admin', [
                    _buildDrawerItem(context, Icons.admin_panel_settings, 'Dashboard', AppConstants.adminRoute),
                    _buildDrawerItem(context, Icons.approval, 'User Approval', AppConstants.adminApprovalRoute),
                    _buildDrawerItem(context, Icons.people, 'BOD Trustees', AppConstants.bodTrusteesRoute),
                    _buildDrawerItem(context, Icons.archive, 'User Archive', AppConstants.userArchiveRoute),
                    _buildDrawerItem(context, Icons.security, 'Role Management', AppConstants.roleManagementRoute),
                  ]),
                ),
              ],
              const Divider(),
              _buildDrawerSection(context, 'About', [
                _buildDrawerItem(context, Icons.info, 'About App', AppConstants.aboutAppRoute),
                _buildDrawerItem(context, Icons.info_outline, 'About ALIVE', AppConstants.aboutAliveRoute),
                _buildDrawerItem(context, Icons.person, 'Profile', AppConstants.profileRoute),
              ]),
              const Divider(),
              _buildDrawerSection(context, 'Settings', [
                _buildThemeToggleDrawerItem(context, ref),
                _buildLanguageToggleDrawerItem(context, ref),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrawerSection(BuildContext context, String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...items,
      ],
    );
  }

  Widget _buildDrawerItem(BuildContext context, IconData icon, String title, String route) {
    final currentLocation = GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
    final isSelected = currentLocation == route;
    
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected 
            ? Theme.of(context).colorScheme.primary 
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 179 / 255.0),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected 
              ? Theme.of(context).colorScheme.primary 
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Theme.of(context).colorScheme.primary.withValues(alpha: 26 / 255.0),
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
    );
  }

  Widget _buildThemeToggleDrawerItem(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return ListTile(
      leading: Icon(
        isDark ? Icons.light_mode : Icons.dark_mode,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 179 / 255.0),
      ),
      title: Text(
        isDark ? 'Light Mode' : 'Dark Mode',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      onTap: () {
        ref.read(themeModeProvider.notifier).toggleTheme();
      },
    );
  }

  Widget _buildLanguageToggleDrawerItem(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final translate = ref.watch(translationProvider);
    
    return ListTile(
      leading: Icon(
        Icons.language,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 179 / 255.0),
      ),
      title: Text(
        '${translate('language')} (${currentLocale.languageCode.toUpperCase()})',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        _showLanguageSelector(context, ref);
      },
    );
  }

  void _showLanguageSelector(BuildContext context, WidgetRef ref) {
    final translate = ref.watch(translationProvider);
    
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                translate('language'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              ...AppConstants.supportedLanguages.entries.map((entry) {
                return ListTile(
                  title: Text(entry.value),
                  leading: Text(
                    entry.key.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  onTap: () {
                    ref.read(localeProvider.notifier).setLocale(entry.key);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }


}




