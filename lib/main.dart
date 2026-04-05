import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'config/firebase_config.dart';
import 'config/development_config.dart';
import 'services/kids_content_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'providers/theme_provider.dart';
import 'utils/app_router.dart';
import 'utils/app_theme.dart';
import 'config/google_signin_config.dart';
import 'package:go_router/go_router.dart';
import 'constants/app_constants.dart';
import 'providers/auth_provider.dart';
import 'services/role_access_service.dart';
import 'utils/responsive_utils.dart';
import 'widgets/role_guard.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'services/in_app_update_service.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
// DEV ONLY — delete this import + the file below when done testing admin features:
import 'debug/dev_admin_override.dart';
import 'providers/language_provider.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      debugPrint(details.exceptionAsString());
    };

    var firebaseReady = false;
    try {
      await FirebaseConfig.initialize().timeout(const Duration(seconds: 8),
          onTimeout: () {
        debugPrint('Firebase init timeout; continuing app startup');
      });
      firebaseReady = true;
      if (kIsWeb) {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      }
    } catch (e) {
      debugPrint('Firebase init failed: $e');
    }

    runApp(
      const ProviderScope(
        child: AliveApp(),
      ),
    );

    Future(() async {
      try {
        await DevelopmentConfig.initializeFromPrefs();
      } catch (e) {
        debugPrint('Dev config init failed: $e');
      }
      try {
        await GoogleSignInConfig.initialize();
      } catch (e) {
        debugPrint('Google Sign-In initialization failed, continuing: $e');
      }
      if (firebaseReady) {
        try {
          await KidsContentService.initializeKidsContent();
        } catch (e) {
          debugPrint('Failed to initialize Kids Content Service: $e');
        }
      } else {
        debugPrint(
            'Skipping Kids Content initialization: Firebase unavailable');
      }
    });

    // Trigger Android in-app updates (flexible/immediate) after app starts
    // Uses best-effort; silently ignores errors and non-Android platforms
    WidgetsBinding.instance.addPostFrameCallback((_) {
      InAppUpdateService.checkForUpdates();
    });
  }, (error, stack) {
    debugPrint('Unhandled: $error');
  });
}

class AliveApp extends ConsumerWidget {
  const AliveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('Post frame: MaterialApp.router');
    });

    return MaterialApp.router(
      title: 'ALIVE-NG APP',
      debugShowCheckedModeBanner: false,

      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,

      // Localization - Always use English for MaterialLocalizations
      locale: const Locale('en', 'US'),
      supportedLocales: const [
        Locale('en', 'US'), // English - MaterialLocalizations support
        // Note: Other languages handled by custom translation system
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        // Always return English for MaterialLocalizations compatibility
        // Our custom translation system handles the actual language switching
        return const Locale('en', 'US');
      },

      // Routing
      routerConfig: router,
    );
  }
}

class MainNavigationScreen extends ConsumerWidget {
  final Widget child;

