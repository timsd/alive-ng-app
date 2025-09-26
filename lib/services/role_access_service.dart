import '../models/app_models.dart';
import '../utils/logger.dart';
import 'supabase_service.dart';
import 'auth_service.dart';

/// Service for managing role-based access control throughout the app
class RoleAccessService {
  static final RoleAccessService _instance = RoleAccessService._internal();
  factory RoleAccessService() => _instance;
  RoleAccessService._internal();

  static RoleAccessService get instance => _instance;

  final Logger _logger = Logger('RoleAccessService');
  final SupabaseService _supabaseService = SupabaseService.instance;
  final AuthService _authService = AuthService.instance;
  
  UserProfile? _cachedUserProfile;
  DateTime? _cacheTimestamp;

  /// User roles in hierarchical order (lowest to highest privilege)
  static const List<String> _roleHierarchy = [
    'member',
    'coordinator', 
    'leader',
    'admin'
  ];

  /// Get current user's role
  String? getCurrentUserRole() {
    final user = _supabaseService.currentUser;
    if (user == null) return null;
    
    // Get role from cached user profile or fetch from database
    final profile = _getCachedUserProfile();
    return profile?.role ?? 'member';
  }
  
  /// Get cached user profile or fetch from database
  UserProfile? _getCachedUserProfile() {
    final now = DateTime.now();
    
    // Return cached profile if it's less than 5 minutes old
    if (_cachedUserProfile != null && 
        _cacheTimestamp != null && 
        now.difference(_cacheTimestamp!).inMinutes < 5) {
      return _cachedUserProfile;
    }
    
    // Fetch fresh profile asynchronously and cache it
    _refreshUserProfileCache();
    
    // Return cached profile if available, otherwise null
    return _cachedUserProfile;
  }
  
  /// Refresh user profile cache
  Future<void> _refreshUserProfileCache() async {
    try {
      final profile = await _authService.getCurrentUserProfile();
      if (profile != null) {
        _cachedUserProfile = profile;
        _cacheTimestamp = DateTime.now();
      }
    } catch (e) {
      _logger.error('Failed to refresh user profile cache: $e');
    }
  }
  
  /// Get current user profile (async version)
  Future<UserProfile?> getCurrentUserProfile() async {
    try {
      final profile = await _authService.getCurrentUserProfile();
      if (profile != null) {
        _cachedUserProfile = profile;
        _cacheTimestamp = DateTime.now();
      }
      return profile;
    } catch (e) {
      _logger.error('Failed to get current user profile: $e');
      return null;
    }
  }

  /// Check if current user has required role or higher
  bool hasRole(String requiredRole) {
    final currentRole = getCurrentUserRole();
    if (currentRole == null) return false;
    
    return hasRolePermission(currentRole, requiredRole);
  }

  /// Check if a role has permission for required role
  bool hasRolePermission(String userRole, String requiredRole) {
    final userIndex = _roleHierarchy.indexOf(userRole);
    final requiredIndex = _roleHierarchy.indexOf(requiredRole);
    
    if (userIndex == -1 || requiredIndex == -1) return false;
    
    return userIndex >= requiredIndex;
  }

  /// Check if user can access admin features
  bool canAccessAdmin() {
    return hasRole('admin');
  }

  /// Check if user can access leadership features
  bool canAccessLeadership() {
    return hasRole('leader');
  }

  /// Check if user can access coordinator features
  bool canAccessCoordinator() {
    return hasRole('coordinator');
  }

  /// Check if user can manage other users
  bool canManageUsers() {
    return hasRole('leader');
  }

  /// Check if user can manage roles
  bool canManageRoles() {
    return hasRole('admin');
  }

  /// Check if user can access board documents
  bool canAccessBoardDocuments() {
    final currentRole = getCurrentUserRole();
    return currentRole == 'admin' || 
           currentRole == 'leader' || 
           _isUserBoardMember();
  }

  /// Check if user can access financial reports
  bool canAccessFinancialReports() {
    return hasRole('leader');
  }

  /// Check if user can manage donations
  bool canManageDonations() {
    return hasRole('coordinator');
  }

  /// Check if user can access user archives
  bool canAccessUserArchives() {
    return hasRole('leader');
  }

  /// Check if user can modify another user's role
  bool canModifyUserRole(String targetUserRole) {
    final currentRole = getCurrentUserRole();
    if (currentRole == null) return false;

    // Admins can modify anyone except other admins (unless same person)
    if (currentRole == 'admin') {
      return true;
    }

    // Leaders can modify coordinators and members, but not other leaders or admins
    if (currentRole == 'leader') {
      return targetUserRole == 'coordinator' || targetUserRole == 'member';
    }

    // Coordinators and members cannot modify roles
    return false;
  }

  /// Check if user can assign a specific role
  bool canAssignRole(String roleToAssign) {
    final currentRole = getCurrentUserRole();
    if (currentRole == null) return false;

    // Admins can assign any role
    if (currentRole == 'admin') {
      return true;
    }

    // Leaders can assign coordinator and member roles
    if (currentRole == 'leader') {
      return roleToAssign == 'coordinator' || roleToAssign == 'member';
    }

    // Others cannot assign roles
    return false;
  }

