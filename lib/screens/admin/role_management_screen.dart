import 'dart:async';
import '../../utils/error_handler.dart';
import '../../utils/appwrite_id_utils.dart';
import 'package:flutter/material.dart';

import '../../config/appwrite_backend_config.dart';
import '../../models/app_models.dart';
import '../../models/leadership_models.dart' show RoleHistoryRecord;
import '../../services/appwrite_profile_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/custom_image.dart';
import '../../constants/chapters.dart';
import '../../utils/text_formatter.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/admin_filter_header.dart';
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
  StreamSubscription<UserProfile>? _profileUpdatesSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    _profileUpdatesSub = _profileService.onUserProfileUpdated.listen((updated) {
      if (!mounted) return;
      setState(() {
        final index = _users.indexWhere((u) => u.id == updated.id);
        if (index != -1) {
          _users[index] = updated;
        } else {
          _users.add(updated);
        }
      });
    });
  }

  Future<void> _loadData() async {
    try {
      _currentUserId = _authService.currentUser?.uid;
      await _loadUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: ${ErrorHandler.getUserFriendlyMessage(e)}'),
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
            content: Text('Error loading users: ${ErrorHandler.getUserFriendlyMessage(e)}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  bool _matchesRoleFilter(String userRole, String selectedRole) {
    if (selectedRole == 'all') return true;
    switch (selectedRole) {
      case 'admin':
        return userRole == 'admin' || userRole == 'super_admin';
      case 'director':
        return userRole.contains('director');
      case 'coordinator':
        return userRole.contains('coordinator');
      case 'bod':
        return userRole == 'bod' || userRole.contains('bod');
      case 'field_worker':
        return userRole.contains('field_worker');
      case 'campus_missionary':
        return userRole.contains('campus_missionary');
      case 'amtc_team':
        return userRole.contains('amtc_team');
      case 'member':
        return userRole == 'member';
      default:
        return userRole == selectedRole;
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
      if (!_matchesRoleFilter(user.role, _selectedRole)) {
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
      appBar: CustomAppBar(
        title: 'Role Management',
        showBackButton: true,
        showDonationButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search, Filters & Interactive Metric Header (Option 3)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Builder(
              builder: (context) {
                final activeUsers = _users.where((u) => !u.isArchived).toList();
                final allCount = activeUsers.length;
                final adminCount = activeUsers
                    .where((u) => u.role == 'admin' || u.role == 'super_admin')
                    .length;
                final directorCount =
                    activeUsers.where((u) => u.role.contains('director')).length;
                final coordinatorCount =
                    activeUsers.where((u) => u.role.contains('coordinator')).length;
                final bodCount = activeUsers
                    .where((u) => u.role == 'bod' || u.role.contains('bod'))
                    .length;
                final fieldWorkerCount = activeUsers
                    .where((u) => u.role.contains('field_worker'))
                    .length;
                final campusMissCount = activeUsers
                    .where((u) => u.role.contains('campus_missionary'))
                    .length;
                final amtcCount =
                    activeUsers.where((u) => u.role.contains('amtc_team')).length;
                final memberCount =
                    activeUsers.where((u) => u.role == 'member').length;

                return AdminFilterHeader<String>(
                  searchController: _searchController,
                  searchHint: 'Search users by name or email...',
                  onSearchChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  onSearchCleared: () {
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  dropdownFilters: [
                    AdminDropdownPill<String>(
                      label: 'Chapter',
                      icon: Icons.location_on_outlined,
                      selectedValue: _selectedChapter,
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
                  ],
                  metricPills: [
                    AdminMetricPill<String>(
                      label: 'All',
                      value: 'all',
                      count: allCount,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    AdminMetricPill<String>(
                      label: 'Admins',
                      value: 'admin',
                      count: adminCount,
                      color: Colors.red,
                    ),
                    AdminMetricPill<String>(
                      label: 'Directors',
                      value: 'director',
                      count: directorCount,
                      color: Colors.purple,
                    ),
                    AdminMetricPill<String>(
                      label: 'Coordinators',
                      value: 'coordinator',
                      count: coordinatorCount,
                      color: Colors.orange,
                    ),
                    AdminMetricPill<String>(
                      label: 'BOD',
                      value: 'bod',
                      count: bodCount,
                      color: Colors.blue,
                    ),
                    AdminMetricPill<String>(
                      label: 'Field Workers',
                      value: 'field_worker',
                      count: fieldWorkerCount,
                      color: Colors.teal,
                    ),
                    AdminMetricPill<String>(
                      label: 'Campus Missionaries',
                      value: 'campus_missionary',
                      count: campusMissCount,
                      color: Colors.indigo,
                    ),
                    AdminMetricPill<String>(
                      label: 'AMTC Team',
                      value: 'amtc_team',
                      count: amtcCount,
                      color: Colors.deepOrange,
                    ),
                    AdminMetricPill<String>(
                      label: 'Members',
                      value: 'member',
                      count: memberCount,
                      color: Colors.grey,
                    ),
                  ],
                  selectedMetric: _selectedRole,
                  onSelectMetric: (value) {
                    setState(() {
                      _selectedRole = value;
                    });
                  },
                  hasActiveNonDefaultFilters: _selectedRole != 'all' ||
                      _selectedChapter != 'all' ||
                      _searchQuery.isNotEmpty,
                  onClearAllFilters: () {
                    _searchController.clear();
                    setState(() {
                      _selectedRole = 'all';
                      _selectedChapter = 'all';
                      _searchQuery = '';
                    });
                  },
                );
              },
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
        leading: Builder(
          builder: (context) {
            final avatarUrl = (user.avatarUrl != null && user.avatarUrl!.trim().isNotEmpty)
                ? user.avatarUrl!.trim()
                : ((user.photoUrl != null && user.photoUrl!.trim().isNotEmpty)
                    ? user.photoUrl!.trim()
                    : null);
            return CircleAvatar(
              backgroundColor: _getRoleColor(context, user.role),
              child: ClipOval(
                child: avatarUrl != null
                    ? CustomImage(
                        imageUrl: avatarUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorWidget: Icon(
                          Icons.person,
                          color: _getRoleForegroundColor(context, user.role),
                        ),
                      )
                    : Icon(
                        Icons.person,
                        color: _getRoleForegroundColor(context, user.role),
                      ),
              ),
            );
          },
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
      case 'field_worker':
        return Colors.teal;
      case 'campus_missionary':
        return Colors.indigo;
      case 'amtc_team':
        return Colors.deepOrange;
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
      case 'field_worker':
      case 'campus_missionary':
      case 'amtc_team':
        return Colors.white;
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

    final isCurrentSuperAdmin = AppwriteBackendConfig.isSuperAdminEmail(currentUser.email) ||
        currentUser.role == 'super_admin';
    final isCurrentAdmin = isCurrentSuperAdmin || currentUser.role == 'admin';

    // Super Admins can modify anyone; Admins can modify anyone except other admins (unless same person)
    if (isCurrentSuperAdmin) return true;
    if (isCurrentAdmin) {
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
      // Functional mission roles drop straight back to a plain member.
      case 'field_worker':
      case 'campus_missionary':
      case 'amtc_team':
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
              borderRadius: BorderRadius.circular(12),
              dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              icon: const Icon(Icons.arrow_drop_down_rounded),
              decoration: const InputDecoration(
                labelText: 'New Role',
                border: OutlineInputBorder(),
              ),
              items: ChapterConstants.userRoles
                  .where((role) => _canAssignRole(role))
                  .map(
                    (role) => DropdownMenuItem(
                      value: role,
                      child: Text(TextFormatter.formatRole(role)),
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

    final isCurrentSuperAdmin = AppwriteBackendConfig.isSuperAdminEmail(currentUser.email) ||
        currentUser.role == 'super_admin';
    final isCurrentAdmin = isCurrentSuperAdmin || currentUser.role == 'admin';

    if (isCurrentAdmin) {
      return true; // Admins and Super Admins can assign any role
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
            content: Text('Error updating user role: ${ErrorHandler.getUserFriendlyMessage(e)}'),
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
              content: Text('Error archiving user: ${ErrorHandler.getUserFriendlyMessage(e)}'),
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
    _profileUpdatesSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}
