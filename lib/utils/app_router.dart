import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/offline_bible_service.dart';
import '../screens/splash/animated_splash_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/oath/oath_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/study_guides/study_screen.dart';
import '../screens/daily/daily_screen.dart';
import '../screens/prayer/prayer_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/health/health_screen.dart';
import '../screens/missions/missions_screen.dart';
import '../screens/auth/appwrite_auth_screen.dart';
import '../services/office_access_service.dart';
import '../screens/auth/reset_password_screen.dart';
import '../main.dart';
import '../screens/about/about_app_screen.dart';
import '../screens/about/about_alive_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/content_management_screen.dart';
import '../screens/admin/admin_kids_stories_screen.dart';
import '../screens/admin/admin_kids_missions_screen.dart';
import '../screens/admin/chat_tag_management_screen.dart';
import '../screens/admin/admin_study_guides_screen.dart';
import '../screens/admin/tract_podcast_admin_screen.dart';
import '../screens/admin/meeting_file_sharing_screen.dart';
import '../screens/admin/bod_trustees_screen.dart';
import '../screens/admin/chapter_reports_screen.dart';
import '../screens/admin/user_archive_screen.dart';
import '../screens/admin/role_management_screen.dart';
import '../services/role_access_service.dart';
import '../providers/guest_provider.dart';
import '../screens/conference/conference_platform_screen.dart';
import '../screens/conference/livekit_meeting_screen.dart';
import '../config/meeting_links_config.dart';
import '../screens/admin/leader_meeting_transcription_screen.dart';
import '../screens/bible/bible_game_screen.dart';
import '../screens/bible/bible_reader_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/chapters/chapter_screen.dart';
import '../screens/health/enhanced_health_screen.dart';
import '../screens/health/recipe_submission_screen.dart';
import '../screens/kids/kids_mission_screen.dart';
import '../screens/prayer/prayer_wall_screen.dart';
import '../screens/prayer/private_prayer_room_screen.dart';
import '../screens/library/library_screen.dart';
import '../screens/podcasts/podcasts_screen.dart';
import '../screens/lessons/interactive_lessons_screen.dart';
import '../screens/tracts/tracts_screen.dart';
import '../screens/study_guides/study_guide_screen.dart';
import '../screens/kids/kids_stories_screen.dart';
import '../screens/discipleship/discipleship_screen.dart';
import '../screens/events/events_screen.dart';
import '../screens/admin/admin_approval_screen.dart';
import '../screens/admin/admin_donations_report_screen.dart';
import '../screens/admin/admin_health_content_screen.dart';
import '../screens/admin/admin_billboard_screen.dart';
import '../screens/admin/admin_approval_link_handler_screen.dart';
import '../screens/help/help_support_screen.dart';
import '../screens/settings/notification_settings_screen.dart';
import '../screens/testimonies/testimonies_screen.dart';
import '../screens/donation/donation_screen.dart';
import '../screens/donation/project_3d_viewer_screen.dart';
import '../screens/donation/gift_in_kind_form_screen.dart';
import '../screens/donation/non_monetary_gift_form_screen.dart';
import '../screens/achievements/achievement_screen.dart';
import '../constants/app_constants.dart';
import '../services/onboarding_service.dart';
import '../utils/web_launch_params.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_setup_provider.dart';
import '../utils/navigation_keys.dart';

// New screen imports
import '../screens/admin/leadership_archive_screen.dart';
import '../screens/admin/video_content_admin_screen.dart';
import '../screens/profile/profile_completion_screen.dart';
import '../screens/payment/payment_callback_screen.dart';

const bool kMinimalRouterMode = false;

// Helper function to determine if a route is accessible to guest users
bool _isGuestAccessibleRoute(String path) {
  final normalized = path.length > 1 && path.endsWith('/') ? path.substring(0, path.length - 1) : path;
  const guestAccessibleRoutes = [
    '/onboarding',
    '/oath',
    '/home',
    '/study',
    '/study-guide',
    '/daily',
    '/health',
    '/enhanced-health',
    '/about-app',
    '/about-alive',
    '/bible',
    '/bible-game',
    '/kids-mission',
    '/recipes',
    '/healthy-recipes',
    '/library',
    '/podcasts',
    '/interactive-lessons',
    '/books-tracts',
    '/tracts',
    '/kids-stories',
    '/testimonies',
    '/help-support',
    '/donation',
    '/donate',
    '/project-3d-viewer',
    '/alive_ng_3d_viewer.html',
    '/billboard',
    '/showcase',
    '/payment/callback',
    '/payment-callback',
    '/gift-in-kind',
    '/non-monetary-gift',
    '/admin-approve',
    '/reset-password',
    '/meet',
    '/conference',
    '/events',
    '/announcements',
    '/announcement',
    '/prayer',
    '/prayer-wall',
    '/prayer-requests',
    '/achievements',
  ];

  if (guestAccessibleRoutes.contains(path) ||
      guestAccessibleRoutes.contains(normalized)) {
    return true;
  }
  if (normalized.startsWith('/prayer-requests/')) {
    return true;
  }
  return false;
}

