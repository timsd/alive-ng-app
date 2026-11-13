import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';

import '../../config/appwrite_backend_config.dart';
import '../../main.dart';
import '../../services/channel_membership_sync_service.dart';

/// Admin screen for managing chat #role tags, special announcement tags,
/// and channel directory & bridge mappings.
class ChatTagManagementScreen extends StatefulWidget {
  const ChatTagManagementScreen({super.key});

  @override
  State<ChatTagManagementScreen> createState() =>
      _ChatTagManagementScreenState();
}

class _ChatTagManagementScreenState extends State<ChatTagManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isLoading = true;

  // Channel data
  List<Map<String, dynamic>> _channels = [];
  int _totalMessages = 0;

  // Role-to-channel bridge definitions
  static const List<Map<String, String>> _roleBridges = [
    {
      'role': 'coordinator',
      'channelId': ChannelMembershipSyncService.channelCoordinatorsId,
      'label': 'Chapter Coordinators',
      'description': 'All active coordinators auto-join this channel',
    },
    {
      'role': 'bod / trustee / director',
      'channelId': ChannelMembershipSyncService.channelBodId,
      'label': 'Board of Directors',
      'description': 'BOD, Trustees, Directors, and Admins',
    },
    {
      'role': 'field_worker',
      'channelId': ChannelMembershipSyncService.channelFieldWorkersId,
      'label': 'Field Workers',
      'description': 'Field workers + leadership oversight',
    },
    {
      'role': 'campus_missionary',
      'channelId': ChannelMembershipSyncService.channelCampusMissionariesId,
      'label': 'Campus Missionaries',
      'description': 'Campus missionaries + leadership oversight',
    },
    {
      'role': 'amtc_team',
      'channelId': ChannelMembershipSyncService.channelAmtcId,
      'label': 'AMTC Team',
      'description': 'AMTC team members + leadership oversight',
    },
    {
      'role': 'donor / financial',
      'channelId': ChannelMembershipSyncService.channelDonorsId,
      'label': 'Donors',
      'description': 'Users with donor role or financial commitment',
    },
    {
      'role': 'single (marital status)',
      'channelId': ChannelMembershipSyncService.channelSinglesId,
      'label': 'Singles',
      'description': 'Auto-assigned by marital status',
    },
    {
      'role': 'married (marital status)',
      'channelId': ChannelMembershipSyncService.channelMarriedId,
      'label': 'Married',
      'description': 'Auto-assigned by marital status',
    },
    {
      'role': 'all active members',
      'channelId': ChannelMembershipSyncService.channelGeneralId,
      'label': 'General',
      'description': 'Every active (non-archived) member',
    },
  ];

  // Special tags
  static const List<Map<String, String>> _specialTags = [
    {
      'tag': '@everyone',
      'scope': 'All members in the current channel',
      'description':
          'Sends a push notification to every member of the channel. Use sparingly for important announcements.',
    },
    {
      'tag': '@here',
      'scope': 'Currently online members',
      'description':
          'Notifies members who are currently active in the app. Less intrusive than @everyone.',
    },
    {
      'tag': '@admins',
      'scope': 'Admin & Super Admin roles',
      'description':
          'Pings all users with admin or super_admin roles in the channel.',
    },
    {
      'tag': '@leaders',
      'scope': 'Coordinators, Directors, BOD, Trustees',
      'description':
          'Pings all leadership-tier users in the channel.',
    },
    {
      'tag': '#role-tag',
      'scope': 'Dynamic role-based tag',
      'description':
          'Typing # in chat shows autocomplete for role tags. E.g., #coordinator mentions all coordinators. Mapped via the Role Tags tab.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

      final channelsResult = await tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.chatChannelsCollectionId,
        queries: [Query.limit(100)],
      );

      final msgResult = await tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.chatMessagesCollectionId,
        queries: [Query.limit(1)],
      );

      if (!mounted) return;
      setState(() {
        _channels = channelsResult.rows
            .map((r) => <String, dynamic>{
                  'id': r.$id,
                  ...r.data,
                })
            .toList();
        _totalMessages = msgResult.total;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat & Tag Management'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFD49B28),
          labelColor: isDark ? Colors.white : theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          tabs: const [
            Tab(icon: Icon(Icons.tag, size: 18), text: 'Role Tags'),
            Tab(
                icon: Icon(Icons.campaign_outlined, size: 18),
                text: 'Special Tags'),
            Tab(
                icon: Icon(Icons.hub_outlined, size: 18),
                text: 'Channels'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded, size: 20),
            tooltip: 'Refresh',
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

  // ─── Tab 1: Role Tags & Bridge Mappings ───

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
                  'Role tags automatically bridge user roles to chat channels. '
                  'When a user\'s role matches, they are auto-enrolled in the mapped channel via ChannelMembershipSyncService.',
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
        const SizedBox(height: 16),
        Text(
          'Active Role → Channel Bridges (${_roleBridges.length})',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        ..._roleBridges.map((bridge) {
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.link_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '#${bridge['role']}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.arrow_forward_rounded,
                                  size: 14, color: Colors.grey),
                            ),
                            Flexible(
                              child: Text(
                                bridge['label']!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          bridge['description']!,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$memberCount',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ─── Tab 2: Special Announcement Tags ───

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
                  'Special tags let leaders mention groups of users in chat. They trigger push notifications to the targeted scope.',
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
        const SizedBox(height: 16),
        Text(
          'Available Special Tags (${_specialTags.length})',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        ..._specialTags.map((tag) {
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
                          color: const Color(0xFFD49B28).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tag['tag']!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFD49B28),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tag['scope']!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tag['description']!,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ─── Tab 3: Channel Directory ───

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
                  '${_channels.length}', 'Channels', Icons.forum_outlined,
                  theme.colorScheme.primary),
              const SizedBox(width: 16),
              _buildChannelStat(
                  '$_totalMessages', 'Messages', Icons.message_outlined,
                  const Color(0xFF2FAD72)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Channel Directory',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
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
          final name = (channel['name'] ?? channel['id'] ?? '').toString();
          final members = (channel['members'] is List)
              ? (channel['members'] as List)
              : [];
          final description =
              (channel['description'] ?? '').toString();
          final isSystemChannel =
              name.startsWith('channel_') || channel['is_system'] == true;

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
                          ? const Color(0xFFD49B28).withValues(alpha: 0.1)
                          : theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isSystemChannel
                          ? Icons.lock_outline_rounded
                          : Icons.forum_outlined,
                      size: 18,
                      color: isSystemChannel
                          ? const Color(0xFFD49B28)
                          : theme.colorScheme.secondary,
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
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.5),
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
                ],
              ),
            ),
          );
        }),
      ],
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
    // Transform channel_general → General, channel_bod → Board of Directors
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