  /// Check if user is a board member (BOD/Trustee)
  bool _isUserBoardMember() {
    final profile = _getCachedUserProfile();
    if (profile == null) return false;
    
    // Check if user has leadership role or admin role (board members)
    return profile.role == 'leader' || profile.role == 'admin';
  }
  
  /// Check if user is archived
  bool isUserArchived() {
    final profile = _getCachedUserProfile();
    return profile?.isArchived ?? false;
  }
  
  /// Check if user is a new convert
  bool isNewConvert() {
    final profile = _getCachedUserProfile();
    return profile?.isNewConvert ?? false;
  }

  /// Check if user is approved by admin
  bool isUserApproved() {
    final profile = _getCachedUserProfile();
    return profile?.isApproved ?? false;
  }

  /// Get user's approval status
  String getUserApprovalStatus() {
    final profile = _getCachedUserProfile();
    return profile?.approvalStatus ?? 'pending';
  }

  /// Check if user can access role-gated features
  bool canAccessRoleGatedFeatures() {
    // User must be approved to access role-gated features
    return isUserApproved() && !isUserArchived();
  }
  
  /// Get user's chapter ID
  String? getUserChapterId() {
    final profile = _getCachedUserProfile();
    return profile?.chapterId;
  }

  /// Get accessible routes for current user
  List<String> getAccessibleRoutes() {
    final currentRole = getCurrentUserRole();
    if (currentRole == null) return [];

    // Check if user is approved for role-gated features
    if (!canAccessRoleGatedFeatures()) {
      // Return only basic routes for unapproved users
      return [
        '/home',
        '/profile',
        '/about',
      ];
    }

    final routes = <String>[
      '/home',
      '/study',
      '/daily',
      '/prayer',
      '/profile',
      '/health',
      '/missions',
      '/bible-game',
      '/chat',
      '/events',
      '/testimonies',
      '/resources',
    ];

    // Add role-specific routes
    if (hasRole('coordinator')) {
      routes.addAll([
        '/donations',
        '/reports',
      ]);
    }

    if (hasRole('leader')) {
      routes.addAll([
        '/user-management',
        '/financial-reports',
        '/board-documents',
        '/user-archives',
      ]);
    }

    if (hasRole('admin')) {
      routes.addAll([
        '/admin',
        '/role-management',
        '/system-settings',
        '/admin-approval',
      ]);
    }

    return routes;
  }

  /// Check if user can access a specific route
  bool canAccessRoute(String route) {
    return getAccessibleRoutes().contains(route);
  }

  /// Get user's permission level for content access
  String getContentAccessLevel() {
    final currentRole = getCurrentUserRole();
    
    switch (currentRole) {
      case 'admin':
        return 'admin_only';
      case 'leader':
        return 'trustees_only';
      case 'coordinator':
        return 'board_only';
      default:
        return 'public';
    }
  }

  /// Log access attempt for audit purposes
  void logAccessAttempt(String resource, bool granted) {
    final currentRole = getCurrentUserRole();
    final userId = _supabaseService.currentUser?.id;
    final profile = _getCachedUserProfile();
    
    _logger.info(
      'Access attempt: User($userId) Role($currentRole) Resource($resource) Granted($granted)'
    );
    
    // Store access logs in database for audit trail
    _storeAccessLog(userId, currentRole, resource, granted, profile?.fullName);
  }
  
  /// Store access log in database
  Future<void> _storeAccessLog(String? userId, String? role, String resource, 
      bool granted, String? userName) async {
    if (userId == null) return;
    
    try {
      await _supabaseService.client.from('access_logs').insert({
        'user_id': userId,
        'user_name': userName ?? 'Unknown',
        'user_role': role ?? 'unknown',
        'resource': resource,
        'access_granted': granted,
        'timestamp': DateTime.now().toIso8601String(),
        'ip_address': 'mobile_app', // Could be enhanced with actual IP
      });
    } catch (e) {
      _logger.error('Failed to store access log: $e');
    }
  }
  
  /// Clear cached user profile (call when user profile is updated)
  void clearCache() {
    _cachedUserProfile = null;
    _cacheTimestamp = null;
  }

  /// Validate access and throw exception if denied
  void requireRole(String requiredRole, {String? resource}) {
    if (!hasRole(requiredRole)) {
      final currentRole = getCurrentUserRole();
      logAccessAttempt(resource ?? 'unknown', false);
      throw UnauthorizedAccessException(
        'Access denied. Required role: $requiredRole, Current role: $currentRole'
      );
    }
    
    logAccessAttempt(resource ?? 'unknown', true);
  }
}

/// Exception thrown when user lacks required permissions
class UnauthorizedAccessException implements Exception {
  final String message;
  
  const UnauthorizedAccessException(this.message);
  
  @override
  String toString() => 'UnauthorizedAccessException: $message';
}



