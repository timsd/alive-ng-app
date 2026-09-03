import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/language_provider.dart';
import '../../providers/appwrite_auth_provider.dart';
import '../../models/app_models.dart';
import '../../services/appwrite_profile_service.dart';
import '../../utils/responsive_utils.dart';
import '../../services/user_statistics_service.dart';
import 'edit_profile_screen.dart';
import '../../widgets/custom_app_bar.dart';
import '../../constants/app_constants.dart';
import '../../widgets/custom_image.dart';

// Provider for user profile
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(appwriteUserStreamProvider).value;
  if (user == null) return null;

  final profileService = ref.watch(appwriteProfileServiceProvider);
  final document = await profileService.ensureUserProfile(
    userId: user.uid,
    email: user.email,
    fullName: user.displayName ?? user.email.split('@').first,
  );
  return profileService.userProfileFromDocument(
    document,
    fallbackEmail: user.email,
    fallbackFullName: user.displayName,
    isEmailVerified: user.emailVerified,
    isAnonymous: user.isAnonymous,
    photoUrl: user.photoURL,
  );
});

// Provider for user statistics
final userStatisticsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final user = ref.watch(appwriteUserStreamProvider).value;

  // Return zero stats for guests or unauthenticated users
  if (user == null) {
    return {
      'prayers_offered': 0,
      'study_sessions_completed': 0,
      'current_streak': 0,
    };
  }

  try {
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

  BoxDecoration _sectionDecoration(BuildContext context) {
    final theme = Theme.of(context);
    return BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: theme.colorScheme.outlineVariant),
      boxShadow: [
        BoxShadow(
          color: theme.colorScheme.shadow.withValues(alpha: 0.08),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translate = ref.watch(translationProvider);

    return Scaffold(
      appBar: CustomAppBar(
        title: translate('profile'),
        actions: [
          IconButton(
            onPressed: () {
              context.push(AppConstants.notificationSettingsRoute);
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

                    // Management Section (Admin/BOD only)
                    _buildManagementSection(context, translate, ref),
                    SizedBox(
                        height: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 24,
                            tablet: 32,
                            desktop: 40)),

                    // Settings Section
                    _buildSettingsSection(context, translate, ref),
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
          decoration: _sectionDecoration(context),
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
                            color: Theme.of(context).colorScheme.onPrimary,
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
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 16, tablet: 20, desktop: 24)),
              Text(
                userProfile?.fullName ?? translate('guest_user'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
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
                    ),
                textAlign: TextAlign.center,
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
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 14,
                            tablet: 16,
                            desktop: 18),
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
        decoration: _sectionDecoration(context),
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
        decoration: _sectionDecoration(context),
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
      decoration: _sectionDecoration(context),
      child: statsAsync.when(
        data: (stats) => Row(
          children: [
            Expanded(
              child: _buildStatItem(
                context,
                translate('prayers'),
                '${stats['prayers_offered'] ?? 0}',
                Icons.favorite,
                Theme.of(context).colorScheme.error,
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
                Theme.of(context).colorScheme.primary,
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
                Theme.of(context).colorScheme.secondary,
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
                Theme.of(context).colorScheme.error,
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
                Theme.of(context).colorScheme.primary,
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
                Theme.of(context).colorScheme.secondary,
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
                Theme.of(context).colorScheme.error,
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
                Theme.of(context).colorScheme.primary,
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
                Theme.of(context).colorScheme.secondary,
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
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
        ),
      ],
    );
  }

  Widget _buildManagementSection(
      BuildContext context, String Function(String) translate, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);

    return userProfileAsync.when(
      data: (profile) {
        final role = profile?.role ?? 'user';
        final canAccessAdmin = ['admin', 'staff'].contains(role);
        final canAccessBOD = ['admin', 'bod', 'trustee'].contains(role);

        if (!canAccessAdmin && !canAccessBOD) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 20, tablet: 24, desktop: 28)),
              child: Text(
                translate('administrative'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
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
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context)
                        .colorScheme
                        .shadow
                        .withValues(alpha: 0.08),
                    blurRadius: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 8, tablet: 10, desktop: 12),
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  if (canAccessAdmin) ...[
                    ListTile(
                      leading: Icon(
                        Icons.admin_panel_settings,
                        color: Theme.of(context).colorScheme.primary,
                        size: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 24,
                            tablet: 28,
                            desktop: 32),
                      ),
                      title: Text(
                        translate('admin_dashboard'),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        size: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 16,
                            tablet: 18,
                            desktop: 20),
                      ),
                      onTap: () {
                        context.push(AppConstants.adminRoute);
                      },
                    ),
                    const Divider(height: 1),
                  ],
                  if (canAccessBOD) ...[
                    ListTile(
                      leading: Icon(
                        Icons.people,
                        color: Theme.of(context).colorScheme.primary,
                        size: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 24,
                            tablet: 28,
                            desktop: 32),
                      ),
                      title: Text(
                        translate('bod_trustees'),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        size: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 16,
                            tablet: 18,
                            desktop: 20),
                      ),
                      onTap: () {
                        context.push(AppConstants.bodTrusteesRoute);
                      },
                    ),
                    const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSettingsSection(
      BuildContext context, String Function(String) translate, WidgetRef ref) {
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
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context)
                    .colorScheme
                    .shadow
                    .withValues(alpha: 0.08),
                blurRadius: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 8, tablet: 10, desktop: 12),
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.notifications,
                  color: Theme.of(context).colorScheme.primary,
                  size: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 24, tablet: 28, desktop: 32),
                ),
                title: Text(
                  translate('notifications'),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 16,
                            tablet: 18,
                            desktop: 20),
                      ),
                ),
                subtitle: Text(
                  translate('manage_notifications'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 14,
                            tablet: 16,
                            desktop: 18),
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
                  color: Theme.of(context).colorScheme.onSurface,
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
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context)
                    .colorScheme
                    .shadow
                    .withValues(alpha: 0.08),
                blurRadius: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 8, tablet: 10, desktop: 12),
                offset: const Offset(0, 6),
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
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 16,
                            tablet: 18,
                            desktop: 20),
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
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 16,
                            tablet: 18,
                            desktop: 20),
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
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 16,
                            tablet: 18,
                            desktop: 20),
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
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 16,
                            tablet: 18,
                            desktop: 20),
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
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 16,
                            tablet: 18,
                            desktop: 20),
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

  void _showSignOutDialog(
      BuildContext context, WidgetRef ref, String Function(String) translate) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          translate('sign_out'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 18, tablet: 20, desktop: 22),
              ),
        ),
        content: Text(
          translate('sign_out_confirmation'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 16, tablet: 18, desktop: 20),
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              translate('cancel'),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 14, tablet: 16, desktop: 18),
                  ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(appwriteAuthControllerProvider).signOut();
              if (context.mounted) {
                Navigator.of(context).pop();
                context.go('/auth');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(
              translate('sign_out'),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 14, tablet: 16, desktop: 18),
                    color: Theme.of(context).colorScheme.onError,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
