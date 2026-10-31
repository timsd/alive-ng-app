import 'package:flutter/material.dart';
import '../../services/appwrite_facade.dart';

import '../../config/appwrite_backend_config.dart';
import '../../main.dart';
import '../../models/app_models.dart';
import '../../services/auth_service.dart';
import '../../services/appwrite_profile_service.dart';
import '../../widgets/custom_image.dart';

class AdminApprovalScreen extends StatefulWidget {
  const AdminApprovalScreen({super.key});

  @override
  State<AdminApprovalScreen> createState() => _AdminApprovalScreenState();
}

class _AdminApprovalScreenState extends State<AdminApprovalScreen>
    with SingleTickerProviderStateMixin {
  late final TablesDB _tables;
  final AppwriteProfileService _profileService = AppwriteProfileService();
  final AuthService _authService = AuthService.instance;
  late TabController _tabController;

  List<UserProfile> _pendingUsers = [];
  List<UserProfile> _approvedUsers = [];
  List<UserProfile> _rejectedUsers = [];

  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tables = TablesDB(appwriteClient);
    _tabController = TabController(length: 3, vsync: this);
    _currentUserId = _authService.currentUser?.uid;
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);

    try {
      final users = await _listUsers();
      final userProfiles = users.map(_profileFromDocument).toList();

      setState(() {
        _pendingUsers = userProfiles
            .where((user) => user.approvalStatus == 'pending')
            .toList();
        _approvedUsers = userProfiles
            .where((user) => user.approvalStatus == 'approved')
            .toList();
        _rejectedUsers = userProfiles
            .where((user) => user.approvalStatus == 'rejected')
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error loading users: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<List<dynamic>> _listUsers() async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.usersCollectionId,
        queries: [
          Query.orderDesc('created_at'),
          Query.limit(200),
        ],
      );
      return response.rows;
    } on AppwriteException {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.usersCollectionId,
        queries: [
          Query.limit(200),
        ],
      );
      return response.rows;
    }
  }

  UserProfile _profileFromDocument(dynamic document) {
    return _profileService.userProfileFromDocument(
      document,
      fallbackEmail: document.data['email']?.toString() ?? '',
      fallbackFullName:
          (document.data['fullName'] ?? document.data['full_name'])?.toString(),
    );
  }

  Future<void> _approveUser(UserProfile user) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final targetRole = (user.requestedRole != null && user.requestedRole!.trim().isNotEmpty)
          ? user.requestedRole!.trim()
          : user.role;

      final updateData = <String, dynamic>{
        'is_approved': true,
        'approval_status': 'approved',
        'approved_by': _currentUserId,
        'approved_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (targetRole.isNotEmpty) {
        updateData['role'] = targetRole;
      }

      await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.usersCollectionId,
        rowId: user.id,
        data: updateData,
      );

      await _loadUsers();

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('${user.fullName ?? 'User'} approved successfully as ${targetRole.toUpperCase()}'),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error approving user: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _rejectUser(UserProfile user, String reason) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.usersCollectionId,
        rowId: user.id,
        data: {
          'is_approved': false,
          'approval_status': 'rejected',
          'rejection_reason': reason,
          'approved_by': _currentUserId,
          'approved_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
      );

      await _loadUsers();

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('${user.fullName ?? 'User'} rejected'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error rejecting user: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showUserDetailsDialog(UserProfile user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.fullName ?? 'User Details',
            style: Theme.of(context).textTheme.titleLarge),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Email', user.email ?? 'Not provided'),
              _buildDetailRow('Phone', user.phoneNumber ?? 'Not provided'),
              _buildDetailRow('Address', user.address ?? 'Not provided'),
              _buildDetailRow('Bio', user.bio ?? 'Not provided'),
              if (user.requestedRole != null && user.requestedRole!.trim().isNotEmpty)
                _buildDetailRow('Requested Role', user.requestedRole!.toUpperCase()),
              _buildDetailRow('Current Role', user.role.toUpperCase()),
              const SizedBox(height: 16),
              Text('Verification Details:',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildDetailRow(
                  'Local Chapter', user.localChapter ?? 'Not provided'),
              _buildDetailRow(
                  'Local Church', user.localChurch ?? 'Not provided'),
              const SizedBox(height: 16),
              Text('Commitment Details:',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildDetailRow(
                  'Commitment Type', user.commitmentType ?? 'Not specified'),
              if (user.financialCommitment != null)
                _buildDetailRow('Financial Commitment',
                    '₦${user.financialCommitment!.toStringAsFixed(2)}'),
              _buildDetailRow('Availability',
                  user.availabilityCommitment ?? 'Not specified'),
              const SizedBox(height: 16),
              _buildDetailRow(
                  'Registration Date', user.createdAt.toString().split(' ')[0]),
              if (user.approvalStatus == 'rejected' &&
                  user.rejectionReason != null)
                _buildDetailRow('Rejection Reason', user.rejectionReason!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (user.approvalStatus == 'pending') ...[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showRejectDialog(user);
              },
              child: Text('Reject',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _approveUser(user);
              },
              child: const Text('Approve'),
            ),
          ],
        ],
      ),
    );
  }

  void _showRejectDialog(UserProfile user) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject ${user.fullName ?? 'User'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter rejection reason...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.of(context).pop();
                _rejectUser(user, reasonController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(UserProfile user) {
    Color statusColor;
    IconData statusIcon;

    switch (user.approvalStatus) {
      case 'approved':
        statusColor = Theme.of(context).colorScheme.tertiary;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Theme.of(context).colorScheme.error;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Theme.of(context).colorScheme.secondary;
        statusIcon = Icons.pending;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: user.avatarUrl != null
              ? CustomImage.provider(user.avatarUrl!)
              : null,
          child: user.avatarUrl == null
              ? Text((user.fullName != null && user.fullName!.trim().isNotEmpty)
                  ? user.fullName!.trim().substring(0, 1).toUpperCase()
                  : 'U')
              : null,
        ),
        title: Text(user.fullName ?? 'Unknown User'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email ?? 'No email'),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(statusIcon, size: 16, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  user.approvalStatus.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                if (user.requestedRole != null && user.requestedRole!.trim().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Requested: ${user.requestedRole!.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (user.localChapter != null || user.localChurch != null)
              Text(
                '${user.localChapter ?? ''} ${user.localChurch != null ? '• ${user.localChurch}' : ''}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
          ],
        ),
        trailing: user.approvalStatus == 'pending'
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.close,
                        color: Theme.of(context).colorScheme.error),
                    onPressed: () => _showRejectDialog(user),
                  ),
                  IconButton(
                    icon: Icon(Icons.check,
                        color: Theme.of(context).colorScheme.tertiary),
                    onPressed: () => _approveUser(user),
                  ),
                ],
              )
            : null,
        onTap: () => _showUserDetailsDialog(user),
      ),
    );
  }

  Widget _buildUserList(List<UserProfile> users, String emptyMessage) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) => _buildUserCard(users[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Approval Management'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          tabs: [
            Tab(
              text: 'Pending (${_pendingUsers.length})',
              icon: const Icon(Icons.pending),
            ),
            Tab(
              text: 'Approved (${_approvedUsers.length})',
              icon: const Icon(Icons.check_circle),
            ),
            Tab(
              text: 'Rejected (${_rejectedUsers.length})',
              icon: const Icon(Icons.cancel),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUserList(_pendingUsers, 'No pending approvals'),
                _buildUserList(_approvedUsers, 'No approved users'),
                _buildUserList(_rejectedUsers, 'No rejected users'),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadUsers,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
