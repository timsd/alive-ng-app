import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';

import '../../config/appwrite_backend_config.dart';
import '../../main.dart';
import '../../services/channel_membership_sync_service.dart';
import '../../widgets/custom_app_bar.dart';

/// Admin screen for managing and editing chat #role tags, special @announcement tags,
/// and channel directory & bridge mappings.
class ChatTagManagementScreen extends StatefulWidget {
  const ChatTagManagementScreen({super.key});

  @override
  State<ChatTagManagementScreen> createState() =>
      _ChatTagManagementScreenState();
}

class _ChatTagManagementScreenState extends State<ChatTagManagementScreen>
    with SingleTickerProviderStateMixin {
  static const String _tagConfigKey = 'chat_tag_configuration';

  late final TabController _tabController;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _tagConfigRowId;

  // Channel data
  List<Map<String, dynamic>> _channels = [];
  int _totalMessages = 0;

  // Editable Role-to-channel bridge definitions
  List<Map<String, dynamic>> _roleBridges = [];

  // Editable Special tags
  List<Map<String, dynamic>> _specialTags = [];

  static final List<Map<String, dynamic>> _defaultRoleBridges = [
    {
      'role': 'coordinator',
      'channelId': ChannelMembershipSyncService.channelCoordinatorsId,
      'label': 'Chapter Coordinators',
      'description': 'All active coordinators auto-join this channel',
      'enabled': true,
    },
    {
      'role': 'bod / trustee / director',
      'channelId': ChannelMembershipSyncService.channelBodId,
      'label': 'Board of Directors',
      'description': 'BOD, Trustees, Directors, and Admins',
      'enabled': true,
    },
    {
      'role': 'field_worker',
      'channelId': ChannelMembershipSyncService.channelFieldWorkersId,
      'label': 'Field Workers',
      'description': 'Field workers + leadership oversight',
      'enabled': true,
    },
    {
      'role': 'campus_missionary',
      'channelId': ChannelMembershipSyncService.channelCampusMissionariesId,
      'label': 'Campus Missionaries',
      'description': 'Campus missionaries + leadership oversight',
      'enabled': true,
    },
    {
      'role': 'amtc_team',
      'channelId': ChannelMembershipSyncService.channelAmtcId,
      'label': 'AMTC Team',
      'description': 'AMTC team members + leadership oversight',
      'enabled': true,
    },
    {
      'role': 'donor / financial',
      'channelId': ChannelMembershipSyncService.channelDonorsId,
      'label': 'Donors',
      'description': 'Users with donor role or financial commitment',
      'enabled': true,
    },
    {
      'role': 'single (marital status)',
      'channelId': ChannelMembershipSyncService.channelSinglesId,
      'label': 'Singles',
      'description': 'Auto-assigned by marital status',
      'enabled': true,
    },
    {
      'role': 'married (marital status)',
      'channelId': ChannelMembershipSyncService.channelMarriedId,
      'label': 'Married',
      'description': 'Auto-assigned by marital status',
      'enabled': true,
    },
    {
      'role': 'all active members',
      'channelId': ChannelMembershipSyncService.channelGeneralId,
      'label': 'General',
      'description': 'Every active (non-archived) member',
      'enabled': true,
    },
  ];

  static final List<Map<String, dynamic>> _defaultSpecialTags = [
    {
      'tag': '@everyone',
      'scope': 'All members in the current channel',
      'description':
          'Sends a push notification to every member of the channel. Use sparingly for important announcements.',
      'enabled': true,
    },
    {
      'tag': '@here',
      'scope': 'Currently online members',
      'description':
          'Notifies members who are currently active in the app. Less intrusive than @everyone.',
      'enabled': true,
    },
    {
      'tag': '@admins',
      'scope': 'Admin & Super Admin roles',
      'description':
          'Pings all users with admin or super_admin roles in the channel.',
      'enabled': true,
    },
    {
      'tag': '@leaders',
      'scope': 'Coordinators, Directors, BOD, Trustees',
      'description': 'Pings all leadership-tier users in the channel.',
      'enabled': true,
    },
    {
      'tag': '#role-tag',
      'scope': 'Dynamic role-based tag',
      'description':
          'Typing # in chat shows autocomplete for role tags. E.g., #coordinator mentions all coordinators. Mapped via the Role Tags tab.',
      'enabled': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _roleBridges = _defaultRoleBridges
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    _specialTags = _defaultSpecialTags
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final tables = TablesDB(appwriteClient);

      final channelsFuture = tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.chatChannelsCollectionId,
        queries: [Query.limit(100)],
      );

      final msgFuture = tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.chatMessagesCollectionId,
        queries: [Query.limit(1)],
      );

      final configFuture = tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.appSettingsCollectionId,
        queries: [Query.equal('key', _tagConfigKey), Query.limit(1)],
      );

      final results = await Future.wait([
        channelsFuture,
        msgFuture,
        configFuture,
      ]);

      final channelsResult = results[0];
      final msgResult = results[1];
      final configResult = results[2];

      List<Map<String, dynamic>> loadedBridges = _defaultRoleBridges
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      List<Map<String, dynamic>> loadedTags = _defaultSpecialTags
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      String? configRowId;

      if (configResult.rows.isNotEmpty) {
        final row = configResult.rows.first;
        configRowId = row.$id;
        final rawValue = (row.data['value'] ?? '').toString().trim();
        if (rawValue.isNotEmpty) {
          try {
            final decoded = jsonDecode(rawValue);
            if (decoded is Map) {
              if (decoded['role_bridges'] is List &&
                  (decoded['role_bridges'] as List).isNotEmpty) {
                loadedBridges = (decoded['role_bridges'] as List)
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList();
              }
              if (decoded['special_tags'] is List &&
                  (decoded['special_tags'] as List).isNotEmpty) {
                loadedTags = (decoded['special_tags'] as List)
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList();
              }
            }
          } catch (_) {}
        }
      }

      if (!mounted) return;
      setState(() {
        _channels = channelsResult.rows
            .map((r) => <String, dynamic>{
                  'id': r.$id,
                  ...r.data,
                })
            .toList();
        _totalMessages = msgResult.total;
        _roleBridges = loadedBridges;
        _specialTags = loadedTags;
        _tagConfigRowId = configRowId;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveTagConfiguration({String? toastMessage}) async {
    setState(() => _isSaving = true);
    try {
      final tables = TablesDB(appwriteClient);
      final encoded = jsonEncode({
        'role_bridges': _roleBridges,
        'special_tags': _specialTags,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      final payload = <String, dynamic>{
        'key': _tagConfigKey,
        'value': encoded,
        'category': 'social',
        'data_type': 'json',
        'display_name': 'Chat & Role Tag Configuration',
        'description':
            'Role-to-channel bridges (#role) and special announcement (@mention) tag definitions.',
        'is_active': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (_tagConfigRowId != null && _tagConfigRowId!.isNotEmpty) {
        await tables.updateRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.appSettingsCollectionId,
          rowId: _tagConfigRowId!,
          data: payload,
        );
      } else {
        final existing = await tables.listRows(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.appSettingsCollectionId,
          queries: [Query.equal('key', _tagConfigKey), Query.limit(1)],
        );
        if (existing.rows.isNotEmpty) {
          _tagConfigRowId = existing.rows.first.$id;
          await tables.updateRow(
            databaseId: AppwriteBackendConfig.databaseId,
            tableId: AppwriteBackendConfig.appSettingsCollectionId,
            rowId: _tagConfigRowId!,
            data: payload,
          );
        } else {
          final created = await tables.createRow(
            databaseId: AppwriteBackendConfig.databaseId,
            tableId: AppwriteBackendConfig.appSettingsCollectionId,
            rowId: ID.unique(),
            data: {
              ...payload,
              'created_at': DateTime.now().toUtc().toIso8601String(),
            },
          );
          _tagConfigRowId = created.$id;
        }
      }

      if (!mounted) return;
      if (toastMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(toastMessage)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save tag configuration: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _syncChannelBridges() async {
    setState(() => _isSaving = true);
    try {
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('System channels and role bridges synced'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Chat & Tag Management',
        showBackButton: true,
        showDonationButton: false,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          tabs: const [
            Tab(icon: Icon(Icons.tag_rounded, size: 18), text: 'Role Tags'),
            Tab(
                icon: Icon(Icons.campaign_outlined, size: 18),
                text: 'Special Tags'),
            Tab(
                icon: Icon(Icons.account_tree_outlined, size: 18),
                text: 'Channels'),
          ],
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync_rounded, size: 20),
              tooltip: 'Refresh & Sync',
              onPressed: _loadData,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRoleTagsTab(context),
                _buildSpecialTagsTab(context),
                _buildChannelsTab(context),
              ],
            ),
    );
  }

  // ─── Tab 1: Editable Role Tags & Bridge Mappings ───

  Widget _buildRoleTagsTab(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFD49B28).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFD49B28).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFFD49B28), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Role tags bridge user roles to chat channels and #role mentions. '
                  'Tap any role tag below to edit its mapping, toggle auto-enrollment, or add a new bridge.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.white70 : Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                'Role → Channel Bridges (${_roleBridges.length})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.sync_rounded, size: 15),
              label: const Text('Sync', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _isSaving ? null : _syncChannelBridges,
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Role Tag', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _showRoleBridgeDialog(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._roleBridges.asMap().entries.map((entry) {
          final idx = entry.key;
          final bridge = entry.value;
          final isEnabled = bridge['enabled'] != false;
          final channelDoc = _channels.firstWhere(
            (c) => c['id'] == bridge['channelId'],
            orElse: () => <String, dynamic>{},
          );
          final memberCount = (channelDoc['members'] is List)
              ? (channelDoc['members'] as List).length
              : 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showRoleBridgeDialog(existing: bridge, index: idx),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isEnabled
                            ? theme.colorScheme.primary.withValues(alpha: 0.12)
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.link_rounded,
                        size: 18,
                        color: isEnabled
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '#${bridge['role'] ?? ''}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF3B82F6),
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_forward_rounded,
                                  size: 13, color: Colors.grey),
                              Text(
                                (bridge['label'] ?? '').toString(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: isEnabled
                                      ? null
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$memberCount mbrs',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.greenAccent.shade200
                                        : Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            (bridge['description'] ?? '').toString(),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: isEnabled,
                      onChanged: (val) {
                        setState(() {
                          _roleBridges[idx] = {
                            ...bridge,
                            'enabled': val,
                          };
                        });
                        _saveTagConfiguration(
                          toastMessage: val
                              ? 'Enabled #${bridge['role']} bridge'
                              : 'Paused #${bridge['role']} bridge',
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit Role Tag',
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          _showRoleBridgeDialog(existing: bridge, index: idx),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          size: 18, color: theme.colorScheme.error),
                      tooltip: 'Delete Role Tag',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _confirmDeleteRoleBridge(idx),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _showRoleBridgeDialog({
    Map<String, dynamic>? existing,
    int? index,
  }) async {
    final roleCtrl = TextEditingController(
      text: (existing?['role'] ?? '')
          .toString()
          .replaceFirst(RegExp(r'^#'), ''),
    );
    final labelCtrl =
        TextEditingController(text: (existing?['label'] ?? '').toString());
    final descCtrl = TextEditingController(
        text: (existing?['description'] ?? '').toString());
    String selectedChannelId = (existing?['channelId'] ??
            (_channels.isNotEmpty
                ? _channels.first['id'].toString()
                : ChannelMembershipSyncService.channelGeneralId))
        .toString();
    bool isEnabled = existing?['enabled'] != false;

    final channelOptions = <Map<String, String>>[
      ..._channels.map((c) => {
            'id': c['id'].toString(),
            'name': _formatChannelName(
                (c['name'] ?? c['id'] ?? '').toString()),
          }),
    ];
    if (!channelOptions.any((c) => c['id'] == selectedChannelId)) {
      channelOptions.insert(0, {
        'id': selectedChannelId,
        'name': _formatChannelName(selectedChannelId),
      });
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.fromLTRB(20, 18, 14, 8),
            contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            title: Row(
              children: [
                Icon(Icons.tag_rounded, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    existing == null ? 'Add Role Tag Bridge' : 'Edit Role Tag',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: roleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Role Tag Handle *',
                      hintText: 'e.g. coordinator or prayer_team',
                      prefixText: '#',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: labelCtrl,
                    decoration: InputDecoration(
                      labelText: 'Display Label *',
                      hintText: 'e.g. Chapter Coordinators',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Target Chat Channel',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final picked = await showModalBottomSheet<String>(
                        context: ctx,
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (sheetCtx) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'Select Target Channel',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                              ),
                              Flexible(
                                child: ListView(
                                  shrinkWrap: true,
                                  children: channelOptions
                                      .map((opt) => ListTile(
                                            leading: const Icon(
                                                Icons.forum_outlined),
                                            title: Text(opt['name']!),
                                            subtitle: Text(opt['id']!),
                                            trailing: opt['id'] ==
                                                    selectedChannelId
                                                ? Icon(Icons.check_circle,
                                                    color: colorScheme.primary)
                                                : null,
                                            onTap: () => Navigator.pop(
                                                sheetCtx, opt['id']),
                                          ))
                                      .toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedChannelId = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.outline),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.forum_outlined,
                              size: 18, color: colorScheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              channelOptions.firstWhere(
                                (c) => c['id'] == selectedChannelId,
                                orElse: () => {
                                  'id': selectedChannelId,
                                  'name': selectedChannelId
                                },
                              )['name']!,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText: 'Who gets enrolled or pinged by this tag',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Active Auto-Bridge',
                      style:
                          TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Enable #role mentions and automatic channel enrollment',
                      style: TextStyle(fontSize: 11.5),
                    ),
                    value: isEnabled,
                    onChanged: (v) => setDialogState(() => isEnabled = v),
                  ),
                ],
              ),
            ),
            actions: [
              SizedBox(
                width: double.maxFinite,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Save Role Tag'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          final role = roleCtrl.text
                              .trim()
                              .replaceFirst(RegExp(r'^#'), '');
                          final label = labelCtrl.text.trim();
                          if (role.isEmpty || label.isEmpty) return;

                          final updated = <String, dynamic>{
                            'role': role,
                            'channelId': selectedChannelId,
                            'label': label,
                            'description': descCtrl.text.trim().isEmpty
                                ? 'Mapped to $label'
                                : descCtrl.text.trim(),
                            'enabled': isEnabled,
                          };

                          setState(() {
                            if (index != null) {
                              _roleBridges[index] = updated;
                            } else {
                              _roleBridges.add(updated);
                            }
                          });
                          Navigator.pop(ctx);
                          _saveTagConfiguration(
                            toastMessage: index != null
                                ? 'Updated #$role tag'
                                : 'Added #$role tag',
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteRoleBridge(int index) async {
    final bridge = _roleBridges[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Remove Role Tag?'),
        content: Text(
          'Remove #${bridge['role']} (${bridge['label']}) from the active role tag bridges?',
        ),
        actions: [
          SizedBox(
            width: double.maxFinite,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(ctx).colorScheme.error,
                      foregroundColor: Theme.of(ctx).colorScheme.onError,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _roleBridges.removeAt(index));
      await _saveTagConfiguration(
        toastMessage: 'Removed #${bridge['role']} tag',
      );
    }
  }

  // ─── Tab 2: Editable Special Announcement Tags ───

  Widget _buildSpecialTagsTab(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.campaign_outlined,
                  color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Special tags let leaders mention groups of users in chat. Tap any tag to customize its scope or toggle it on/off.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.white70 : Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                'Available Special Tags (${_specialTags.length})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.add_rounded, size: 16),
              label:
                  const Text('Add Special Tag', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _showSpecialTagDialog(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._specialTags.asMap().entries.map((entry) {
          final idx = entry.key;
          final tag = entry.value;
          final isEnabled = tag['enabled'] != false;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showSpecialTagDialog(existing: tag, index: idx),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isEnabled
                                ? const Color(0xFFD49B28).withValues(alpha: 0.15)
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            (tag['tag'] ?? '').toString(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isEnabled
                                  ? const Color(0xFFD49B28)
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            (tag['scope'] ?? '').toString(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Switch.adaptive(
                          value: isEnabled,
                          onChanged: (val) {
                            setState(() {
                              _specialTags[idx] = {
                                ...tag,
                                'enabled': val,
                              };
                            });
                            _saveTagConfiguration(
                              toastMessage: val
                                  ? 'Enabled ${tag['tag']}'
                                  : 'Disabled ${tag['tag']}',
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Edit Special Tag',
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              _showSpecialTagDialog(existing: tag, index: idx),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 18, color: theme.colorScheme.error),
                          tooltip: 'Delete Special Tag',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _confirmDeleteSpecialTag(idx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (tag['description'] ?? '').toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _showSpecialTagDialog({
    Map<String, dynamic>? existing,
    int? index,
  }) async {
    final handleCtrl =
        TextEditingController(text: (existing?['tag'] ?? '@').toString());
    final scopeCtrl =
        TextEditingController(text: (existing?['scope'] ?? '').toString());
    final descCtrl = TextEditingController(
        text: (existing?['description'] ?? '').toString());
    bool isEnabled = existing?['enabled'] != false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.fromLTRB(20, 18, 14, 8),
            contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            title: Row(
              children: [
                Icon(Icons.campaign_outlined,
                    color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    existing == null ? 'Add Special Tag' : 'Edit Special Tag',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: handleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Tag Handle *',
                      hintText: 'e.g. @everyone, @leaders, #role',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: scopeCtrl,
                    decoration: InputDecoration(
                      labelText: 'Target Audience / Scope *',
                      hintText: 'e.g. All members in the current channel',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText: 'How this mention tag behaves in chat',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Tag Enabled',
                      style:
                          TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Allow leaders/members to trigger this tag in chat',
                      style: TextStyle(fontSize: 11.5),
                    ),
                    value: isEnabled,
                    onChanged: (v) => setDialogState(() => isEnabled = v),
                  ),
                ],
              ),
            ),
            actions: [
              SizedBox(
                width: double.maxFinite,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Save Tag'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          var handle = handleCtrl.text.trim();
                          final scope = scopeCtrl.text.trim();
                          if (handle.isEmpty || scope.isEmpty) return;
                          if (!handle.startsWith('@') &&
                              !handle.startsWith('#')) {
                            handle = '@$handle';
                          }

                          final updated = <String, dynamic>{
                            'tag': handle,
                            'scope': scope,
                            'description': descCtrl.text.trim(),
                            'enabled': isEnabled,
                          };

                          setState(() {
                            if (index != null) {
                              _specialTags[index] = updated;
                            } else {
                              _specialTags.add(updated);
                            }
                          });
                          Navigator.pop(ctx);
                          _saveTagConfiguration(
                            toastMessage: index != null
                                ? 'Updated $handle'
                                : 'Added $handle',
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteSpecialTag(int index) async {
    final tag = _specialTags[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Special Tag?'),
        content: Text('Remove ${tag['tag']} from available special tags?'),
        actions: [
          SizedBox(
            width: double.maxFinite,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(ctx).colorScheme.error,
                      foregroundColor: Theme.of(ctx).colorScheme.onError,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _specialTags.removeAt(index));
      await _saveTagConfiguration(toastMessage: 'Deleted ${tag['tag']}');
    }
  }

  // ─── Tab 3: Editable Channel Directory ───

  Widget _buildChannelsTab(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              _buildChannelStat(
                '${_channels.length}',
                'Channels',
                Icons.forum_outlined,
                theme.colorScheme.primary,
              ),
              const SizedBox(width: 16),
              _buildChannelStat(
                '$_totalMessages',
                'Messages',
                Icons.message_outlined,
                const Color(0xFF2FAD72),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Channel Directory',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.add_rounded, size: 16),
              label:
                  const Text('New Channel', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _showChannelEditorDialog(),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_channels.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.forum_outlined,
                      size: 48, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(
                    'No channels found',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ..._channels.map((channel) {
          final id = (channel['id'] ?? '').toString();
          final name = (channel['name'] ?? id).toString();
          final members = (channel['members'] is List)
              ? (channel['members'] as List)
              : [];
          final description = (channel['description'] ?? '').toString();
          final isSystemChannel = id.startsWith('channel_') ||
              name.startsWith('channel_') ||
              channel['is_system'] == true;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showChannelEditorDialog(existing: channel),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isSystemChannel
                            ? const Color(0xFFD49B28).withValues(alpha: 0.14)
                            : theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isSystemChannel
                            ? Icons.lock_outline_rounded
                            : Icons.forum_outlined,
                        size: 18,
                        color: isSystemChannel
                            ? const Color(0xFFD49B28)
                            : theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _formatChannelName(name),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isSystemChannel) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD49B28)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'SYSTEM',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFD49B28),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (description.isNotEmpty)
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_alt_outlined,
                            size: 13,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${members.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit Channel',
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          _showChannelEditorDialog(existing: channel),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _showChannelEditorDialog({
    Map<String, dynamic>? existing,
  }) async {
    final nameCtrl = TextEditingController(
      text: existing != null
          ? (existing['name'] ?? existing['id'] ?? '').toString()
          : '',
    );
    final descCtrl = TextEditingController(
      text: (existing?['description'] ?? '').toString(),
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 14, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          title: Row(
            children: [
              Icon(Icons.forum_outlined, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  existing == null ? 'Create Chat Channel' : 'Edit Channel',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(ctx),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Channel Name *',
                    hintText: 'e.g. Prayer Warriors',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Channel Description',
                    hintText: 'Purpose and scope of this channel',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.maxFinite,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Save Channel'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        Navigator.pop(ctx);
                        try {
                          final tables = TablesDB(appwriteClient);
                          if (existing != null && existing['id'] != null) {
                            await tables.updateRow(
                              databaseId: AppwriteBackendConfig.databaseId,
                              tableId: AppwriteBackendConfig
                                  .chatChannelsCollectionId,
                              rowId: existing['id'].toString(),
                              data: {
                                'name': name,
                                'description': descCtrl.text.trim(),
                              },
                            );
                          } else {
                            await tables.createRow(
                              databaseId: AppwriteBackendConfig.databaseId,
                              tableId: AppwriteBackendConfig
                                  .chatChannelsCollectionId,
                              rowId: ID.unique(),
                              data: {
                                'name': name,
                                'description': descCtrl.text.trim(),
                                'type': 'group',
                                'is_private': false,
                                'members': <String>[],
                                'admins': <String>[],
                                'created_at':
                                    DateTime.now().toUtc().toIso8601String(),
                              },
                            );
                          }
                          await _loadData();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(existing != null
                                  ? 'Updated channel "$name"'
                                  : 'Created channel "$name"'),
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Failed to save channel: $e')),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChannelStat(
      String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatChannelName(String raw) {
    final mapping = <String, String>{
      ChannelMembershipSyncService.channelGeneralId: '🌐 General',
      ChannelMembershipSyncService.channelSinglesId: '💛 Singles Fellowship',
      ChannelMembershipSyncService.channelMarriedId: '💍 Married / Couples',
      ChannelMembershipSyncService.channelCoordinatorsId: '📋 Coordinators',
      ChannelMembershipSyncService.channelDonorsId: '💰 Donors',
      ChannelMembershipSyncService.channelBodId: '🏛️ Board of Directors',
      ChannelMembershipSyncService.channelFieldWorkersId: '🌾 Field Workers',
      ChannelMembershipSyncService.channelCampusMissionariesId:
          '🎓 Campus Missionaries',
      ChannelMembershipSyncService.channelAmtcId: '⚡ AMTC Team',
    };
    return mapping[raw] ??
        raw
            .replaceAll('channel_', '')
            .replaceAll('_', ' ')
            .split(' ')
            .map((w) => w.isEmpty
                ? ''
                : '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' ');
  }
}
