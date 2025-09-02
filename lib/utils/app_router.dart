import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/splash/animated_splash_screen.dart';
import '../screens/home_screen.dart';
import '../screens/study_screen.dart';
import '../screens/daily_screen.dart';
import '../screens/prayer_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/health_screen.dart';
import '../screens/missions_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../screens/about/about_app_screen.dart';
import '../screens/about/about_alive_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/bod_trustees_screen.dart';
import '../screens/admin/user_archive_screen.dart';
import '../screens/admin/role_management_screen.dart';
import '../screens/conference/conference_platform_screen.dart';
import '../screens/bible_game_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/chapters/chapter_screen.dart';
import '../screens/health/enhanced_health_screen.dart';
import '../screens/health/recipe_submission_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/guest_provider.dart';
import '../constants/app_constants.dart';

// Helper function to determine if a route is accessible to guest users
bool _isGuestAccessibleRoute(String path) {
  const guestAccessibleRoutes = [
    '/home',
    '/study',
    '/daily',
    '/health',
    '/about-app',
    '/about-alive',
    '/bible-game',
  ];

  return guestAccessibleRoutes.contains(path);
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final isGuest = ref.watch(isGuestModeProvider);

  return GoRouter(
    initialLocation: AppConstants.splashRoute,
    redirect: (context, state) {
      final isAuthenticated = authState.when(
        data: (user) => user != null,
        loading: () => false,
        error: (_, __) => false,
      );

      final isAuthRoute = state.uri.path == AppConstants.authRoute;
      final isSplashRoute = state.uri.path == AppConstants.splashRoute;
      final isGuestAccessibleRoute = _isGuestAccessibleRoute(state.uri.path);
      final hasAccess = isAuthenticated || isGuest;

      // Allow splash screen to show initially
      if (isSplashRoute) {
        return null;
      }

      // Allow access to basic features if authenticated or guest
      if (hasAccess && isGuestAccessibleRoute) {
        return null;
      }

      // If authenticated, allow access to all routes except auth
      if (isAuthenticated && !isAuthRoute) {
        return null;
      }

      // If not authenticated and not guest, redirect to auth for protected routes
      if (!hasAccess && !isAuthRoute) {
        return AppConstants.authRoute;
      }

      // If authenticated and on auth route, redirect to home
      if (isAuthenticated && isAuthRoute) {
        return AppConstants.homeRoute;
      }

      return null; // No redirect needed
    },
    routes: [
      // Splash Route
      GoRoute(
        path: AppConstants.splashRoute,
        builder: (context, state) => AnimatedSplashScreen(
          onAnimationComplete: () {
            // Animation complete callback
          },
        ),
      ),

      // Auth Route
      GoRoute(
        path: AppConstants.authRoute,
        builder: (context, state) => const AuthScreen(),
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
          ),

          // BOD Trustees Route
          GoRoute(
            path: AppConstants.bodTrusteesRoute,
            builder: (context, state) => const BodTrusteesScreen(),
          ),

          // User Archive Route
          GoRoute(
            path: AppConstants.userArchiveRoute,
            builder: (context, state) => const UserArchiveScreen(),
          ),

          // Role Management Route
          GoRoute(
            path: AppConstants.roleManagementRoute,
            builder: (context, state) => const RoleManagementScreen(),
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
        ],
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
