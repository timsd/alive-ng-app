import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart' hide Locale;
import 'config/development_config.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'providers/theme_provider.dart';
import 'utils/app_router.dart';
import 'utils/app_theme.dart';
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
import 'providers/language_provider.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/widget_localizations.dart';
import 'config/appwrite_backend_config.dart';
import 'services/analytics_service.dart';
import 'services/crash_reporting_service.dart';
import 'services/notification_service.dart';

// Global Appwrite service instances for provider access.
final appwriteClient = Client();
late final Account appwriteAccount;
late final Storage appwriteStorage;
late final Realtime appwriteRealtime;

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await CrashReportingService.instance.initialize();

    // Restore the preference before the first frame; ARB messages are compiled.
    try {
      await LocaleNotifier.loadSavedLocale();
    } catch (e) {
      debugPrint('I18n initialization failed: $e');
    }

    FlutterError.onError = (details) {
      debugPrint(details.exceptionAsString());
      CrashReportingService.instance.captureFlutterError(details);
    };

    var backendReady = false;
    try {
      appwriteClient
          .setEndpoint(AppwriteBackendConfig.endpoint)
          .setProject(AppwriteBackendConfig.projectId)
          .setSelfSigned(status: !kReleaseMode);

      appwriteAccount = Account(appwriteClient);
      appwriteStorage = Storage(appwriteClient);
      appwriteRealtime = Realtime(appwriteClient);

      backendReady = true;
      debugPrint('Self-hosted Appwrite initialized successfully.');
    } catch (e) {
      debugPrint('Backend initialization failed: $e');
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
      if (backendReady) {
        try {
          await AnalyticsService.instance.initialize();
        } catch (e) {
          debugPrint('Appwrite analytics initialization failed: $e');
        }

        try {
          await NotificationService.instance.initialize();
        } catch (e) {
          debugPrint('Notification initialization failed: $e');
        }
      } else {
        debugPrint(
          'Skipping Kids Content initialization: self-hosted server unreachable',
        );
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      InAppUpdateService.checkForUpdates();
    });
  }, (error, stack) {
    debugPrint('Unhandled: $error');
    CrashReportingService.instance.captureError(error, stack, fatal: true);
  });
}

