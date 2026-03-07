import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_claims_preview_screen.dart';
import 'kids_content_admin_screen.dart';
import 'dev_settings_dialog.dart';
import '../../services/role_access_service.dart';

class AdminPreviewHome extends ConsumerStatefulWidget {
  const AdminPreviewHome({super.key});

  @override
  ConsumerState<AdminPreviewHome> createState() => _AdminPreviewHomeState();
}

class _AdminPreviewHomeState extends ConsumerState<AdminPreviewHome> {
  final RoleAccessService _roleService = RoleAccessService.instance;
  bool _showDevSettings = false;
  
  @override
  void initState() {
    super.initState();
    _checkRoles();
  }
  
  Future<void> _checkRoles() async {
    final hasAdminRole = _roleService.hasRole('admin');
    // Removed unused local variable; kid admin role enforced at route level
    
    if (mounted) {
      setState(() {
        _showDevSettings = hasAdminRole;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Preview'),
        actions: [
          // App view switch button
          // App view switch disabled in admin preview build to reduce dependencies
          IconButton(
            icon: const Icon(Icons.phone_android),
            tooltip: 'Switch to App View (disabled in admin preview)',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Switch to App View is disabled in admin preview build.')),
              );
            },
          ),
          // Only show dev settings if user has admin role
          if (_showDevSettings)
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Developer Settings',
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (_) => const DevSettingsDialog(),
                );
              },
            ),
        ],
      ), 
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final crossAxisCount = width < 600 ? 1 : (width < 900 ? 2 : 3);
          const childAspectRatio = 3.5;

          final items = <Widget>[
            _previewTile(
              context,
              title: 'Admin Claims Preview',
              subtitle: 'See what admin users can do',
              icon: Icons.verified_user,
              builder: (ctx) => const AdminClaimsPreviewScreen(),
            ),
            // Only show Kids Content Admin if user has kidadmin role or is a full admin
            Builder(
              builder: (context) {
                if (_roleService.hasRole('kidadmin') || _roleService.hasRole('admin')) {
                  return _previewTile(
                    context,
                    title: 'Kids Content Admin',
                    subtitle: 'Manage kids stories and resources',
                    icon: Icons.child_care,
                    builder: (ctx) => const KidsContentAdminScreen(bypassGuard: true),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            // Developer Settings tile removed as it's redundant with the icon in AppBar
          ];

          return GridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
            children: items,
          );
        },
      ),
    );
  }

  Widget _previewTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required WidgetBuilder builder,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: builder),
        ),
      ),
    );
  }
}
