import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/app_models.dart';
import '../../services/supabase_service.dart';

class AdminApprovalScreen extends StatefulWidget {
  const AdminApprovalScreen({super.key});

  @override
  State<AdminApprovalScreen> createState() => _AdminApprovalScreenState();
}

class _AdminApprovalScreenState extends State<AdminApprovalScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService.instance;
  late TabController _tabController;
  
  List<UserProfile> _pendingUsers = [];
  List<UserProfile> _approvedUsers = [];
  List<UserProfile> _rejectedUsers = [];
  
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentUserId = _supabaseService.currentUser?.id;
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    
    try {
      // Fetch all users with their approval status
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .order('created_at', ascending: false);

      final users = response.map((json) => UserProfile.fromJson(json)).toList();
      
      setState(() {
        _pendingUsers = users.where((user) => user.approvalStatus == 'pending').toList();
        _approvedUsers = users.where((user) => user.approvalStatus == 'approved').toList();
        _rejectedUsers = users.where((user) => user.approvalStatus == 'rejected').toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approveUser(UserProfile user) async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({
            'is_approved': true,
            'approval_status': 'approved',
            'approved_by': _currentUserId,
            'approved_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);

      await _loadUsers();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.fullName ?? 'User'} approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectUser(UserProfile user, String reason) async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({
            'is_approved': false,
            'approval_status': 'rejected',
            'rejection_reason': reason,
            'approved_by': _currentUserId,
            'approved_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);

      await _loadUsers();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.fullName ?? 'User'} rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showUserDetailsDialog(UserProfile user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.fullName ?? 'User Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Email', user.email ?? 'Not provided'),
              _buildDetailRow('Phone', user.phoneNumber ?? 'Not provided'),
              _buildDetailRow('Address', user.address ?? 'Not provided'),
              _buildDetailRow('Bio', user.bio ?? 'Not provided'),
              const SizedBox(height: 16),
              const Text('Verification Details:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildDetailRow('Local Chapter', user.localChapter ?? 'Not provided'),
              _buildDetailRow('Local Church', user.localChurch ?? 'Not provided'),
              _buildDetailRow('Conference', user.conference ?? 'Not provided'),
              const SizedBox(height: 16),
              const Text('Commitment Details:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildDetailRow('Commitment Type', user.commitmentType ?? 'Not specified'),
              if (user.financialCommitment != null)
                _buildDetailRow('Financial Commitment', '\$${user.financialCommitment!.toStringAsFixed(2)}'),
              _buildDetailRow('Availability', user.availabilityCommitment ?? 'Not specified'),
              const SizedBox(height: 16),
              _buildDetailRow('Registration Date', user.createdAt.toString().split(' ')[0]),
              if (user.approvalStatus == 'rejected' && user.rejectionReason != null)
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
              child: const Text('Reject', style: TextStyle(color: Colors.red)),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
              style: const TextStyle(fontWeight: FontWeight.w500),
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
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: user.avatarUrl != null 
              ? NetworkImage(user.avatarUrl!) 
              : null,
          child: user.avatarUrl == null 
              ? Text(user.fullName?.substring(0, 1).toUpperCase() ?? 'U')
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
              ],
            ),
            if (user.localChapter != null || user.localChurch != null)
              Text(
                '${user.localChapter ?? ''} ${user.localChurch != null ? '• ${user.localChurch}' : ''}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        trailing: user.approvalStatus == 'pending'
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => _showRejectDialog(user),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
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
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
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