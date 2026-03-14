import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../services/role_access_service.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/custom_app_bar.dart';
import '../../constants/chapters.dart';
import '../../constants/app_constants.dart';
import 'content_management_screen.dart';
import '../../models/podcast_models.dart';
import 'storage_admin_screen.dart';
import 'admin_claims_preview_screen.dart';
import 'role_management_screen.dart';
import 'board_reports_screen.dart';
import '../../services/firebase_database_service.dart';
import '../../services/admin_service.dart';
import '../../services/admin_notification_service.dart';
import '../../utils/responsive_utils.dart';

import 'package:url_launcher/url_launcher.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return const RoleProtectedScreen(
      requiredRole: 'admin',
      screenName: 'Admin Dashboard',
      child: _AdminDashboardContent(),
    );
  }
}

class _AdminDashboardContent extends StatefulWidget {
  const _AdminDashboardContent();

  @override
  State<_AdminDashboardContent> createState() => _AdminDashboardContentState();
}

class _AdminDashboardContentState extends State<_AdminDashboardContent> {
  final RoleAccessService _roleService = RoleAccessService.instance;
  bool _isLoading = true;
  bool _hasAccess = false;
  User? _currentUser;

  // Dashboard stats
  int _totalUsers = 0;
  int _totalChapters = 0;
  int _activeReports = 0;
  int _archivedUsers = 0;
  int _totalPodcasts = 0;
  Map<String, int> _podcastCategoryCounts = {};

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      _currentUser = AuthService.instance.currentUser;
      if (_currentUser != null) {
        _hasAccess = _roleService.hasRole('admin');
      }
      await _loadDashboardStats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading dashboard: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
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
      // Fetch real-time stats from Firestore
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('profiles')
          .where('is_archived', isEqualTo: false)
          .get();

      final archivedUsersSnapshot = await FirebaseFirestore.instance
          .collection('profiles')
          .where('is_archived', isEqualTo: true)
          .get();

      final activeReportsSnapshot = await FirebaseFirestore.instance
          .collection('board_documents')
          .where('is_archived', isEqualTo: false)
          .get();

      final podcastsSnapshot =
          await FirebaseFirestore.instance.collection('podcasts').get();

      final Map<String, int> categoryCounts = {};
      for (final doc in podcastsSnapshot.docs) {
        final data = doc.data();
        final category = (data['category'] as String?) ?? 'uncategorized';
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      }

