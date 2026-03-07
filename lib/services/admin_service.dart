import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/admin_models.dart';
import 'admin_database_helper.dart';
import 'admin_email_settings_service.dart';
import '../utils/logger.dart';

class AdminService {
  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();

  static final Logger _logger = Logger('AdminService');

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final AdminDatabaseHelper _dbHelper = AdminDatabaseHelper();

  // Admin configuration moved to AdminEmailSettingsService

  // Default super admin email - first admin to be created
  static const String superAdminEmail = 'alivenigeria2011@gmail.com';

  // Admin roles hierarchy
  static const Map<String, int> _roleHierarchy = {
    'user': 0,
    'moderator': 1,
    'admin': 2,
    'super_admin': 3,
  };

  // Check if current user is admin
  Future<bool> isCurrentUserAdmin() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Check local database first
      final localAdmin = await _dbHelper.getAdminUser(currentUser.uid);
      if (localAdmin != null && localAdmin.isActive && localAdmin.isApproved) {
        return true;
      }

      // Fallback to Firebase
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final role = userData['role'] as String?;

      if (_isAdminRole(role)) {
        // Cache in local database
        final adminUser = AdminUser(
          userId: currentUser.uid,
          email: userData['email'] ?? '',
          fullName: userData['fullName'] ?? '',
          phoneNumber: userData['phoneNumber'],
          role: role ?? 'admin',
          isApproved: userData['isApproved'] ?? false,
          isActive: userData['isActive'] ?? false,
          createdAt:
              (userData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          lastLoginAt: (userData['lastLoginAt'] as Timestamp?)?.toDate(),
          permissions: List<String>.from(userData['permissions'] ?? []),
        );
        await _dbHelper.insertAdminUser(adminUser);
        return true;
      }

      return false;
    } catch (e) {
      _logger.error('Error checking admin status', e);
      return false;
    }
  }

  // Get current user's admin level
  Future<AdminLevel> getCurrentUserAdminLevel() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return AdminLevel.none;

      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) return AdminLevel.none;

      final userData = userDoc.data()!;
      final role = userData['role'] as String? ?? 'user';

      return _getAdminLevelFromRole(role);
    } catch (e) {
      _logger.error('Error getting admin level', e);
      return AdminLevel.none;
    }
  }

  // Admin signup (only for super admin to create other admins)
  Future<AdminSignupResult> createAdminAccount({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? phoneNumber,
  }) async {
    try {
      // Check if current user is super admin
      final currentAdminLevel = await getCurrentUserAdminLevel();
      if (currentAdminLevel != AdminLevel.superAdmin) {
        return const AdminSignupResult(
          success: false,
          message: 'Only super admins can create admin accounts',
        );
      }

      // Validate role
      if (!_roleHierarchy.containsKey(role) || role == 'user') {
        return const AdminSignupResult(
          success: false,
          message: 'Invalid admin role specified',
        );
      }

      // Create user account
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        return const AdminSignupResult(
          success: false,
          message: 'Failed to create user account',
        );
      }

      // Update user profile
      await user.updateDisplayName(fullName);

      // Create admin profile in Firestore
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'role': role,
        'isApproved': true, // Admins are auto-approved
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _auth.currentUser?.uid,
        'adminLevel': _getAdminLevelFromRole(role).index,
        'permissions': _getDefaultPermissions(role),
      });

      // Log admin creation
      await _logAdminAction(
        action: 'admin_created',
        targetUserId: user.uid,
        details: {
          'email': email,
          'role': role,
          'createdBy': _auth.currentUser?.uid,
        },
      );

      return AdminSignupResult(
        success: true,
        message: 'Admin account created successfully',
        userId: user.uid,
      );
    } catch (e) {
      _logger.error('Error creating admin account', e);
      return AdminSignupResult(
        success: false,
        message: 'Failed to create admin account: ${e.toString()}',
      );
    }
  }

  // Get pending user approvals
  Future<List<UserApprovalRequest>> getPendingApprovals() async {
    try {
      // Get from local database first
      final localRequests = await _dbHelper.getPendingApprovalRequests();
      if (localRequests.isNotEmpty) {
        return localRequests;
      }

      // Fallback to Firebase
      final querySnapshot = await _firestore
          .collection('users')
          .where('isApproved', isEqualTo: false)
          .where('role', isEqualTo: 'user')
          .orderBy('createdAt', descending: true)
          .get();

      final requests = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return UserApprovalRequest(
          userId: doc.id,
          email: data['email'] ?? '',
          fullName: data['fullName'] ?? '',
          phoneNumber: data['phoneNumber'],
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          additionalInfo: data['additionalInfo'],
        );
      }).toList();

      // Cache in local database
      for (final request in requests) {
        await _dbHelper.insertUserApprovalRequest(request);
      }

      return requests;
    } catch (e) {
      _logger.error('Error getting pending approvals', e);
      return [];
    }
  }

  // Approve user registration
  Future<bool> approveUserRegistration(String userId, {String? notes}) async {
    try {
      // Check admin permissions
      if (!await _hasPermission('approve_users')) {
        return false;
      }

      // Update user approval status
      await _firestore.collection('users').doc(userId).update({
        'isApproved': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': _auth.currentUser?.uid,
        'approvalNotes': notes,
      });

      // Send approval notification to user
      await _sendUserApprovalNotification(userId, approved: true);

      // Log admin action
      await _logAdminAction(
        action: 'user_approved',
        targetUserId: userId,
        details: {'notes': notes},
      );

      return true;
    } catch (e) {
      _logger.error('Error approving user', e);
      return false;
    }
  }

  // Reject user registration
  Future<bool> rejectUserRegistration(String userId, {String? reason}) async {
    try {
      // Check admin permissions
      if (!await _hasPermission('approve_users')) {
        return false;
      }

      // Update user status
      await _firestore.collection('users').doc(userId).update({
        'isApproved': false,
        'isRejected': true,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': _auth.currentUser?.uid,
        'rejectionReason': reason,
      });

      // Send rejection notification to user
      await _sendUserApprovalNotification(userId,
          approved: false, reason: reason);

      // Log admin action
      await _logAdminAction(
        action: 'user_rejected',
        targetUserId: userId,
        details: {'reason': reason},
      );

      return true;
    } catch (e) {
      _logger.error('Error rejecting user', e);
      return false;
    }
  }

  // Get all users with admin capabilities
  Future<List<AdminUser>> getAllUsers({int? limit, String? role}) async {
    try {
      Query query = _firestore.collection('users');

      if (role != null) {
        query = query.where('role', isEqualTo: role);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      query = query.orderBy('createdAt', descending: true);

      final querySnapshot = await query.get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return AdminUser(
          userId: doc.id,
          email: data['email'] ?? '',
          fullName: data['fullName'] ?? '',
          phoneNumber: data['phoneNumber'],
          role: data['role'] ?? 'user',
          isApproved: data['isApproved'] ?? false,
          isActive: data['isActive'] ?? true,
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
          permissions: data['permissions']?.cast<String>() ?? [],
        );
      }).toList();
    } catch (e) {
      _logger.error('Error getting all users', e);
      return [];
    }
  }

  // Update user role
  Future<bool> updateUserRole(String userId, String newRole) async {
    try {
      // Check if current user can modify roles
      if (!await _hasPermission('manage_roles')) {
        return false;
      }

      // Validate role
      if (!_roleHierarchy.containsKey(newRole)) {
        return false;
      }

      // Update user role
      await _firestore.collection('users').doc(userId).update({
        'role': newRole,
        'adminLevel': _getAdminLevelFromRole(newRole).index,
        'permissions': _getDefaultPermissions(newRole),
        'roleUpdatedAt': FieldValue.serverTimestamp(),
        'roleUpdatedBy': _auth.currentUser?.uid,
      });

      // Log admin action
      await _logAdminAction(
        action: 'role_updated',
        targetUserId: userId,
        details: {'newRole': newRole},
      );

      return true;
    } catch (e) {
      _logger.error('Error updating user role', e);
      return false;
    }
  }

  // Send email notification for new signups
  Future<void> sendNewSignupNotification(
      String userEmail, String userName) async {
    try {
      // This would integrate with your email service (SendGrid, etc.)
      // For now, we'll log it and store in Firestore

      await _firestore.collection('admin_notifications').add({
        'type': 'new_signup',
        'userEmail': userEmail,
        'userName': userName,
        'notificationEmails':
            await AdminEmailSettingsService.instance.getRecipients(),
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'priority': 'normal',
      });

      // Trigger Cloud Function for email sending
      await FirebaseFunctions.instance
          .httpsCallable('sendNewSignupEmail')
          .call({
        'userEmail': userEmail,
        'userName': userName,
        'recipients': await AdminEmailSettingsService.instance.getRecipients(),
      });
      _logger.info(
          'New signup notification triggered for: $userName ($userEmail)');
    } catch (e) {
      _logger.error('Error sending signup notification', e);
    }
  }

  // Get admin dashboard statistics
  Future<AdminDashboardStats> getDashboardStats() async {
    try {
      // Get user counts
      final totalUsersSnapshot = await _firestore.collection('users').get();
      final pendingRequests = await getPendingApprovals();
      final activeUsersSnapshot = await _firestore
          .collection('users')
          .where('isActive', isEqualTo: true)
          .get();

      // Get recent activity from local database
      final recentActivity =
          await _dbHelper.getRecentAdminActivities(limit: 10);

      return AdminDashboardStats(
        totalUsers: totalUsersSnapshot.docs.length,
        pendingApprovals: pendingRequests.length,
        activeUsers: activeUsersSnapshot.docs.length,
        recentSignups: await _getRecentSignupsCount(),
        recentActivity: recentActivity,
      );
    } catch (e) {
      _logger.error('Error getting dashboard stats', e);
      return const AdminDashboardStats(
        totalUsers: 0,
        pendingApprovals: 0,
        activeUsers: 0,
        recentSignups: 0,
        recentActivity: [],
      );
    }
  }

  // Private helper methods

  bool _isAdminRole(String? role) {
    if (role == null) return false;
    final level = _roleHierarchy[role] ?? 0;
    return level >= 1; // moderator and above
  }

  AdminLevel _getAdminLevelFromRole(String role) {
    switch (role) {
      case 'super_admin':
        return AdminLevel.superAdmin;
      case 'admin':
        return AdminLevel.admin;
      case 'moderator':
        return AdminLevel.moderator;
      default:
        return AdminLevel.none;
    }
  }

  List<String> _getDefaultPermissions(String role) {
    switch (role) {
      case 'super_admin':
        return [
          'approve_users',
          'manage_roles',
          'manage_content',
          'view_analytics',
          'manage_admins',
          'system_settings',
        ];
      case 'admin':
        return [
          'approve_users',
          'manage_content',
          'view_analytics',
        ];
      case 'moderator':
        return [
          'manage_content',
        ];
      default:
        return [];
    }
  }

  Future<bool> _hasPermission(String permission) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final permissions = userData['permissions']?.cast<String>() ?? <String>[];

      return permissions.contains(permission);
    } catch (e) {
      return false;
    }
  }

  Future<void> _logAdminAction({
    required String action,
    String? targetUserId,
    Map<String, dynamic>? details,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final activity = AdminActivity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        action: action,
        adminId: currentUser.uid,
        targetUserId: targetUserId,
        timestamp: DateTime.now(),
        details: details,
      );

      // Save to local database
      await _dbHelper.insertAdminActivity(activity);

      // Save to Firebase
      await _firestore.collection('admin_logs').add({
        'action': action,
        'adminId': currentUser.uid,
        'targetUserId': targetUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'details': details,
      });
    } catch (e) {
      _logger.error('Error logging admin action', e);
    }
  }

  Future<void> _sendUserApprovalNotification(String userId,
      {required bool approved, String? reason}) async {
    try {
      // This would integrate with your notification service
      // For now, we'll store in Firestore

      await _firestore.collection('user_notifications').add({
        'userId': userId,
        'type': approved ? 'approval_granted' : 'approval_denied',
        'title': approved ? 'Account Approved' : 'Account Not Approved',
        'message': approved
            ? 'Your account has been approved. You can now access all features.'
            : 'Your account registration was not approved. ${reason ?? ''}',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      _logger.error('Error sending approval notification', e);
    }
  }

  Future<int> _getRecentSignupsCount() async {
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final snapshot = await _firestore
          .collection('users')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }
}
