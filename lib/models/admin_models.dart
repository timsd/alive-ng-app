import 'package:json_annotation/json_annotation.dart';

part 'admin_models.g.dart';

// Admin levels enum
enum AdminLevel {
  none,
  moderator,
  admin,
  superAdmin,
}

@JsonSerializable()
class AdminUser {
  final String userId;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final String role;
  final bool isApproved;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final List<String> permissions;

  const AdminUser({
    required this.userId,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    required this.role,
    required this.isApproved,
    required this.isActive,
    required this.createdAt,
    this.lastLoginAt,
    required this.permissions,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) => _$AdminUserFromJson(json);
  Map<String, dynamic> toJson() => _$AdminUserToJson(this);
}

@JsonSerializable()
class UserApprovalRequest {
  final String userId;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final DateTime createdAt;
  final Map<String, dynamic>? additionalInfo;

  const UserApprovalRequest({
    required this.userId,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    required this.createdAt,
    this.additionalInfo,
  });

  factory UserApprovalRequest.fromJson(Map<String, dynamic> json) => _$UserApprovalRequestFromJson(json);
  Map<String, dynamic> toJson() => _$UserApprovalRequestToJson(this);
}

@JsonSerializable()
class AdminSignupResult {
  final bool success;
  final String message;
  final String? userId;
  final Map<String, dynamic>? errors;

  const AdminSignupResult({
    required this.success,
    required this.message,
    this.userId,
    this.errors,
  });

  factory AdminSignupResult.fromJson(Map<String, dynamic> json) => _$AdminSignupResultFromJson(json);
  Map<String, dynamic> toJson() => _$AdminSignupResultToJson(this);
}

@JsonSerializable()
class AdminActivity {
  final String id;
  final String action;
  final String adminId;
  final String? targetUserId;
  final DateTime timestamp;
  final Map<String, dynamic>? details;

  const AdminActivity({
    required this.id,
    required this.action,
    required this.adminId,
    this.targetUserId,
    required this.timestamp,
    this.details,
  });

  factory AdminActivity.fromJson(Map<String, dynamic> json) => _$AdminActivityFromJson(json);
  Map<String, dynamic> toJson() => _$AdminActivityToJson(this);
}

@JsonSerializable()
class AdminDashboardStats {
  final int totalUsers;
  final int pendingApprovals;
  final int activeUsers;
  final int recentSignups;
  final List<AdminActivity> recentActivity;

  const AdminDashboardStats({
    required this.totalUsers,
    required this.pendingApprovals,
    required this.activeUsers,
    required this.recentSignups,
    required this.recentActivity,
  });

  factory AdminDashboardStats.fromJson(Map<String, dynamic> json) => _$AdminDashboardStatsFromJson(json);
  Map<String, dynamic> toJson() => _$AdminDashboardStatsToJson(this);
}

@JsonSerializable()
class AdminPermission {
  final String id;
  final String name;
  final String description;
  final String category;
  final bool isActive;

  const AdminPermission({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.isActive,
  });

  factory AdminPermission.fromJson(Map<String, dynamic> json) => _$AdminPermissionFromJson(json);
  Map<String, dynamic> toJson() => _$AdminPermissionToJson(this);
}

@JsonSerializable()
class AdminRole {
  final String id;
  final String name;
  final String description;
  final int level;
  final List<String> permissions;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AdminRole({
    required this.id,
    required this.name,
    required this.description,
    required this.level,
    required this.permissions,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdminRole.fromJson(Map<String, dynamic> json) => _$AdminRoleFromJson(json);
  Map<String, dynamic> toJson() => _$AdminRoleToJson(this);
}

@JsonSerializable()
class AdminNotification {
  final String id;
  final String type;
  final String title;
  final String message;
  final String? targetUserId;
  final String? adminId;
  final DateTime createdAt;
  final bool isRead;
  final String priority; // 'low', 'normal', 'high', 'urgent'
  final Map<String, dynamic>? metadata;

  const AdminNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.targetUserId,
    this.adminId,
    required this.createdAt,
    required this.isRead,
    required this.priority,
    this.metadata,
  });

  factory AdminNotification.fromJson(Map<String, dynamic> json) => _$AdminNotificationFromJson(json);
  Map<String, dynamic> toJson() => _$AdminNotificationToJson(this);
}

@JsonSerializable()
class SystemSettings {
  final String id;
  final String key;
  final dynamic value;
  final String type; // 'string', 'number', 'boolean', 'json'
  final String description;
  final String category;
  final bool isPublic;
  final DateTime updatedAt;
  final String? updatedBy;

  const SystemSettings({
    required this.id,
    required this.key,
    required this.value,
    required this.type,
    required this.description,
    required this.category,
    required this.isPublic,
    required this.updatedAt,
    this.updatedBy,
  });

  factory SystemSettings.fromJson(Map<String, dynamic> json) => _$SystemSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$SystemSettingsToJson(this);
}

@JsonSerializable()
class UserSession {
  final String id;
  final String userId;
  final String deviceInfo;
  final String ipAddress;
  final DateTime loginAt;
  final DateTime? logoutAt;
  final bool isActive;
  final String? location;

  const UserSession({
    required this.id,
    required this.userId,
    required this.deviceInfo,
    required this.ipAddress,
    required this.loginAt,
    this.logoutAt,
    required this.isActive,
    this.location,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) => _$UserSessionFromJson(json);
  Map<String, dynamic> toJson() => _$UserSessionToJson(this);
}

@JsonSerializable()
class ContentModerationRequest {
  final String id;
  final String contentType; // 'post', 'comment', 'message', etc.
  final String contentId;
  final String reportedBy;
  final String reason;
  final String description;
  final DateTime reportedAt;
  final String status; // 'pending', 'approved', 'rejected', 'removed'
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNotes;

  const ContentModerationRequest({
    required this.id,
    required this.contentType,
    required this.contentId,
    required this.reportedBy,
    required this.reason,
    required this.description,
    required this.reportedAt,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNotes,
  });

  factory ContentModerationRequest.fromJson(Map<String, dynamic> json) => _$ContentModerationRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ContentModerationRequestToJson(this);
}

@JsonSerializable()
class AdminAuditLog {
  final String id;
  final String adminId;
  final String action;
  final String resource;
  final String? resourceId;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final DateTime timestamp;
  final String ipAddress;
  final String userAgent;

  const AdminAuditLog({
    required this.id,
    required this.adminId,
    required this.action,
    required this.resource,
    this.resourceId,
    this.oldValues,
    this.newValues,
    required this.timestamp,
    required this.ipAddress,
    required this.userAgent,
  });

  factory AdminAuditLog.fromJson(Map<String, dynamic> json) => _$AdminAuditLogFromJson(json);
  Map<String, dynamic> toJson() => _$AdminAuditLogToJson(this);
}