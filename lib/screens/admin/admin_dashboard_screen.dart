import '../../services/appwrite_facade.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/appwrite_backend_config.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import '../../services/role_access_service.dart';
import '../../services/office_access_service.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/custom_app_bar.dart';
import '../../constants/chapters.dart';
import '../../constants/app_constants.dart';
import 'content_management_screen.dart';
import 'admin_announcements_screen.dart';
import 'admin_chapters_screen.dart';
import 'chapter_reports_screen.dart';
import 'app_settings_screen.dart';
import '../../models/podcast_models.dart';
import 'storage_admin_screen.dart';
import 'admin_donations_report_screen.dart';
import '../../services/appwrite_admin_export_service.dart';
import '../../services/monthly_reminder_setting_service.dart';
import '../../utils/responsive_utils.dart';
import '../../models/discipleship_models.dart';
import '../../services/discipleship_service.dart';
import 'package:intl/intl.dart';

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

  /// Whether the signed-in person may see Donations & Finance.
  ///
  /// This is gated on the OFFICE (Treasurer or Executive President) held in
  /// `org_office_holders`, not on the role ladder -- `treasurer` and
  /// `president` are offices, and the role hierarchy has no such entries.
  /// An admin always passes. Defaults to false so the section stays hidden
  /// until the office has actually been confirmed.
  bool _canAccessFinance = false;

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

  /// Resolves whether this person holds a financial office.
  ///
  /// Fails closed: any error, or a user the office table cannot be matched
  /// to, leaves the section hidden. An admin bypasses the lookup, because an
  /// administrator must still be able to reach finance to repair data.
  Future<void> _resolveFinanceAccess() async {
    final user = _currentUser;
    if (user == null) {
      _canAccessFinance = false;
      return;
    }
    if (_roleService.hasRole('admin')) {
      _canAccessFinance = true;
      return;
    }
    try {
      _canAccessFinance = await OfficeAccessService.instance.canAccessFinance(
        userId: user.uid,
        email: user.email,
      );
    } catch (_) {
      _canAccessFinance = false;
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      _currentUser = AuthService.instance.currentUser;
      if (_currentUser != null) {
        _hasAccess = _roleService.hasRole('admin');
      }
      await _resolveFinanceAccess();
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
        showDonationButton: false,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh dashboard',
            onPressed: _loadDashboardStats,
          ),

          IconButton(
            icon: const Icon(Icons.chat_outlined),
            tooltip: 'Export Chat (channels + messages)',
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
                            Text(
                                'Channels exported: ${data['count'] ?? 0}'),
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
                            TextButton(
                              onPressed: () async {
                                try {
                                  final msgData =
                                      await AppwriteAdminExportService.instance
                                          .exportChatMessages(
                                    type: 'messaging',
                                    limitPerChannel: 500,
                                  );
                                  if (!context.mounted) return;
                                  final files =
                                      (msgData['files'] as List?) ?? const [];
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Messages exported: ${files.length} channel file(s)'),
                                    ),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Chat messages export failed: $e'),
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .error,
                                    ),
                                  );
                                }
                              },
                              child: const Text('Also Export Messages'),
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
                  'Sample Content (user-facing seeds)',
                  'Hide or restore sample podcasts & episodes users currently see',
                  Icons.preview_outlined,
                  () => context.go(AppConstants.sampleContentAdminRoute),
                ),
                _buildActionTile(
                  'Monthly Support Reminder',
                  'Send on the 1st of each month. Enable to let members opt out themselves.',
                  Icons.notifications_active_outlined,
                  () => _showMonthlyReminderControl(),
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
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminAnnouncementsScreen(),
                    ),
                  ),
                ),
                _buildActionTile(
                  'Kids Stories',
                  'Upload PDF to extract text or type in content and upload media (choose which to use)',
                  Icons.auto_stories,
                  () => context.go(AppConstants.adminKidsStoriesRoute),
                ),
                _buildActionTile(
                  'Kids Missions',
                  'Upload PDF to extract text or type in content and upload media (choose which to use)',
                  Icons.assignment_turned_in,
                  () => context.go(AppConstants.adminKidsMissionsRoute),
                ),
                _buildActionTile(
                  'Study Guides',
                  'Upload PDF to extract text or type in content and upload media (choose which to use)',
                  Icons.menu_book,
                  () => context.go(AppConstants.adminStudyGuidesRoute),
                ),
                _buildActionTile(
                  'Health+ Content',
                  'Manage plant-based recipes, natural remedies, and community discussions',
                  Icons.health_and_safety_rounded,
                  () => context.go(AppConstants.adminHealthContentRoute),
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

            // Donations & Finance
            //
            // Restricted to the Treasurer and Executive President. Previously
            // this section had no check of its own, so anyone who could reach
            // the dashboard at all also saw every gift and the finance report.
            if (_canAccessFinance)
              _buildManagementSection(
                'Donations & Finance',
                Icons.savings_outlined,
                [
                  _buildActionTile(
                    'Donation Reports',
                    'Search, filter and export every gift, including the purpose '
                        'each donation was designated toward',
                    Icons.receipt_long_outlined,
                    () => context.go(AppConstants.adminDonationsReportRoute),
                  ),
                ],
              ),

            const SizedBox(height: 16),

            // Discipleship Operations
            _buildManagementSection(
              'Discipleship Operations',
              Icons.people_outline,
              [
                _buildActionTile(
                  'Report Officers & Routing',
                  'Map Coordinators and Directors to receive dispatched discipleship reports',
                  Icons.mark_email_read_outlined,
                  () => _showOfficerRoutingDialog(),
                ),
                _buildActionTile(
                  'Disciple Deletion Requests',
                  'Review and approve or reject disciple deletion requests',
                  Icons.person_remove_outlined,
                  () => _showDeletionRequestsDialog(),
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

  /// Admin control for the monthly ministry-support reminder.
  /// When enabled, members get an opt-out toggle in their notification
  /// preferences; when disabled the toggle is greyed out and everyone
  /// receives the reminder on the 1st of each month.
  Future<void> _showMonthlyReminderControl() async {
    final current =
        await MonthlyReminderSettingService.isUserToggleEnabled();
    if (!mounted) return;

    var enabled = current;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Monthly Support Reminder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sent to all members on the 1st of each month, reminding them '
                'to support the ministry and honour monthly commitments.',
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Let members opt out'),
                subtitle: Text(
                  enabled
                      ? 'Members can turn this reminder off themselves'
                      : 'Everyone receives it (toggle is greyed out for members)',
                ),
                value: enabled,
                onChanged: (value) => setDialogState(() => enabled = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final saved = await MonthlyReminderSettingService
                    .setUserToggleEnabled(enabled);
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      saved
                          ? (enabled
                              ? 'Members can now opt out of the monthly reminder'
                              : 'Monthly reminder is now admin-managed for everyone')
                          : 'Could not save the monthly reminder setting',
                    ),
                  ),
                );
              },
              child: const Text('Save'),
            ),
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
        builder: (context) => const AdminChaptersScreen(),
      ),
    );
  }

  void _navigateToChapterReports() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChapterReportsScreen(),
      ),
    );
  }

  void _navigateToAppSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AppSettingsScreen(),
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

  // Discipleship Officer Mapping & Report Routing Dialog
  void _showOfficerRoutingDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.mark_email_read_outlined,
                      color: colorScheme.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Discipleship Report Officers'),
                  ),
                ],
              ),
              content: SizedBox(
                width: 550,
                child: FutureBuilder<List<OfficerOfficeAssignment>>(
                  future: DiscipleshipService.instance.getOfficerAssignments(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final assignments = snapshot.data ?? [];
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Designate Coordinators and Directors to receive dispatched reports from disciple makers:',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (assignments.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                Icon(Icons.person_off_outlined,
                                    size: 40,
                                    color: colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.5)),
                                const SizedBox(height: 8),
                                Text(
                                  'No officers assigned yet',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: assignments.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final a = assignments[index];
                                final isDirector =
                                    a.officeType.toLowerCase() == 'director';
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: isDirector
                                        ? colorScheme.primary
                                            .withValues(alpha: 0.15)
                                        : colorScheme.secondary
                                            .withValues(alpha: 0.15),
                                    child: Icon(
                                      isDirector
                                          ? Icons.shield_outlined
                                          : Icons.co_present_outlined,
                                      color: isDirector
                                          ? colorScheme.primary
                                          : colorScheme.secondary,
                                    ),
                                  ),
                                  title: Text(
                                    a.officeTitle,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    '${a.officerName}\n${a.officerEmail}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  isThreeLine: true,
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.redAccent),
                                    tooltip: 'Remove office assignment',
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                          title: const Text('Remove Officer?'),
                                          content: Text(
                                              'Remove ${a.officerName} from ${a.officeTitle}?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(c, false),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(c, true),
                                              child: const Text('Remove'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await DiscipleshipService.instance
                                            .removeOfficerAssignment(a.id);
                                        setDialogState(() {});
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Close'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Assign Officer'),
                  onPressed: () => _showAddOfficerDialog(setDialogState),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddOfficerDialog(void Function(void Function()) parentSetState) {
    final titleController = TextEditingController();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final idController = TextEditingController();
    String officeType = 'coordinator';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSubState) {
            return AlertDialog(
              title: const Text('Assign Report Officer'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Office / Role Title *',
                        hintText: 'e.g. Zonal Director, District Coordinator',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: officeType,
                      decoration: const InputDecoration(labelText: 'Office Type *'),
                      items: const [
                        DropdownMenuItem(
                            value: 'coordinator', child: Text('Coordinator')),
                        DropdownMenuItem(
                            value: 'director', child: Text('Director')),
                      ],
                      onChanged: (val) {
                        if (val != null) setSubState(() => officeType = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Officer Full Name *',
                        hintText: 'e.g. Pastor John Doe',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Officer Email *',
                        hintText: 'e.g. pastor.john@aliveng.org',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: idController,
                      decoration: const InputDecoration(
                        labelText: 'User ID (Optional)',
                        hintText: 'Leave empty to auto-generate',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty ||
                        nameController.text.trim().isEmpty ||
                        emailController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please fill all required fields')),
                      );
                      return;
                    }
                    final officerId = idController.text.trim().isEmpty
                        ? emailController.text.trim().toLowerCase()
                        : idController.text.trim();
                    await DiscipleshipService.instance.assignOfficerToOffice(
                      officeTitle: titleController.text.trim(),
                      officeType: officeType,
                      officerName: nameController.text.trim(),
                      officerEmail: emailController.text.trim(),
                      officerId: officerId,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    parentSetState(() {});
                  },
                  child: const Text('Save Assignment'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Disciple Deletion Requests Approval Queue
  void _showDeletionRequestsDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setQueueState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.person_remove_outlined,
                      color: colorScheme.primary),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Disciple Deletion Requests')),
                ],
              ),
              content: SizedBox(
                width: 600,
                child: FutureBuilder<List<DiscipleDeletionRequest>>(
                  future: DiscipleshipService.instance.getDeletionRequests(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final requests = snapshot.data ?? [];
                    if (requests.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 48,
                                color: Colors.green.withValues(alpha: 0.7)),
                            const SizedBox(height: 12),
                            Text(
                              'No deletion requests pending',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Coordinators and Directors can request deletion of disciples who have zero activity records.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: requests.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final req = requests[index];
                          final isPending =
                              req.status == DeletionRequestStatus.pending;
                          final isApproved =
                              req.status == DeletionRequestStatus.approved;

                          final statusColor = isPending
                              ? Colors.orange
                              : (isApproved ? Colors.green : Colors.red);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        req.contactName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: statusColor.withValues(alpha: 0.5)),
                                      ),
                                      child: Text(
                                        req.status.name.toUpperCase(),
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Requested by: ${req.requesterName} (${req.requesterRole}) · ${DateFormat.yMMMd().format(req.createdAt)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                if (req.reason.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Reason: ${req.reason}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                                if (req.adminReviewNotes != null &&
                                    req.adminReviewNotes!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Admin Note: ${req.adminReviewNotes}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                                if (isPending) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(
                                              color: Colors.red),
                                        ),
                                        onPressed: () => _handleRejectDeletion(
                                            req, setQueueState),
                                        child: const Text('Reject'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.redAccent,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () => _handleApproveDeletion(
                                            req, setQueueState),
                                        child: const Text('Approve Deletion'),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleApproveDeletion(DiscipleDeletionRequest req,
      void Function(void Function()) parentSetState) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirm Permanent Deletion'),
        content: Text(
            'Are you sure you want to approve deletion for "${req.contactName}"? This will permanently remove the contact record from the system.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DiscipleshipService.instance
          .approveDeletionRequest(req.id, adminNotes: 'Approved by admin');
      parentSetState(() {});
    }
  }

  Future<void> _handleRejectDeletion(DiscipleDeletionRequest req,
      void Function(void Function()) parentSetState) async {
    final noteController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reject Deletion Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Provide a reason for rejecting the deletion of "${req.contactName}":'),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason *',
                hintText: 'e.g. Please archive or reassign instead.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(c, noteController.text.trim()),
            child: const Text('Submit Rejection'),
          ),
        ],
      ),
    );
    if (reason != null && reason.isNotEmpty) {
      await DiscipleshipService.instance
          .rejectDeletionRequest(req.id, reason: reason);
      parentSetState(() {});
    }
  }
}
