// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdminUser _$AdminUserFromJson(Map<String, dynamic> json) => AdminUser(
      userId: json['userId'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      role: json['role'] as String,
      isApproved: json['isApproved'] as bool,
      isActive: json['isActive'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLoginAt: json['lastLoginAt'] == null
          ? null
          : DateTime.parse(json['lastLoginAt'] as String),
      permissions: (json['permissions'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$AdminUserToJson(AdminUser instance) => <String, dynamic>{
      'userId': instance.userId,
      'email': instance.email,
      'fullName': instance.fullName,
      'phoneNumber': instance.phoneNumber,
      'role': instance.role,
      'isApproved': instance.isApproved,
      'isActive': instance.isActive,
      'createdAt': instance.createdAt.toIso8601String(),
      'lastLoginAt': instance.lastLoginAt?.toIso8601String(),
      'permissions': instance.permissions,
    };

UserApprovalRequest _$UserApprovalRequestFromJson(Map<String, dynamic> json) =>
    UserApprovalRequest(
      userId: json['userId'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      additionalInfo: json['additionalInfo'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$UserApprovalRequestToJson(
        UserApprovalRequest instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'email': instance.email,
      'fullName': instance.fullName,
      'phoneNumber': instance.phoneNumber,
      'createdAt': instance.createdAt.toIso8601String(),
      'additionalInfo': instance.additionalInfo,
    };

AdminSignupResult _$AdminSignupResultFromJson(Map<String, dynamic> json) =>
    AdminSignupResult(
      success: json['success'] as bool,
      message: json['message'] as String,
      userId: json['userId'] as String?,
      errors: json['errors'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$AdminSignupResultToJson(AdminSignupResult instance) =>
    <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
      'userId': instance.userId,
      'errors': instance.errors,
    };

AdminActivity _$AdminActivityFromJson(Map<String, dynamic> json) =>
    AdminActivity(
      id: json['id'] as String,
      action: json['action'] as String,
      adminId: json['adminId'] as String,
      targetUserId: json['targetUserId'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      details: json['details'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$AdminActivityToJson(AdminActivity instance) =>
    <String, dynamic>{
      'id': instance.id,
      'action': instance.action,
      'adminId': instance.adminId,
      'targetUserId': instance.targetUserId,
      'timestamp': instance.timestamp.toIso8601String(),
      'details': instance.details,
    };

AdminDashboardStats _$AdminDashboardStatsFromJson(Map<String, dynamic> json) =>
    AdminDashboardStats(
      totalUsers: (json['totalUsers'] as num).toInt(),
      pendingApprovals: (json['pendingApprovals'] as num).toInt(),
      activeUsers: (json['activeUsers'] as num).toInt(),
      recentSignups: (json['recentSignups'] as num).toInt(),
      recentActivity: (json['recentActivity'] as List<dynamic>)
          .map((e) => AdminActivity.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$AdminDashboardStatsToJson(
        AdminDashboardStats instance) =>
    <String, dynamic>{
      'totalUsers': instance.totalUsers,
      'pendingApprovals': instance.pendingApprovals,
      'activeUsers': instance.activeUsers,
      'recentSignups': instance.recentSignups,
      'recentActivity': instance.recentActivity,
    };

AdminPermission _$AdminPermissionFromJson(Map<String, dynamic> json) =>
    AdminPermission(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      isActive: json['isActive'] as bool,
    );

Map<String, dynamic> _$AdminPermissionToJson(AdminPermission instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'category': instance.category,
      'isActive': instance.isActive,
    };

AdminRole _$AdminRoleFromJson(Map<String, dynamic> json) => AdminRole(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      level: (json['level'] as num).toInt(),
      permissions: (json['permissions'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      isActive: json['isActive'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$AdminRoleToJson(AdminRole instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'level': instance.level,
      'permissions': instance.permissions,
      'isActive': instance.isActive,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

AdminNotification _$AdminNotificationFromJson(Map<String, dynamic> json) =>
    AdminNotification(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      targetUserId: json['targetUserId'] as String?,
      adminId: json['adminId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: json['isRead'] as bool,
      priority: json['priority'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$AdminNotificationToJson(AdminNotification instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'title': instance.title,
      'message': instance.message,
      'targetUserId': instance.targetUserId,
      'adminId': instance.adminId,
      'createdAt': instance.createdAt.toIso8601String(),
      'isRead': instance.isRead,
      'priority': instance.priority,
      'metadata': instance.metadata,
    };

SystemSettings _$SystemSettingsFromJson(Map<String, dynamic> json) =>
    SystemSettings(
      id: json['id'] as String,
      key: json['key'] as String,
      value: json['value'],
      type: json['type'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      isPublic: json['isPublic'] as bool,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      updatedBy: json['updatedBy'] as String?,
    );

Map<String, dynamic> _$SystemSettingsToJson(SystemSettings instance) =>
    <String, dynamic>{
      'id': instance.id,
      'key': instance.key,
      'value': instance.value,
      'type': instance.type,
      'description': instance.description,
      'category': instance.category,
      'isPublic': instance.isPublic,
      'updatedAt': instance.updatedAt.toIso8601String(),
      'updatedBy': instance.updatedBy,
    };

UserSession _$UserSessionFromJson(Map<String, dynamic> json) => UserSession(
      id: json['id'] as String,
      userId: json['userId'] as String,
      deviceInfo: json['deviceInfo'] as String,
      ipAddress: json['ipAddress'] as String,
      loginAt: DateTime.parse(json['loginAt'] as String),
      logoutAt: json['logoutAt'] == null
          ? null
          : DateTime.parse(json['logoutAt'] as String),
      isActive: json['isActive'] as bool,
      location: json['location'] as String?,
    );

Map<String, dynamic> _$UserSessionToJson(UserSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'deviceInfo': instance.deviceInfo,
      'ipAddress': instance.ipAddress,
      'loginAt': instance.loginAt.toIso8601String(),
      'logoutAt': instance.logoutAt?.toIso8601String(),
      'isActive': instance.isActive,
      'location': instance.location,
    };

ContentModerationRequest _$ContentModerationRequestFromJson(
        Map<String, dynamic> json) =>
    ContentModerationRequest(
      id: json['id'] as String,
      contentType: json['contentType'] as String,
      contentId: json['contentId'] as String,
      reportedBy: json['reportedBy'] as String,
      reason: json['reason'] as String,
      description: json['description'] as String,
      reportedAt: DateTime.parse(json['reportedAt'] as String),
      status: json['status'] as String,
      reviewedBy: json['reviewedBy'] as String?,
      reviewedAt: json['reviewedAt'] == null
          ? null
          : DateTime.parse(json['reviewedAt'] as String),
      reviewNotes: json['reviewNotes'] as String?,
    );

Map<String, dynamic> _$ContentModerationRequestToJson(
        ContentModerationRequest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'contentType': instance.contentType,
      'contentId': instance.contentId,
      'reportedBy': instance.reportedBy,
      'reason': instance.reason,
      'description': instance.description,
      'reportedAt': instance.reportedAt.toIso8601String(),
      'status': instance.status,
      'reviewedBy': instance.reviewedBy,
      'reviewedAt': instance.reviewedAt?.toIso8601String(),
      'reviewNotes': instance.reviewNotes,
    };

AdminAuditLog _$AdminAuditLogFromJson(Map<String, dynamic> json) =>
    AdminAuditLog(
      id: json['id'] as String,
      adminId: json['adminId'] as String,
      action: json['action'] as String,
      resource: json['resource'] as String,
      resourceId: json['resourceId'] as String?,
      oldValues: json['oldValues'] as Map<String, dynamic>?,
      newValues: json['newValues'] as Map<String, dynamic>?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      ipAddress: json['ipAddress'] as String,
      userAgent: json['userAgent'] as String,
    );

Map<String, dynamic> _$AdminAuditLogToJson(AdminAuditLog instance) =>
    <String, dynamic>{
      'id': instance.id,
      'adminId': instance.adminId,
      'action': instance.action,
      'resource': instance.resource,
      'resourceId': instance.resourceId,
      'oldValues': instance.oldValues,
      'newValues': instance.newValues,
      'timestamp': instance.timestamp.toIso8601String(),
      'ipAddress': instance.ipAddress,
      'userAgent': instance.userAgent,
    };
