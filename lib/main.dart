import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart' hide Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'providers/theme_provider.dart';
import 'utils/app_router.dart';
import 'utils/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'constants/app_constants.dart';
import 'providers/auth_provider.dart';
import 'providers/appwrite_auth_provider.dart';
import 'services/role_access_service.dart';
import 'utils/responsive_utils.dart';
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
import 'package:firebase_core/firebase_core.dart';
import 'config/payment_config.dart';
import 'services/notification_service.dart';
import 'widgets/app_tour/app_tour_service.dart';

export 'services/appwrite_client.dart';
import 'services/appwrite_client.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    if (!kIsWeb) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );
    }
    await CrashReportingService.instance.initialize();

    if (!kIsWeb) {
      try {
        await Firebase.initializeApp();
        debugPrint('Firebase initialized successfully for push transport.');
      } catch (e) {
        debugPrint('Firebase initialization failed: $e');
      }
    }

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

        try {
          await PaymentConfig.loadCachedPublicKey();
          PaymentConfig.syncPublicKeyFromAppwrite().catchError((_) => '');
        } catch (e) {
          debugPrint('Payment config initialization failed: $e');
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
      title: 'ALIVE Nigeria',
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
    ref.watch(authStateProvider);
    final translator = ref.watch(languageProvider);

    return Scaffold(
      drawerEnableOpenDragGesture: false,
      body: Stack(
        children: [
          child,
        ],
      ),
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
                ref.invalidate(currentUserProfileProvider);
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // The route is a transparent carrier only. The card is drawn once, in
      // `_buildMoreBottomSheet` below. Passing an empty shape + zero elevation
      // stops the global `bottomSheetTheme` shape from painting a second,
      // bordered container behind this one (the "ghost card"), and the theme
      // drag handle is disabled so there is only ever one grabber.
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(),
      elevation: 0,
      builder: (context) => SafeArea(
        top: true,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 640,
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            child: _buildMoreBottomSheet(context, ref),
          ),
        ),
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
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
                    'icon': Icons.medical_services_rounded,
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
                  'icon': Icons.explore_rounded,
                  'label': 'app_tour',
                  'onTap': () {
                    AppTourService.maybeStartTour(context, force: true);
                  },
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
}
