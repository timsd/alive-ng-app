import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/appwrite_backend_config.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import '../../utils/appwrite_upsert_helper.dart';
import '../../utils/error_handler.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/modern_dropdown.dart';
import '../../widgets/role_guard.dart';

/// Unified Admin hub covering the community, moderation, and library backlog:
/// 0: Events, 1: Daily Verses, 2: Testimonies Moderation,
/// 3: Gift Submissions Review, 4: Adult Missions, 5: Library Books & Articles.
class AdminOperationsHubScreen extends StatelessWidget {
  final int initialTab;

  const AdminOperationsHubScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    return RoleProtectedScreen(
      requiredRole: 'admin',
      screenName: 'Admin Content & Moderation Hub',
      child: _AdminOperationsHubBody(initialTab: initialTab),
    );
  }
}

class _AdminOperationsHubBody extends StatefulWidget {
  final int initialTab;
  const _AdminOperationsHubBody({required this.initialTab});

  @override
  State<_AdminOperationsHubBody> createState() =>
      _AdminOperationsHubBodyState();
}

class _AdminOperationsHubBodyState extends State<_AdminOperationsHubBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TablesDB _tables = TablesDB(appwriteClient);

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _dailyVerses = [];
  List<Map<String, dynamic>> _testimonies = [];
  List<Map<String, dynamic>> _giftSubmissions = [];
  List<Map<String, dynamic>> _missions = [];
  List<Map<String, dynamic>> _books = [];
  List<Map<String, dynamic>> _articles = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 6,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 5),
    );
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _listTable(
    String tableId, {
    String? orderDescField,
  }) async {
    try {
      final queries = <String>[
        Query.limit(200),
        if (orderDescField != null) Query.orderDesc(orderDescField),
      ];
      final res = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: tableId,
        queries: queries,
      );
      return res.rows
          .map((r) => <String, dynamic>{...r.data, 'id': r.$id})
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _listTable(AppwriteBackendConfig.eventsCollectionId,
            orderDescField: 'created_at'),
        _listTable(AppwriteBackendConfig.dailyVersesCollectionId,
            orderDescField: 'date'),
        _listTable(AppwriteBackendConfig.testimoniesCollectionId,
            orderDescField: 'created_at'),
        _listTable(AppwriteBackendConfig.giftSubmissionsCollectionId,
            orderDescField: 'created_at'),
        _listTable(AppwriteBackendConfig.missionsCollectionId,
            orderDescField: 'created_at'),
        _listTable(AppwriteBackendConfig.booksCollectionId,
            orderDescField: 'created_at'),
        _listTable(AppwriteBackendConfig.articlesCollectionId,
            orderDescField: 'created_at'),
      ]);
      if (!mounted) return;
      setState(() {
        _events = results[0];
        _dailyVerses = results[1];
        _testimonies = results[2];
        _giftSubmissions = results[3];
        _missions = results[4];
        _books = results[5];
        _articles = results[6];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorHandler.getUserFriendlyMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _deleteRow(String tableId, String rowId, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $label?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _tables.deleteRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: tableId,
        rowId: rowId,
      );
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHandler.getUserFriendlyMessage(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Operations & Content Hub',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.event_outlined), text: 'Events'),
            Tab(icon: Icon(Icons.wb_sunny_outlined), text: 'Daily Verses'),
            Tab(icon: Icon(Icons.verified_outlined), text: 'Testimonies'),
            Tab(icon: Icon(Icons.card_giftcard_outlined), text: 'Gifts'),
            Tab(icon: Icon(Icons.flag_outlined), text: 'Missions'),
            Tab(icon: Icon(Icons.local_library_outlined), text: 'Library'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildEventsTab(),
                    _buildDailyVersesTab(),
                    _buildTestimoniesTab(),
                    _buildGiftSubmissionsTab(),
                    _buildMissionsTab(),
                    _buildLibraryTab(),
                  ],
                ),
    );
  }

  // ── 1. Events ─────────────────────────────────────────────────────────────
  Widget _buildEventsTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEventDialog(),
        icon: const Icon(Icons.add),
        label: const Text('New Event'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: _events.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No events found.')),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _events.length,
                itemBuilder: (context, i) {
                  final e = _events[i];
                  final status = (e['status'] ?? 'published').toString();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text((e['title'] ?? 'Untitled Event').toString()),
                      subtitle: Text(
                        '${e['location'] ?? ''} • Status: $status',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _showEventDialog(existing: e),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () => _deleteRow(
                              AppwriteBackendConfig.eventsCollectionId,
                              e['id'].toString(),
                              'Event',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _showEventDialog({Map<String, dynamic>? existing}) async {
    final titleCtrl =
        TextEditingController(text: existing?['title']?.toString() ?? '');
    final descCtrl =
        TextEditingController(text: existing?['description']?.toString() ?? '');
    final locCtrl =
        TextEditingController(text: existing?['location']?.toString() ?? '');
    var status = (existing?['status'] ?? 'published').toString();
    if (!['published', 'draft', 'archived'].contains(status)) {
      status = 'published';
    }
    var scheduledDate = DateTime.tryParse(
          existing?['scheduled_date']?.toString() ?? '',
        ) ??
        DateTime.now().add(const Duration(days: 7));

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(existing == null ? 'Create Event' : 'Edit Event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: locCtrl,
                  decoration: const InputDecoration(labelText: 'Location'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                ModernDropdownFormField<String>(
                  value: status,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'published', child: Text('Published')),
                    DropdownMenuItem(value: 'draft', child: Text('Draft')),
                    DropdownMenuItem(
                        value: 'archived', child: Text('Archived')),
                  ],
                  onChanged: (v) {
                    if (v != null) setS(() => status = v);
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Event Date'),
                  subtitle:
                      Text(DateFormat('MMM d, yyyy').format(scheduledDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: scheduledDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setS(() => scheduledDate = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                final now = DateTime.now().toUtc().toIso8601String();
                final id = existing?['id']?.toString() ?? ID.unique();
                final uid = AuthService.instance.currentUser?.uid ?? 'admin';
                final payload = {
                  'title': titleCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'location': locCtrl.text.trim(),
                  'status': status,
                  'scheduled_date': scheduledDate.toUtc().toIso8601String(),
                  'author_id': existing?['author_id'] ?? uid,
                  'updated_at': now,
                };
                await AppwriteUpsertHelper.updateOrCreateRow(
                  _tables,
                  databaseId: AppwriteBackendConfig.databaseId,
                  tableId: AppwriteBackendConfig.eventsCollectionId,
                  rowId: id,
                  data: payload,
                  createData: {...payload, 'created_at': now},
                );
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadAll();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ── 2. Daily Verses ───────────────────────────────────────────────────────
  Widget _buildDailyVersesTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDailyVerseDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Daily Verse'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: _dailyVerses.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No daily verses in Appwrite yet.')),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _dailyVerses.length,
                itemBuilder: (context, i) {
                  final v = _dailyVerses[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(
                        '${v['date'] ?? ''} — ${v['verse_reference'] ?? v['reference'] ?? 'Verse'}',
                      ),
                      subtitle: Text(
                        (v['verse_text'] ?? v['text'] ?? '').toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _showDailyVerseDialog(existing: v),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () => _deleteRow(
                              AppwriteBackendConfig.dailyVersesCollectionId,
                              v['id'].toString(),
                              'Daily Verse',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _showDailyVerseDialog({Map<String, dynamic>? existing}) async {
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dateCtrl = TextEditingController(
      text: (existing?['date']?.toString() ?? todayKey).split('T').first,
    );
    final refCtrl = TextEditingController(
      text: (existing?['verse_reference'] ?? existing?['reference'] ?? '')
          .toString(),
    );
    final textCtrl = TextEditingController(
      text: (existing?['verse_text'] ?? existing?['text'] ?? '').toString(),
    );
    final reflCtrl = TextEditingController(
      text: (existing?['reflection'] ?? '').toString(),
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Daily Verse' : 'Edit Daily Verse'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dateCtrl,
                decoration: const InputDecoration(
                  labelText: 'Date (YYYY-MM-DD)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: refCtrl,
                decoration:
                    const InputDecoration(labelText: 'Scripture Reference'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: textCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Verse Text'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reflCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Reflection'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (refCtrl.text.trim().isEmpty || textCtrl.text.trim().isEmpty) {
                return;
              }
              final dateKey = dateCtrl.text.trim().isEmpty
                  ? todayKey
                  : dateCtrl.text.trim();
              final id = existing?['id']?.toString() ?? 'dv_$dateKey';
              final now = DateTime.now().toUtc().toIso8601String();
              final payload = {
                'date': dateKey,
                'verse_reference': refCtrl.text.trim(),
                'verse_text': textCtrl.text.trim(),
                'reflection': reflCtrl.text.trim(),
                'updated_at': now,
              };
              await AppwriteUpsertHelper.updateOrCreateRow(
                _tables,
                databaseId: AppwriteBackendConfig.databaseId,
                tableId: AppwriteBackendConfig.dailyVersesCollectionId,
                rowId: id,
                data: payload,
                createData: {...payload, 'created_at': now},
              );
              if (ctx.mounted) Navigator.pop(ctx);
              await _loadAll();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ── 3. Testimonies Moderation ─────────────────────────────────────────────
  Widget _buildTestimoniesTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: _testimonies.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No testimonies submitted yet.')),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _testimonies.length,
              itemBuilder: (context, i) {
                final t = _testimonies[i];
                final approved = t['is_approved'] == true;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text((t['user_name'] ?? 'Member').toString()),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (t['content'] ?? '').toString(),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Chip(
                          label: Text(approved ? 'Approved' : 'Pending Review'),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            approved
                                ? Icons.unpublished_outlined
                                : Icons.check_circle_outline,
                            color: approved ? Colors.orange : Colors.green,
                          ),
                          tooltip: approved ? 'Unapprove' : 'Approve',
                          onPressed: () async {
                            await AppwriteUpsertHelper.updateOrCreateRow(
                              _tables,
                              databaseId: AppwriteBackendConfig.databaseId,
                              tableId:
                                  AppwriteBackendConfig.testimoniesCollectionId,
                              rowId: t['id'].toString(),
                              data: {
                                'is_approved': !approved,
                                'updated_at':
                                    DateTime.now().toUtc().toIso8601String(),
                              },
                            );
                            await _loadAll();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () => _deleteRow(
                            AppwriteBackendConfig.testimoniesCollectionId,
                            t['id'].toString(),
                            'Testimony',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  // ── 4. Gift Submissions Review ────────────────────────────────────────────
  Widget _buildGiftSubmissionsTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: _giftSubmissions.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No gift submissions yet.')),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _giftSubmissions.length,
              itemBuilder: (context, i) {
                final g = _giftSubmissions[i];
                final status = (g['status'] ?? 'submitted').toString();
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(
                      '${g['full_name'] ?? 'Donor'} • ${g['gift_type'] ?? 'Gift'}',
                    ),
                    subtitle: Text(
                      '${g['item_type'] ?? g['skills_or_service'] ?? g['description'] ?? ''}\nStatus: $status • ${g['phone'] ?? ''}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.rate_review_outlined),
                          tooltip: 'Review status',
                          onPressed: () => _showGiftReviewDialog(g),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () => _deleteRow(
                            AppwriteBackendConfig.giftSubmissionsCollectionId,
                            g['id'].toString(),
                            'Gift Submission',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _showGiftReviewDialog(Map<String, dynamic> gift) async {
    var status = (gift['status'] ?? 'submitted').toString();
    const statuses = [
      'submitted',
      'reviewed',
      'approved',
      'completed',
      'archived',
    ];
    if (!statuses.contains(status)) status = 'submitted';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(gift['full_name']?.toString() ?? 'Gift Submission'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Type: ${gift['gift_type'] ?? ''}'),
                Text('Email: ${gift['email'] ?? ''}'),
                Text('Phone: ${gift['phone'] ?? ''}'),
                if ((gift['item_type'] ?? '').toString().isNotEmpty)
                  Text('Item: ${gift['item_type']} (${gift['quantity'] ?? ''})'),
                if ((gift['location'] ?? '').toString().isNotEmpty)
                  Text('Location: ${gift['location']}'),
                if ((gift['description'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Details: ${gift['description']}'),
                ],
                const SizedBox(height: 14),
                ModernDropdownFormField<String>(
                  value: status,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Review Status',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: statuses
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s[0].toUpperCase() + s.substring(1)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setS(() => status = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await AppwriteUpsertHelper.updateOrCreateRow(
                  _tables,
                  databaseId: AppwriteBackendConfig.databaseId,
                  tableId: AppwriteBackendConfig.giftSubmissionsCollectionId,
                  rowId: gift['id'].toString(),
                  data: {
                    'status': status,
                    'updated_at': DateTime.now().toUtc().toIso8601String(),
                  },
                );
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadAll();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ── 5. Adult Missions ─────────────────────────────────────────────────────
  Widget _buildMissionsTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showMissionDialog(),
        icon: const Icon(Icons.add),
        label: const Text('New Mission'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: _missions.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No adult missions yet.')),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _missions.length,
                itemBuilder: (context, i) {
                  final m = _missions[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text((m['title'] ?? 'Mission').toString()),
                      subtitle: Text(
                        '${m['location'] ?? ''} • ${m['points'] ?? 0} pts',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _showMissionDialog(existing: m),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () => _deleteRow(
                              AppwriteBackendConfig.missionsCollectionId,
                              m['id'].toString(),
                              'Mission',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _showMissionDialog({Map<String, dynamic>? existing}) async {
    final titleCtrl =
        TextEditingController(text: existing?['title']?.toString() ?? '');
    final descCtrl =
        TextEditingController(text: existing?['description']?.toString() ?? '');
    final locCtrl =
        TextEditingController(text: existing?['location']?.toString() ?? '');
    final ptsCtrl = TextEditingController(
      text: (existing?['points'] ?? 50).toString(),
    );
    var isActive = existing?['is_active'] != false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(existing == null ? 'Create Mission' : 'Edit Mission'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: locCtrl,
                  decoration: const InputDecoration(labelText: 'Location'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ptsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Points'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (v) => setS(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                final now = DateTime.now().toUtc().toIso8601String();
                final id = existing?['id']?.toString() ?? ID.unique();
                final payload = {
                  'title': titleCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'location': locCtrl.text.trim(),
                  'points': int.tryParse(ptsCtrl.text.trim()) ?? 50,
                  'category': existing?['category'] ?? 'community',
                  'start_date': existing?['start_date'] ?? now,
                  'is_active': isActive,
                  'updated_at': now,
                };
                await AppwriteUpsertHelper.updateOrCreateRow(
                  _tables,
                  databaseId: AppwriteBackendConfig.databaseId,
                  tableId: AppwriteBackendConfig.missionsCollectionId,
                  rowId: id,
                  data: payload,
                  createData: {...payload, 'created_at': now},
                );
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadAll();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ── 6. Library (Books & Articles) ─────────────────────────────────────────
  Widget _buildLibraryTab() {
    final items = [
      ..._books.map((b) => {...b, '_kind': 'book'}),
      ..._articles.map((a) => {...a, '_kind': 'article'}),
    ];
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLibraryItemDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Book / Article'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: items.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No books or articles in Library yet.')),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  final isBook = item['_kind'] == 'book';
                  final tableId = isBook
                      ? AppwriteBackendConfig.booksCollectionId
                      : AppwriteBackendConfig.articlesCollectionId;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Icon(
                        isBook ? Icons.menu_book_rounded : Icons.article_rounded,
                      ),
                      title: Text((item['title'] ?? 'Untitled').toString()),
                      subtitle: Text(
                        '${isBook ? 'Book' : 'Article'} • ${item['author'] ?? 'ALIVE Nigeria'}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _showLibraryItemDialog(
                              existing: item,
                              initialIsBook: isBook,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () => _deleteRow(
                              tableId,
                              item['id'].toString(),
                              isBook ? 'Book' : 'Article',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _showLibraryItemDialog({
    Map<String, dynamic>? existing,
    bool initialIsBook = true,
  }) async {
    var isBook = initialIsBook;
    final titleCtrl =
        TextEditingController(text: existing?['title']?.toString() ?? '');
    final authorCtrl = TextEditingController(
      text: existing?['author']?.toString() ?? 'ALIVE Nigeria',
    );
    final catCtrl = TextEditingController(
      text: existing?['category']?.toString() ?? 'Spiritual Growth',
    );
    final descCtrl = TextEditingController(
      text: (existing?['description'] ?? existing?['content'] ?? '').toString(),
    );
    final urlCtrl = TextEditingController(
      text: (existing?['file_url'] ?? existing?['url'] ?? '').toString(),
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(existing == null
              ? 'Add Library Item'
              : 'Edit ${isBook ? 'Book' : 'Article'}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (existing == null)
                  ModernDropdownFormField<bool>(
                    value: isBook,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: true, child: Text('Book')),
                      DropdownMenuItem(value: false, child: Text('Article')),
                    ],
                    onChanged: (v) {
                      if (v != null) setS(() => isBook = v);
                    },
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: authorCtrl,
                  decoration: const InputDecoration(labelText: 'Author'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: catCtrl,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'File / Resource URL (optional)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description / Content',
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
            FilledButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                final now = DateTime.now().toUtc().toIso8601String();
                final id = existing?['id']?.toString() ?? ID.unique();
                final tableId = isBook
                    ? AppwriteBackendConfig.booksCollectionId
                    : AppwriteBackendConfig.articlesCollectionId;
                final payload = {
                  'title': titleCtrl.text.trim(),
                  'author': authorCtrl.text.trim(),
                  'category': catCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  if (!isBook) 'content': descCtrl.text.trim(),
                  if (urlCtrl.text.trim().isNotEmpty)
                    'file_url': urlCtrl.text.trim(),
                  'is_active': true,
                  'updated_at': now,
                };
                await AppwriteUpsertHelper.updateOrCreateRow(
                  _tables,
                  databaseId: AppwriteBackendConfig.databaseId,
                  tableId: tableId,
                  rowId: id,
                  data: payload,
                  createData: {...payload, 'created_at': now},
                );
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadAll();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
