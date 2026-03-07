import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/development_config.dart';
import '../../services/role_access_service.dart';

class AdminClaimsPreviewScreen extends StatelessWidget {
  const AdminClaimsPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    final roleService = RoleAccessService.instance;

    final claims = <Map<String, dynamic>>[
      {'name': 'Access Admin Dashboard', 'granted': true, 'desc': 'Visit and use admin dashboard'},
      {'name': 'Manage Users', 'granted': true, 'desc': 'Approve, reject, archive users'},
      {'name': 'Manage Roles', 'granted': true, 'desc': 'Assign and update user roles'},
      {'name': 'Create Content', 'granted': true, 'desc': 'Pages, announcements, featured content'},
      {'name': 'Create Missions', 'granted': true, 'desc': 'Add and manage mission activities'},
      {'name': 'Create Events', 'granted': true, 'desc': 'Schedule and manage events'},
      {'name': 'Manage Donations', 'granted': true, 'desc': 'View donation logs and reports'},
      {'name': 'Access Board Documents', 'granted': true, 'desc': 'View BOD and leadership docs'},
      {'name': 'Access Financial Reports', 'granted': true, 'desc': 'View finance-related reports'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Claims Preview'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderCard(user),
          const SizedBox(height: 16),
          _buildPreviewInfoCard(roleService),
          const SizedBox(height: 16),
          _buildClaimsList(claims),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(User? user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Current User', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('UID: ${user?.uid ?? 'Not signed in'}'),
            Text('Email: ${user?.email ?? 'N/A'}'),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewInfoCard(RoleAccessService roleService) {
    final devBypass = DevelopmentConfig.shouldBypassRoleGuards;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Preview Mode', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(devBypass ? Icons.check_circle : Icons.info, color: devBypass ? Colors.green : Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    devBypass
                        ? 'Development bypass is active. Admin checks are skipped.'
                        : 'Development bypass disabled. Real role checks are enforced.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _pill('Role Guards Bypassed', devBypass),
                _pill('Admin Preview Enabled', DevelopmentConfig.isAdminPreviewEnabled),
                _pill('Has Admin Access (real)', roleService.canAccessAdmin()),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Note: This screen previews what an admin can do. In development, guards may be bypassed. Disable in lib/config/development_config.dart for production.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimsList(List<Map<String, dynamic>> claims) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Admin Capabilities', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...claims.map((c) => ListTile(
                  leading: Icon(c['granted'] ? Icons.check_circle : Icons.cancel, color: c['granted'] ? Colors.green : Colors.red),
                  title: Text(c['name'] as String),
                  subtitle: Text(c['desc'] as String),
                )),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, bool enabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: enabled ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
        border: Border.all(color: enabled ? Colors.green : Colors.orange),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(enabled ? Icons.check : Icons.info, size: 16, color: enabled ? Colors.green : Colors.orange),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}
