import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/app_models.dart';
import '../../services/supabase_service.dart';
import '../../constants/chapters.dart';

class RoleManagementScreen extends StatefulWidget {
  const RoleManagementScreen({super.key});

  @override
  State<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen> {
  final SupabaseService _supabaseService = SupabaseService.instance;
  bool _isLoading = true;
  bool _hasAccess = false;
  User? _currentUser;
  List<UserProfile> _users = [];
  String _searchQuery = '';
  String _selectedRole = 'all';
  String _selectedChapter = 'all';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      final user = _supabaseService.currentUser;
      if (user != null) {
        _currentUser = user;
        // For now, allow access - role checking should be implemented with UserProfile
        _hasAccess = true;

        if (_hasAccess) {
          await _loadUsers();
        }
      }
    } catch (e) {
      _hasAccess = false;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUsers() async {
    try {
      // TODO: Implement actual data fetching from Supabase
      // For now, using placeholder data
      setState(() {
        _users = [
          // Placeholder users
        ];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading users: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.green,
          ),
        ),
      );
    }

    if (!_hasAccess) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                size: 80,
                color: Colors.red,
              ),
              SizedBox(height: 16),
              Text(
                'Access Denied',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'You do not have permission to manage user roles.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'This section is restricted to\nAdministrators and Leaders only.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Role Management'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey.shade50,
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
              color: Colors.indigo.shade50,
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
                          const Text(
                            'User Management',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                          Text(
                            'Managing ${_filteredUsers.length} users. Promote or demote users as needed.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.indigo,
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
          backgroundColor: _getRoleColor(user.role),
          backgroundImage:
              user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
          child: user.avatarUrl == null
              ? const Icon(
                  Icons.person,
                  color: Colors.white,
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
                    color: _getRoleColor(user.role).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user.role.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getRoleColor(user.role),
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
                    child: const Text(
                      'NC',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                if (user.isNewConvert) const SizedBox(width: 8),
                if (user.chapterId != null)
                  Text(
                    user.chapterId!,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
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
                ],
              )
            : Icon(
                Icons.lock_outline,
                color: Colors.grey.shade400,
              ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'leader':
        return Colors.purple;
      case 'coordinator':
        return Colors.blue;
      case 'member':
      default:
        return Colors.green;
    }
  }

  bool _canModifyUser(UserProfile user) {
    if (_currentUser == null) return false;

    // Admins can modify anyone except other admins (unless they're the same person)
    if (_currentUser!.role == 'admin') {
      return user.id != _currentUser!.id || user.role != 'admin';
    }

    // Leaders can modify coordinators and members, but not other leaders or admins
    if (_currentUser!.role == 'leader') {
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
      case 'leader':
        newRole = 'coordinator';
        break;
      case 'coordinator':
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
    if (_currentUser?.role == 'admin') {
      return true; // Admins can assign any role
    }

    if (_currentUser?.role == 'leader') {
      return role != 'admin' &&
          role != 'leader'; // Leaders can't create other leaders or admins
    }

    return false;
  }

  Future<void> _updateUserRole(
      UserProfile user, String newRole, String action) async {
    try {
      // TODO: Implement actual role update in Supabase

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${user.fullName} has been $action to ${newRole.toUpperCase()}',
          ),
          backgroundColor: Colors.green,
        ),
      );

      await _loadUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating user role: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // TODO: Implement user archiving logic
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.fullName} has been archived'),
            backgroundColor: Colors.orange,
          ),
        );
        await _loadUsers();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error archiving user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
