import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/language_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../models/app_models.dart';

// Provider for user profile
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final supabase = ref.read(supabaseServiceProvider);
  final response =
      await supabase.client.from('profiles').select().eq('id', user.id);

  if (response.isNotEmpty) {
    return UserProfile.fromJson(response.first);
  }
  return null;
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translate = ref.watch(translationProvider);
    final currentUser = ref.watch(currentUserProvider);
    final userProfileAsync = ref.watch(userProfileProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(translate('profile')),
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
            final isTablet = constraints.maxWidth > 600;
            final horizontalPadding = isTablet ? 32.0 : 20.0;
            
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(currentUserProvider);
                ref.invalidate(userProfileProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Profile Header
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(horizontalPadding),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: userProfileAsync.when(
                  data: (profile) => _buildProfileHeader(
                      context, translate, currentUser, profile),
                  loading: () => _buildProfileHeaderLoading(context),
                  error: (error, stack) =>
                      _buildProfileHeaderError(context, translate),
                ),
              ),

              const SizedBox(height: 24),

              // Quick Stats
              _buildQuickStats(context, translate),

              const SizedBox(height: 24),

              // Settings Section
              _buildSettingsSection(context, translate, ref, themeMode),

              const SizedBox(height: 24),

              // Account Section
              _buildAccountSection(context, translate, ref),

              const SizedBox(height: 24),
              
              // Bottom padding for FAB
              const SizedBox(height: 80),
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
      BuildContext context,
      String Function(String) translate,
      dynamic currentUser,
      UserProfile? profile) {
    final userName = profile?.fullName ??
        currentUser?.userMetadata?['full_name'] as String? ??
        currentUser?.email?.split('@').first ??
        'User';
    final userEmail = currentUser?.email ?? '';

    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          child: profile?.avatarUrl != null
              ? ClipOval(
                  child: Image.network(
                    profile!.avatarUrl!,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.white,
                      );
                    },
                  ),
                )
              : Icon(
                  Icons.person,
                  size: 50,
                  color: Colors.white,
                ),
        ),
        const SizedBox(height: 16),
        Text(
          userName,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          userEmail,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            // Navigate to edit profile (placeholder implementation)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${translate('edit_profile')} - ${translate('coming_soon')}'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Theme.of(context).colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Text(translate('edit_profile')),
        ),
      ],
    );
  }

  Widget _buildProfileHeaderLoading(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          child: const CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: 150,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 200,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeaderError(
      BuildContext context, String Function(String) translate) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          child: Icon(
            Icons.error_outline,
            size: 50,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          translate('error_loading_profile'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
              ),
        ),
      ],
    );
  }

  Widget _buildQuickStats(
      BuildContext context, String Function(String) translate) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              context,
              translate('prayers'),
              '24',
              Icons.favorite,
              Colors.red,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Theme.of(context).dividerColor,
          ),
          Expanded(
            child: _buildStatItem(
              context,
              translate('studies'),
              '12',
              Icons.menu_book,
              Colors.blue,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Theme.of(context).dividerColor,
          ),
          Expanded(
            child: _buildStatItem(
              context,
              translate('streak'),
              '7',
              Icons.local_fire_department,
              Colors.orange,
            ),
          ),
        ],
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
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(BuildContext context,
      String Function(String) translate, WidgetRef ref, ThemeMode themeMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            translate('preferences'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
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
                ),
                title: Text(translate('theme')),
                subtitle: Text(
                  themeMode == ThemeMode.dark
                      ? translate('dark_mode')
                      : themeMode == ThemeMode.light
                          ? translate('light_mode')
                          : translate('system_mode'),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  _showThemeDialog(context, ref, translate);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.language,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(translate('language')),
                subtitle: Text(translate('english')),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // Show language selection (placeholder implementation)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${translate('language')} ${translate('selection')} - ${translate('coming_soon')}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.notifications,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(translate('notifications')),
                subtitle: Text(translate('manage_notifications')),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // Navigate to notification settings (placeholder implementation)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${translate('notifications')} ${translate('settings')} - ${translate('coming_soon')}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            translate('account'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
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
                ),
                title: Text(translate('help_support')),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // Navigate to help (placeholder implementation)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${translate('help_support')} - ${translate('coming_soon')}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.privacy_tip_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(translate('privacy_policy')),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // Navigate to privacy policy (placeholder implementation)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${translate('privacy_policy')} - ${translate('coming_soon')}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(translate('about')),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // Navigate to about app screen
                  context.push('/about-app');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.logout,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  translate('sign_out'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
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
        title: Text(translate('choose_theme')),
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
                    title: Text(translate('light_mode')),
                    value: ThemeMode.light,
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text(translate('dark_mode')),
                    value: ThemeMode.dark,
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text(translate('system_mode')),
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

  void _showSignOutDialog(
      BuildContext context, WidgetRef ref, String Function(String) translate) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(translate('sign_out')),
        content: Text(translate('sign_out_confirmation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(translate('cancel')),
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
            child: Text(translate('sign_out')),
          ),
        ],
      ),
    );
  }
}
