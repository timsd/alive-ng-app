import 'package:flutter/material.dart';

import '../../../models/chat_models.dart';
import '../../../services/appwrite_chat_service.dart';

class ManageMembersDialog extends StatefulWidget {
  final ChatChannel channel;
  final AppwriteChatService chatService;
  final String? currentUserId;
  final Function(List<String> updatedMembers) onMembersUpdated;

  const ManageMembersDialog({
    super.key,
    required this.channel,
    required this.chatService,
    required this.currentUserId,
    required this.onMembersUpdated,
  });

  @override
  State<ManageMembersDialog> createState() => _ManageMembersDialogState();
}

class _ManageMembersDialogState extends State<ManageMembersDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<ChatUser> _channelMembers = [];
  List<ChatUser> _nonMembers = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final allUsers =
          await widget.chatService.getAllCommunityUsers(limit: 200);
      final memberSet = widget.channel.members.toSet();

      final members = <ChatUser>[];
      final nonMembers = <ChatUser>[];

      for (final user in allUsers) {
        if (memberSet.contains(user.id)) {
          members.add(user);
        } else {
          nonMembers.add(user);
        }
      }

      // Add placeholder for any channel member IDs not in loaded user list
      for (final memberId in widget.channel.members) {
        if (!members.any((u) => u.id == memberId)) {
          members.add(ChatUser(
            id: memberId,
            name:
                'Member (${memberId.substring(0, memberId.length.clamp(0, 6))}...)',
            email: '',
            role: UserRole.member,
          ));
        }
      }

      if (mounted) {
        setState(() {
          _channelMembers = members;
          _nonMembers = nonMembers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: $e')),
        );
      }
    }
  }

  Future<void> _addMember(ChatUser user) async {
    try {
      await widget.chatService
          .addMemberToChannel(widget.channel.id, user.id);
      setState(() {
        _nonMembers.removeWhere((u) => u.id == user.id);
        _channelMembers.add(user);
      });
      widget.onMembersUpdated(_channelMembers.map((u) => u.id).toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} added to #${widget.channel.name}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding member: $e')),
        );
      }
    }
  }

  Future<void> _removeMember(ChatUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
            'Are you sure you want to remove "${user.name}" from #${widget.channel.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await widget.chatService
          .removeMemberFromChannel(widget.channel.id, user.id);
      setState(() {
        _channelMembers.removeWhere((u) => u.id == user.id);
        _nonMembers.add(user);
      });
      widget.onMembersUpdated(_channelMembers.map((u) => u.id).toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} removed from #${widget.channel.name}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing member: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final filteredNonMembers = _searchQuery.isEmpty
        ? _nonMembers
        : _nonMembers.where((u) {
            final query = _searchQuery.toLowerCase();
            return u.name.toLowerCase().contains(query) ||
                u.email.toLowerCase().contains(query);
          }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dialog Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.manage_accounts_rounded,
                        color: colorScheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Manage Channel Members',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '#${widget.channel.name}',
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tab Bar
            TabBar(
              controller: _tabController,
              labelColor: colorScheme.primary,
              indicatorColor: colorScheme.primary,
              tabs: [
                Tab(
                  icon: const Icon(Icons.people_alt_rounded, size: 18),
                  text: 'Current (${_channelMembers.length})',
                ),
                Tab(
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  text: 'Add Member (${_nonMembers.length})',
                ),
              ],
            ),

            // Tab Views
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 1: Current Members
                        _channelMembers.isEmpty
                            ? Center(
                                child: Text(
                                  'No members in this channel yet.',
                                  style: TextStyle(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                itemCount: _channelMembers.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final member = _channelMembers[index];
                                  final isSelf =
                                      widget.currentUserId != null &&
                                          member.id == widget.currentUserId;

                                  return ListTile(
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                    leading: CircleAvatar(
                                      backgroundColor: colorScheme.primary
                                          .withValues(alpha: 0.15),
                                      child: Text(
                                        member.name.isNotEmpty
                                            ? member.name[0].toUpperCase()
                                            : 'U',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            member.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isSelf) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2),
                                            decoration: BoxDecoration(
                                              color: colorScheme.primary
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'YOU',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    subtitle: member.email.isNotEmpty
                                        ? Text(
                                            member.email,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: colorScheme.onSurface
                                                  .withValues(alpha: 0.6),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        : null,
                                    trailing: isSelf
                                        ? null
                                        : IconButton(
                                            icon: Icon(
                                              Icons.person_remove_rounded,
                                              color: colorScheme.error,
                                              size: 20,
                                            ),
                                            tooltip: 'Remove from channel',
                                            onPressed: () =>
                                                _removeMember(member),
                                          ),
                                  );
                                },
                              ),

                        // Tab 2: Add Members
                        Column(
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText:
                                      'Search members by name or email...',
                                  prefixIcon:
                                      const Icon(Icons.search, size: 20),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear,
                                              size: 18),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(
                                                () => _searchQuery = '');
                                          },
                                        )
                                      : null,
                                  isDense: true,
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          vertical: 10, horizontal: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onChanged: (val) {
                                  setState(
                                      () => _searchQuery = val.trim());
                                },
                              ),
                            ),
                            Expanded(
                              child: filteredNonMembers.isEmpty
                                  ? Center(
                                      child: Text(
                                        _searchQuery.isEmpty
                                            ? 'All community members are already in this channel!'
                                            : 'No matching users found.',
                                        style: TextStyle(
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.6),
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      itemCount:
                                          filteredNonMembers.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final user =
                                            filteredNonMembers[index];

                                        return ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4),
                                          leading: CircleAvatar(
                                            backgroundColor: colorScheme
                                                .secondary
                                                .withValues(alpha: 0.15),
                                            child: Text(
                                              user.name.isNotEmpty
                                                  ? user.name[0]
                                                      .toUpperCase()
                                                  : 'U',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.secondary,
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            user.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: user.email.isNotEmpty
                                              ? Text(
                                                  user.email,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: colorScheme
                                                        .onSurface
                                                        .withValues(alpha: 0.6),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                )
                                              : null,
                                          trailing: ElevatedButton.icon(
                                            onPressed: () =>
                                                _addMember(user),
                                            icon: const Icon(
                                                Icons.person_add_rounded,
                                                size: 16),
                                            label: const Text('Add'),
                                            style: ElevatedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                              visualDensity:
                                                  VisualDensity.compact,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