class AliveApp extends ConsumerWidget {
  const AliveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);
    // Watching the locale provider makes the whole app rebuild whenever the
    // user picks a different language, so every screen switches at once.
    final currentLocale = ref.watch(localeProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('Post frame: MaterialApp.router');
    });

    return MaterialApp.router(
      title: 'ALIVE-NG APP',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,

      locale: currentLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        AppMaterialDelegate(),
        AppCupertinoDelegate(),
        GlobalWidgetsLocalizations.delegate,
      ],
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
        ],
      ),
      drawer: _buildNavigationDrawer(context, isAuthenticated),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _getCurrentIndex(currentLocation),
        onTap: (index) => _onItemTapped(context, ref, index),
        selectedItemColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.primary,
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
            icon: const FaIcon(FontAwesomeIcons.personPraying),
            activeIcon: const FaIcon(FontAwesomeIcons.personPraying),
            label: translator('prayer'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.health_and_safety_outlined),
            activeIcon: const Icon(Icons.health_and_safety),
            label: translator('health'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.grid_view_rounded),
            activeIcon: const Icon(Icons.grid_view_rounded),
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

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    final translate = ref.read(languageProvider);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(translate('sign_out')),
        content: Text(translate('sign_out_confirmation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              try {
                await ref.read(authGatewayProvider).signOut();
                if (context.mounted) {
                  context.go(AppConstants.authRoute);
                }
              } catch (_) {}
            },
            child: Text(translate('sign_out')),
          ),
        ],
      ),
    );
  }

  void _showMoreBottomSheet(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: _buildMoreBottomSheet(context, ref),
      ),
    );
  }

  Widget _buildMoreBottomSheet(BuildContext context, WidgetRef ref) {
    final translate = ref.watch(languageProvider);
    final roleService = RoleAccessService.instance;
    final canAccessRoleGated = roleService.canAccessRoleGatedFeatures();
    const crossAxisCount = 4;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text(
              translate('more_features'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
            ),
          ),
          if (!canAccessRoleGated) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.pending_actions,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      translate('account_pending_approval'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: Builder(builder: (context) {
              final items = <Map<String, dynamic>>[
                if (canAccessRoleGated) ...[
                  {
                    'icon': Icons.health_and_safety_rounded,
                    'label': 'Health+',
                    'route': AppConstants.enhancedHealthRoute
                  },
                  {
                    'icon': Icons.wb_sunny_rounded,
                    'label': 'daily',
                    'route': AppConstants.dailyRoute
                  },
                  {
                    'icon': Icons.explore_rounded,
                    'label': 'missions',
                    'route': AppConstants.missionsRoute
                  },
                  {
                    'icon': Icons.event_available_rounded,
                    'label': 'events',
                    'route': AppConstants.eventsRoute
                  },
                  {
                    'icon': Icons.sports_esports_rounded,
                    'label': 'bible_game',
                    'route': AppConstants.bibleGameRoute
                  },
                  {
                    'icon': Icons.forum_rounded,
                    'label': 'chat',
                    'route': AppConstants.chatRoute
                  },
                  {
                    'icon': Icons.diversity_3_rounded,
                    'label': 'chapters',
                    'route': AppConstants.chaptersRoute
                  },
                  {
                    'icon': Icons.video_call_rounded,
                    'label': 'alive_meet',
                    'route': AppConstants.conferenceRoute
                  },
                  {
                    'icon': Icons.shield_rounded,
                    'label': 'bod_trustees',
                    'route': AppConstants.bodTrusteesRoute,
                    'allowedRoles': ['admin', 'bod', 'trustee']
                  },
                ],
                {
                  'icon': Icons.menu_book_rounded,
                  'label': 'bible',
                  'route': AppConstants.bibleRoute,
                },
                {
                  'icon': Icons.account_circle_rounded,
                  'label': 'profile',
                  'route': AppConstants.profileRoute
                },
                {
                  'icon': Icons.admin_panel_settings_rounded,
                  'label': 'admin',
                  'route': AppConstants.adminRoute,
                  'roleOnly': true
                },
                {
                  'icon': Icons.auto_stories_rounded,
                  'label': 'kids_stories',
                  'route': AppConstants.kidsStoriesRoute
                },
                {
                  'icon': Icons.local_library_rounded,
                  'label': 'library',
                  'route': AppConstants.libraryRoute
                },
                {
                  'icon': Icons.podcasts_rounded,
                  'label': 'podcasts',
                  'route': AppConstants.podcastsRoute
                },
                {
                  'icon': Icons.school_rounded,
                  'label': 'lessons',
                  'route': AppConstants.interactiveLessonsRoute
                },
                {
                  'icon': Icons.library_books_rounded,
                  'label': 'tracts',
                  'route': AppConstants.booksTractsRoute
                },
                {
                  'icon': Icons.record_voice_over_rounded,
                  'label': 'testimonies',
                  'route': AppConstants.testimoniesRoute
                },
                {
                  'icon': Icons.emoji_events_rounded,
                  'label': 'kids_mission',
                  'route': AppConstants.kidsMissionRoute
                },
                {
                  'icon': Icons.help_outline_rounded,
                  'label': 'help_support',
                  'route': '/help-support',
                },
                {
                  'icon': Icons.info_outline_rounded,
                  'label': 'about_app',
                  'route': '/about-app',
                },
                {
                  'icon': Icons.info_rounded,
                  'label': 'about_alive',
                  'route': '/about-alive',
                },
                {
                  'icon': Icons.login_rounded,
                  'label': 'sign_in',
                  'route': AppConstants.authRoute,
                  'guestOnly': true,
                },
                {
                  'icon': Icons.logout_rounded,
                  'label': 'sign_out',
                  'authOnly': true,
                  'onTap': () => _showSignOutDialog(context, ref),
                },
              ];
              final authState = ref.watch(authStateProvider);
              final isAuthenticated = authState.maybeWhen(
                data: (user) => user != null,
                orElse: () => false,
              );
              final userRole = RoleAccessService.instance.getCurrentUserRole();

              final visibleItems = items.where((item) {
                if (item['guestOnly'] == true && isAuthenticated) {
                  return false;
                }
                if (item['authOnly'] == true && !isAuthenticated) {
                  return false;
                }
                if (item['roleOnly'] == true && userRole != 'admin') {
                  return false;
                }
                if (item['allowedRoles'] is List) {
                  final allowed = (item['allowedRoles'] as List)
                      .map((e) => e.toString())
                      .toList();
                  if (userRole == null || !allowed.contains(userRole)) {
                    return false;
                  }
                }
                return true;
              }).toList();

              return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.88,
                  ),
                  itemCount: visibleItems.length,
                  itemBuilder: (context, index) {
                    final item = visibleItems[index];
                    return _buildMoreItem(
                      context,
                      item['icon'] as IconData,
                      translate(item['label'] as String),
                      item['route'] as String?,
                      roleOnly: item['roleOnly'] == true,
                      onTap: item['onTap'] as VoidCallback?,
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
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.20)
                  : Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Stack(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: Theme.of(context).colorScheme.primary,
                ),
                if (roleOnly)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Icon(
                      Icons.lock,
                      size: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
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
                          translate('pending_admin_approval'),
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
                    context, Icons.home, translate('home'), AppConstants.homeRoute),
                if (canAccessRoleGated) ...[
                  _buildDrawerItem(
                      context, Icons.book, translate('study'), AppConstants.studyRoute),
                  _buildDrawerItem(context, Icons.favorite, translate('prayer'),
                      AppConstants.prayerRoute),
                  _buildDrawerItem(context, Icons.health_and_safety, translate('health'),
                      AppConstants.healthRoute),
                  _buildDrawerItem(context, Icons.calendar_today, translate('daily'),
                      AppConstants.dailyRoute),
                ],
              ]),
              if (canAccessRoleGated) ...[
                const Divider(),
                _buildDrawerSection(context, translate('community'), [
                  _buildDrawerItem(context, Icons.volunteer_activism,
                      translate('missions'), AppConstants.missionsRoute),
                  _buildDrawerItem(
                      context, Icons.chat, translate('chat'), AppConstants.chatRoute),
                  _buildDrawerItem(context, Icons.groups, translate('chapters'),
                      AppConstants.chaptersRoute),
                  _buildDrawerItem(context, Icons.video_call, translate('alive_meet'),
                      AppConstants.conferenceRoute),
                ]),
                const Divider(),
                _buildDrawerSection(context, translate('tools_games'), [
                  _buildDrawerItem(context, Icons.games, translate('bible_game'),
                      AppConstants.bibleGameRoute),
                  _buildDrawerItem(context, Icons.restaurant, translate('recipes'),
                      AppConstants.recipesRoute),
                  _buildDrawerItem(context, Icons.add_circle, translate('submit_recipe'),
                      AppConstants.recipeSubmissionRoute),
                ]),
              ],
              if (isAuthenticated && canAccessRoleGated) ...[
                const Divider(),
                if (roleService.canCreateContent())
                  _buildDrawerSection(context, translate('content_tools'), [
                    _buildDrawerItem(
                      context,
                      Icons.edit_note,
                      translate('content_management'),
                      AppConstants.contentManagementRoute,
                    ),
                  ]),
                if (roleService.canCreateContent()) const Divider(),
                RoleVisibility(
                  allowedRoles: const ['admin'],
                  child: _buildDrawerSection(context, translate('admin'), [
                    _buildDrawerItem(context, Icons.admin_panel_settings,
                        translate('dashboard'), AppConstants.adminRoute),
                    _buildDrawerItem(context, Icons.approval, translate('user_approval'),
                        AppConstants.adminApprovalRoute),
                    _buildDrawerItem(context, Icons.people, translate('bod_trustees'),
                        AppConstants.bodTrusteesRoute),
                    _buildDrawerItem(context, Icons.archive, translate('user_archive'),
                        AppConstants.userArchiveRoute),
                    _buildDrawerItem(context, Icons.security, translate('role_management'),
                        AppConstants.roleManagementRoute),
                  ]),
                ),
              ],
              const Divider(),
              _buildDrawerSection(context, translate('about'), [
                _buildDrawerItem(context, Icons.info, translate('about_app'),
                    AppConstants.aboutAppRoute),
                _buildDrawerItem(context, Icons.info_outline, translate('about_alive'),
                    AppConstants.aboutAliveRoute),
                _buildDrawerItem(context, Icons.person, translate('profile'),
                    AppConstants.profileRoute),
              ]),
              const Divider(),
              _buildDrawerSection(context, translate('settings'), [
                _buildThemeToggleDrawerItem(context, ref),
                _buildLanguageToggleDrawerItem(context, ref),
              ]),
              if (!isAuthenticated) ...[
                const Divider(),
                _buildDrawerSection(context, translate('account'), [
                  _buildDrawerItem(
                      context, Icons.login, translate('sign_in'), AppConstants.authRoute),
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
    final translate = ref.watch(languageProvider);

    IconData themeIcon;
    String themeText;

    switch (themeMode) {
      case ThemeMode.system:
        themeIcon = Icons.brightness_auto;
        themeText = translate('auto_theme');
        break;
      case ThemeMode.light:
        themeIcon = Icons.light_mode;
        themeText = translate('light_mode');
        break;
      case ThemeMode.dark:
        themeIcon = Icons.dark_mode;
        themeText = translate('dark_mode');
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
    final translate = ref.watch(languageProvider);
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
        translate('language'),
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
