import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../services/role_access_service.dart';

class AdminClaimsPreviewScreen extends ConsumerWidget {
  const AdminClaimsPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final roleService = RoleAccessService.instance;

    final claims = <Map<String, dynamic>>[
      {
        'name': 'Access Admin Dashboard',
        'granted': true,
        'desc': 'Visit and use admin dashboard',
      },
      {
        'name': 'Manage Users',
        'granted': true,
        'desc': 'Approve, reject, archive users',
      },
      {
        'name': 'Manage Roles',
        'granted': true,
        'desc': 'Assign and update user roles',
      },
      {
        'name': 'Create Content',
        'granted': true,
        'desc': 'Pages, announcements, featured content',
      },
      {
        'name': 'Create Missions',
        'granted': true,
        'desc': 'Add and manage mission activities',
      },
      {
        'name': 'Create Events',
        'granted': true,
        'desc': 'Schedule and manage events',
      },
      {
        'name': 'Manage Donations',
        'granted': true,
        'desc': 'View donation logs and reports',
      },
      {
        'name': 'Access Board Documents',
        'granted': true,
        'desc': 'View BOD and leadership docs',
      },
      {
        'name': 'Access Financial Reports',
        'granted': true,
        'desc': 'View finance-related reports',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Claims Preview'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderCard(context, user),
          const SizedBox(height: 16),
          _buildPreviewInfoCard(context, roleService),
          const SizedBox(height: 16),
          _buildClaimsList(context, claims),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, AppUser? user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current User',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'UID: ${user?.uid ?? 'Not signed in'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Email: ${user?.email ?? 'N/A'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewInfoCard(
    BuildContext context,
    RoleAccessService roleService,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Access Mode',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Production role enforcement active. Real Appwrite roles are verified.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _pill(context, 'Role Guards Enforced', true),
                _pill(
                  context,
                  'Has Admin Access',
                  roleService.canAccessAdmin(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Note: This screen previews claims. In production, real Appwrite role checks are strictly enforced.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimsList(
    BuildContext context,
    List<Map<String, dynamic>> claims,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Capabilities',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...claims.map(
              (c) => ListTile(
                leading: Icon(
                  c['granted'] ? Icons.check_circle : Icons.cancel,
                  color: c['granted']
                      ? Theme.of(context).colorScheme.tertiary
                      : Theme.of(context).colorScheme.error,
                ),
                title: Text(c['name'] as String),
                subtitle: Text(c['desc'] as String),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, String label, bool enabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: enabled
            ? Theme.of(context)
                .colorScheme
                .tertiaryContainer
                .withValues(alpha: 0.15)
            : Theme.of(context)
                .colorScheme
                .secondaryContainer
                .withValues(alpha: 0.15),
        border: Border.all(
          color: enabled
              ? Theme.of(context).colorScheme.tertiary
              : Theme.of(context).colorScheme.secondary,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enabled ? Icons.check : Icons.info,
            size: 16,
            color: enabled
                ? Theme.of(context).colorScheme.tertiary
                : Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
