import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/language_provider.dart';
import '../../providers/appwrite_auth_provider.dart';
import '../../models/app_models.dart';
import '../../services/appwrite_profile_service.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_auth_service.dart';
import '../../utils/toast_utils.dart';
import '../../config/appwrite_backend_config.dart';
import '../../utils/responsive_utils.dart';
import 'edit_profile_screen.dart';
import '../../widgets/custom_app_bar.dart';
import '../../constants/app_constants.dart';
import '../../widgets/custom_image.dart';
import '../../widgets/shimmer_loading.dart';
import 'subscriptions_sheet.dart';

// Provider for user profile — gracefully falls back to session data on error
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(appwriteUserStreamProvider).value;
  if (user == null) return null;

  try {
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
      isEmailVerified: user.isEmailVerified,
      isAnonymous: user.isAnonymous,
      photoUrl: user.photoUrl,
    );
  } catch (_) {
    // Fallback: build a minimal profile from the session so the UI never
    // shows a raw error container.
    return UserProfile(
      id: user.uid,
      email: user.email,
      fullName: user.displayName ?? user.email.split('@').first,
      photoUrl: user.photoUrl,
      isEmailVerified: user.isEmailVerified,
      isAnonymous: user.isAnonymous,
      role: AppwriteBackendConfig.isSuperAdminEmail(user.email)
          ? 'admin'
          : 'member',
      approvalStatus: AppwriteBackendConfig.isSuperAdminEmail(user.email)
          ? 'approved'
          : 'pending',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translate = ref.watch(translationProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: CustomAppBar(
        showBackButton: true,
        title: translate('profile'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(userProfileProvider);
          },
          child: _buildBody(context, ref, translate, theme),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref,
      String Function(String) translate, ThemeData theme) {
    final userProfileAsync = ref.watch(userProfileProvider);

    return userProfileAsync.when(
      data: (profile) {
        if (profile == null) {
          return const Center(child: Text('Please sign in to view your profile.'));
        }
        return _buildProfileContent(context, ref, translate, theme, profile);
      },
      loading: () => const _ProfileScreenSkeleton(),
      error: (_, __) {
        // Even on error, try to show basic content
        final user = ref.watch(appwriteUserStreamProvider).value;
        if (user != null) {
          final fallback = UserProfile(
            id: user.uid,
            email: user.email,
            fullName: user.displayName ?? user.email.split('@').first,
            photoUrl: user.photoUrl,
            role: 'member',
            approvalStatus: 'pending',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          return _buildProfileContent(context, ref, translate, theme, fallback);
        }
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(translate('error_loading_profile')),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(userProfileProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileContent(BuildContext context, WidgetRef ref,
      String Function(String) translate, ThemeData theme, UserProfile profile) {
    final isSuperAdmin = AppwriteBackendConfig.isSuperAdminEmail(profile.email);
    final effectiveRole = isSuperAdmin ? 'admin' : profile.role;
    final effectiveApproval =
        isSuperAdmin || effectiveRole == 'admin' ? 'approved' : profile.approvalStatus;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getResponsiveValue(
            context: context, mobile: 16, tablet: 24, desktop: 32),
        vertical: ResponsiveUtils.getResponsiveValue(
            context: context, mobile: 16, tablet: 24, desktop: 32),
      ),
      child: Column(
        children: [
          // ── Profile Header Card ──
          _ProfileHeaderCard(
            profile: profile,
            effectiveRole: effectiveRole,
            effectiveApproval: effectiveApproval,
            onEditProfile: () => _navigateToEditProfile(context, ref, profile),
          ),
          const SizedBox(height: 20),

          // ── Personal & Ministry Info ──
          _InfoSection(
            title: 'Personal & Ministry Info',
            icon: Icons.person_rounded,
            items: [
              _InfoItem('Email', profile.email ?? 'Not set', Icons.email_rounded),
              _InfoItem('Phone', profile.phoneNumber ?? 'Not set', Icons.phone_rounded),
              _InfoItem('Location', profile.location ?? 'Not set', Icons.location_on_rounded),
              _InfoItem('Local Church', profile.localChurch ?? 'Not set', Icons.church_rounded),
              _InfoItem('Chapter', profile.localChapter ?? 'Not set', Icons.groups_rounded),
              _InfoItem('Occupation', profile.occupation ?? 'Not set', Icons.work_rounded),
              _InfoItem('Skills', profile.skills ?? 'Not set', Icons.build_rounded),
              if (profile.bio != null && profile.bio!.isNotEmpty)
                _InfoItem('Bio', profile.bio!, Icons.info_rounded),
              _InfoItem(
                'Commitment',
                _formatCommitment(profile.commitmentType),
                Icons.handshake_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Admin entry points live under More > Admin Dashboard and More >
          // Board (BOD). Profile intentionally omits that Administrative block.
          // ── Preferences ──
          _SectionCard(
            title: translate('preferences'),
            icon: Icons.tune_rounded,
            children: [
              _ActionTile(
                icon: Icons.notifications_rounded,
                iconColor: const Color(0xFFEAB308),
                title: translate('notifications'),
                subtitle: translate('manage_notifications'),
                onTap: () => context.push(AppConstants.notificationSettingsRoute),
              ),
              _ActionTile(
                icon: Icons.emoji_events_rounded,
                iconColor: const Color(0xFF8B5CF6),
                title: 'Achievements',
                subtitle: 'View your ministry achievements',
                onTap: () => context.push('/achievements'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Recurring Giving ──
          _SectionCard(
            title: 'Recurring Giving',
            icon: Icons.autorenew_rounded,
            children: [
              _ActionTile(
                icon: Icons.card_membership_rounded,
                iconColor: const Color(0xFF10B981),
                title: 'Monthly Donations',
                subtitle: 'View or cancel your recurring donations',
                onTap: () => _showSubscriptionsSheet(context, profile),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Account & Security ──
          _SectionCard(
            title: 'Account & Security',
            icon: Icons.security_rounded,
            children: [
              // Biometric sign-in belongs with account settings, not buried on
              // the sign-in screen: once someone is signed in, the auth screen
              // is unreachable, so that was the only place they could turn it
              // on -- effectively nowhere.
              //
              // Only shown when the device actually supports it. The service
              // reports unavailable on web, so on the deployed web build this
              // row is correctly hidden rather than offering a switch that
              // cannot work.
              _BiometricToggle(profile: profile),
              _ActionTile(
                icon: Icons.lock_reset_rounded,
                iconColor: const Color(0xFF3B82F6),
                title: 'Reset Password',
                subtitle: 'Send a password reset email',
                onTap: () => _showResetPasswordDialog(context, profile),
              ),
              _ActionTile(
                icon: Icons.logout_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: 'Sign Out',
                subtitle: 'Sign out of your account',
                onTap: () => _showSignOutDialog(context, ref),
              ),
              _ActionTile(
                icon: Icons.delete_forever_rounded,
                iconColor: const Color(0xFFDC2626),
                title: 'Delete Account',
                subtitle: 'Permanently delete your account and data',
                onTap: () => _showDeleteAccountDialog(context, ref),
                isDanger: true,
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _formatCommitment(String? type) {
    switch (type) {
      case 'financial':
        return 'Financial Commitment';
      case 'active_availability':
        return 'Active Availability';
      case 'both':
        return 'Financial & Active Availability';
      default:
        return 'Not set';
    }
  }

  void _navigateToEditProfile(
      BuildContext context, WidgetRef ref, UserProfile profile) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(userProfile: profile),
      ),
    );
    // Always refresh: the edit screen may have uploaded a new profile picture
    // (persisted immediately) even when the user left without saving.
    ref.invalidate(userProfileProvider);
    if (result != null) {
      ref.invalidate(currentUserProfileProvider);
    }
  }

  void _showResetPasswordDialog(BuildContext context, UserProfile profile) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Text(
          'A password reset link will be sent to ${profile.email}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await AuthService.instance.resetPassword(profile.email ?? '');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password reset email sent!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to send reset email: $e')),
                  );
                }
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await AuthService.instance.signOut();
                ref.invalidate(currentUserProfileProvider);
                if (context.mounted) {
                  context.go(AppConstants.authRoute);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Unable to sign out: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showSubscriptionsSheet(BuildContext context, UserProfile profile) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, controller) => SubscriptionsSheet(
          email: profile.email ?? '',
          scrollController: controller,
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded,
            size: 48, color: Theme.of(context).colorScheme.error),
        title: const Text('Delete Account'),
        content: const Text(
          'This action is permanent and cannot be undone. '
          'All your data, profile information, reading history, and '
          'achievements will be permanently deleted.\n\n'
          'Are you absolutely sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Second confirmation — the user must actually type DELETE.
              final deleteController = TextEditingController();
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx2) => StatefulBuilder(
                  builder: (ctx2, setState) => AlertDialog(
                    title: const Text('Final Confirmation'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Type DELETE below to confirm account deletion. '
                          'A confirmation email will be sent to your inbox.',
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: deleteController,
                          autofocus: true,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Type DELETE',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx2, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: deleteController.text.trim().toUpperCase() ==
                                'DELETE'
                            ? () => Navigator.pop(ctx2, true)
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                        child: const Text('Delete Forever'),
                      ),
                    ],
                  ),
                ),
              );
              deleteController.dispose();
              if (confirmed == true) {
                try {
                  await AuthService.instance.deleteAccount();
                  if (context.mounted) {
                    context.go(AppConstants.authRoute);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Unable to delete account: $e')),
                    );
                  }
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete My Account'),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable Profile Widgets ────────────────────────────────────────────────

class _ProfileHeaderCard extends StatelessWidget {
  final UserProfile profile;
  final String effectiveRole;
  final String effectiveApproval;
  final VoidCallback onEditProfile;

  const _ProfileHeaderCard({
    required this.profile,
    required this.effectiveRole,
    required this.effectiveApproval,
    required this.onEditProfile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarRadius = ResponsiveUtils.getResponsiveValue(
        context: context, mobile: 44.0, tablet: 54.0, desktop: 64.0);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
          context: context, mobile: 24, tablet: 28, desktop: 32)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.08),
            theme.colorScheme.primary.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          // Avatar
          // Avatar
          Builder(
            builder: (context) {
              final avatar = (profile.avatarUrl != null &&
                      profile.avatarUrl!.trim().isNotEmpty)
                  ? profile.avatarUrl!.trim()
                  : ((profile.photoUrl != null &&
                          profile.photoUrl!.trim().isNotEmpty)
                      ? profile.photoUrl!.trim()
                      : null);

              return CircleAvatar(
                radius: avatarRadius,
                backgroundColor: theme.colorScheme.primary,
                child: avatar != null
                    ? ClipOval(
                        child: CustomImage(
                          imageUrl: avatar,
                          width: avatarRadius * 2,
                          height: avatarRadius * 2,
                          fit: BoxFit.cover,
                          placeholder: Icon(Icons.person,
                              size: avatarRadius,
                              color: theme.colorScheme.onPrimary),
                        ),
                      )
                    : Icon(Icons.person,
                        size: avatarRadius,
                        color: theme.colorScheme.onPrimary),
              );
            },
          ),
          const SizedBox(height: 16),

          // Name
          Text(
            profile.fullName ?? 'Guest User',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // Email
          Text(
            profile.email ?? '',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Role & Status badges
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _RoleBadge(role: effectiveRole),
              _StatusBadge(status: effectiveApproval),
            ],
          ),
          const SizedBox(height: 20),

          // Edit Profile button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onEditProfile,
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Edit Profile'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String label) = switch (role) {
      'admin' => (const Color(0xFFDC2626), Colors.white, 'Admin'),
      'staff' => (const Color(0xFF2563EB), Colors.white, 'Staff'),
      'director' => (const Color(0xFF7C3AED), Colors.white, 'Director'),
      'leader' => (const Color(0xFF059669), Colors.white, 'Leader'),
      'coordinator' => (const Color(0xFFD97706), Colors.white, 'Coordinator'),
      'bod' => (const Color(0xFF4F46E5), Colors.white, 'Board of Directors'),
      'trustee' => (const Color(0xFF0891B2), Colors.white, 'Trustee'),
      _ => (const Color(0xFF64748B), Colors.white, 'Member'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData icon, String label) = switch (status) {
      'approved' => (
          const Color(0xFF059669),
          Colors.white,
          Icons.verified_rounded,
          'Approved'
        ),
      'rejected' => (
          const Color(0xFFDC2626),
          Colors.white,
          Icons.cancel_rounded,
          'Rejected'
        ),
      _ => (
          const Color(0xFFD97706),
          Colors.white,
          Icons.hourglass_bottom_rounded,
          'Pending'
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _InfoItem {
  final String label;
  final String value;
  final IconData icon;
  _InfoItem(this.label, this.value, this.icon);
}

class _BiometricToggle extends StatefulWidget {
  final UserProfile? profile;
  const _BiometricToggle({required this.profile});

  @override
  State<_BiometricToggle> createState() => _BiometricToggleState();
}

class _BiometricToggleState extends State<_BiometricToggle> {
  final BiometricAuthService _bio = BiometricAuthService.instance;

  bool _available = false;
  bool _enabled = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Both calls report unavailable on web, which is correct: a browser
      // build has no biometric prompt to offer.
      final available = await _bio.isBiometricAvailable();
      final enabled = available && await _bio.isBiometricEnabled();
      if (!mounted) return;
      setState(() {
        _available = available;
        _enabled = enabled;
      });
    } catch (_) {
      if (mounted) setState(() => _available = false);
    }
  }

  Future<void> _setEnabled(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (value) {
        final ok = await _promptPasswordAndEnable();
        if (!mounted) return;
        if (ok) setState(() => _enabled = true);
      } else {
        await _bio.disableBiometricAuth();
        if (!mounted) return;
        setState(() => _enabled = false);
        ToastUtils.showSuccess('Biometric sign-in turned off');
      }
    } catch (e) {
      if (!mounted) return;
      ToastUtils.showError('Could not update biometric sign-in: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Enabling stores the account's credentials for later sign-in, so the
  /// password is required again. The server is never asked for it.
  Future<bool> _promptPasswordAndEnable() async {
    final controller = TextEditingController();
      final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm your password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            helperText: 'Needed once so you can sign in with your fingerprint.',
          ),
          onSubmitted: (_) => Navigator.of(dialogContext).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (confirmed != true) return false;

    final password = controller.text;
    if (password.isEmpty) {
      ToastUtils.showError('Please enter your password');
      return false;
    }
    final email = widget.profile?.email ??
        AuthService.instance.currentUser?.email ??
        '';
    if (email.isEmpty) {
      ToastUtils.showError('No email address is available for this account');
      return false;
    }
    final ok = await _bio.enableBiometricAuth(email: email, password: password);
    if (ok) {
      ToastUtils.showSuccess('Biometric sign-in turned on');
    } else {
      ToastUtils.showError('Could not enable biometric sign-in');
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const SizedBox.shrink();
    return SwitchListTile(
      secondary: const Icon(Icons.fingerprint_rounded, color: Color(0xFF10B981)),
      title: const Text('Biometric Sign-In'),
      subtitle: const Text('Use your fingerprint or face to sign in'),
      value: _enabled,
      onChanged: _busy ? null : _setEnabled,
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_InfoItem> items;
  const _InfoSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1),
          ...items.map((item) => _InfoRow(item: item)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final _InfoItem item;
  const _InfoRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSet = item.value != 'Not set';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(item.icon, size: 20,
              color: isSet
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                    )),
                const SizedBox(height: 2),
                Text(
                  item.value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSet
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.outline,
                    fontStyle: isSet ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDanger;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: isDanger ? theme.colorScheme.error : null,
          fontWeight: isDanger ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ))
          : null,
      trailing: Icon(Icons.arrow_forward_ios,
          size: 16,
          color: isDanger
              ? theme.colorScheme.error
              : theme.colorScheme.onSurface.withValues(alpha: 0.3)),
      onTap: onTap,
    );
  }
}

class _ProfileScreenSkeleton extends StatelessWidget {
  const _ProfileScreenSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: const [
          Center(child: ShimmerLoading(width: 88, height: 88, borderRadius: 44)),
          SizedBox(height: 16),
          Center(child: ShimmerLoading(width: 160, height: 22, borderRadius: 6)),
          SizedBox(height: 8),
          Center(child: ShimmerLoading(width: 200, height: 14, borderRadius: 4)),
          SizedBox(height: 24),
          ShimmerLoading(height: 160, borderRadius: 16),
          SizedBox(height: 16),
          ShimmerLoading(height: 200, borderRadius: 16),
        ],
      ),
    );
  }
}