/// Captures the initial incoming deep link from either `sessionStorage['start_route']`
/// (saved by `web/index.html` before Flutter boots) or `Uri.base` (before `GoRouter`
/// replaces the browser URL with `initialLocation: '/'`).
String? _extractStartupDeepLink() {
  try {
    final fromStorage = getInitialRoute()?.trim();
    if (fromStorage != null &&
        fromStorage.isNotEmpty &&
        fromStorage != '/' &&
        fromStorage != AppConstants.splashRoute &&
        fromStorage != AppConstants.authRoute &&
        fromStorage != AppConstants.onboardingRoute) {
      return fromStorage;
    }
  } catch (_) {}

  try {
    final base = Uri.base;
    if (base.fragment.startsWith('/') && base.fragment.length > 1) {
      final frag = base.fragment;
      if (frag != AppConstants.splashRoute &&
          frag != AppConstants.authRoute &&
          frag != AppConstants.onboardingRoute) {
        return frag;
      }
    }
    final path = base.path;
    if (path.isNotEmpty &&
        path != '/' &&
        !path.endsWith('.html') &&
        !path.contains(':') &&
        path != AppConstants.splashRoute &&
        path != AppConstants.authRoute &&
        path != AppConstants.onboardingRoute) {
      return base.hasQuery ? '$path?${base.query}' : path;
    }
  } catch (_) {}

  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  if (kMinimalRouterMode) {
    debugPrint('Using minimal router mode');
    return GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) {
            debugPrint('Minimal route build: /home');
            return const Scaffold(
              body: Center(
                child: Text('Minimal Home'),
              ),
            );
          },
        ),
      ],
    );
  }

  final refresh = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, next) {
    final signedInUser = next.valueOrNull;
    if (signedInUser != null && ref.read(isGuestModeProvider)) {
      ref.read(isGuestModeProvider.notifier).state = false;
    }
    refresh.value++;
  });
  ref.onDispose(refresh.dispose);
  String? lastRouterUri;
  String? pendingStartupDeepLink = _extractStartupDeepLink();
  const String lastActiveRouteKey = 'last_active_route';

  bool isPersistableRoute(String path) {
    if (path.isEmpty || path == '/') return false;
    const excluded = <String>{
      AppConstants.splashRoute,
      AppConstants.authRoute,
      AppConstants.onboardingRoute,
      AppConstants.resetPasswordRoute,
      '/oath',
      '/profile-completion',
      '/admin-approve',
      '/payment/callback',
      '/payment-callback',
      '/meet',
      '/conference',
    };
    if (path.startsWith('/meet/')) return false;
    return !excluded.contains(path);
  }

  Future<void> saveLastActiveRoute(String uri) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(lastActiveRouteKey, uri);
    } catch (_) {}
  }

  Future<void> clearLastActiveRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(lastActiveRouteKey);
    } catch (_) {}
  }

  return GoRouter(
    refreshListenable: refresh,
    navigatorKey: rootNavigatorKey,
    // Always start from splash so web/mobile behavior is consistent.
    initialLocation: AppConstants.splashRoute,
    redirect: (context, state) async {
      // Rewrite custom scheme payment callback (`aliveng://payment.callback?reference=...`)
      if (state.uri.scheme == 'aliveng' && state.uri.host == 'payment.callback') {
        final q = state.uri.hasQuery ? '?${state.uri.query}' : '';
        return '/payment/callback$q';
      }
      final currentUri = state.uri.toString();
      if (lastRouterUri != null && lastRouterUri != currentUri) {
        WidgetsBinding.instance.addPostFrameCallback((_) => dismissActivePopups());
      }
      lastRouterUri = currentUri;
      debugPrint('Router redirect start: ${state.uri.path}');
      final currentUser = ref.read(authGatewayProvider).currentUser;
      final isAuthenticated = currentUser != null;
      if (isAuthenticated) {
        unawaited(OfflineBibleService().prewarmBundle());
        if (isPersistableRoute(state.uri.path)) {
          unawaited(saveLastActiveRoute(currentUri));
        }
      } else if (state.uri.path == AppConstants.authRoute) {
        unawaited(clearLastActiveRoute());
      }
      try {
        debugPrint('Auth state: authenticated=$isAuthenticated');
      } catch (e) {
        debugPrint('Auth state read failed: $e');
      }

      final isAuthRoute = state.uri.path == AppConstants.authRoute;
      final isSplashRoute = state.uri.path == AppConstants.splashRoute;
      final isOnboardingRoute = state.uri.path == AppConstants.onboardingRoute;
      final isGuestAccessibleRoute = _isGuestAccessibleRoute(state.uri.path);
      // Removed unused variable: hasAccess
      String? selectedProjectId;
      String? postAuthRedirect;
      try {
        selectedProjectId = getSelectedProjectId();
        postAuthRedirect = getPostAuthRedirect();
        debugPrint(
            'Launch params: selectedProjectId=$selectedProjectId, postAuthRedirect=$postAuthRedirect');
      } catch (e) {
        debugPrint('Launch params read failed: $e');
      }

      // Allow splash screen to show initially
      if (isSplashRoute) {
        debugPrint('Allow splash route');
        return null;
      }

      // Allow onboarding route before authentication; signed-in users proceed straight to home.
      if (isOnboardingRoute) {
        if (isAuthenticated) {
          return AppConstants.homeRoute;
        }
        debugPrint('Allow onboarding route');
        return null;
      }

      // Allow guest-accessible shared deep links (everything except '/home')
      // even if the visitor has not yet completed onboarding, so clicking a
      // shared podcast, tract, Bible verse, meeting, or event link opens the
      // shared destination directly.
      if (!isAuthenticated &&
          isGuestAccessibleRoute &&
          state.uri.path != AppConstants.homeRoute &&
          state.uri.path != AppConstants.onboardingRoute) {
        debugPrint('Allow direct guest deep link: ${state.uri}');
        return null;
      }

      // If onboarding hasn't been completed and user is not authenticated,
      // route to onboarding first so visitors get the Onboarding -> Oath -> Auth flow
      // (while preserving direct deep links like password reset or admin approval).
      if (!isAuthenticated &&
          !OnboardingService.isCompleted &&
          state.uri.path != '/oath' &&
          state.uri.path != '/admin-approve' &&
          state.uri.path != AppConstants.donationRoute &&
          state.uri.path != '/donate' &&
          state.uri.path != AppConstants.resetPasswordRoute &&
          state.uri.path != AppConstants.authRoute) {
        final target = state.uri.toString();
        if (target.isNotEmpty &&
            target != '/' &&
            target != AppConstants.homeRoute &&
            target != AppConstants.splashRoute) {
          setPostAuthRedirect(target);
        }
        debugPrint('Unauthenticated visitor: redirecting to onboarding');
        return AppConstants.onboardingRoute;
      }

      // Allow guest-accessible routes for unauthenticated users.
      if (!isAuthenticated && isGuestAccessibleRoute) {
        debugPrint('Route is guest accessible: ${state.uri.path}');
        return null;
      }

      // Check before allowing any main-app route, including post-auth links.
      // Skip async provider await immediately if already cached for this session.
      if (currentUser != null &&
          state.uri.path != '/profile-completion' &&
          !ProfileSetupCache.isCompleted(currentUser.uid)) {
        try {
          final required = await ref
              .read(profileSetupRequiredProvider(currentUser.uid).future)
              .timeout(const Duration(seconds: 4), onTimeout: () => false);
          if (required) return '/profile-completion';
        } catch (e) {
          debugPrint('Profile check failed; open setup for retry: $e');
          return '/profile-completion';
        }
      }

      // Authenticated users can access non-auth routes.
      if (isAuthenticated && !isAuthRoute) {
        if (state.uri.path == '/profile-completion') {
          return null;
        }
        // Enforce guest restrictions only for accounts explicitly assigned the 'guest' role
        final userRole = RoleAccessService.instance.getCurrentUserRole();
        final isGuest = userRole == 'guest';
        if (isGuest && !isGuestAccessibleRoute) {
          debugPrint('Guest user restricted from protected route: ${state.uri.path}, redirecting to home');
          return AppConstants.homeRoute;
        }
        debugPrint('Authenticated; allow route: ${state.uri.path}');
        return null;
      }

      // Password reset must be reachable while signed out -- that is the whole
      // point of the link, since a member who forgot their password cannot be
      // logged in. The old check redirected every unauthenticated visitor away
      // from any non-auth route, so /reset-password bounced to /auth and the
      // recovery screen never rendered, no matter how good the link was.
      if (!isAuthenticated &&
          !isAuthRoute &&
          state.uri.path != AppConstants.resetPasswordRoute) {
        final target = state.uri.toString();
        if (target.isNotEmpty &&
            target != '/' &&
            target != AppConstants.authRoute &&
            target != AppConstants.splashRoute) {
          setPostAuthRedirect(target);
        }
        debugPrint('Unauthenticated; saved target: $target; redirect to auth');
        return AppConstants.authRoute;
      }

      // If authenticated and on auth route, redirect to target or home
      if (isAuthenticated && isAuthRoute) {
        final pendingRedirect = getPostAuthRedirect();
        if (pendingRedirect != null && pendingRedirect.isNotEmpty) {
          clearPostAuthRedirect();
          debugPrint('Post-auth redirect to: $pendingRedirect');
          return pendingRedirect;
        }
        if (selectedProjectId != null) {
          debugPrint('Selected project present; redirect to donation');
          return AppConstants.donationRoute;
        }
        debugPrint('Default post-auth redirect: home');
        return AppConstants.homeRoute;
      }

      return null; // No redirect needed
    },
    routes: [
      // Splash Route
      GoRoute(
        path: AppConstants.splashRoute,
        builder: (context, state) => AnimatedSplashScreen(
          onAnimationComplete: () async {
            final isAuthenticated =
                ref.read(authGatewayProvider).currentUser != null;

            // 1. Check if the app was launched via a shared deep link!
            final incomingDeepLink = pendingStartupDeepLink ??
                getInitialRoute() ??
                getPostAuthRedirect();
            pendingStartupDeepLink = null;
            clearInitialRoute();

            if (incomingDeepLink != null &&
                incomingDeepLink.trim().isNotEmpty &&
                incomingDeepLink.trim() != '/' &&
                incomingDeepLink.trim() != AppConstants.splashRoute &&
                incomingDeepLink.trim() != AppConstants.authRoute &&
                incomingDeepLink.trim() != AppConstants.onboardingRoute) {
              final deepLink = incomingDeepLink.trim();
              final parsedUri = Uri.tryParse(deepLink);
              final deepLinkPath = parsedUri?.path ?? deepLink;

              if (isAuthenticated || _isGuestAccessibleRoute(deepLinkPath)) {
                clearPostAuthRedirect();
                if (!isAuthenticated) {
                  ref.read(isGuestModeProvider.notifier).state = true;
                }
                if (!context.mounted) return;
                context.go(deepLink);
                return;
              } else {
                // Protected deep link while unauthenticated: save it so after
                // login the user lands on their shared destination.
                setPostAuthRedirect(deepLink);
              }
            }

            if (isAuthenticated) {
              String targetRoute = AppConstants.homeRoute;
              try {
                final prefs = await SharedPreferences.getInstance();
                final savedRoute = prefs.getString(lastActiveRouteKey);
                if (savedRoute != null &&
                    savedRoute.isNotEmpty &&
                    savedRoute != '/' &&
                    savedRoute != AppConstants.splashRoute) {
                  targetRoute = savedRoute;
                }
              } catch (_) {}
              if (!context.mounted) return;
              context.go(targetRoute);
              return;
            }
            bool show = true;
            try {
              show = await OnboardingService.shouldShowOnboarding()
                  .timeout(const Duration(seconds: 2), onTimeout: () => true);
            } catch (e) {
              debugPrint('Onboarding check failed; defaulting to onboarding: $e');
              show = true;
            }
            if (!context.mounted) return;
            final nextRoute = show
                ? AppConstants.onboardingRoute
                : AppConstants.authRoute;
            context.go(nextRoute);
          },
        ),
      ),

      // Auth Route
      GoRoute(
        path: AppConstants.authRoute,
        builder: (context, state) {
          debugPrint('Route build: /auth');
          return const AppwriteAuthScreen();
        },
      ),

      GoRoute(
        path: AppConstants.resetPasswordRoute,
        builder: (context, state) {
          // Appwrite's own recovery mail and branded mail can both arrive, and
          // links may be formatted either with standard query string or fragment:
          // 1. https://app.alivenigeria.org/reset-password?userId=..&secret=..
          // 2. https://app.alivenigeria.org/#/reset-password?userId=..&secret=..
          // 3. https://app.alivenigeria.org/?userId=..&secret=..#/reset-password
          final query = state.uri.queryParameters;
          final fragment = state.uri.fragment;
          final fromFragment = fragment.contains('?')
              ? Uri.splitQueryString(fragment.split('?').last)
              : const <String, String>{};

          final baseQuery = Uri.base.queryParameters;
          final baseFrag = Uri.base.fragment;
          final fromBaseFrag = baseFrag.contains('?')
              ? Uri.splitQueryString(baseFrag.split('?').last)
              : const <String, String>{};

          final resolvedUserId = query['userId'] ??
              query['user_id'] ??
              query['id'] ??
              fromFragment['userId'] ??
              fromFragment['user_id'] ??
              fromFragment['id'] ??
              baseQuery['userId'] ??
              baseQuery['user_id'] ??
              baseQuery['id'] ??
              fromBaseFrag['userId'] ??
              fromBaseFrag['user_id'] ??
              fromBaseFrag['id'];

          final resolvedSecret = query['secret'] ??
              query['token'] ??
              fromFragment['secret'] ??
              fromFragment['token'] ??
              baseQuery['secret'] ??
              baseQuery['token'] ??
              fromBaseFrag['secret'] ??
              fromBaseFrag['token'];

          return ResetPasswordScreen(
            userId: resolvedUserId,
            secret: resolvedSecret,
          );
        },
      ),

      // Admin approval-link route (email link handler)
      GoRoute(
        path: AppConstants.adminApprovalLinkRoute,
        builder: (context, state) => const AdminApprovalLinkHandlerScreen(),
      ),

      // Onboarding Route
      GoRoute(
        path: AppConstants.onboardingRoute,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppConstants.oathRoute,
        builder: (context, state) => const OathScreen(),
      ),

      // Profile Completion Route — shown after Google sign-in for new users
      GoRoute(
        path: AppConstants.profileCompletionRoute,
        builder: (context, state) => const ProfileCompletionScreen(),
      ),

      // Main Navigation Shell Route
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) {
          return MainNavigationScreen(child: child);
        },
        routes: [
          // Home Route
          GoRoute(
            path: AppConstants.homeRoute,
            builder: (context, state) => const HomeScreen(),
          ),

          // Study Route
          GoRoute(
            path: AppConstants.studyRoute,
            builder: (context, state) => const StudyScreen(),
          ),

          // Daily Route
          GoRoute(
            path: AppConstants.dailyRoute,
            builder: (context, state) => const DailyScreen(),
          ),

          // Prayer Route
          GoRoute(
            path: AppConstants.prayerRoute,
            builder: (context, state) => const PrayerScreen(),
          ),

          // Profile Route
          GoRoute(
            path: AppConstants.profileRoute,
            builder: (context, state) => const ProfileScreen(),
          ),

          // Health Route
          GoRoute(
            path: AppConstants.healthRoute,
            builder: (context, state) {
              final day = int.tryParse(state.uri.queryParameters['day'] ?? '');
              return HealthScreen(initialDay: day);
            },
          ),

          // Missions Route
          GoRoute(
            path: AppConstants.missionsRoute,
            builder: (context, state) => const MissionsScreen(),
          ),

          // About App Route
          GoRoute(
            path: AppConstants.aboutAppRoute,
            builder: (context, state) => const AboutAppScreen(),
          ),

          // About ALIVE Route
          GoRoute(
            path: AppConstants.aboutAliveRoute,
            builder: (context, state) => const AboutAliveScreen(),
          ),

          // Leadership Reports Route
          GoRoute(
            path: AppConstants.leadershipReportsRoute,
            builder: (context, state) => const ChapterReportsScreen(),
            redirect: (context, state) {
              final roleService = RoleAccessService.instance;
              if (!roleService.canAccessRoleGatedFeatures()) {
                return AppConstants.homeRoute;
              }
              if (roleService.canAccessAdmin() || roleService.isSuperAdmin()) {
                return null;
              }
              final role = (roleService.getCurrentUserRole() ?? '').toLowerCase();
              const leadershipTokens = [
                'coordinator',
                'director',
                'executive',
                'president',
                'bod',
                'trustee',
                'leader',
              ];
              final isAllowed = leadershipTokens.any((t) => role.contains(t));
              return isAllowed ? null : AppConstants.homeRoute;
            },
          ),
          GoRoute(
            path: '/hierarchical-reports',
            redirect: (context, state) => AppConstants.leadershipReportsRoute,
          ),

          // Admin Dashboard Route
          GoRoute(
            path: AppConstants.adminRoute,
            builder: (context, state) => const AdminDashboardScreen(),
            redirect: (context, state) {
              final roleService = RoleAccessService.instance;
              if (!roleService.canAccessAdmin()) {
                return '/home';
              }
              return null;
            },
          ),

          GoRoute(
            path: AppConstants.contentManagementRoute,
            builder: (context, state) => ContentManagementScreen(
              contentType: state.uri.queryParameters['type'],
            ),
            redirect: (context, state) {
              final roleService = RoleAccessService.instance;
              if (!roleService.canAccessRoleGatedFeatures() ||
                  !roleService.canCreateContent()) {
                return AppConstants.homeRoute;
              }
              return null;
            },
          ),
          GoRoute(
            path: '/content',
            redirect: (context, state) => AppConstants.contentManagementRoute,
          ),

          // Tract & Podcast Admin Route
          GoRoute(
            path: AppConstants.tractPodcastAdminRoute,
            builder: (context, state) => const TractPodcastAdminScreen(),
            redirect: (context, state) {
              final roleService = RoleAccessService.instance;
              if (!roleService.canAccessAdmin()) {
                return '/home';
              }
              return null;
            },
          ),
          GoRoute(
            path: '/tract-management',
            redirect: (context, state) => AppConstants.tractPodcastAdminRoute,
          ),
          GoRoute(
            path: '/podcast-management',
            redirect: (context, state) => AppConstants.tractPodcastAdminRoute,
          ),

          // Meeting File Sharing Route
          GoRoute(
            path: AppConstants.meetingFileSharingRoute,
            builder: (context, state) => const MeetingFileSharingScreen(),
            redirect: (context, state) {
              final roleService = RoleAccessService.instance;
              if (!roleService.canAccessBoardDocuments()) {
                return '/home';
              }
              return null;
            },
          ),
          GoRoute(
            path: '/meeting-files',
            redirect: (context, state) => AppConstants.meetingFileSharingRoute,
          ),

          // Board of Directors Route
          GoRoute(
            path: AppConstants.bodRoute,
            builder: (context, state) => const BodTrusteesScreen(),
            redirect: (context, state) {
              final roleService = RoleAccessService.instance;
              if (!roleService.canAccessBoardDocuments()) {
                return '/home';
              }
              return null;
            },
          ),
          GoRoute(
            path: '/board',
            redirect: (context, state) => AppConstants.bodRoute,
          ),
          GoRoute(
            path: '/admin/board-decisions',
            redirect: (context, state) => AppConstants.bodRoute,
          ),

          // User Archive Route
          GoRoute(
            path: AppConstants.userArchiveRoute,
            builder: (context, state) => const UserArchiveScreen(),
            redirect: (context, state) {
              final roleService = RoleAccessService.instance;
              if (!roleService.canAccessUserArchives()) {
                return '/home';
              }
              return null;
            },
          ),

          // Role Management Route
          GoRoute(
            path: AppConstants.roleManagementRoute,
            builder: (context, state) => const RoleManagementScreen(),
            redirect: (context, state) {
              final roleService = RoleAccessService.instance;
              if (!roleService.canManageRoles()) {
                return '/home';
              }
              return null;
            },
          ),

          // Admin Approval Route
          GoRoute(
            path: AppConstants.adminApprovalRoute,
            builder: (context, state) => const AdminApprovalScreen(),
            redirect: (context, state) {
              final roleService = RoleAccessService.instance;
              if (!roleService.canAccessAdmin()) {
                return '/home';
              }
              return null;
            },
          ),

          // Admin Donations Report Route
          GoRoute(
            path: AppConstants.adminDonationsReportRoute,
            builder: (context, state) => const AdminDonationsReportScreen(),
            // Hiding the dashboard tile is not enough on its own: the route
            // is reachable by URL. The report exposes every gift, so it is
            // guarded on the same financial office as the section that links
            // to it. An admin passes, since they may need it to repair data.
            redirect: (context, state) async {
              final roleService = RoleAccessService.instance;
              if (roleService.hasRole('admin')) return null;

              final user = ref.read(authGatewayProvider).currentUser;
              if (user == null) return '/home';
              try {
                final allowed = await OfficeAccessService.instance
                    .canAccessFinance(userId: user.uid, email: user.email);
                return allowed ? null : '/home';
              } catch (_) {
                // Fail closed: an unreadable office table must not open the
                // finance report.
                return '/home';
              }
            },
          ),

          // Admin Health+ Content Route
          GoRoute(
            path: AppConstants.adminHealthContentRoute,
            builder: (context, state) => const AdminHealthContentScreen(),
            redirect: (context, state) {
              final roleService = RoleAccessService.instance;
              if (!roleService.canAccessAdmin() &&
                  !roleService.canManageHealthContent()) {
                return '/home';
              }
              return null;
            },
          ),

          // Conference Platform Route & Direct Meeting Join Alias
          GoRoute(
            path: AppConstants.conferenceRoute,
            builder: (context, state) {
              final room = state.uri.queryParameters['room'];
              if (room != null && room.isNotEmpty) {
                return LiveKitMeetingScreen(customRoomName: room);
              }
              return const ConferencePlatformScreen();
            },
          ),
          GoRoute(
            path: AppConstants.meetRoute,
            builder: (context, state) {
              final room = state.uri.queryParameters['room'] ?? AliveMeetConfig.communityRoom;
              return LiveKitMeetingScreen(customRoomName: room);
            },
          ),

          // Leader Scribe & Meeting Notes Route
          GoRoute(
            path: AppConstants.scribeRoute,
            builder: (context, state) => const LeaderMeetingTranscriptionScreen(),
            redirect: (context, state) {
              final roleService = RoleAccessService.instance;
              if (!roleService.canAccessAdmin() &&
                  !roleService.canStartConferencing() &&
                  !roleService.canAccessBoardDocuments()) {
                return '/home';
              }
              return null;
            },
          ),

          // Bible Game Route
          GoRoute(
            path: AppConstants.bibleGameRoute,
            builder: (context, state) => const BibleGameScreen(),
          ),

          // Bible Reader Route
          GoRoute(
            path: AppConstants.bibleRoute,
            builder: (context, state) {
              final qp = state.uri.queryParameters;
              final tab = qp['tab'];
              String? refParam = qp['ref'] ?? qp['reference'];
              if ((refParam == null || refParam.trim().isEmpty) &&
                  qp['book'] != null &&
                  qp['book']!.trim().isNotEmpty) {
                final book = qp['book']!.trim();
                final chapter = qp['chapter']?.trim() ?? '1';
                final verse = qp['verse']?.trim();
                refParam = (verse != null && verse.isNotEmpty)
                    ? '$book $chapter:$verse'
                    : '$book $chapter';
              }
              return BibleReaderScreen(
                initialReference: refParam,
                initialTab: tab == 'study' ? 2 : (tab == 'search' ? 1 : 0),
              );
            },
          ),

          // Chat Route (Auth Required)
          GoRoute(
            path: AppConstants.chatRoute,
            builder: (context, state) {
              final channelId = state.uri.queryParameters['channelId'];
              return ChatScreen(channelId: channelId);
            },
          ),

          // Chapters Route (Auth Required)
          GoRoute(
            path: AppConstants.chaptersRoute,
            builder: (context, state) => const ChapterScreen(),
          ),

          // Enhanced Health Route (Auth Required - includes recipes)
          GoRoute(
            path: AppConstants.enhancedHealthRoute,
            builder: (context, state) => const EnhancedHealthScreen(),
          ),

          // Recipe Submission Route (Auth Required)
          GoRoute(
            path: AppConstants.recipeSubmissionRoute,
            builder: (context, state) => const RecipeSubmissionScreen(),
          ),

          // Kids Mission Route
          GoRoute(
            path: AppConstants.kidsMissionRoute,
            builder: (context, state) => const KidsMissionScreen(),
          ),

          // Prayer Wall Route
          GoRoute(
            path: AppConstants.prayerWallRoute,
            builder: (context, state) {
              final prayerId = state.uri.queryParameters['prayerId'] ??
                  state.uri.queryParameters['id'];
              return PrayerWallScreen(initialPrayerId: prayerId);
            },
          ),
          GoRoute(
            path: '/prayer-requests',
            redirect: (context, state) {
              final id = state.uri.queryParameters['prayerId'] ??
                  state.uri.queryParameters['id'];
              return (id != null && id.isNotEmpty)
                  ? '${AppConstants.prayerWallRoute}?prayerId=${Uri.encodeComponent(id)}'
                  : AppConstants.prayerWallRoute;
            },
          ),
          GoRoute(
            path: '/prayer-requests/:id',
            redirect: (context, state) {
              final id = state.pathParameters['id'];
              return (id != null && id.isNotEmpty)
                  ? '${AppConstants.prayerWallRoute}?prayerId=${Uri.encodeComponent(id)}'
                  : AppConstants.prayerWallRoute;
            },
          ),

          // Private Prayer Room Route
          GoRoute(
            path: AppConstants.privatePrayerRoomRoute,
            builder: (context, state) => const PrivatePrayerRoomScreen(),
          ),

          // Library Route
          GoRoute(
            path: AppConstants.libraryRoute,
            builder: (context, state) => const LibraryScreen(),
          ),

          // Podcasts Route
          GoRoute(
            path: AppConstants.podcastsRoute,
            builder: (context, state) {
              final episodeId = state.uri.queryParameters['episodeId'];
              final podcastId = state.uri.queryParameters['podcastId'];
              return PodcastsScreen(
                initialEpisodeId: episodeId,
                initialPodcastId: podcastId,
              );
            },
          ),

          // Interactive Lessons Route
          GoRoute(
            path: AppConstants.interactiveLessonsRoute,
            builder: (context, state) => const InteractiveLessonsScreen(),
          ),

          // Tracts Route & Alias
          GoRoute(
            path: AppConstants.tractsRoute,
            builder: (context, state) {
              final tabParam = state.uri.queryParameters['tab'];
              final initialTab =
                  (tabParam == 'downloaded' || tabParam == '1') ? 1 : 0;
              final tractId = state.uri.queryParameters['tractId'] ??
                  state.uri.queryParameters['id'];
              return TractsScreen(
                initialTabIndex: initialTab,
                initialTractId: tractId,
              );
            },
          ),
          GoRoute(
            path: AppConstants.booksTractsRoute,
            redirect: (context, state) {
              final query = state.uri.query;
              return query.isNotEmpty
                  ? '${AppConstants.tractsRoute}?$query'
                  : AppConstants.tractsRoute;
            },
          ),

          // Payment Callback Route & Alias
          GoRoute(
            path: AppConstants.paymentCallbackRoute,
            builder: (context, state) {
              final ref = state.uri.queryParameters['reference'] ??
                  state.uri.queryParameters['trxref'];
              return PaymentCallbackScreen(reference: ref);
            },
          ),
          GoRoute(
            path: '/payment-callback',
            redirect: (context, state) {
              final ref = state.uri.queryParameters['reference'] ??
                  state.uri.queryParameters['trxref'];
              return ref != null
                  ? '${AppConstants.paymentCallbackRoute}?reference=$ref'
                  : AppConstants.paymentCallbackRoute;
            },
          ),

          // Kids Stories Route
          GoRoute(
            path: AppConstants.kidsStoriesRoute,
            builder: (context, state) => const KidsStoriesScreen(),
          ),

          // Discipleship Tracker Route & Alias
          GoRoute(
            path: AppConstants.discipleshipTrackerRoute,
            builder: (context, state) => const DiscipleshipScreen(),
          ),
          GoRoute(
            path: '/discipleship',
            redirect: (context, state) => AppConstants.discipleshipTrackerRoute,
          ),
          GoRoute(
            path: '/more',
            redirect: (context, state) => AppConstants.homeRoute,
          ),

          // Events & Announcements Routes
          GoRoute(
            path: AppConstants.eventsRoute,
            builder: (context, state) => EventsScreen(
              initialTab: state.uri.queryParameters['tab'] ?? 'events',
              initialItemId: state.uri.queryParameters['id'],
            ),
          ),
          GoRoute(
            path: AppConstants.announcementsRoute,
            builder: (context, state) => EventsScreen(
              initialTab: 'announcements',
              initialItemId: state.uri.queryParameters['id'],
            ),
          ),
          GoRoute(
            path: '/announcement',
            redirect: (context, state) {
              final query = state.uri.query;
              return query.isNotEmpty
                  ? '${AppConstants.announcementsRoute}?$query'
                  : AppConstants.announcementsRoute;
            },
          ),

          // Help & Support Route
          GoRoute(
            path: AppConstants.helpSupportRoute,
            builder: (context, state) => const HelpSupportScreen(),
          ),

          // Notification Settings Route
          GoRoute(
            path: AppConstants.notificationSettingsRoute,
            builder: (context, state) => const NotificationSettingsScreen(),
            redirect: (context, state) {
              // Protect notification settings for unauthenticated users
              final user = ref.read(authGatewayProvider).currentUser;
              if (user == null) {
                return AppConstants.authRoute;
              }
              return null;
            },
          ),

          // Testimonies Route
          GoRoute(
            path: AppConstants.testimoniesRoute,
            builder: (context, state) => const TestimoniesScreen(),
          ),

          // Donation Route
          GoRoute(
            path: AppConstants.donationRoute,
            builder: (context, state) => const DonationScreen(),
          ),
          GoRoute(
            path: '/donate',
            builder: (context, state) => const DonationScreen(),
          ),

          // Achievements Route
          GoRoute(
            path: AppConstants.achievementsRoute,
            builder: (context, state) => const AchievementScreen(),
          ),

          // Gift In Kind Form Route
          GoRoute(
            path: AppConstants.giftInKindRoute,
            builder: (context, state) => const GiftInKindFormScreen(),
          ),

          GoRoute(
            path: AppConstants.nonMonetaryGiftRoute,
            builder: (context, state) => const NonMonetaryGiftFormScreen(),
          ),

          // Missing Routes configured
          GoRoute(
            path: AppConstants.studyGuideRoute,
            builder: (context, state) => const StudyGuideScreen(),
          ),
          GoRoute(
            path: AppConstants.leadershipDirectoryRoute,
            builder: (context, state) => const LeadershipArchiveScreen(),
            redirect: (context, state) {
              final roleService = RoleAccessService.instance;
              if (!roleService.canAccessAdmin() &&
                  !roleService.canAccessBoardDocuments()) {
                return '/home';
              }
              return null;
            },
          ),

          // Admin Video Content management (single source of truth for videos)
          GoRoute(
            path: AppConstants.videoContentAdminRoute,
            builder: (context, state) => const VideoContentAdminScreen(),
            redirect: (context, state) {
              final roleService = RoleAccessService.instance;
              if (!roleService.canAccessAdmin()) {
                return '/home';
              }
              return null;
            },
          ),
        ],
      ),

      GoRoute(
        path: AppConstants.adminKidsStoriesRoute,
        builder: (context, state) => const AdminKidsStoriesScreen(),
        redirect: (context, state) {
          final roleService = RoleAccessService.instance;
          if (!roleService.canAccessAdmin() &&
              !roleService.canManageKidsContent()) {
            return '/home';
          }
          return null;
        },
      ),
      GoRoute(
        path: AppConstants.adminKidsMissionsRoute,
        builder: (context, state) => const AdminKidsMissionsScreen(),
        redirect: (context, state) {
          final roleService = RoleAccessService.instance;
          if (!roleService.canAccessAdmin() &&
              !roleService.canManageKidsContent()) {
            return '/home';
          }
          return null;
        },
      ),
      GoRoute(
        path: AppConstants.adminStudyGuidesRoute,
        builder: (context, state) => const AdminStudyGuidesScreen(),
        redirect: (context, state) {
          final roleService = RoleAccessService.instance;
          if (!roleService.canAccessAdmin()) {
            return '/home';
          }
          return null;
        },
      ),
      GoRoute(
        path: AppConstants.adminChatTagManagementRoute,
        builder: (context, state) => const ChatTagManagementScreen(),
        redirect: (context, state) {
          final roleService = RoleAccessService.instance;
          if (!roleService.canAccessAdmin()) {
            return '/home';
          }
          return null;
        },
      ),
      GoRoute(
        path: AppConstants.project3dViewerRoute,
        builder: (context, state) {
          final url = state.uri.queryParameters['url'] ?? '';
          return Project3DViewerScreen(viewerUrl: url);
        },
      ),
      GoRoute(
        path: '/alive_ng_3d_viewer.html',
        builder: (context, state) => const Project3DViewerScreen(),
      ),
      GoRoute(
        path: AppConstants.billboardRoute,
        builder: (context, state) => const Project3DViewerScreen(),
      ),
      GoRoute(
        path: '/showcase',
        builder: (context, state) => const Project3DViewerScreen(),
      ),
      GoRoute(
        path: AppConstants.adminBillboardRoute,
        builder: (context, state) => const AdminBillboardScreen(),
        redirect: (context, state) {
          final roleService = RoleAccessService.instance;
          if (!roleService.canAccessAdmin()) {
            return '/home';
          }
          return null;
        },
      ),
    ],

    // Error handling: lightweight self-contained fallback so dead routes never
    // trigger secondary router/state exceptions or freeze the web app.
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(
        title: const Text('Page Not Found'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (GoRouter.of(context).canPop()) {
              context.pop();
            } else {
              context.go(AppConstants.homeRoute);
            }
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.explore_off_rounded,
                size: 56,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              Text(
                'Route unavailable',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                state.uri.toString(),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go(AppConstants.homeRoute),
                icon: const Icon(Icons.home_rounded),
                label: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});
