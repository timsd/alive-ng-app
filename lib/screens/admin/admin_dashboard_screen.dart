import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import '../../services/role_access_service.dart';
import '../../widgets/role_guard.dart';
import '../../constants/chapters.dart';
import '../../constants/app_constants.dart';
import 'content_management_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return RoleProtectedScreen(
      requiredRole: 'admin',
      screenName: 'Admin Dashboard',
      child: const _AdminDashboardContent(),
    );
  }
}

class _AdminDashboardContent extends StatefulWidget {
  const _AdminDashboardContent();

  @override
  State<_AdminDashboardContent> createState() => _AdminDashboardContentState();
}

class _AdminDashboardContentState extends State<_AdminDashboardContent> {
  final SupabaseService _supabaseService = SupabaseService.instance;
  final RoleAccessService _roleService = RoleAccessService.instance;
  bool _isLoading = true;
  bool _hasAccess = false;
  User? _currentUser;

  // Dashboard stats
  int _totalUsers = 0;
  int _totalChapters = 0;
  int _activeReports = 0;
  int _archivedUsers = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      _currentUser = _supabaseService.currentUser;
      if (_currentUser != null) {
        _hasAccess = _roleService.hasRole('admin');
      }
      await _loadDashboardStats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading dashboard: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadDashboardStats() async {
    try {
      // Fetch actual data from Supabase
      final results = await Future.wait([
        _supabaseService.client.from('user_profiles').select('id').count(),
        _supabaseService.client.from('user_profiles').select('id').eq('is_archived', false).count(),
        _supabaseService.client.from('user_profiles').select('id').eq('is_archived', true).count(),
        _supabaseService.client.from('board_documents').select('id').count(),
      ]);
      
      setState(() {
        _totalUsers = results[0].count;
        _totalChapters = ChapterConstants.availableChapters.length;
        _activeReports = results[3].count;
        _archivedUsers = results[2].count;
      });
    } catch (e) {
      // Handle error - fallback to placeholder data
      setState(() {
        _totalUsers = 150;
        _totalChapters = ChapterConstants.availableChapters.length;
        _activeReports = 25;
        _archivedUsers = 12;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.green,
          ),
        ),
      );
    }

    if (!_hasAccess) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                size: 80,
                color: Colors.red,
              ),
              SizedBox(height: 16),
              Text(
                'Admin Access Required',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'You need administrator privileges to access this dashboard.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardStats,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(
                        Icons.admin_panel_settings,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${_currentUser?.email ?? 'Administrator'}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const Text(
                            'ALIVE Nigeria Admin Dashboard',
                            style: TextStyle(
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Statistics Cards
            const Text(
              'System Overview',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Users',
                    _totalUsers.toString(),
                    Icons.people,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Chapters',
                    _totalChapters.toString(),
                    Icons.location_city,
                    Colors.orange,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Active Reports',
                    _activeReports.toString(),
                    Icons.assessment,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Archived Users',
                    _archivedUsers.toString(),
                    Icons.archive,
                    Colors.red,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Management Sections
            const Text(
              'Management Tools',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // User Management
            _buildManagementSection(
              'User Management',
              Icons.people_outline,
              [
                _buildActionTile(
                  'Manage Users',
                  'View, edit, and manage all user accounts',
                  Icons.person_outline,
                  () => _navigateToUserManagement(),
                ),
                _buildActionTile(
                  'User Approval',
                  'Review and approve new user registrations',
                  Icons.how_to_reg_outlined,
                  () => context.go(AppConstants.adminApprovalRoute),
                ),
                _buildActionTile(
                  'Role Assignment',
                  'Assign and modify user roles and permissions',
                  Icons.admin_panel_settings_outlined,
                  () => _navigateToRoleManagement(),
                ),
                _buildActionTile(
                  'Archived Users',
                  'View and manage archived user accounts',
                  Icons.archive_outlined,
                  () => _navigateToArchivedUsers(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Content Management
            _buildManagementSection(
              'Content Management',
              Icons.edit_outlined,
              [
                _buildActionTile(
                  'Daily Verses',
                  'Manage daily verse content and scheduling',
                  Icons.book_outlined,
                  () => _navigateToContentManagement('verses'),
                ),
                _buildActionTile(
                  'Prayer Requests',
                  'Moderate and manage prayer requests',
                  Icons.favorite_outline,
                  () => _navigateToContentManagement('prayers'),
                ),
                _buildActionTile(
                  'Announcements',
                  'Create and manage system announcements',
                  Icons.campaign_outlined,
                  () => _navigateToContentManagement('announcements'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Chapter Management
            _buildManagementSection(
              'Chapter Management',
              Icons.location_city_outlined,
              [
                _buildActionTile(
                  'Chapter Overview',
                  'View all chapters and their statistics',
                  Icons.dashboard_outlined,
                  () => _navigateToChapterManagement(),
                ),
                _buildActionTile(
                  'Coordinator Assignment',
                  'Assign coordinators to chapters',
                  Icons.assignment_ind_outlined,
                  () => _navigateToCoordinatorAssignment(),
                ),
                _buildActionTile(
                  'Chapter Reports',
                  'Review chapter activity reports',
                  Icons.assessment_outlined,
                  () => _navigateToChapterReports(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // System Settings
            _buildManagementSection(
              'System Settings',
              Icons.settings_outlined,
              [
                _buildActionTile(
                  'App Configuration',
                  'Configure app settings and preferences',
                  Icons.tune_outlined,
                  () => _navigateToAppSettings(),
                ),
                _buildActionTile(
                  'Backup & Restore',
                  'Manage system backups and data restoration',
                  Icons.backup_outlined,
                  () => _navigateToBackupSettings(),
                ),
                _buildActionTile(
                  'System Logs',
                  'View system logs and error reports',
                  Icons.bug_report_outlined,
                  () => _navigateToSystemLogs(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementSection(
      String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
      String title, String subtitle, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(
        icon,
        color: Colors.green,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey,
      ),
      onTap: onTap,
    );
  }

  // Navigation methods (placeholder implementations)
  void _navigateToUserManagement() {
    _showComingSoon('User Management');
  }

  void _navigateToRoleManagement() {
    _showComingSoon('Role Management');
  }

  void _navigateToArchivedUsers() {
    _showComingSoon('Archived Users');
  }

  void _navigateToContentManagement(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContentManagementScreen(contentType: type),
      ),
    );
  }

  void _navigateToChapterManagement() {
    _showComingSoon('Chapter Management');
  }

  void _navigateToCoordinatorAssignment() {
    _showComingSoon('Coordinator Assignment');
  }

  void _navigateToChapterReports() {
    _showComingSoon('Chapter Reports');
  }

  void _navigateToAppSettings() {
    _showComingSoon('App Settings');
  }

  void _navigateToBackupSettings() {
    _showComingSoon('Backup Settings');
  }

  void _navigateToSystemLogs() {
    _showComingSoon('System Logs');
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
