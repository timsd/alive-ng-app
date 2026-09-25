import '../models/app_models.dart';
import '../utils/logger.dart';
import 'auth_service.dart';
import '../config/development_config.dart';
import '../config/appwrite_backend_config.dart';
import '../constants/chapters.dart';

/// Service for managing role-based access control throughout the app
class RoleAccessService {
  static final RoleAccessService _instance = RoleAccessService._internal();
  factory RoleAccessService() => _instance;
  RoleAccessService._internal();

  static RoleAccessService get instance => _instance;

  final Logger _logger = Logger('RoleAccessService');
  final AuthService _authService = AuthService.instance;

  UserProfile? _cachedUserProfile;
  DateTime? _cacheTimestamp;

  /// User roles in hierarchical order (lowest to highest privilege)
  ///
  /// `healthContributor` sits directly above `member`: it is the lowest
  /// elevated role and exists purely to unlock the Health+ content editor
  /// (recipes + remedies). Being second-lowest means it cannot reach any other
  /// gated feature, including the admin dashboard.
  static const List<String> _roleHierarchy = [
    'guest',
    'member',
    'healthcontributor',
    'coordinator',
    'leader',
    'director',
    'bod',
    'trustee',
    'admin'
  ];

  /// Cache duration - standard 5 minutes for balanced performance
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Get current user's role
  String? getCurrentUserRole() {
    final user = _authService.currentUser;
    if (user == null) return null;

    if (AppwriteBackendConfig.isSuperAdminEmail(user.email)) {
      return 'admin';
    }

    // Get role from cached user profile or fetch from database
    final profile = _getCachedUserProfile();
    if (profile != null &&
        AppwriteBackendConfig.isSuperAdminEmail(profile.email)) {
      return 'admin';
    }

    if (profile != null) {
      final normalized = _normalizeRole(profile.role);
      // If a staff or coordinator role is pending approval, user operates
      // with standard member permissions until an admin approves the role.
      if (!profile.isApproved || profile.approvalStatus != 'approved') {
        const elevatedRoles = {
          'coordinator',
          'leader',
          'director',
          'bod',
          'trustee',
          'admin'
        };
        if (elevatedRoles.contains(normalized)) {
          return 'member';
        }
      }
      return normalized;
    }

    return null;
  }

  /// Whether the current user is registered as a guest (non-member)
  bool isGuest() {
    final role = getCurrentUserRole();
    return role == 'guest';
  }

  /// Whether the current user is a full ALIVE member or higher
  bool isMemberOrHigher() {
    return hasRole('member');
  }

  /// Get cached user profile or fetch from database
  UserProfile? _getCachedUserProfile() {
    final now = DateTime.now();

    // Return cached profile if it's still valid
    if (_cachedUserProfile != null &&
        _cacheTimestamp != null &&
        now.difference(_cacheTimestamp!) < _cacheDuration) {
      return _cachedUserProfile;
    }

    // Fetch fresh profile asynchronously and cache it
    _refreshUserProfileCache();

    // Return cached profile if available, otherwise null
    return _cachedUserProfile;
  }

  /// Update cached profile directly (e.g. from Riverpod provider)
  void updateCachedUserProfile(UserProfile profile) {
    _cachedUserProfile = profile;
    _cacheTimestamp = DateTime.now();
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
    // Check for development mode bypass
    if (DevelopmentConfig.shouldBypassRoleGuards) {
      DevelopmentConfig.logDevelopmentWarning('Role check for $requiredRole');
      return true;
    }

    final currentRole = getCurrentUserRole();
    if (currentRole == null) return false;

    return hasRolePermission(currentRole, requiredRole);
  }

  /// Check if a role has permission for required role
  bool hasRolePermission(String userRole, String requiredRole) {
    final userIndex = _roleHierarchy.indexOf(_normalizeRole(userRole) ?? '');
    final requiredIndex =
        _roleHierarchy.indexOf(_normalizeRole(requiredRole) ?? '');

    if (userIndex == -1 || requiredIndex == -1) return false;

    return userIndex >= requiredIndex;
  }

  String? _normalizeRole(String? role) {
    if (role == null || role.trim().isEmpty) return null;
    final normalized = role.trim().toLowerCase();
    return normalized == 'user' ? 'member' : normalized;
  }

  /// Check if user can access admin features
  bool canAccessAdmin() {
    if (DevelopmentConfig.shouldBypassRoleGuards) {
      _logger.warning('DEVELOPMENT MODE: Bypassing admin access check');
      return true;
    }

    return hasRole('admin');
  }

  /// Check if the user may add/edit Health+ content (recipes and remedies).
  ///
  /// Deliberately WIDER than [canAccessAdmin] but NARROWER than
  /// [canAccessLeadership]: a `healthContributor` gets the Health+ editor and
  /// nothing else. Admins and the leadership roles keep their existing access.
  bool canManageHealthContent() {
    if (DevelopmentConfig.shouldBypassRoleGuards) return true;

    final role = _normalizeRole(getCurrentUserRole());
    if (role == null) return false;
    return ChapterConstants.healthContentRoles.contains(role);
  }