  const MainNavigationScreen({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('MainNavigationScreen build');
    final currentLocation =
        GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
    debugPrint('Current location: $currentLocation');
    final authState = ref.watch(authStateProvider);
    debugPrint('authStateProvider watched');
    final isAuthenticated = authState.when(
      data: (user) => user != null,
      loading: () => false,
      error: (_, __) => false,
    );
    final translator = ref.watch(languageProvider);
    debugPrint('isAuthenticated=$isAuthenticated');

    return Scaffold(
      body: Stack(
        children: [
          child,
          // DEV ONLY overlay — invisible in release builds; delete dev_admin_override.dart + this import to clean up
          if (kDebugMode) const DevAdminOverlayButton(),
        ],
      ),
      drawer: _buildNavigationDrawer(context, isAuthenticated),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _getCurrentIndex(currentLocation),
        onTap: (index) => _onItemTapped(context, ref, index),
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context)
            .colorScheme
            .onSurface
            .withValues(alpha: 153 / 255.0),
        selectedFontSize: context.responsiveFontSize(12),
        unselectedFontSize: context.responsiveFontSize(10),
        iconSize: context.responsiveIconSize(24),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: translator('home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.book_outlined),
            activeIcon: const Icon(Icons.book),
            label: translator('study'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(FontAwesomeIcons.personPraying),
            activeIcon: const Icon(FontAwesomeIcons.personPraying),
            label: translator('prayer'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.health_and_safety_outlined),
            activeIcon: const Icon(Icons.health_and_safety),
            label: translator('health'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.more_horiz),
            activeIcon: const Icon(Icons.more_horiz),
            label: translator('more'),
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

  void _onItemTapped(BuildContext context, WidgetRef ref, int index) {
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
        _showMoreBottomSheet(context, ref);
        break;
    }
  }

  void _showMoreBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildMoreBottomSheet(context, ref),
    );
  }

  Widget _buildMoreBottomSheet(BuildContext context, WidgetRef ref) {
    final translate = ref.watch(languageProvider);
    final roleService = RoleAccessService.instance;
    final canAccessRoleGated = roleService.canAccessRoleGatedFeatures();
    final userEmail = ref.watch(authStateProvider).maybeWhen(
          data: (user) => user?.email?.toLowerCase(),
          orElse: () => null,
        );
    final canClaimAdmin = userEmail == 'alivenigeria2011@gmail.com';

    // Use responsive utilities instead of hardcoded MediaQuery values
    final bottomSheetHeight = ResponsiveUtils.getResponsiveValue(
      context: context,
      mobile: MediaQuery.of(context).size.height * 0.85,
      tablet: MediaQuery.of(context).size.height * 0.7,
      desktop: MediaQuery.of(context).size.height * 0.6,
    );

    // Responsive cross axis count
    final crossAxisCount = ResponsiveUtils.getResponsiveGridColumns(context);

    return Container(
      height: bottomSheetHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(context.responsiveBorderRadius.topLeft.x)),
      ),
      child: Column(
        children: [
          Container(
            width: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 40.0,
              tablet: 48.0,
              desktop: 56.0,
            ),
            height: 4,
            margin: EdgeInsets.symmetric(
                vertical: context.responsivePadding.top / 2),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 77 / 255.0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: context.responsivePadding,
            child: Text(
              translate('more_features'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: context.responsiveFontSize(20),
                  ),
            ),
          ),
          if (!canAccessRoleGated) ...[
            Container(
              margin: context.responsiveMargin,
              padding: context.responsivePadding,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: context.responsiveBorderRadius,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.pending_actions,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    size: context.responsiveIconSize(24),
                  ),
                  SizedBox(
                      width: context.getResponsiveValue(
                              mobile: 16.0, tablet: 24.0, desktop: 32.0) /
                          2),
                  Expanded(
                    child: Text(
                      translate('account_pending_approval'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w500,
                        fontSize: context.responsiveFontSize(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
                height: context.getResponsiveValue(
                    mobile: 8.0, tablet: 12.0, desktop: 16.0)),
          ],
          Expanded(
            child: Builder(builder: (context) {
              final items = <Map<String, dynamic>>[
                if (canAccessRoleGated) ...[
                  {
                    'icon': Icons.health_and_safety,
                    'label': 'Health',
                    'route': AppConstants.enhancedHealthRoute
                  },
                  {
                    'icon': Icons.calendar_today,
                    'label': 'Daily',
                    'route': AppConstants.dailyRoute
                  },
                  {
                    'icon': Icons.volunteer_activism,
                    'label': 'Missions',
                    'route': AppConstants.missionsRoute
                  },
                  {
                    'icon': Icons.event,
                    'label': 'Events',
                    'route': AppConstants.eventsRoute
                  },
                  {
                    'icon': Icons.games,
                    'label': 'Bible Game',
                    'route': AppConstants.bibleGameRoute
                  },
                  {
                    'icon': Icons.chat,
                    'label': 'Chat',
                    'route': AppConstants.chatRoute
                  },
                  {
                    'icon': Icons.groups,
                    'label': 'Chapters',
                    'route': AppConstants.chaptersRoute
                  },
                  {
                    'icon': Icons.video_call,
                    'label': 'Conference',
                    'route': AppConstants.conferenceRoute
                  },
                  {
                    'icon': Icons.restaurant,
                    'label': 'Recipes',
                    'route': AppConstants.recipesRoute
                  },
                  {
                    'icon': Icons.people,
                    'label': 'BOD Trustees',
                    'route': AppConstants.bodTrusteesRoute,
                    'allowedRoles': ['admin', 'bod', 'trustee']
                  },
                ],
                {
                  'icon': Icons.person,
                  'label': 'Profile',
                  'route': AppConstants.profileRoute
                },
                {
                  'icon': Icons.admin_panel_settings,
                  'label': 'Admin',
                  'route': AppConstants.adminRoute,
                  'roleOnly': true
                },
                if (canClaimAdmin)
                  {
                    'icon': Icons.verified_user,
                    'label': 'Claim Admin Role (Temp)',
                    'action': 'claimAdminRole',
                  },
                {
                  'icon': Icons.auto_stories,
                  'label': 'Kids Stories',
                  'route': AppConstants.kidsStoriesRoute
                },
                {
                  'icon': Icons.library_books,
                  'label': 'Library',
                  'route': AppConstants.libraryRoute
                },
                {
                  'icon': Icons.headset,
                  'label': 'Podcasts',
                  'route': AppConstants.podcastsRoute
                },
                {
                  'icon': Icons.school,
                  'label': 'Lessons',
                  'route': AppConstants.interactiveLessonsRoute
                },
                {
                  'icon': Icons.menu_book,
                  'label': 'Tracts',
                  'route': AppConstants.booksTractsRoute
                },
                {
                  'icon': Icons.record_voice_over,
                  'label': 'Testimonies',
                  'route': AppConstants.testimoniesRoute
                },
                {
                  'icon': Icons.child_care,
                  'label': 'Kids Mission',
                  'route': AppConstants.kidsMissionRoute
                },
                {
                  'icon': Icons.login,
                  'label': 'Sign In',
                  'route': AppConstants.authRoute,
                  'guestOnly': true,
                },
              ];
              return GridView.builder(
                  padding: context.responsivePadding,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: context.responsivePadding.top,
                    crossAxisSpacing: context.responsivePadding.left,
                    childAspectRatio: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 1.1,
                      tablet: 1.0,
                      desktop: 0.95,
                    ),
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (item['guestOnly'] == true) {
                      return Consumer(builder: (context, ref, _) {
                        final authState = ref.watch(authStateProvider);
                        final isAuthenticated = authState.maybeWhen(
                          data: (user) => user != null,
                          orElse: () => false,
                        );
                        if (isAuthenticated) {
                          return const SizedBox.shrink();
                        }
                        return _buildMoreItem(
                          context,
                          item['icon'] as IconData,
                          item['label'] as String,
                          item['route'] as String?,
                        );
                      });
                    }
                    if (item['roleOnly'] == true) {
                      return RoleVisibility(
                        allowedRoles: const ['admin'],
                        child: _buildMoreItem(
                          context,
                          item['icon'] as IconData,
                          item['label'] as String,
                          item['route'] as String?,
                          roleOnly: true,
                        ),
                      );
                    }
                    if (item['allowedRoles'] is List) {
                      final allowedRoles = (item['allowedRoles'] as List)
                          .map((e) => e.toString())
                          .toList();
                      return RoleVisibility(
                        allowedRoles: allowedRoles,
                        child: _buildMoreItem(
                          context,
                          item['icon'] as IconData,
                          item['label'] as String,
                          item['route'] as String?,
                        ),
                      );
                    }
                    if (item['action'] == 'claimAdminRole') {
                      return _buildMoreItem(
                        context,
                        item['icon'] as IconData,
                        item['label'] as String,
                        null,
                        onTap: () => _claimAdminRole(context, ref),
                      );
                    }
                    return _buildMoreItem(
                      context,
                      item['icon'] as IconData,
                      item['label'] as String,
                      item['route'] as String?,
                    );
                  });
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreItem(
    BuildContext context,
    IconData icon,
    String label,
    String? route, {
    bool roleOnly = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        if (onTap != null) {
          onTap();
          return;
        }
        if (route != null) {
          context.go(route);
        }
      },
      borderRadius: context.responsiveBorderRadius,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.surface
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: context.responsiveBorderRadius,
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 51 / 255.0),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: context.responsiveIconSize(28),
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.primary,
                ),
                SizedBox(
                    height: context.getResponsiveValue(
                            mobile: 8.0, tablet: 12.0, desktop: 16.0) *
                        0.5),
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: context.responsiveFontSize(12),
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (roleOnly)
            Positioned(
              top: context.getResponsiveValue(
                  mobile: 6.0, tablet: 8.0, desktop: 10.0),
              right: context.getResponsiveValue(
                  mobile: 6.0, tablet: 8.0, desktop: 10.0),
              child: Container(
                padding: EdgeInsets.all(context.getResponsiveValue(
                    mobile: 4.0, tablet: 5.0, desktop: 6.0)),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock,
                  size: context.responsiveIconSize(14),
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _claimAdminRole(BuildContext context, WidgetRef ref) async {
    final translate = ref.read(languageProvider);
    try {
      final ok =
          await ref.read(firebaseDatabaseServiceProvider).claimAdminRole();
      if (!context.mounted) return;
      if (ok) {
        await FirebaseAuth.instance.currentUser?.getIdToken(true);
        if (!context.mounted) return;
        RoleAccessService.instance.clearCache();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(translate('admin_role_claimed')),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(translate('claim_failed')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(translate('could_not_claim_admin')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Widget _buildNavigationDrawer(BuildContext context, bool isAuthenticated) {
    return Consumer(
      builder: (context, ref, _) {
        final translate = ref.watch(languageProvider);
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
                      Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 204 / 255.0),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: context.responsiveIconSize(30),
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      child: Icon(
                        Icons.person,
                        size: context.responsiveIconSize(35),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    SizedBox(
                        height: context.getResponsiveValue(
                            mobile: 8.0, tablet: 12.0, desktop: 16.0)),
                    Text(
                      'ALIVE Nigeria',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: context.responsiveFontSize(20),
                              ),
                    ),
                    Text(
                      translate('christian_community'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimary
                                .withValues(alpha: 230 / 255.0),
                            fontSize: context.responsiveFontSize(14),
                          ),
                    ),
                  ],
                ),
              ),
              // Show approval status for unapproved users
              if (isAuthenticated && !canAccessRoleGated) ...[
                Container(
                  margin: context.responsiveMargin,
                  padding: context.responsivePadding,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: context.responsiveBorderRadius,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.pending_actions,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        size: context.responsiveIconSize(24),
                      ),
                      SizedBox(
                          width: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 8.0,
                        tablet: 10.0,
                        desktop: 12.0,
                      )),
                      Expanded(
                        child: Text(
                          'Account pending admin approval',
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w500,
                            fontSize: context.responsiveFontSize(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              _buildDrawerSection(context, translate('main_features'), [
                _buildDrawerItem(
                    context, Icons.home, 'Home', AppConstants.homeRoute),
                if (canAccessRoleGated) ...[
                  _buildDrawerItem(
                      context, Icons.book, 'Study', AppConstants.studyRoute),
                  _buildDrawerItem(context, Icons.favorite, 'Prayer',
                      AppConstants.prayerRoute),
                  _buildDrawerItem(context, Icons.health_and_safety, 'Health',
                      AppConstants.healthRoute),
                  _buildDrawerItem(context, Icons.calendar_today, 'Daily',
                      AppConstants.dailyRoute),
                ],
              ]),
              if (canAccessRoleGated) ...[
                const Divider(),
                _buildDrawerSection(context, translate('community'), [
                  _buildDrawerItem(context, Icons.volunteer_activism,
                      'Missions', AppConstants.missionsRoute),
                  _buildDrawerItem(
                      context, Icons.chat, 'Chat', AppConstants.chatRoute),
                  _buildDrawerItem(context, Icons.groups, 'Chapters',
                      AppConstants.chaptersRoute),
                  _buildDrawerItem(context, Icons.video_call, 'Conference',
                      AppConstants.conferenceRoute),
                ]),
                const Divider(),
                _buildDrawerSection(context, 'Tools & Games', [
                  _buildDrawerItem(context, Icons.games, 'Bible Game',
                      AppConstants.bibleGameRoute),
                  _buildDrawerItem(context, Icons.restaurant, 'Recipes',
                      AppConstants.recipesRoute),
                  _buildDrawerItem(context, Icons.add_circle, 'Submit Recipe',
                      AppConstants.recipeSubmissionRoute),
                ]),
              ],
              if (isAuthenticated && canAccessRoleGated) ...[
                const Divider(),
                RoleVisibility(
                  allowedRoles: const ['admin'],
                  child: _buildDrawerSection(context, 'Admin', [
                    _buildDrawerItem(context, Icons.admin_panel_settings,
                        'Dashboard', AppConstants.adminRoute),
                    _buildDrawerItem(context, Icons.approval, 'User Approval',
                        AppConstants.adminApprovalRoute),
                    _buildDrawerItem(context, Icons.people, 'BOD Trustees',
                        AppConstants.bodTrusteesRoute),
                    _buildDrawerItem(context, Icons.archive, 'User Archive',
                        AppConstants.userArchiveRoute),
                    _buildDrawerItem(context, Icons.security, 'Role Management',
                        AppConstants.roleManagementRoute),
                  ]),
                ),
              ],
              const Divider(),
              _buildDrawerSection(context, 'About', [
                _buildDrawerItem(context, Icons.info, 'About App',
                    AppConstants.aboutAppRoute),
                _buildDrawerItem(context, Icons.info_outline, 'About ALIVE',
                    AppConstants.aboutAliveRoute),
                _buildDrawerItem(context, Icons.person, 'Profile',
                    AppConstants.profileRoute),
              ]),
              const Divider(),
              _buildDrawerSection(context, 'Settings', [
                _buildThemeToggleDrawerItem(context, ref),
                _buildLanguageToggleDrawerItem(context, ref),
              ]),
              if (!isAuthenticated) ...[
                const Divider(),
                _buildDrawerSection(context, 'Account', [
                  _buildDrawerItem(
                      context, Icons.login, 'Sign In', AppConstants.authRoute),
                ]),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrawerSection(
      BuildContext context, String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: context.responsivePadding * 0.75,
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: context.responsiveFontSize(16.0) * 0.9,
                ),
          ),
        ),
        ...items,
      ],
    );
  }

  Widget _buildDrawerItem(
      BuildContext context, IconData icon, String title, String route) {
    final currentLocation =
        GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
    final isSelected = currentLocation == route;

    return ListTile(
      leading: Icon(
        icon,
        size: context.responsiveIconSize(24.0),
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 179 / 255.0),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          fontSize: context.responsiveFontSize(16.0),
        ),
      ),
      selected: isSelected,
      selectedTileColor:
          Theme.of(context).colorScheme.primary.withValues(alpha: 26 / 255.0),
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
    );
  }

  Widget _buildThemeToggleDrawerItem(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    IconData themeIcon;
    String themeText;

    switch (themeMode) {
      case ThemeMode.system:
        themeIcon = Icons.brightness_auto;
        themeText = 'Auto Theme';
        break;
      case ThemeMode.light:
        themeIcon = Icons.light_mode;
        themeText = 'Light Mode';
        break;
      case ThemeMode.dark:
        themeIcon = Icons.dark_mode;
        themeText = 'Dark Mode';
        break;
    }

    return ListTile(
      leading: Icon(
        themeIcon,
        size: context.responsiveIconSize(24.0),
        color: Theme.of(context)
            .colorScheme
            .onSurface
            .withValues(alpha: 179 / 255.0),
      ),
      title: Text(
        themeText,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: context.responsiveFontSize(16.0),
        ),
      ),
      onTap: () {
        Navigator.pop(context);
      },
    );
  }

  Widget _buildLanguageToggleDrawerItem(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(
        Icons.language,
        size: context.responsiveIconSize(24.0),
        color: Theme.of(context)
            .colorScheme
            .onSurface
            .withValues(alpha: 179 / 255.0),
      ),
      title: Text(
        'Language',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: context.responsiveFontSize(16.0),
        ),
      ),
      onTap: () {
        Navigator.pop(context);
      },
    );
  }
}
