import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/app_models.dart';
import '../../services/supabase_service.dart';
import '../../utils/logger.dart';

class UserArchiveScreen extends StatefulWidget {
  const UserArchiveScreen({super.key});

  @override
  State<UserArchiveScreen> createState() => _UserArchiveScreenState();
}

class _UserArchiveScreenState extends State<UserArchiveScreen> {
  final SupabaseService _supabaseService = SupabaseService.instance;
  final Logger _logger = Logger('UserArchiveScreen');
  bool _isLoading = true;
  bool _hasAccess = false;
  User? _currentUser;
  List<UserProfile> _archivedUsers = [];
  String _searchQuery = '';
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
          await _loadArchivedUsers();
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
  
  Future<void> _loadArchivedUsers() async {
    try {
      // Fetch archived users from Supabase
      final response = await _supabaseService.client
          .from('user_profiles')
          .select()
          .eq('is_archived', true)
          .order('updated_at', ascending: false);

      final List<UserProfile> archivedUsers = [];
      for (final userData in response) {
        try {
          archivedUsers.add(UserProfile.fromJson(userData));
        } catch (e) {
          _logger.error('Error parsing user data', e);
        }
      }

      setState(() {
        _archivedUsers = archivedUsers;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading archived users: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  List<UserProfile> get _filteredUsers {
    if (_searchQuery.isEmpty) {
      return _archivedUsers;
    }
    return _archivedUsers.where((user) {
      final name = user.fullName?.toLowerCase() ?? '';
      final email = user.email?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || email.contains(query);
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
                Icons.archive_outlined,
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
                'You do not have permission to access archived users.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'This section is restricted to Leaders,\nCoordinators, and Administrators only.',
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
        title: const Text('Archived Users'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadArchivedUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search archived users...',
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
          ),
          
          // Info Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Archived Users',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          Text(
                            'Users who have left the organization. Found ${_filteredUsers.length} archived users.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
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
          
          const SizedBox(height: 16),
          
          // Archived Users List
          Expanded(
            child: _filteredUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.archive_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No archived users found'
                              : 'No users match your search',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Users who leave the organization will appear here'
                              : 'Try adjusting your search terms',
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
                      return _buildArchivedUserCard(user);
                    },
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildArchivedUserCard(UserProfile user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange,
          backgroundImage: user.avatarUrl != null 
              ? NetworkImage(user.avatarUrl!) 
              : null,
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
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ARCHIVED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  user.role.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (user.isNewConvert) ...[
                  const SizedBox(width: 8),
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
                ],
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Phone', user.phoneNumber ?? 'Not provided'),
                _buildDetailRow('Address', user.address ?? 'Not provided'),
                _buildDetailRow('Chapter', user.chapterId ?? 'Not assigned'),
                _buildDetailRow('Bio', user.bio ?? 'No bio available'),
                _buildDetailRow(
                  'Archived Date',
                  user.updatedAt.toString().split(' ')[0],
                ),
                const SizedBox(height: 16),
                
                // Action Buttons
                if (_currentUser != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _restoreUser(user),
                          icon: const Icon(Icons.restore),
                          label: const Text('Restore User'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _permanentlyDeleteUser(user),
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Delete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _restoreUser(UserProfile user) async {
    try {
      // Update user profile to unarchive them
      // Store context in local variable before async gap
      final messenger = ScaffoldMessenger.of(context);
      
      await _supabaseService.client
          .from('users')
          .update({
            'is_archived': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);

      messenger.showSnackBar(
        SnackBar(
          content: Text('${user.fullName} has been restored'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadArchivedUsers();
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error restoring user: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _permanentlyDeleteUser(UserProfile user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanent Deletion'),
        content: Text(
          'Are you sure you want to permanently delete ${user.fullName}? This action cannot be undone.',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        // Permanently delete user profile from database
        await _supabaseService.client
            .from('user_profiles')
            .delete()
            .eq('id', user.id);

        // Also delete related data (prayer requests, health tracking, etc.)
        await Future.wait([
          _supabaseService.client
              .from('prayer_requests')
              .delete()
              .eq('user_id', user.id),
          _supabaseService.client
              .from('health_tracking')
              .delete()
              .eq('user_id', user.id),
          _supabaseService.client
              .from('mission_participants')
              .delete()
              .eq('user_id', user.id),
          _supabaseService.client
              .from('study_guide_progress')
              .delete()
              .eq('user_id', user.id),
        ]);

        // Store context in local variable before async gap
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text('${user.fullName} has been permanently deleted'),
            backgroundColor: Colors.red,
          ),
        );
        await _loadArchivedUsers();
      } catch (e) {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error deleting user: $e'),
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
