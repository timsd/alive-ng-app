import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/splash/animated_splash_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/study_guides/study_screen.dart';
import '../screens/daily/daily_screen.dart';
import '../screens/prayer/prayer_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/health/health_screen.dart';
import '../screens/missions/missions_screen.dart';
import '../screens/auth/appwrite_auth_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../main.dart';
import '../screens/about/about_app_screen.dart';
import '../screens/about/about_alive_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/content_management_screen.dart';
import '../screens/admin/kids_content_admin_screen.dart';
import '../screens/admin/admin_kids_stories_screen.dart';
import '../screens/admin/admin_kids_missions_screen.dart';
import '../screens/admin/admin_study_guides_screen.dart';
import '../screens/admin/tract_podcast_admin_screen.dart';
import '../screens/admin/meeting_file_sharing_screen.dart';
import '../screens/admin/bod_trustees_screen.dart';
import '../screens/admin/user_archive_screen.dart';
import '../screens/admin/role_management_screen.dart';
import '../services/role_access_service.dart';
import '../screens/conference/conference_platform_screen.dart';
import '../screens/bible/bible_game_screen.dart';
import '../screens/bible/bible_reader_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/chapters/chapter_screen.dart';
import '../screens/health/enhanced_health_screen.dart';
import '../screens/health/recipe_submission_screen.dart';
import '../screens/kids/kids_mission_screen.dart';
import '../screens/prayer/prayer_wall_screen.dart';
import '../screens/library/library_screen.dart';
import '../screens/podcasts/podcasts_screen.dart';
import '../screens/lessons/interactive_lessons_screen.dart';
import '../screens/books/books_tracts_screen.dart';
import '../screens/study_guides/study_guide_screen.dart';
import '../screens/kids/kids_stories_screen.dart';
import '../screens/discipleship/discipleship_screen.dart';
import '../screens/events/events_screen.dart';
import '../screens/admin/admin_approval_screen.dart';
import '../screens/admin/admin_donations_report_screen.dart';
import '../screens/admin/admin_approval_link_handler_screen.dart';
import '../screens/help/help_support_screen.dart';
import '../screens/settings/notification_settings_screen.dart';
import '../screens/testimonies/testimonies_screen.dart';
import '../screens/resources/resources_screen.dart';
import '../screens/donation/donation_screen.dart';
import '../screens/donation/gift_in_kind_form_screen.dart';
import '../screens/donation/non_monetary_gift_form_screen.dart';
import '../services/appwrite_auth_service.dart';
import '../constants/app_constants.dart';
import '../services/onboarding_service.dart';
import '../utils/web_launch_params.dart';
import '../utils/navigation_keys.dart';

// New screen imports
import '../screens/admin/leadership_archive_screen.dart';

const bool kMinimalRouterMode = false;

