import 'dart:convert';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
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
import 'ssl_status_screen.dart';
import '../../services/appwrite_admin_export_service.dart';
import '../../services/monthly_reminder_setting_service.dart';
import '../../utils/responsive_utils.dart';
import '../../models/discipleship_models.dart';
import '../../services/discipleship_service.dart';
import '../../widgets/shimmer_loading.dart';
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

class _AdminDashboardContentState extends State<_AdminDashboardContent>
    with TickerProviderStateMixin {
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

  // ─── Premium animation & search ───
  late final AnimationController _staggerController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _loadDashboardData();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
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
        _staggerController.forward();
      }
    }
  }

  Future<void> _loadDashboardStats() async {
    try {
      final now = DateTime.now();
      final todayStart =
          DateTime(now.year, now.month, now.day).toIso8601String();

      final results = await Future.wait([
        // Total users registered in system
        _safeCountDocuments(AppwriteBackendConfig.usersCollectionId),
        // Archived users
        _safeCountDocuments(
          AppwriteBackendConfig.usersCollectionId,
          queries: [Query.equal('is_archived', true)],
        ),
        // Chapter reports
        _safeCountDocuments(AppwriteBackendConfig.chapterReportsCollectionId),
        // Board reports
        _safeCountDocuments(AppwriteBackendConfig.boardReportsCollectionId),
        // Podcasts
        _listDocuments(
          AppwriteBackendConfig.podcastsCollectionId,
          queries: [Query.limit(500)],
        ),
        // Daily active users
        _calculateDailyUsers(todayStart),
        // Prayer requests
        _safeCountDocuments(AppwriteBackendConfig.prayerRequestsCollectionId),
        // Answered prayers
        _safeCountDocuments(
          AppwriteBackendConfig.prayerRequestsCollectionId,
          queries: [Query.equal('is_answered', true)],
        ),
        // Real chapters in DB
        _safeCountDocuments(AppwriteBackendConfig.chaptersCollectionId),
      ]);

      final totalUsers = results[0] as int;
      final archivedUsers = results[1] as int;
      final activeUsers = (totalUsers - archivedUsers).clamp(0, 999999);
      final chapterReports = results[2] as int;
      final boardReports = results[3] as int;
      final totalReports = chapterReports + boardReports;
      final podcasts = results[4] as List<Podcast>;
      final dailyUsers = results[5] as int;
      final totalPrayers = results[6] as int;
      final answeredPrayers = results[7] as int;
      final dbChapters = results[8] as int;
      final totalChapters = dbChapters > 0
          ? dbChapters
          : ChapterConstants.availableChapters.length;

      final Map<String, int> categoryCounts = {};
      for (final data in podcasts) {
        final category = data.category.name;
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      }

      if (!mounted) return;
      setState(() {
        _totalUsers = activeUsers;
        _archivedUsers = archivedUsers;
        _activeReports = totalReports;
        _totalChapters = totalChapters;
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
        appBar: CustomAppBar(
          showBackButton: true,
          showDonationButton: false,
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
        body: const AdminDashboardSkeleton(),
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

    final isWide = MediaQuery.of(context).size.width >= 920;

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
            onPressed: () {
              _staggerController.reset();
              _loadDashboardStats().then((_) {
                if (mounted) _staggerController.forward();
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const AdminDashboardSkeleton()
          : (isWide ? _buildDesktopLayout(context) : _buildMobileLayout(context)),
    );
  }

  // ─── Desktop: sidebar + content ───

  Widget _buildDesktopLayout(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        // Sidebar
        Container(
          width: 240,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              right: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    'NAVIGATION',
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                _buildSidebarTile(Icons.people_outline, 'Manage Users', () => context.go(AppConstants.roleManagementRoute)),
                _buildSidebarTile(Icons.how_to_reg_outlined, 'Approvals', () => context.go(AppConstants.adminApprovalRoute)),
                _buildSidebarTile(Icons.library_books_outlined, 'Content', () => context.go(AppConstants.tractPodcastAdminRoute)),
                _buildSidebarTile(Icons.location_city_outlined, 'Chapters', () => _navigateToChapterManagement()),
                if (_canAccessFinance)
                  _buildSidebarTile(Icons.savings_outlined, 'Finance', () => context.go(AppConstants.adminDonationsReportRoute)),
                _buildSidebarTile(Icons.people_outline, 'Discipleship', () => _showOfficerRoutingDialog()),
                _buildSidebarTile(Icons.cloud_upload_outlined, 'Storage', () => _navigateToStorageAdmin()),
                _buildSidebarTile(Icons.settings_outlined, 'Settings', () => _navigateToAppSettings()),
                const Divider(height: 32),
                _buildSidebarTile(Icons.archive_outlined, 'Archived', () => context.go(AppConstants.userArchiveRoute)),
                _buildSidebarTile(Icons.lock_clock_outlined, 'SSL Check', () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SSLStatusScreen()),
                )),
              ],
            ),
          ),
        ),
        // Main content area
        Expanded(
          child: _buildScrollableContent(context),
        ),
      ],
    );
  }

  Widget _buildSidebarTile(IconData icon, String label, VoidCallback onTap) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Mobile: single-column scroll ───

  Widget _buildMobileLayout(BuildContext context) {
    return _buildScrollableContent(context);
  }

  // ─── Shared scrollable content ───

  Widget _buildScrollableContent(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 920;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 28 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Hero welcome banner ───
          _buildStaggeredChild(
            index: 0,
            child: _buildHeroBanner(context),
          ),

          const SizedBox(height: 24),

          // ─── Unified stats grid (no duplicate) ───
          _buildStaggeredChild(
            index: 1,
            child: _buildStatsGrid(context),
          ),

          const SizedBox(height: 24),

          // ─── Podcast breakdown (collapsible) ───
          if (_totalPodcasts > 0) ...[
            _buildStaggeredChild(
              index: 2,
              child: _buildPodcastBreakdownPanel(context),
            ),
            const SizedBox(height: 24),
          ],

          // ─── Management tools search ───
          _buildStaggeredChild(
            index: 3,
            child: _buildManagementHeader(context),
          ),

          const SizedBox(height: 16),

          // ─── Management sections ───
          _buildStaggeredChild(
            index: 4,
            child: _buildFilteredManagementSections(context),
          ),
        ],
      ),
    );
  }

  // ─── Staggered animation wrapper ───

  Widget _buildStaggeredChild({required int index, required Widget child}) {
    final delay = (index * 0.12).clamp(0.0, 0.6);
    final end = (delay + 0.4).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: _staggerController,
      curve: Interval(delay, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - animation.value)),
            child: child,
          ),
        );
      },
    );
  }

  // ─── Hero banner with gradient ───

  Widget _buildHeroBanner(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  theme.colorScheme.primary.withValues(alpha: 0.25),
                  theme.colorScheme.secondary.withValues(alpha: 0.12),
                ]
              : [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.75),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.admin_panel_settings,
                color: isDark ? theme.colorScheme.primary : Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${_currentUser?.email != null ? _currentUser!.email.split('@').first : 'Administrator'}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? theme.colorScheme.onSurface : Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ALIVE Nigeria Admin Dashboard',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? theme.colorScheme.onSurfaceVariant
                          : Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Unified stats grid (replaces duplicate Community Highlights + System Overview) ───

  Widget _buildStatsGrid(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 920;
    final crossCount = isWide ? 4 : 2;

    final stats = [
      _StatItem('Members', _totalUsers.toString(), Icons.groups_rounded, theme.colorScheme.primary),
      _StatItem('Daily Active', _dailyUsers.toString(), Icons.bolt_rounded, theme.colorScheme.tertiary),
      _StatItem('Prayers', _totalPrayerRequests.toString(), Icons.favorite_rounded, const Color(0xFFE5513E)),
      _StatItem('Answered', _answeredPrayers.toString(), Icons.verified_rounded, const Color(0xFF2FAD72)),
      _StatItem('Chapters', _totalChapters.toString(), Icons.location_city_rounded, theme.colorScheme.secondary),
      _StatItem('Podcasts', _totalPodcasts.toString(), Icons.podcasts_rounded, const Color(0xFF8B5CF6)),
      _StatItem('Reports', _activeReports.toString(), Icons.assessment_rounded, const Color(0xFF0EA5E9)),
      _StatItem('Archived', _archivedUsers.toString(), Icons.archive_rounded, theme.colorScheme.error),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: isWide ? 1.55 : 1.10,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) => _buildPremiumStatCard(stats[index]),
    );
  }

  Widget _buildPremiumStatCard(_StatItem item) {
    return _buildStatCard(item.title, item.value, item.icon, item.color);
  }

  // ─── Podcast categories breakdown ───

  Widget _buildPodcastBreakdownPanel(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: _panelDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.legend_toggle, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Podcast Categories',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '$_totalPodcasts total',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _podcastCategoryCounts.entries.map((e) {
                final display = _displayPodcastCategory(e.key);
                return Chip(
                  avatar: Icon(Icons.label, size: 16, color: theme.colorScheme.primary),
                  label: Text('$display: ${e.value}',
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Management header with search ───

  Widget _buildManagementHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Management Tools',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Search tools...',
            prefixIcon: Icon(Icons.search, size: 20, color: theme.colorScheme.onSurfaceVariant),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Filtered management sections ───

  Widget _buildFilteredManagementSections(BuildContext context) {
    final q = _searchQuery;

    // Each tile carries a searchable label so we can filter the whole section
    final sections = <_MgmtSection>[
      _MgmtSection('User Management', Icons.people_outline, [
        _MgmtTile('Manage Users', 'View, edit, and manage all user accounts', Icons.person_outline, () => _navigateToUserManagement()),
        _MgmtTile('User Approval', 'Review and approve new user registrations', Icons.how_to_reg_outlined, () => context.go(AppConstants.adminApprovalRoute)),
        _MgmtTile('Archived Users', 'View and manage archived user accounts', Icons.archive_outlined, () => _navigateToArchivedUsers()),
      ]),
      _MgmtSection('Content Management', Icons.library_books_outlined, [
        _MgmtTile('Tract & Podcast Management', 'Manage tracts, podcasts, and categories', Icons.article_outlined, () => context.go(AppConstants.tractPodcastAdminRoute)),
        _MgmtTile('Sample Content (user-facing seeds)', 'Hide or restore sample podcasts & episodes users currently see', Icons.preview_outlined, () => context.go(AppConstants.sampleContentAdminRoute)),
        _MgmtTile('Monthly Support Reminder', 'Send on the 1st of each month. Enable to let members opt out.', Icons.notifications_active_outlined, () => _showMonthlyReminderControl()),
        _MgmtTile('Featured Content', 'Manage featured content and highlights', Icons.star_outline, () => _navigateToContentManagement('featured')),
        _MgmtTile('Announcements', 'Create and manage app announcements', Icons.campaign_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAnnouncementsScreen()))),
        _MgmtTile('Kids Stories', 'Upload PDF or type content with media', Icons.auto_stories, () => context.go(AppConstants.adminKidsStoriesRoute)),
        _MgmtTile('Kids Missions', 'Upload PDF or type content with media', Icons.assignment_turned_in, () => context.go(AppConstants.adminKidsMissionsRoute)),
        _MgmtTile('Study Guides', 'Upload PDF or type content with media', Icons.menu_book, () => context.go(AppConstants.adminStudyGuidesRoute)),
        _MgmtTile('Content Pages & Projects', 'Manage app content pages, custom sections, and projects', Icons.post_add_outlined, () => context.go(AppConstants.contentManagementRoute)),
        _MgmtTile('Health+ Content', 'Manage plant-based recipes, remedies, and discussions', Icons.health_and_safety_rounded, () => context.go(AppConstants.adminHealthContentRoute)),
      ]),
      _MgmtSection('Chapter Management', Icons.location_city_outlined, [
        _MgmtTile('Chapter Overview', 'View all chapters and their statistics', Icons.dashboard_outlined, () => _navigateToChapterManagement()),
        _MgmtTile('Leadership Archive', 'View historical leadership records', Icons.history_edu, () => context.go(AppConstants.leadershipArchiveRoute)),
        _MgmtTile('Board of Trustees (BOD)', 'Manage Board records, resolutions, decisions', Icons.account_balance_outlined, () => context.go(AppConstants.bodTrusteesRoute)),
        _MgmtTile('Chapter Reports', 'Review chapter activity reports', Icons.assessment_outlined, () => _navigateToChapterReports()),
      ]),
      if (_canAccessFinance)
        _MgmtSection('Donations & Finance', Icons.savings_outlined, [
          _MgmtTile('Donation Reports', 'Search, filter and export every gift', Icons.receipt_long_outlined, () => context.go(AppConstants.adminDonationsReportRoute)),
        ]),
      _MgmtSection('Discipleship Operations', Icons.people_outline, [
        _MgmtTile('Report Officers & Routing', 'Map Coordinators and Directors to receive dispatched reports', Icons.mark_email_read_outlined, () => _showOfficerRoutingDialog()),
        _MgmtTile('Disciple Deletion Requests', 'Review and approve or reject deletion requests', Icons.person_remove_outlined, () => _showDeletionRequestsDialog()),
      ]),
      _MgmtSection('Storage Management', Icons.cloud_upload_outlined, [
        _MgmtTile('File Storage', 'Manage buckets, audio, PDFs and profile pictures', Icons.folder_outlined, () => _navigateToStorageAdmin()),
      ]),
      _MgmtSection('Communication & Data Export', Icons.import_export_rounded, [
        _MgmtTile('Chat & Messages Export', 'Export chat channels, messages, and communication backups', Icons.chat_outlined, () => _showChatExportDialog()),
      ]),
      _MgmtSection('System Settings', Icons.settings_outlined, [
        _MgmtTile('App Configuration', 'Configure app settings and preferences', Icons.tune_outlined, () => _navigateToAppSettings()),
        _MgmtTile('Backup & Restore', 'Manage system backups and data restoration', Icons.backup_outlined, () => _navigateToBackupSettings()),
        _MgmtTile('System Logs', 'View system logs and error reports', Icons.bug_report_outlined, () => _navigateToSystemLogs()),
        _MgmtTile('SSL & Network Diagnostics', 'Verify endpoint connectivity and SSL encryption', Icons.lock_clock_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SSLStatusScreen()))),
      ]),
    ];

    // Filter sections and tiles when search is active
    final List<_MgmtSection> filtered = q.isEmpty
        ? sections
        : sections
            .map<_MgmtSection?>((s) {
              final matchedTiles = s.tiles
                  .where((t) =>
                      t.title.toLowerCase().contains(q) ||
                      t.subtitle.toLowerCase().contains(q) ||
                      s.title.toLowerCase().contains(q))
                  .toList();
              return matchedTiles.isEmpty ? null : _MgmtSection(s.title, s.icon, matchedTiles);
            })
            .whereType<_MgmtSection>()
            .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            children: [
              Icon(Icons.search_off, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              Text(
                'No tools match "$_searchQuery"',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: filtered.map<Widget>((section) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildManagementSection(
            section.title,
            section.icon,
            section.tiles
                .map<Widget>((t) => _buildActionTile(t.title, t.subtitle, t.icon, t.onTap))
                .toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 920;
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
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? 16.0 : 10.0,
          vertical: isWide ? 16.0 : 10.0,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(isWide ? 8 : 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: isWide ? 26 : 22,
                color: color,
              ),
            ),
            SizedBox(height: isWide ? 10 : 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: (isWide
                        ? theme.textTheme.headlineMedium
                        : theme.textTheme.titleLarge)
                    ?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                fontSize: isWide ? 11 : 9.5,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
              const SizedBox(height: 8),
              // Oversight: who has actually declined. Without this an admin
              // cannot tell a member who opted out from one who simply never
              // gets the notification.
              if (enabled)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.people_outline, size: 18),
                    label: const Text('View members who opted out'),
                    onPressed: () => _showMonthlyReminderOptOuts(dialogContext),
                  ),
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

  /// Lists members who have opted out of the monthly giving reminder.
  ///
  /// Opened from the reminder control, and only offered while the member toggle
  /// is enabled: while it is disabled the reminder goes to everyone regardless,
  /// so an opt-out is not a meaningful state.
  Future<void> _showMonthlyReminderOptOuts(BuildContext dialogContext) async {
    final messenger = ScaffoldMessenger.of(context);
    final optOuts = await MonthlyReminderSettingService.listOptedOutMembers();
    if (!dialogContext.mounted) return;

    await showDialog<void>(
      context: dialogContext,
      builder: (listContext) => AlertDialog(
        title: const Text('Opted out of the monthly reminder'),
        content: SizedBox(
          width: 420,
          child: optOuts.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Nobody has opted out. Every member with a push target will '
                    'receive the reminder on the 1st of each month.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: optOuts.length,
                  itemBuilder: (context, index) {
                    final o = optOuts[index];
                    final subtitle =
                        (o.name != null && o.name!.trim().isNotEmpty)
                            ? o.email
                            : null;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        child: Icon(Icons.notifications_off_outlined, size: 18),
                      ),
                      title: Text(o.label),
                      subtitle: subtitle != null ? Text(subtitle) : null,
                      trailing: TextButton(
                        child: const Text('Re-enable'),
                        onPressed: () async {
                          final ok = await MonthlyReminderSettingService
                              .clearOptOut(o.userId);
                          if (!listContext.mounted) return;
                          Navigator.of(listContext).pop();
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? '${o.label} will receive the reminder again'
                                  : 'Could not update ${o.label}'),
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
            onPressed: () => Navigator.of(listContext).pop(),
            child: const Text('Close'),
          ),
        ],
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

  Future<void> _showChatExportDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final data = await AppwriteAdminExportService.instance.exportChatBackup(
        type: 'messaging',
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading

      final file = data['file'] as Map?;
      final downloadUrl = file?['url']?.toString();
      final content = data['content']?.toString() ?? '';

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.chat_outlined, color: Colors.blue),
              SizedBox(width: 8),
              Text('Chat Backup Exported'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Prefix: ${data['prefix'] ?? ''}'),
              const SizedBox(height: 8),
              Text('Channels exported: ${data['count'] ?? 0}'),
              const SizedBox(height: 12),
              const Text(
                'You can save/share the JSON backup directly or export channel message logs.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            if (content.isNotEmpty)
              OutlinedButton.icon(
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('Share / Save Backup'),
                onPressed: () async {
                  await SharePlus.instance.share(
                    ShareParams(
                      files: [
                        XFile.fromData(
                          Uint8List.fromList(utf8.encode(content)),
                          name: 'alive_chat_channels_backup.json',
                          mimeType: 'application/json',
                        ),
                      ],
                      subject: 'ALIVE Nigeria Chat Backup',
                    ),
                  );
                },
              ),
            FilledButton.icon(
              icon: const Icon(Icons.forum_outlined, size: 16),
              label: const Text('Export Messages'),
              onPressed: () async {
                try {
                  final msgData = await AppwriteAdminExportService.instance
                      .exportChatMessages(type: 'messaging', limitPerChannel: 500);
                  if (!mounted) return;
                  final files = (msgData['files'] as List?) ?? const [];
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Exported ${files.length} channel message file(s)')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Export failed: $e')),
                  );
                }
              },
            ),
            if (downloadUrl != null)
              TextButton(
                onPressed: () async {
                  final url = Uri.parse(downloadUrl);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                child: const Text('Download Link'),
              ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chat export failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
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
                      initialValue: officeType,
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

class _MgmtSection {
  final String title;
  final IconData icon;
  final List<_MgmtTile> tiles;

  const _MgmtSection(this.title, this.icon, this.tiles);
}

class _MgmtTile {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _MgmtTile(this.title, this.subtitle, this.icon, this.onTap);
}

class _StatItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem(this.title, this.value, this.icon, this.color);
}