      setState(() {
        _totalUsers = usersSnapshot.docs.length;
        _archivedUsers = archivedUsersSnapshot.docs.length;
        _activeReports = activeReportsSnapshot.docs.length;
        _totalChapters = ChapterConstants.availableChapters.length;
        _totalPodcasts = podcastsSnapshot.docs.length;
        _podcastCategoryCounts = categoryCounts;
      });
    } catch (e) {
      // Handle error - fallback to placeholder data
      setState(() {
        _totalUsers = 150;
        _totalChapters = ChapterConstants.availableChapters.length;
        _activeReports = 25;
        _archivedUsers = 12;
        _totalPodcasts = 0;
        _podcastCategoryCounts = {};
      });
    }
  }

  String _displayPodcastCategory(String key) {
    try {
      final cat = PodcastCategory.values.firstWhere((c) => c.name == key);
      return cat.displayName;
    } catch (_) {
      if (key.isEmpty) return 'Uncategorized';
      final humanized = key.replaceAll('_', ' ');
      return humanized[0].toUpperCase() + humanized.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    if (!_hasAccess) {
      return Scaffold(
        appBar: CustomAppBar(
          showBackButton: true,
          backgroundColor: Theme.of(context).colorScheme.error,
          foregroundColor: Theme.of(context).colorScheme.onError,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                size: ResponsiveUtils.getResponsiveIconSize(context, 80),
                color: Theme.of(context).colorScheme.error,
              ),
              SizedBox(height: 16),
              Text(
                'Admin Access Required',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'You need administrator privileges to access this dashboard.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: CustomAppBar(
        showBackButton: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardStats,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export Data Backup',
            onPressed: () async {
              try {
                final data =
                    await FirebaseDatabaseService.instance.exportDataBackup(
                  collections: [
                    'profiles',
                    'prayer_requests',
                    'chapters',
                    'user_roles',
                    'user_groups',
                    'notification_history',
                  ],
                  format: 'csv',
                );
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (context) {
                      final files = (data['files'] as Map?) ?? {};
                      return AlertDialog(
                        title: const Text('Backup Exported'),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Prefix: ${data['prefix'] ?? ''}'),
                              const SizedBox(height: 12),
                              for (final entry in files.entries)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          '${entry.key}: ${entry.value['path']}'),
                                      if (entry.value['url'] != null)
                                        TextButton(
                                          onPressed: () async {
                                            final url =
                                                Uri.parse(entry.value['url']);
                                            if (await canLaunchUrl(url)) {
                                              await launchUrl(url,
                                                  mode: LaunchMode
                                                      .externalApplication);
                                            }
                                          },
                                          child:
                                              const Text('Open Download Link'),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      );
                    },
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Export failed: $e'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Export Chat Backup',
            onPressed: () async {
              try {
                final data =
                    await FirebaseDatabaseService.instance.exportChatBackup(
                  type: 'messaging',
                );
                if (context.mounted) {
                  final file = data['file'] as Map?;
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Chat Backup Exported'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Prefix: ${data['prefix'] ?? ''}'),
                            const SizedBox(height: 8),
                            Text('Channels exported: ${data['count'] ?? 0}'),
                            const SizedBox(height: 12),
                            if (file != null && file['url'] != null)
                              TextButton(
                                onPressed: () async {
                                  final url = Uri.parse(file['url']);
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url,
                                        mode: LaunchMode.externalApplication);
                                  }
                                },
                                child: const Text('Open Download Link'),
                              ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      );
                    },
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Chat export failed: $e'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat_outlined),
            tooltip: 'Export Chat Messages',
            onPressed: () async {
              try {
                final data =
                    await FirebaseDatabaseService.instance.exportChatMessages(
                  type: 'messaging',
                  limitPerChannel: 500,
                );
                if (context.mounted) {
                  final files = (data['files'] as List?) ?? const [];
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Chat Messages Exported'),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Prefix: ${data['prefix'] ?? ''}'),
                              const SizedBox(height: 12),
                              for (final item in files)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          'CID: ${item['cid']} (${item['count']} messages)'),
                                      Text('${item['path']}'),
                                      if (item['url'] != null)
                                        TextButton(
                                          onPressed: () async {
                                            final url = Uri.parse(item['url']);
                                            if (await canLaunchUrl(url)) {
                                              await launchUrl(url,
                                                  mode: LaunchMode
                                                      .externalApplication);
                                            }
                                          },
                                          child:
                                              const Text('Open Download Link'),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      );
                    },
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Chat messages export failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
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
                    CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Icon(
                        Icons.admin_panel_settings,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${_currentUser?.email ?? 'Administrator'}',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Text(
                            'ALIVE Nigeria Admin Dashboard',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
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
            Text(
              'System Overview',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
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

            const SizedBox(height: 24),

            // Podcast Stats
            Text(
              'Podcast Stats',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Podcasts',
                    _totalPodcasts.toString(),
                    Icons.podcasts,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Categories',
                    _podcastCategoryCounts.length.toString(),
                    Icons.category,
                    Colors.purple,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.legend_toggle, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Podcast Categories Breakdown',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _podcastCategoryCounts.entries.map((e) {
                        final display = _displayPodcastCategory(e.key);
                        return Chip(
                          avatar: const Icon(Icons.label,
                              size: 18, color: Colors.blue),
                          label: Text('$display: ${e.value}'),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
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
            Text(
              'Management Tools',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
              Icons.library_books_outlined,
              [
                _buildActionTile(
                  'Tract & Podcast Management',
                  'Manage tracts, podcasts, and categories',
                  Icons.article_outlined,
                  () => context.go(AppConstants.tractPodcastAdminRoute),
                ),
                _buildActionTile(
                  'Featured Content',
                  'Manage featured content and highlights',
                  Icons.star_outline,
                  () => _navigateToContentManagement('featured'),
                ),
                _buildActionTile(
                  'Announcements',
                  'Create and manage app announcements',
                  Icons.campaign_outlined,
                  () => _navigateToContentManagement('announcements'),
                ),
                _buildActionTile(
                  'Zero-Code Kids Stories',
                  'Upload PDF to extract text or type in content and upload media (choose which to use)',
                  Icons.auto_stories,
                  () => context.go(AppConstants.adminKidsStoriesRoute),
                ),
                _buildActionTile(
                  'Zero-Code Kids Missions',
                  'Upload PDF to extract text or type in content and upload media (choose which to use)',
                  Icons.assignment_turned_in,
                  () => context.go(AppConstants.adminKidsMissionsRoute),
                ),
                _buildActionTile(
                  'Zero-Code Study Guides',
                  'Upload PDF to extract text or type in content and upload media (choose which to use)',
                  Icons.menu_book,
                  () => context.go(AppConstants.adminStudyGuidesRoute),
                ),
                _buildActionTile(
                  'Kids Content (Legacy)',
                  'Manage kids stories, projects, and resources manually',
                  Icons.child_care_outlined,
                  () => context.go(AppConstants.kidsContentAdminRoute),
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
                  'Leadership Archive',
                  'View historical leadership records and past administrations',
                  Icons.history_edu,
                  () => context.go(AppConstants.leadershipArchiveRoute),
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

            // Storage Management
            _buildManagementSection(
              'Storage Management',
              Icons.cloud_upload_outlined,
              [
                _buildActionTile(
                  'File Storage',
                  'Manage Firebase Cloud Storage buckets and files',
                  Icons.folder_outlined,
                  () => _navigateToStorageAdmin(),
                ),
                _buildActionTile(
                  'Audio Files',
                  'Upload and manage audio files for podcasts',
                  Icons.audiotrack_outlined,
                  () => _navigateToStorageAdmin(),
                ),
                _buildActionTile(
                  'PDF Documents',
                  'Upload and manage PDF files for tracts',
                  Icons.picture_as_pdf_outlined,
                  () => _navigateToStorageAdmin(),
                ),
                _buildActionTile(
                  'Profile Pictures',
                  'Manage user profile pictures and avatars',
                  Icons.person_outlined,
                  () => _navigateToStorageAdmin(),
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
                  'Admin Claims Preview',
                  'Preview admin capabilities and role status',
                  Icons.verified_user_outlined,
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (ctx) => const AdminClaimsPreviewScreen()),
                  ),
                ),
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
      elevation: 4,
      shadowColor: color.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              color.withValues(alpha: 0.05),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: ResponsiveUtils.getResponsiveIconSize(context, 28),
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
      String title, String subtitle, IconData icon, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: ResponsiveUtils.getResponsiveIconSize(context, 14),
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }

  // Navigation methods (placeholder implementations)
  void _navigateToUserManagement() {
    context.go(AppConstants.roleManagementRoute);
  }

  void _navigateToRoleManagement() {
    context.go(AppConstants.roleManagementRoute);
  }

  void _navigateToArchivedUsers() {
    context.go(AppConstants.userArchiveRoute);
  }

  void _navigateToContentManagement(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContentManagementScreen(contentType: type),
      ),
    );
  }

  void _navigateToStorageAdmin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const StorageAdminScreen(),
      ),
    );
  }

  void _navigateToChapterManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ContentManagementScreen(contentType: 'chapters'),
      ),
    );
  }

  void _navigateToCoordinatorAssignment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RoleManagementScreen(),
      ),
    );
  }

  void _navigateToChapterReports() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BoardReportsScreen(),
      ),
    );
  }

  void _navigateToAppSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ContentManagementScreen(contentType: 'settings'),
      ),
    );
  }

  void _navigateToBackupSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const StorageAdminScreen(initialBucket: 'system-backups'),
      ),
    );
  }

  void _navigateToSystemLogs() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const StorageAdminScreen(initialBucket: 'app-logs'),
      ),
    );
  }
}