// Helper function to determine if a route is accessible to guest users
bool _isGuestAccessibleRoute(String path) {
  const guestAccessibleRoutes = [
    '/onboarding',
    '/home',
    '/study',
    '/daily',
    '/health',
    '/about-app',
    '/about-alive',
    '/bible',
    '/bible-game',
    '/kids-mission',
    '/library',
    '/podcasts',
    '/interactive-lessons',
    '/books-tracts',
    '/kids-stories',
    '/testimonies',
    '/resources',
    '/help-support',
    '/donation',
    '/gift-in-kind',
    '/admin-approve',
    '/reset-password',
  ];

  return guestAccessibleRoutes.contains(path);
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

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    // Always start from splash so web/mobile behavior is consistent.
    initialLocation: AppConstants.splashRoute,
    redirect: (context, state) async {
      debugPrint('Router redirect start: ${state.uri.path}');
      final currentUser = ref.watch(appwriteUserProvider);
      final isAuthenticated = currentUser != null;
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

      // Allow onboarding route before authentication.
      if (isOnboardingRoute) {
        debugPrint('Allow onboarding route');
        return null;
      }

      // Allow guest-accessible routes for unauthenticated users.
      if (!isAuthenticated && isGuestAccessibleRoute) {
        debugPrint('Route is guest accessible: ${state.uri.path}');
        return null;
      }

      // Profile-completion checks will be restored against Appwrite profiles.

      // Authenticated users can access all non-auth routes.
      if (isAuthenticated && !isAuthRoute) {
        debugPrint('Authenticated; allow route: ${state.uri.path}');
        return null;
      }

      // If not authenticated, redirect to auth for protected routes
      if (!isAuthenticated && !isAuthRoute) {
        debugPrint('Unauthenticated; redirect to auth');
        return AppConstants.authRoute;
      }

      // If authenticated and on auth route, redirect to home
      if (isAuthenticated && isAuthRoute) {
        if (postAuthRedirect != null) {
          clearPostAuthRedirect();
          debugPrint('Post-auth redirect: $postAuthRedirect');
          return postAuthRedirect;
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
            bool show = false;
            try {
              show = await OnboardingService.shouldShowOnboarding()
                  .timeout(const Duration(seconds: 2), onTimeout: () => false);
            } catch (e) {
              debugPrint('Onboarding check failed; defaulting to home: $e');
              show = false;
            }
            if (!context.mounted) return;
            final nextRoute = show
                ? AppConstants.onboardingRoute
                : (kIsWeb ? AppConstants.homeRoute : AppConstants.authRoute);
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
        builder: (context, state) => ResetPasswordScreen(
          userId: state.uri.queryParameters['userId'],
          secret: state.uri.queryParameters['secret'],
        ),
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

      // Main Navigation Shell Route
      ShellRoute(
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
            builder: (context, state) => const HealthScreen(),
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

          // BOD Trustees Route
          GoRoute(
            path: AppConstants.bodTrusteesRoute,
            builder: (context, state) => const BodTrusteesScreen(),
            redirect: (context, state) {
              final roleService = RoleAccessService.instance;
              if (!roleService.canAccessBoardDocuments()) {
                return '/home';
              }
              return null;
            },
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
            redirect: (context, state) {
              final roleService = RoleAccessService.instance;
              if (!roleService.canAccessAdmin()) {
                return '/home';
              }
              return null;
            },
          ),

          // Conference Platform Route
          GoRoute(
            path: AppConstants.conferenceRoute,
            builder: (context, state) => const ConferencePlatformScreen(),
          ),

          // Bible Game Route
          GoRoute(
            path: AppConstants.bibleGameRoute,
            builder: (context, state) => const BibleGameScreen(),
          ),

          // Bible Reader Route
          GoRoute(
            path: AppConstants.bibleRoute,
            builder: (context, state) => const BibleReaderScreen(),
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

          GoRoute(
            path: AppConstants.recipesRoute,
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
            builder: (context, state) => const PrayerWallScreen(),
          ),

          // Library Route
          GoRoute(
            path: AppConstants.libraryRoute,
            builder: (context, state) => const LibraryScreen(),
          ),

          // Podcasts Route
          GoRoute(
            path: AppConstants.podcastsRoute,
            builder: (context, state) => const PodcastsScreen(),
          ),

          // Interactive Lessons Route
          GoRoute(
            path: AppConstants.interactiveLessonsRoute,
            builder: (context, state) => const InteractiveLessonsScreen(),
          ),

          // Books & Tracts Route
          GoRoute(
            path: AppConstants.booksTractsRoute,
            builder: (context, state) => const BooksTractsScreen(),
          ),

          // Kids Stories Route
          GoRoute(
            path: AppConstants.kidsStoriesRoute,
            builder: (context, state) => const KidsStoriesScreen(),
          ),

          // Discipleship Tracker Route
          GoRoute(
            path: AppConstants.discipleshipTrackerRoute,
            builder: (context, state) => const DiscipleshipScreen(),
          ),

          // Events Route
          GoRoute(
            path: AppConstants.eventsRoute,
            builder: (context, state) => const EventsScreen(),
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
              final user = ref.read(appwriteUserProvider);
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

          // Resources Route
          GoRoute(
            path: AppConstants.resourcesRoute,
            builder: (context, state) => const ResourcesScreen(),
          ),

          // Donation Route
          GoRoute(
            path: AppConstants.donationRoute,
            builder: (context, state) => const DonationScreen(),
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
            path: AppConstants.leadershipArchiveRoute,
            builder: (context, state) => const LeadershipArchiveScreen(),
          ),
        ],
      ),

      GoRoute(
        path: AppConstants.kidsContentAdminRoute,
        builder: (context, state) => const KidsContentAdminScreen(),
        redirect: (context, state) {
          final roleService = RoleAccessService.instance;
          if (!roleService.canAccessAdmin()) {
            return '/home';
          }
          return null;
        },
      ),
      GoRoute(
        path: AppConstants.adminKidsStoriesRoute,
        builder: (context, state) => const AdminKidsStoriesScreen(),
        redirect: (context, state) {
          final roleService = RoleAccessService.instance;
          if (!roleService.canAccessAdmin()) {
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
          if (!roleService.canAccessAdmin()) {
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
    ],

    // Error handling
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.error?.toString() ?? 'Unknown error occurred',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppConstants.homeRoute),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});
