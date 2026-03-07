import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/language_provider.dart';
import '../../providers/firebase_auth_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/app_models.dart';
import '../../utils/responsive_utils.dart';
import '../../services/user_statistics_service.dart';
import 'edit_profile_screen.dart';
import '../../widgets/custom_app_bar.dart';
import '../../constants/app_constants.dart';
import '../../services/firestore_service.dart';
import '../../widgets/custom_image.dart';

// Provider for user profile
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(firebaseUserProvider).value;
  if (user == null) return null;

  // Attempt to load extended profile from Firestore
  final firestore = FirestoreService.instance;
  final data = await firestore.getProfile(user.uid);

  if (data == null) {
    // Seed a basic profile document for future extension
    await firestore.upsertProfile(user.uid, {
      'id': user.uid,
      'email': user.email,
      'full_name': user.displayName,
      'photo_url': user.photoURL,
      'is_email_verified': user.emailVerified,
      'is_anonymous': user.isAnonymous,
      'provider': user.providerData.isNotEmpty
          ? user.providerData.first.providerId
          : 'email',
      'created_at':
          (user.metadata.creationTime ?? DateTime.now()).toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    return UserProfile(
      id: user.uid,
      email: user.email,
      fullName: user.displayName,
      photoUrl: user.photoURL,
      isEmailVerified: user.emailVerified,
      isAnonymous: user.isAnonymous,
      provider: user.providerData.isNotEmpty
          ? user.providerData.first.providerId
          : 'email',
      createdAt: user.metadata.creationTime ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // Merge Firestore fields with Firebase user defaults
  try {
    final json = {
      'id': user.uid,
      ...data,
      // Ensure defaults for auth-derived fields
      'email': data['email'] ?? user.email,
      'full_name': data['full_name'] ?? user.displayName,
      'photo_url': data['photo_url'] ?? user.photoURL,
      'is_email_verified': data['is_email_verified'] ?? user.emailVerified,
      'is_anonymous': data['is_anonymous'] ?? user.isAnonymous,
      'provider': data['provider'] ??
          (user.providerData.isNotEmpty
              ? user.providerData.first.providerId
              : 'email'),
    };
    return UserProfile.fromJson(json);
  } catch (_) {
    // Fallback to minimal profile if schema differs
    return UserProfile(
      id: user.uid,
      email: user.email,
      fullName: user.displayName,
      photoUrl: user.photoURL,
      isEmailVerified: user.emailVerified,
      isAnonymous: user.isAnonymous,
      provider: user.providerData.isNotEmpty
          ? user.providerData.first.providerId
          : 'email',
      createdAt: user.metadata.creationTime ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
});

// Provider for user statistics
final userStatisticsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final user = ref.watch(firebaseUserProvider).value;

  // Return zero stats for guests or unauthenticated users
  if (user == null) {
    return {
      'prayers_offered': 0,
      'study_sessions_completed': 0,
      'current_streak': 0,
    };
  }

  try {
    // Use Firebase user ID
    final userId = user.uid;

    final stats =
        await UserStatisticsService.instance.getUserStatistics(userId);

    // Calculate current streak (simplified - you may want to implement proper streak logic)
    final currentStreak = await _calculateCurrentStreak(userId);

    return {
      'prayers_offered': stats['prayers_offered'] ?? 0,
      'study_sessions_completed': stats['study_sessions_completed'] ?? 0,
      'current_streak': currentStreak,
    };
  } catch (e) {
    // Return zero stats on error
    return {
      'prayers_offered': 0,
      'study_sessions_completed': 0,
      'current_streak': 0,
    };
  }
});

// Helper function to calculate current streak
Future<int> _calculateCurrentStreak(String userId) async {
  try {
    // This is a simplified streak calculation
    // You may want to implement more sophisticated logic based on your requirements
    final monthlyStats =
        await UserStatisticsService.instance.getMonthlyStatistics(userId);

    // For now, return a simple calculation based on recent activity
    final recentPrayers = monthlyStats['prayersOfferedThisMonth'] ?? 0;
    final recentStudies = monthlyStats['studyTimeThisMonth'] ?? 0;

    // Simple streak logic: if user has recent activity, calculate based on days
    if (recentPrayers > 0 || recentStudies > 0) {
      // This is a placeholder - implement proper streak calculation
      return (recentPrayers + (recentStudies / 30)).round().clamp(0, 365);
    }

    return 0;
  } catch (e) {
    return 0;
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translate = ref.watch(translationProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: CustomAppBar(
        title: translate('profile'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              // Navigate to settings (placeholder implementation)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(translate('settings_coming_soon')),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.settings),
            tooltip: translate('settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(userProfileProvider);
              },
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header
                    _buildProfileHeader(context, translate, ref),
                    SizedBox(
                        height: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 24,
                            tablet: 32,
                            desktop: 40)),

                    // Quick Stats
                    _buildQuickStats(context, translate, ref),
                    SizedBox(
                        height: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 24,
                            tablet: 32,
                            desktop: 40)),

                    // Settings Section
                    _buildSettingsSection(context, translate, ref, themeMode),
                    SizedBox(
                        height: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 24,
                            tablet: 32,
                            desktop: 40)),

                    // Account Section
                    _buildAccountSection(context, translate, ref),
                    SizedBox(
                        height: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 24,
                            tablet: 32,
                            desktop: 40)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
      BuildContext context, String Function(String) translate, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);

    return userProfileAsync.when(
      data: (userProfile) {
        return Container(
          padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
              context: context, mobile: 20, tablet: 24, desktop: 28)),
          margin: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 20, tablet: 24, desktop: 28)),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(
                ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 16, tablet: 20, desktop: 24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 8, tablet: 10, desktop: 12),
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 40, tablet: 50, desktop: 60),
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: userProfile?.avatarUrl != null
                    ? ClipOval(
                        child: CustomImage(
                          imageUrl: userProfile!.avatarUrl!,
                          width: ResponsiveUtils.getResponsiveValue(
                              context: context,
                              mobile: 80,
                              tablet: 100,
                              desktop: 120),
                          height: ResponsiveUtils.getResponsiveValue(
                              context: context,
                              mobile: 80,
                              tablet: 100,
                              desktop: 120),
                          fit: BoxFit.cover,
                          placeholder: Icon(
                            Icons.person,
                            size: ResponsiveUtils.getResponsiveValue(
                                context: context,
                                mobile: 40,
                                tablet: 50,
                                desktop: 60),
                            color: Colors.white,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 40,
                            tablet: 50,
                            desktop: 60),
                        color: Colors.white,
                      ),
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 16, tablet: 20, desktop: 24)),
              Text(
                userProfile?.fullName ?? translate('guest_user'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveUtils.getResponsiveValue(
                          context: context,
                          mobile: 20,
                          tablet: 24,
                          desktop: 28),
                    ),
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 8, tablet: 10, desktop: 12)),
              Text(
                userProfile?.email ?? translate('no_email'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                      fontSize: ResponsiveUtils.getResponsiveValue(
                          context: context,
                          mobile: 14,
                          tablet: 16,
                          desktop: 18),
                    ),
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 16, tablet: 20, desktop: 24)),
              ElevatedButton(
                onPressed: userProfile != null
                    ? () async {
                        // Navigate to edit profile screen
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                EditProfileScreen(userProfile: userProfile),
                          ),
                        );

                        // Refresh profile data if changes were made
                        if (result != null) {
                          ref.invalidate(userProfileProvider);
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 8,
                            tablet: 10,
                            desktop: 12)),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 24, tablet: 28, desktop: 32),
                    vertical: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 12, tablet: 14, desktop: 16),
                  ),
                ),
                child: Text(
                  translate('edit_profile'),
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 14, tablet: 16, desktop: 18),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
            context: context, mobile: 20, tablet: 24, desktop: 28)),
        margin: EdgeInsets.symmetric(
            horizontal: ResponsiveUtils.getResponsiveValue(
                context: context, mobile: 20, tablet: 24, desktop: 28)),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(
              ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 16, tablet: 20, desktop: 24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 8, tablet: 10, desktop: 12),
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 40, tablet: 50, desktop: 60),
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            ),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 16, tablet: 20, desktop: 24)),
            Container(
              width: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 120, tablet: 140, desktop: 160),
              height: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 20, tablet: 24, desktop: 28),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(
                    ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 4, tablet: 5, desktop: 6)),
              ),
            ),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 8, tablet: 10, desktop: 12)),
            Container(
              width: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 160, tablet: 180, desktop: 200),
              height: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 16, tablet: 18, desktop: 20),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(
                    ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 4, tablet: 5, desktop: 6)),
              ),
            ),
          ],
        ),
      ),
      error: (error, stackTrace) => Container(
        padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
            context: context, mobile: 20, tablet: 24, desktop: 28)),
        margin: EdgeInsets.symmetric(
            horizontal: ResponsiveUtils.getResponsiveValue(
                context: context, mobile: 20, tablet: 24, desktop: 28)),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(
              ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 16, tablet: 20, desktop: 24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 8, tablet: 10, desktop: 12),
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 48, tablet: 56, desktop: 64),
              color: Theme.of(context).colorScheme.error,
            ),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 16, tablet: 20, desktop: 24)),
            Text(
              translate('error_loading_profile'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 14, tablet: 16, desktop: 18),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(
      BuildContext context, String Function(String) translate, WidgetRef ref) {
    final statsAsync = ref.watch(userStatisticsProvider);

    return Container(
      margin: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getResponsiveValue(
              context: context, mobile: 20, tablet: 24, desktop: 28)),
      padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
          context: context, mobile: 20, tablet: 24, desktop: 28)),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(
            context: context, mobile: 16, tablet: 20, desktop: 24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: ResponsiveUtils.getResponsiveValue(
                context: context, mobile: 8, tablet: 10, desktop: 12),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: statsAsync.when(
        data: (stats) => Row(
          children: [
            Expanded(
              child: _buildStatItem(
                context,
                translate('prayers'),
                '${stats['prayers_offered'] ?? 0}',
                Icons.favorite,
                Colors.red,
              ),
            ),
            Container(
              width: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 1, tablet: 1.5, desktop: 2),
              height: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 40, tablet: 48, desktop: 56),
              color: Theme.of(context).dividerColor,
            ),
            Expanded(
              child: _buildStatItem(
                context,
                translate('studies'),
                '${stats['study_sessions_completed'] ?? 0}',
                Icons.book,
                Colors.blue,
              ),
            ),
            Container(
              width: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 1, tablet: 1.5, desktop: 2),
              height: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 40, tablet: 48, desktop: 56),
              color: Theme.of(context).dividerColor,
            ),
            Expanded(
              child: _buildStatItem(
                context,
                translate('streak'),
                '${stats['current_streak'] ?? 0}',
                Icons.local_fire_department,
                Colors.orange,
              ),
            ),
          ],
        ),
        loading: () => Row(
          children: [
            Expanded(
              child: _buildStatItem(
                context,
                translate('prayers'),
                '0',
                Icons.favorite,
                Colors.red,
              ),
            ),
            Container(
              width: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 1, tablet: 1.5, desktop: 2),
              height: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 40, tablet: 48, desktop: 56),
              color: Theme.of(context).dividerColor,
            ),
            Expanded(
              child: _buildStatItem(
                context,
                translate('studies'),
                '0',
                Icons.book,
                Colors.blue,
              ),
            ),
            Container(
              width: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 1, tablet: 1.5, desktop: 2),
              height: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 40, tablet: 48, desktop: 56),
              color: Theme.of(context).dividerColor,
            ),
            Expanded(
              child: _buildStatItem(
                context,
                translate('streak'),
                '0',
                Icons.local_fire_department,
                Colors.orange,
              ),
            ),
          ],
        ),
        error: (_, __) => Row(
          children: [
            Expanded(
              child: _buildStatItem(
                context,
                translate('prayers'),
                '0',
                Icons.favorite,
                Colors.red,
              ),
            ),
            Container(
              width: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 1, tablet: 1.5, desktop: 2),
              height: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 40, tablet: 48, desktop: 56),
              color: Theme.of(context).dividerColor,
            ),
            Expanded(
              child: _buildStatItem(
                context,
                translate('studies'),
                '0',
                Icons.book,
                Colors.blue,
              ),
            ),
            Container(
              width: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 1, tablet: 1.5, desktop: 2),
              height: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 40, tablet: 48, desktop: 56),
              color: Theme.of(context).dividerColor,
            ),
            Expanded(
              child: _buildStatItem(
                context,
                translate('streak'),
                '0',
                Icons.local_fire_department,
                Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value,
      IconData icon, Color color) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: ResponsiveUtils.getResponsiveValue(
              context: context, mobile: 24, tablet: 28, desktop: 32),
        ),
        SizedBox(
            height: ResponsiveUtils.getResponsiveValue(
                context: context, mobile: 8, tablet: 10, desktop: 12)),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 18, tablet: 22, desktop: 26),
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
                fontSize: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 12, tablet: 14, desktop: 16),
              ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(BuildContext context,
      String Function(String) translate, WidgetRef ref, ThemeMode themeMode) {
    // Watch current locale inside this method to avoid undefined identifier
    final currentLocale = ref.watch(localeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 20, tablet: 24, desktop: 28)),
          child: Text(
            translate('preferences'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 18, tablet: 22, desktop: 26),
                ),
          ),
        ),
        SizedBox(
            height: ResponsiveUtils.getResponsiveValue(
                context: context, mobile: 16, tablet: 20, desktop: 24)),
        Container(
          margin: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 20, tablet: 24, desktop: 28)),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(
                ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 16, tablet: 20, desktop: 24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 8, tablet: 10, desktop: 12),
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  themeMode == ThemeMode.dark
                      ? Icons.dark_mode
                      : Icons.light_mode,
                  color: Theme.of(context).colorScheme.primary,
                  size: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 24, tablet: 28, desktop: 32),
                ),
                title: Text(
                  translate('theme'),
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 16, tablet: 18, desktop: 20),
                  ),
                ),
                subtitle: Text(
                  themeMode == ThemeMode.dark
                      ? translate('dark_mode')
                      : themeMode == ThemeMode.light
                          ? translate('light_mode')
                          : translate('system_mode'),
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 14, tablet: 16, desktop: 18),
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 16, tablet: 18, desktop: 20),
                ),
                onTap: () {
                  _showThemeDialog(context, ref, translate);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.language,
                  color: Theme.of(context).colorScheme.primary,
                  size: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 24, tablet: 28, desktop: 32),
                ),
                title: Text(
                  translate('language'),
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 16, tablet: 18, desktop: 20),
                  ),
                ),
                subtitle: Text(
                  AppConstants.supportedLanguages[currentLocale.languageCode] ??
                      translate('english'),
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 14, tablet: 16, desktop: 18),
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 16, tablet: 18, desktop: 20),
                ),
                onTap: () {
                  _showLanguageSelector(context, ref, translate);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.notifications,
                  color: Theme.of(context).colorScheme.primary,
                  size: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 24, tablet: 28, desktop: 32),
                ),
                title: Text(
                  translate('notifications'),
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 16, tablet: 18, desktop: 20),
                  ),
                ),
                subtitle: Text(
                  translate('manage_notifications'),
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 14, tablet: 16, desktop: 18),
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 16, tablet: 18, desktop: 20),
                ),
                onTap: () {
                  context.push(AppConstants.notificationSettingsRoute);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSection(
      BuildContext context, String Function(String) translate, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 20, tablet: 24, desktop: 28)),
          child: Text(
            translate('account'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 18, tablet: 22, desktop: 26),
                ),
          ),
        ),
        SizedBox(
            height: ResponsiveUtils.getResponsiveValue(
                context: context, mobile: 16, tablet: 20, desktop: 24)),
        Container(
          margin: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 20, tablet: 24, desktop: 28)),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(
                ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 16, tablet: 20, desktop: 24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 8, tablet: 10, desktop: 12),
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.help_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 24, tablet: 28, desktop: 32),
                ),
                title: Text(
                  translate('help_support'),
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 16, tablet: 18, desktop: 20),
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 16, tablet: 18, desktop: 20),
                ),
                onTap: () {
                  // Navigate to help & support screen
                  context.push('/help-support');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.privacy_tip_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 24, tablet: 28, desktop: 32),
                ),
                title: Text(
                  translate('privacy_policy'),
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 16, tablet: 18, desktop: 20),
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 16, tablet: 18, desktop: 20),
                ),
                onTap: () {
                  // Navigate to privacy policy
                  context.push('/privacy-policy');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.gavel_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 24, tablet: 28, desktop: 32),
                ),
                title: Text(
                  translate('terms_conditions'),
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 16, tablet: 18, desktop: 20),
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 16, tablet: 18, desktop: 20),
                ),
                onTap: () {
                  // Navigate to terms & conditions
                  context.push('/terms-conditions');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 24, tablet: 28, desktop: 32),
                ),
                title: Text(
                  translate('about_app'),
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 16, tablet: 18, desktop: 20),
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 16, tablet: 18, desktop: 20),
                ),
                onTap: () {
                  // Navigate to about app screen
                  context.push('/about-app');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.info,
                  color: Theme.of(context).colorScheme.primary,
                  size: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 24, tablet: 28, desktop: 32),
                ),
                title: Text(
                  translate('about_alive'),
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 16, tablet: 18, desktop: 20),
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 16, tablet: 18, desktop: 20),
                ),
                onTap: () {
                  // Navigate to about ALIVE screen
                  context.push('/about-alive');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.logout,
                  color: Theme.of(context).colorScheme.error,
                  size: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 24, tablet: 28, desktop: 32),
                ),
                title: Text(
                  translate('sign_out'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 16, tablet: 18, desktop: 20),
                  ),
                ),
                onTap: () {
                  _showSignOutDialog(context, ref, translate);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showThemeDialog(
      BuildContext context, WidgetRef ref, String Function(String) translate) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          translate('choose_theme'),
          style: TextStyle(
            fontSize: ResponsiveUtils.getResponsiveValue(
                context: context, mobile: 18, tablet: 20, desktop: 22),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioGroup<ThemeMode>(
              groupValue: ref.read(themeModeProvider),
              onChanged: (value) {
                ref.read(themeModeProvider.notifier).setThemeMode(value!);
                Navigator.of(context).pop();
              },
              child: Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: Text(
                      translate('light_mode'),
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 16,
                            tablet: 18,
                            desktop: 20),
                      ),
                    ),
                    value: ThemeMode.light,
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text(
                      translate('dark_mode'),
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 16,
                            tablet: 18,
                            desktop: 20),
                      ),
                    ),
                    value: ThemeMode.dark,
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text(
                      translate('system_mode'),
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 16,
                            tablet: 18,
                            desktop: 20),
                      ),
                    ),
                    value: ThemeMode.system,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSelector(
      BuildContext context, WidgetRef ref, String Function(String) translate) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ResponsiveUtils.getResponsiveValue(
              context: context, mobile: 16, tablet: 20, desktop: 24)),
        ),
      ),
      builder: (context) {
        final currentCode = ref.read(localeProvider).languageCode;
        return Padding(
          padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
              context: context, mobile: 16, tablet: 20, desktop: 24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                translate('language'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveUtils.getResponsiveValue(
                          context: context,
                          mobile: 18,
                          tablet: 20,
                          desktop: 22),
                    ),
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 12, tablet: 14, desktop: 16)),
              ...AppConstants.supportedLanguages.entries.map((entry) {
                final code = entry.key;
                final name = entry.value;
                final selected = code == currentCode;
                return ListTile(
                  leading: Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    name,
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getResponsiveValue(
                          context: context,
                          mobile: 16,
                          tablet: 18,
                          desktop: 20),
                    ),
                  ),
                  onTap: () async {
                    await ref.read(localeProvider.notifier).setLocale(code);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showSignOutDialog(
      BuildContext context, WidgetRef ref, String Function(String) translate) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          translate('sign_out'),
          style: TextStyle(
            fontSize: ResponsiveUtils.getResponsiveValue(
                context: context, mobile: 18, tablet: 20, desktop: 22),
          ),
        ),
        content: Text(
          translate('sign_out_confirmation'),
          style: TextStyle(
            fontSize: ResponsiveUtils.getResponsiveValue(
                context: context, mobile: 16, tablet: 18, desktop: 20),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              translate('cancel'),
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 14, tablet: 16, desktop: 18),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) {
                Navigator.of(context).pop();
                context.go('/auth');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: Text(
              translate('sign_out'),
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 14, tablet: 16, desktop: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
