import '../../utils/appwrite_id_utils.dart';
import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../models/leadership_models.dart' show RoleHistoryRecord;
import '../../services/appwrite_profile_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/custom_image.dart';
import '../../constants/chapters.dart';
import 'package:intl/intl.dart';

class RoleManagementScreen extends StatefulWidget {
  const RoleManagementScreen({super.key});

  @override
  State<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return const RoleProtectedScreen(
      requiredRole: 'leader',
      screenName: 'Role Management',
      child: _RoleManagementContent(),
    );
  }
}

class _RoleManagementContent extends StatefulWidget {
  const _RoleManagementContent();

  @override
  State<_RoleManagementContent> createState() => _RoleManagementContentState();
}

class _RoleManagementContentState extends State<_RoleManagementContent> {
  final AppwriteProfileService _profileService = AppwriteProfileService();
  final AuthService _authService = AuthService.instance;
  bool _isLoading = true;
  String? _currentUserId;
  List<UserProfile> _users = [];
  String _searchQuery = '';
  String _selectedRole = 'all';
  String _selectedChapter = 'all';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      _currentUserId = _authService.currentUser?.uid;
      await _loadUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
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

  Future<void> _loadUsers() async {
    try {
      final users = await _profileService.getAllUsers();

      setState(() {
        _users = users;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  List<UserProfile> get _filteredUsers {
    return _users.where((user) {
      // Don't show archived users
      if (user.isArchived) return false;

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final name = user.fullName?.toLowerCase() ?? '';
        final email = user.email?.toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        if (!name.contains(query) && !email.contains(query)) {
          return false;
        }
      }

      // Role filter
      if (_selectedRole != 'all' && user.role != _selectedRole) {
        return false;
      }

      // Chapter filter
      if (_selectedChapter != 'all' && user.chapterId != _selectedChapter) {
        return false;
      }

      return true;
    }).toList();
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Role Management',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
        actionsIconTheme:
            IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            tooltip: 'Refresh',
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),

                const SizedBox(height: 12),

                // Filter Row
                Row(
                  children: [
                    // Role Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Filter by Role',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('All Roles'),
                          ),
                          ...ChapterConstants.userRoles.map(
                            (role) => DropdownMenuItem(
                              value: role,
                              child: Text(role.toUpperCase()),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedRole = value ?? 'all';
                          });
                        },
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Chapter Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedChapter,
                        decoration: const InputDecoration(
                          labelText: 'Filter by Chapter',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('All Chapters'),
                          ),
                          ...ChapterConstants.availableChapters.map(
                            (chapter) => DropdownMenuItem(
                              value: chapter,
                              child: Text(chapter),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedChapter = value ?? 'all';
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Stats Card
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.3),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.people_outline,
                      color: Colors.indigo,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'User Management',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          Text(
                            'Managing ${_filteredUsers.length} users. Promote or demote users as needed.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
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
          ),

          // Users List
          Expanded(
            child: _filteredUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty ||
                                  _selectedRole != 'all' ||
                                  _selectedChapter != 'all'
                              ? 'No users match your filters'
                              : 'No users found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search or filter criteria',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      return _buildUserCard(user);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(UserProfile user) {
    final canModify = _canModifyUser(user);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(context, user.role),
          backgroundImage: user.avatarUrl != null
              ? CustomImage.provider(user.avatarUrl!)
              : null,
          child: user.avatarUrl == null
              ? Icon(
                  Icons.person,
                  color: _getRoleForegroundColor(context, user.role),
                )
              : null,
        ),
        title: Text(
          user.fullName ?? 'Unknown User',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.email ?? 'No email',
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getRoleColor(context, user.role)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user.role.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getRoleColor(context, user.role),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (user.isNewConvert)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'NC',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                    ),
                  ),
                if (user.isNewConvert) const SizedBox(width: 8),
                if (user.chapterId != null)
                  Text(
                    user.chapterId!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ],
        ),
        trailing: canModify
            ? PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (action) => _handleUserAction(user, action),
                itemBuilder: (context) => [
                  if (user.role != 'admin')
                    const PopupMenuItem(
                      value: 'promote',
                      child: Row(
                        children: [
                          Icon(Icons.arrow_upward, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Promote'),
                        ],
                      ),
                    ),
                  if (user.role != 'member')
                    const PopupMenuItem(
                      value: 'demote',
                      child: Row(
                        children: [
                          Icon(Icons.arrow_downward, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Demote'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'change_role',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Change Role'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'archive',
                    child: Row(
                      children: [
                        Icon(Icons.archive, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Archive User'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'view_history',
                    child: Row(
                      children: [
                        Icon(Icons.history, color: Colors.blueGrey),
                        SizedBox(width: 8),
                        Text('View Leadership History'),
                      ],
                    ),
                  ),
                ],
              )
            : Icon(
                Icons.lock_outline,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.4),
              ),
      ),
    );
  }

  Color _getRoleColor(BuildContext context, String role) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (role) {
      case 'admin':
        return colorScheme.error;
      case 'leader':
        return colorScheme.tertiary;
      case 'coordinator':
        return colorScheme.primary;
      case 'dietist':
        return colorScheme.tertiary;
      case 'member':
      default:
        return colorScheme.secondary;
    }
  }

  Color _getRoleForegroundColor(BuildContext context, String role) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (role) {
      case 'admin':
        return colorScheme.onError;
      case 'leader':
      case 'dietist':
        return colorScheme.onTertiary;
      case 'coordinator':
        return colorScheme.onPrimary;
      case 'member':
      default:
        return colorScheme.onSecondary;
    }
  }

  bool _canModifyUser(UserProfile user) {
    if (_currentUserId == null) return false;

    // Get current user from the users list
    final currentUser = _users.firstWhere(
      (u) => u.id == _currentUserId,
      orElse: () => UserProfile(
        id: '',
        email: '',
        role: 'member',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    // Admins can modify anyone except other admins (unless they're the same person)
    if (currentUser.role == 'admin') {
      return user.id != currentUser.id || user.role != 'admin';
    }

    // Leaders can modify coordinators and members, but not other leaders or admins
    if (currentUser.role == 'leader') {
      return user.role == 'coordinator' || user.role == 'member';
    }

    return false;
  }

  Future<void> _handleUserAction(UserProfile user, String action) async {
    switch (action) {
      case 'promote':
        await _promoteUser(user);
        break;
      case 'demote':
        await _demoteUser(user);
        break;
      case 'change_role':
        await _showChangeRoleDialog(user);
        break;
      case 'archive':
        await _archiveUser(user);
        break;
      case 'view_history':
        await _showLeadershipHistoryDialog(user);
        break;
    }
  }

  Future<void> _promoteUser(UserProfile user) async {
    String newRole;
    switch (user.role) {
      case 'member':
        newRole = 'coordinator';
        break;
      case 'coordinator':
        newRole = 'leader';
        break;
      case 'leader':
        newRole = 'admin';
        break;
      default:
        return;
    }

    await _updateUserRole(user, newRole, 'promoted');
  }

  Future<void> _demoteUser(UserProfile user) async {
    String newRole;
    switch (user.role) {
      case 'admin':
        newRole = 'leader';
        break;
      case 'trustee':
        newRole = 'bod';
        break;
      case 'bod':
        newRole = 'director';
        break;
      case 'director':
        newRole = 'leader';
        break;
      case 'leader':
        newRole = 'coordinator';
        break;
      case 'coordinator':
        newRole = 'member';
        break;
      // Health+ contributors drop straight back to a plain member.
      case 'dietist':
        newRole = 'member';
        break;
      default:
        return;
    }

    await _updateUserRole(user, newRole, 'demoted');
  }

  Future<void> _showChangeRoleDialog(UserProfile user) async {
    final newRole = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Role for ${user.fullName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current role: ${user.role.toUpperCase()}'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: user.role,
              decoration: const InputDecoration(
                labelText: 'New Role',
                border: OutlineInputBorder(),
              ),
              items: ChapterConstants.userRoles
                  .where((role) => _canAssignRole(role))
                  .map(
                    (role) => DropdownMenuItem(
                      value: role,
                      child: Text(role.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                Navigator.of(context).pop(value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (newRole != null && newRole != user.role) {
      await _updateUserRole(user, newRole, 'changed');
    }
  }

  bool _canAssignRole(String role) {
    if (_currentUserId == null) return false;

    // Get current user from the users list
    final currentUser = _users.firstWhere(
      (u) => u.id == _currentUserId,
      orElse: () => UserProfile(
        id: '',
        email: '',
        role: 'member',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    if (currentUser.role == 'admin') {
      return true; // Admins can assign any role
    }

    if (currentUser.role == 'leader') {
      return role != 'admin' &&
          role != 'leader'; // Leaders can't create other leaders or admins
    }

    return false;
  }

  Future<void> _updateUserRole(
      UserProfile user, String newRole, String action) async {
    try {
      // Auto-archive leadership roles when they change (e.g. term expires)
      if (['admin', 'leader', 'coordinator'].contains(user.role) &&
          user.role != newRole) {
        final archiveRecord = await _showArchiveRoleDialog(user);
        if (archiveRecord != null) {
          await _profileService.archiveLeadershipRole(archiveRecord);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Past ${user.role.toUpperCase()} role archived successfully for historical records.'),
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            );
          }
        }
      }

      await _profileService.updateUserRole(user.id, newRole);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${user.fullName} has been $action to ${newRole.toUpperCase()}',
            ),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
        );
      }

      await _loadUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating user role: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _archiveUser(UserProfile user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive User'),
        content: Text(
          'Are you sure you want to archive ${user.fullName}? They will be moved to the archived users section.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _profileService.archiveUser(user.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${user.fullName} has been archived'),
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
          );
        }
        await _loadUsers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error archiving user: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<RoleHistoryRecord?> _showArchiveRoleDialog(UserProfile user) async {
    DateTime startDate = DateTime.now().subtract(const Duration(days: 365));
    DateTime endDate = DateTime.now();
    bool shouldArchive = true;

    return await showDialog<RoleHistoryRecord?>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Archive Past Administration?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${user.fullName} is no longer a ${user.role.toUpperCase()}. Do you want to archive their past tenure for historical records?'),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Archive Role'),
                    value: shouldArchive,
                    onChanged: (val) =>
                        setDialogState(() => shouldArchive = val),
                  ),
                  if (shouldArchive) ...[
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Start Date'),
                      subtitle:
                          Text(DateFormat('MMM d, yyyy').format(startDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => startDate = picked);
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('End Date'),
                      subtitle: Text(DateFormat('MMM d, yyyy').format(endDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => endDate = picked);
                        }
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Skip Archiving'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!shouldArchive) {
                      Navigator.of(context).pop(null);
                      return;
                    }
                    final record = RoleHistoryRecord(
                      id: AppwriteIdUtils.uniqueId(),
                      userId: user.id,
                      role: user.role,
                      startDate: startDate,
                      endDate: endDate,
                      chapterId: user.chapterId,
                    );
                    Navigator.of(context).pop(record);
                  },
                  child: const Text('Save & Archive'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showLeadershipHistoryDialog(UserProfile user) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Leadership History: ${user.fullName}'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: FutureBuilder<List<RoleHistoryRecord>>(
              future: _profileService.getLeadershipHistory(user.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Unable to load leadership history right now.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                final records = snapshot.data ?? [];
                if (records.isEmpty) {
                  return const Center(
                      child: Text('No past leadership records found.'));
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getRoleColor(context, record.role),
                          child: Icon(Icons.history,
                              color: _getRoleForegroundColor(context, record.role),
                              size: 20),
                        ),
                        title: Text(record.role.toUpperCase(),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            '${DateFormat('MMM yyyy').format(record.startDate)} - ${DateFormat('MMM yyyy').format(record.endDate)}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