  /// Check if user can create chat channels (strictly admin-only)
  bool canCreateChannels() {
    return canAccessAdmin();
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
  /// Admin bypass: admins can manage everything in the app.
  /// Every granular check below keeps working for non-admins;
  /// admins return true before those checks run.
  bool canManageUsers() {
    if (hasRole('admin')) return true;
    return hasRole('leader');
  }

  /// Check if user can manage roles
  bool canManageRoles() {
    return hasRole('admin');
  }

  /// Check if user can access board documents
  bool canAccessBoardDocuments() {
    if (hasRole('admin')) return true;
    final currentRole = getCurrentUserRole();
    return currentRole == 'leader' ||
        currentRole == 'director' ||
        currentRole == 'bod' ||
        currentRole == 'trustee' ||
        _isUserBoardMember();
  }

  /// Check if user can access financial reports
  bool canAccessFinancialReports() {
    if (hasRole('admin')) return true;
    return hasRole('leader');
  }

  /// Check if user can manage donations
  bool canManageDonations() {
    if (hasRole('admin')) return true;
    return hasRole('coordinator');
  }

  /// Check if user can access user archives
  bool canAccessUserArchives() {
    if (hasRole('admin')) return true;
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
    return profile.role == 'leader' ||
        profile.role == 'director' ||
        profile.role == 'bod' ||
        profile.role == 'trustee' ||
        profile.role == 'admin';
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

  /// Check if user can create content (missions, events, announcements)
  /// Admin bypass: admins can add/edit everywhere.
  /// Keep the granular checks for non-admins; admins return true early.
  bool canPostHealth() {
    if (hasRole('admin')) return true;
    final currentRole = getCurrentUserRole();
    if (currentRole == null) return false;
    const allowed = [
      'admin',
      'super_admin',
      'content_manager',
      'leader',
      'director',
      'president',
      'bod',
      'trustee',
      'health_editor',
    ];
    return allowed.contains(currentRole);
  }

  bool canCreateContent() {
    if (hasRole('admin')) return true;
    final currentRole = getCurrentUserRole();
    if (currentRole == null) return false;

    // Only executives can create content: admin, content_manager, super_admin, directors, president
    const executiveRoles = [
      'admin',
      'super_admin',
      'content_manager',
      'director',
      'president'
    ];

    return executiveRoles.contains(currentRole);
  }

  /// Check if user can create missions
  bool canCreateMissions() {
    return canCreateContent();
  }

  /// Check if user can create events
  bool canCreateEvents() {
    return canCreateContent();
  }

  /// Check if user can create announcements
  bool canCreateAnnouncements() {
    return canCreateContent();
  }

  /// Check if user can access role-gated features
  bool canAccessRoleGatedFeatures() {
    final currentRole = getCurrentUserRole();
    // Admins and staff are always considered approved — they manage approvals
    // for everyone else, so they must never be blocked by their own gate.
    if (currentRole == 'admin' || currentRole == 'staff') return true;
    // For all other roles the Appwrite profile approval flag governs access.
    final profile = _getCachedUserProfile();
    return (profile?.isApproved ?? false) && !isUserArchived();
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

    if (canCreateContent()) {
      routes.add('/content-management');
    }

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
        '/user-archive',
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
    final userId = _authService.currentUser?.uid;
    final profile = _getCachedUserProfile();

    _logger.info(
        'Access attempt: User($userId) Role($currentRole) Resource($resource) Granted($granted)');

    _storeAccessLog(userId, currentRole, resource, granted, profile?.fullName);
  }

  /// Store access log in database
  Future<void> _storeAccessLog(String? userId, String? role, String resource,
      bool granted, String? userName) async {
    if (userId == null) return;

    try {
      _logger.info(
        'Access log pending Appwrite audit collection: '
        'user=$userId name=${userName ?? 'Unknown'} role=${role ?? 'unknown'} '
        'resource=$resource granted=$granted',
      );
    } catch (e) {
      _logger.error('Failed to store access log: $e');
    }
  }

  /// Clear cached user profile (call when user profile is updated)
  void clearCache() {
    _cachedUserProfile = null;
    _cacheTimestamp = null;
  }

  /// Force refresh the user profile cache
  /// Call this when you need immediate fresh data (e.g., after admin approval)
  Future<UserProfile?> forceRefreshCache() async {
    clearCache();
    _cachedUserProfile = await _authService.getCurrentUserProfile();
    if (_cachedUserProfile != null) {
      _cacheTimestamp = DateTime.now();
    }
    return _cachedUserProfile;
  }

  /// Synchronously read the cached approval status (`pending`/`approved`/`rejected`).
  /// Returns null when no profile is cached yet — callers should treat null as
  /// "unknown, still loading" rather than as pending.
  String? getCachedApprovalStatus() => _cachedUserProfile?.approvalStatus;

  /// Synchronously check the cached approval flag. Null-safe: returns false
  /// when no profile is cached yet.
  bool isCachedUserApproved() => _cachedUserProfile?.isApproved ?? false;

  /// Async: fetch the fresh profile then return its approval status.
  Future<String?> getUserApprovalStatus() async {
    final profile = await getCurrentUserProfile();
    return profile?.approvalStatus;
  }

  /// Async: fetch the fresh profile then return whether the user is approved.
  Future<bool> isUserApproved() async {
    final profile = await getCurrentUserProfile();
    return profile?.isApproved ?? false;
  }

  /// Validate access and throw exception if denied
  void requireRole(String requiredRole, {String? resource}) {
    if (!hasRole(requiredRole)) {
      final currentRole = getCurrentUserRole();
      logAccessAttempt(resource ?? 'unknown', false);
      throw UnauthorizedAccessException(
          'Access denied. Required role: $requiredRole, Current role: $currentRole');
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
