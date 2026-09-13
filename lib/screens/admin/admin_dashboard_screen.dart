import '../../services/appwrite_facade.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/appwrite_backend_config.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import '../../services/role_access_service.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/custom_app_bar.dart';
import '../../constants/chapters.dart';
import '../../constants/app_constants.dart';
import 'content_management_screen.dart';
import '../../models/podcast_models.dart';
import 'storage_admin_screen.dart';
import 'admin_donations_report_screen.dart';
import 'role_management_screen.dart';
import 'board_reports_screen.dart';
import '../../services/appwrite_admin_export_service.dart';
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
  final TablesDB _tables = TablesDB(appwriteClient);
  bool _isLoading = true;
  bool _hasAccess = false;
  AppUser? _currentUser;

  // Dashboard stats
  int _totalUsers = 0;
  int _totalChapters = 0;
  int _activeReports = 0;
  int _archivedUsers = 0;
  int _totalPodcasts = 0;
  Map<String, int> _podcastCategoryCounts = {};
  int _dailyUsers = 0;
  int _totalPrayerRequests = 0;
  int _answeredPrayers = 0;

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
      final now = DateTime.now();
      final todayStart =
          DateTime(now.year, now.month, now.day).toIso8601String();

      final results = await Future.wait([
        _countDocuments(
          AppwriteBackendConfig.usersCollectionId,
          queries: [Query.equal('is_archived', false)],
        ),
        _countDocuments(
          AppwriteBackendConfig.usersCollectionId,
          queries: [Query.equal('is_archived', true)],
        ),
        _countDocuments(AppwriteBackendConfig.boardReportsCollectionId),
        _listDocuments(
          AppwriteBackendConfig.podcastsCollectionId,
          queries: [Query.limit(500)],
        ),
        _calculateDailyUsers(todayStart),
        _safeCountDocuments(AppwriteBackendConfig.prayerRequestsCollectionId),
        _safeCountDocuments(
          AppwriteBackendConfig.prayerRequestsCollectionId,
          queries: [Query.equal('is_answered', true)],
        ),
      ]);

      final activeUsers = results[0] as int;
      final archivedUsers = results[1] as int;
      final activeReports = results[2] as int;
      final podcasts = results[3] as List<Podcast>;
      final dailyUsers = results[4] as int;
      final totalPrayers = results[5] as int;
      final answeredPrayers = results[6] as int;

      final Map<String, int> categoryCounts = {};
      for (final data in podcasts) {
        final category = data.category.name;
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      }

      if (!mounted) return;
      setState(() {
        _totalUsers = activeUsers;
        _archivedUsers = archivedUsers;
        _activeReports = activeReports;
        _totalChapters = ChapterConstants.availableChapters.length;
        _totalPodcasts = podcasts.length;
        _podcastCategoryCounts = categoryCounts;
        _dailyUsers = dailyUsers;
        _totalPrayerRequests = totalPrayers;
        _answeredPrayers = answeredPrayers;
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<int> _calculateDailyUsers(String todayStart) async {
    try {
      final activities = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.userActivitiesCollectionId,
        queries: [
          Query.greaterThanEqual('created_at', todayStart),
          Query.limit(500),
        ],
      );

      final userIds = activities.rows
          .map((r) => (r.data['user_id'] ?? r.data['userId']) as String?)
          .whereType<String>()
          .toSet();

      return userIds.isNotEmpty
          ? userIds.length
          : (activities.total > 0 ? activities.total : 0);
    } catch (_) {
      try {
        final events = await _tables.listRows(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.analyticsEventsCollectionId,
          queries: [
            Query.greaterThanEqual('created_at', todayStart),
            Query.limit(500),
          ],
        );
        final userIds = events.rows
            .map((r) => (r.data['user_id'] ?? r.data['userId']) as String?)
            .whereType<String>()
            .toSet();
        return userIds.length;
      } catch (_) {
        return 0;
      }
    }
  }

  Future<int> _safeCountDocuments(
    String collectionId, {
    List<String> queries = const [],
  }) async {
    try {
      return await _countDocuments(collectionId, queries: queries);
    } catch (_) {
      return 0;
    }
  }

  Future<int> _countDocuments(
    String collectionId, {
    List<String> queries = const [],
  }) async {
    final response = await _tables.listRows(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: collectionId,
      queries: [...queries, Query.limit(1)],
    );
    return response.total;
  }

  Future<List<Podcast>> _listDocuments(
    String collectionId, {
    List<String> queries = const [],
  }) async {
    final response = await _tables.listRows(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: collectionId,
      queries: queries,
    );
    return response.rows
        .map((row) => Podcast.fromJson({...row.data, 'id': row.$id}))
        .toList();
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

  BoxDecoration _panelDecoration(BuildContext context, {Color? tint}) {
    final theme = Theme.of(context);
    return BoxDecoration(
      color: tint ?? theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
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
              const SizedBox(height: 16),
              Text(
                'Admin Access Required',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
              const SizedBox(height: 8),
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
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Donations & Financial Report',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => const AdminDonationsReportScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export Data Backup',
            onPressed: () async {
              try {
                final data =
                    await AppwriteAdminExportService.instance.exportDataBackup(
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
                    await AppwriteAdminExportService.instance.exportChatBackup(
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
                final data = await AppwriteAdminExportService.instance
                    .exportChatMessages(
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
            Container(
              decoration: _panelDecoration(
                context,
                tint: Theme.of(context).colorScheme.primaryContainer,
              ),
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
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                          Text(
                            'ALIVE Nigeria Admin Dashboard',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
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

            // Community Highlights — concise archived-user style list
            Row(
              children: [
                Icon(
                  Icons.auto_graph_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Community Highlights',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildHighlightTile('Members', _totalUsers.toString(), Icons.groups_rounded),
            _buildHighlightTile('Daily active', _dailyUsers.toString(), Icons.bolt_rounded),
            _buildHighlightTile('Prayer requests', _totalPrayerRequests.toString(), Icons.favorite_rounded),
            _buildHighlightTile('Answered prayers', _answeredPrayers.toString(), Icons.verified_rounded),

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
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Chapters',
                    _totalChapters.toString(),
                    Icons.location_city,
                    Theme.of(context).colorScheme.secondary,
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
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Categories',
                    _podcastCategoryCounts.length.toString(),
                    Icons.category,
                    Theme.of(context).colorScheme.tertiary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Container(
              decoration: _panelDecoration(context),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.legend_toggle,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Podcast Categories Breakdown',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
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
                          avatar: Icon(Icons.label,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary),
                          label: Text('$display: ${e.value}'),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
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
                    Theme.of(context).colorScheme.tertiary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Archived Users',
                    _archivedUsers.toString(),
                    Icons.archive,
                    Theme.of(context).colorScheme.error,
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

            // Finance & Donation Management
            _buildManagementSection(
              'Finance & Donation Management',
              Icons.monetization_on_outlined,
              [
                _buildActionTile(
                  'Donation Reports & Analytics',
                  'View all incoming donations, track fund usage, and download reports',
                  Icons.receipt_long_outlined,
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => const AdminDonationsReportScreen(),
                    ),
                  ),
                ),
              ],
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
                  'Manage buckets and files, including audio, PDFs and profile pictures',
                  Icons.folder_outlined,
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

  Widget _buildHighlightTile(String title, String value, IconData icon) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shadowColor: color.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
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
    return Container(
      decoration: _panelDecoration(context),
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
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
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
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
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
            ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        builder: (context) =>
            const ContentManagementScreen(contentType: 'chapters'),
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
        builder: (context) =>
            const ContentManagementScreen(contentType: 'settings'),
      ),
    );
  }

  void _navigateToBackupSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const StorageAdminScreen(initialBucket: 'system-backups'),
      ),
    );
  }

  void _navigateToSystemLogs() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const StorageAdminScreen(initialBucket: 'app-logs'),
      ),
    );
  }
}
