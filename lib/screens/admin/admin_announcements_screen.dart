import 'package:flutter/material.dart';
import '../../widgets/modern_dropdown.dart';
import '../../services/appwrite_facade.dart';
import '../../config/appwrite_backend_config.dart';
import '../../services/appwrite_client.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/appwrite_upsert_helper.dart';
import '../../utils/toast_utils.dart';
import '../../utils/text_formatter.dart';
import '../../utils/layout_fix_utils.dart';
import 'announcement_editor_screen.dart';

class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  State<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  final TablesDB _tables = TablesDB(appwriteClient);
  bool _isLoading = true;
  bool _hasAttemptedAutoSeed = false;
  List<Map<String, dynamic>> _announcements = [];
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, active, inactive

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
    });
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() => _isLoading = true);
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.announcementsCollectionId,
        queries: [Query.orderDesc('created_at'), Query.limit(100)],
      );
      if (!mounted) return;
      final rows = response.rows
          .map((row) => {...Map<String, dynamic>.from(row.data), 'id': row.$id})
          .toList();
      if (rows.isEmpty && !_hasAttemptedAutoSeed) {
        _hasAttemptedAutoSeed = true;
        await _seedDefaultAnnouncements();
        return;
      }
      setState(() {
        _announcements = rows;
      });
    } catch (e) {
      debugPrint('Error loading announcements: $e');
      if (mounted) {
        setState(() {
          _announcements = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _seedDefaultAnnouncements() async {
    final now = DateTime.now().toUtc();
    final nowIso = now.toIso8601String();
    final seeds = <Map<String, dynamic>>[
      {
        'id': 'ann_retreat_2027',
        'title': 'ALIVE Nigeria National Retreat 2027',
        'content':
            'Prepare and pray toward the upcoming ALIVE Nigeria National Retreat 2027! Expect powerful Bible study, revival sessions, mission workshops, and fellowship with Adventist young adults nationwide. Registration details and venue updates will be announced soon.',
        'audience': 'all',
        'target_audience': 'all',
        'priority': 'high',
        'is_active': true,
      },
      {
        'id': 'ann_welcome_alive',
        'title': 'Welcome to ALIVE Nigeria',
        'content':
            'Stay connected with Bible studies, gospel tracts, chapter fellowship, live ALIVE Meet sessions, and ministry updates across Nigeria.',
        'audience': 'all',
        'target_audience': 'all',
        'priority': 'normal',
        'is_active': true,
      },
      {
        'id': 'ann_prayer_fellowship',
        'title': 'Weekly Intercessory Prayer Fellowship',
        'content':
            'Join brethren nationwide on the Prayer Wall and in ALIVE Meet prayer sessions as we intercede for revival, missions, and campuses across Africa.',
        'audience': 'all',
        'target_audience': 'all',
        'priority': 'normal',
        'is_active': true,
      },
    ];

    setState(() => _isLoading = true);
    try {
      for (final item in seeds) {
        final id = item['id'] as String;
        final payload = Map<String, dynamic>.from(item)..remove('id');
        payload['published_at'] = nowIso;
        payload['updated_at'] = nowIso;
        await AppwriteUpsertHelper.updateOrCreateRow(
          _tables,
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.announcementsCollectionId,
          rowId: id,
          data: payload,
          createData: {
            ...payload,
            'author_id': 'admin',
            'created_timestamp': now.millisecondsSinceEpoch,
            'created_at': nowIso,
          },
        );
      }
      await _loadAnnouncements();
      if (mounted) {
        ToastUtils.showSuccess(
          'Default & 2027 Retreat announcements seeded to Appwrite.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastUtils.showError('Could not seed announcements: $e');
      }
    }
  }

  List<Map<String, dynamic>> get _filteredAnnouncements {
    return _announcements.where((announcement) {
      final isActive = announcement['is_active'] ?? false;
      if (_selectedFilter == 'active' && !isActive) return false;
      if (_selectedFilter == 'inactive' && isActive) return false;

      if (_searchQuery.isEmpty) return true;
      final title = (announcement['title'] ?? '').toString().toLowerCase();
      final content = (announcement['content'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return title.contains(query) || content.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'App Broadcast',
        showBackButton: true,
        showDonationButton: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('New Broadcast'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search broadcasts...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  ),
                ),
                const SizedBox(width: 12),
                ModernDropdownButton<String>(
                  value: _selectedFilter,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedFilter = val);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const LoadingWidget()
                : _filteredAnnouncements.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _loadAnnouncements,
                        child: LayoutBuilder(
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.campaign_outlined,
                                        size: 64,
                                        color: colorScheme.onSurfaceVariant),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No broadcasts found',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton.icon(
                                      onPressed: () => _openEditor(),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Create Broadcast'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadAnnouncements,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredAnnouncements.length,
                          itemBuilder: (context, index) {
                            final announcement = _filteredAnnouncements[index];
                            return _buildAnnouncementCard(announcement);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> announcement) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isActive = announcement['is_active'] ?? false;
    final priority = announcement['priority'] ?? 'normal';
    final targetAudience = announcement['target_audience'] ?? 'all';

    Color priorityColor = Colors.blue;
    if (priority == 'high') priorityColor = Colors.red;
    if (priority == 'urgent') priorityColor = Colors.deepOrange;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isActive
              ? colorScheme.primary
              : colorScheme.outline.withValues(alpha: 0.5),
          child: Icon(
            Icons.campaign_rounded,
            color: isActive ? colorScheme.onPrimary : Colors.white,
          ),
        ),
        title: Text(
          announcement['title'] ?? 'Untitled',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: LayoutFixUtils.safeColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            LayoutFixUtils.safeText(announcement['content'] ?? ''),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: priorityColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: LayoutFixUtils.safeText(
                    priority.toString().toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Target: ${TextFormatter.formatRole(targetAudience).toUpperCase()}',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  isActive ? 'ACTIVE' : 'INACTIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('Edit'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: isActive ? 'deactivate' : 'activate',
              child: ListTile(
                leading: Icon(isActive ? Icons.pause_circle_outline : Icons.play_circle_outline),
                title: Text(isActive ? 'Deactivate' : 'Activate'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text('Delete', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          onSelected: (value) => _handleAction(value, announcement),
        ),
      ),
    );
  }

  void _openEditor({Map<String, dynamic>? announcement}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnnouncementEditorScreen(announcement: announcement),
      ),
    ).then((_) => _loadAnnouncements());
  }

  Future<void> _handleAction(String action, Map<String, dynamic> announcement) async {
    final id = announcement['id'] as String;
    switch (action) {
      case 'edit':
        _openEditor(announcement: announcement);
        break;
      case 'activate':
        await _toggleActive(id, true);
        break;
      case 'deactivate':
        await _toggleActive(id, false);
        break;
      case 'delete':
        await _confirmDelete(announcement);
        break;
    }
  }

  Future<void> _toggleActive(String id, bool active) async {
    setState(() {
      final index = _announcements.indexWhere((a) => a['id'] == id);
      if (index != -1) {
        _announcements[index] = {..._announcements[index], 'is_active': active};
      }
    });
    try {
      await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.announcementsCollectionId,
        rowId: id,
        data: {'is_active': active},
      );
      ToastUtils.showSuccess('Broadcast ${active ? 'activated' : 'deactivated'}');
    } catch (e) {
      debugPrint('Note: local status updated, Appwrite sync: $e');
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> announcement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Broadcast'),
        content: Text(
            'Are you sure you want to delete "${announcement['title'] ?? 'this broadcast'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final id = announcement['id'] as String;
      setState(() {
        _announcements.removeWhere((a) => a['id'] == id);
      });
      try {
        await _tables.deleteRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.announcementsCollectionId,
          rowId: id,
        );
        ToastUtils.showSuccess('Broadcast deleted');
      } catch (e) {
        debugPrint('Note: local broadcast removed, Appwrite sync: $e');
        ToastUtils.showSuccess('Broadcast deleted');
      }
    }
  }
}
