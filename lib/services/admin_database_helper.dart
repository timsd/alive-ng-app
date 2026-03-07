import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/admin_models.dart';

class AdminDatabaseHelper {
  static final AdminDatabaseHelper _instance = AdminDatabaseHelper._internal();
  factory AdminDatabaseHelper() => _instance;
  AdminDatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'admin_database.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Admin users table
    await db.execute('''
      CREATE TABLE admin_users (
        user_id TEXT PRIMARY KEY,
        email TEXT NOT NULL UNIQUE,
        full_name TEXT NOT NULL,
        phone_number TEXT,
        role TEXT NOT NULL,
        is_approved INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        last_login_at INTEGER,
        permissions TEXT NOT NULL
      )
    ''');

    // User approval requests table
    await db.execute('''
      CREATE TABLE user_approval_requests (
        user_id TEXT PRIMARY KEY,
        email TEXT NOT NULL,
        full_name TEXT NOT NULL,
        phone_number TEXT,
        created_at INTEGER NOT NULL,
        additional_info TEXT
      )
    ''');

    // Admin activities table
    await db.execute('''
      CREATE TABLE admin_activities (
        id TEXT PRIMARY KEY,
        action TEXT NOT NULL,
        admin_id TEXT NOT NULL,
        target_user_id TEXT,
        timestamp INTEGER NOT NULL,
        details TEXT
      )
    ''');

    // Admin permissions table
    await db.execute('''
      CREATE TABLE admin_permissions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Admin roles table
    await db.execute('''
      CREATE TABLE admin_roles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        level INTEGER NOT NULL,
        permissions TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Admin notifications table
    await db.execute('''
      CREATE TABLE admin_notifications (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        target_user_id TEXT,
        admin_id TEXT,
        created_at INTEGER NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0,
        priority TEXT NOT NULL DEFAULT 'normal',
        metadata TEXT
      )
    ''');

    // System settings table
    await db.execute('''
      CREATE TABLE system_settings (
        id TEXT PRIMARY KEY,
        key TEXT NOT NULL UNIQUE,
        value TEXT NOT NULL,
        type TEXT NOT NULL,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        is_public INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL,
        updated_by TEXT
      )
    ''');

    // User sessions table
    await db.execute('''
      CREATE TABLE user_sessions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        device_info TEXT NOT NULL,
        ip_address TEXT NOT NULL,
        login_at INTEGER NOT NULL,
        logout_at INTEGER,
        is_active INTEGER NOT NULL DEFAULT 1,
        location TEXT
      )
    ''');

    // Content moderation requests table
    await db.execute('''
      CREATE TABLE content_moderation_requests (
        id TEXT PRIMARY KEY,
        content_type TEXT NOT NULL,
        content_id TEXT NOT NULL,
        reported_by TEXT NOT NULL,
        reason TEXT NOT NULL,
        description TEXT NOT NULL,
        reported_at INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        reviewed_by TEXT,
        reviewed_at INTEGER,
        review_notes TEXT
      )
    ''');

    // Admin audit logs table
    await db.execute('''
      CREATE TABLE admin_audit_logs (
        id TEXT PRIMARY KEY,
        admin_id TEXT NOT NULL,
        action TEXT NOT NULL,
        resource TEXT NOT NULL,
        resource_id TEXT,
        old_values TEXT,
        new_values TEXT,
        timestamp INTEGER NOT NULL,
        ip_address TEXT NOT NULL,
        user_agent TEXT NOT NULL
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_admin_users_email ON admin_users(email)');
    await db.execute('CREATE INDEX idx_admin_activities_admin_id ON admin_activities(admin_id)');
    await db.execute('CREATE INDEX idx_admin_activities_timestamp ON admin_activities(timestamp)');
    await db.execute('CREATE INDEX idx_admin_notifications_target_user_id ON admin_notifications(target_user_id)');
    await db.execute('CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id)');
    await db.execute('CREATE INDEX idx_content_moderation_status ON content_moderation_requests(status)');
    await db.execute('CREATE INDEX idx_audit_logs_admin_id ON admin_audit_logs(admin_id)');
    await db.execute('CREATE INDEX idx_audit_logs_timestamp ON admin_audit_logs(timestamp)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here
  }

  // Admin Users CRUD operations
  Future<void> insertAdminUser(AdminUser adminUser) async {
    final db = await database;
    await db.insert(
      'admin_users',
      {
        'user_id': adminUser.userId,
        'email': adminUser.email,
        'full_name': adminUser.fullName,
        'phone_number': adminUser.phoneNumber,
        'role': adminUser.role,
        'is_approved': adminUser.isApproved ? 1 : 0,
        'is_active': adminUser.isActive ? 1 : 0,
        'created_at': adminUser.createdAt.millisecondsSinceEpoch,
        'last_login_at': adminUser.lastLoginAt?.millisecondsSinceEpoch,
        'permissions': jsonEncode(adminUser.permissions),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<AdminUser?> getAdminUser(String userId) async {
    final db = await database;
    final maps = await db.query(
      'admin_users',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    return AdminUser(
      userId: map['user_id'] as String,
      email: map['email'] as String,
      fullName: map['full_name'] as String,
      phoneNumber: map['phone_number'] as String?,
      role: map['role'] as String,
      isApproved: (map['is_approved'] as int) == 1,
      isActive: (map['is_active'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      lastLoginAt: map['last_login_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_login_at'] as int)
          : null,
      permissions: List<String>.from(jsonDecode(map['permissions'] as String)),
    );
  }

  Future<List<AdminUser>> getAllAdminUsers() async {
    final db = await database;
    final maps = await db.query('admin_users', orderBy: 'created_at DESC');

    return maps.map((map) => AdminUser(
      userId: map['user_id'] as String,
      email: map['email'] as String,
      fullName: map['full_name'] as String,
      phoneNumber: map['phone_number'] as String?,
      role: map['role'] as String,
      isApproved: (map['is_approved'] as int) == 1,
      isActive: (map['is_active'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      lastLoginAt: map['last_login_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_login_at'] as int)
          : null,
      permissions: List<String>.from(jsonDecode(map['permissions'] as String)),
    )).toList();
  }

  Future<void> updateAdminUser(AdminUser adminUser) async {
    final db = await database;
    await db.update(
      'admin_users',
      {
        'email': adminUser.email,
        'full_name': adminUser.fullName,
        'phone_number': adminUser.phoneNumber,
        'role': adminUser.role,
        'is_approved': adminUser.isApproved ? 1 : 0,
        'is_active': adminUser.isActive ? 1 : 0,
        'last_login_at': adminUser.lastLoginAt?.millisecondsSinceEpoch,
        'permissions': jsonEncode(adminUser.permissions),
      },
      where: 'user_id = ?',
      whereArgs: [adminUser.userId],
    );
  }

  Future<void> deleteAdminUser(String userId) async {
    final db = await database;
    await db.delete(
      'admin_users',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // User Approval Requests CRUD operations
  Future<void> insertUserApprovalRequest(UserApprovalRequest request) async {
    final db = await database;
    await db.insert(
      'user_approval_requests',
      {
        'user_id': request.userId,
        'email': request.email,
        'full_name': request.fullName,
        'phone_number': request.phoneNumber,
        'created_at': request.createdAt.millisecondsSinceEpoch,
        'additional_info': request.additionalInfo != null
            ? jsonEncode(request.additionalInfo)
            : null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<UserApprovalRequest>> getPendingApprovalRequests() async {
    final db = await database;
    final maps = await db.query(
      'user_approval_requests',
      orderBy: 'created_at DESC',
    );

    return maps.map((map) => UserApprovalRequest(
      userId: map['user_id'] as String,
      email: map['email'] as String,
      fullName: map['full_name'] as String,
      phoneNumber: map['phone_number'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      additionalInfo: map['additional_info'] != null
          ? jsonDecode(map['additional_info'] as String)
          : null,
    )).toList();
  }

  Future<void> deleteUserApprovalRequest(String userId) async {
    final db = await database;
    await db.delete(
      'user_approval_requests',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // Admin Activities CRUD operations
  Future<void> insertAdminActivity(AdminActivity activity) async {
    final db = await database;
    await db.insert(
      'admin_activities',
      {
        'id': activity.id,
        'action': activity.action,
        'admin_id': activity.adminId,
        'target_user_id': activity.targetUserId,
        'timestamp': activity.timestamp.millisecondsSinceEpoch,
        'details': activity.details != null ? jsonEncode(activity.details) : null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AdminActivity>> getRecentAdminActivities({int limit = 50}) async {
    final db = await database;
    final maps = await db.query(
      'admin_activities',
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return maps.map((map) => AdminActivity(
      id: map['id'] as String,
      action: map['action'] as String,
      adminId: map['admin_id'] as String,
      targetUserId: map['target_user_id'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      details: map['details'] != null ? jsonDecode(map['details'] as String) : null,
    )).toList();
  }

  // Admin Notifications CRUD operations
  Future<void> insertAdminNotification(AdminNotification notification) async {
    final db = await database;
    await db.insert(
      'admin_notifications',
      {
        'id': notification.id,
        'type': notification.type,
        'title': notification.title,
        'message': notification.message,
        'target_user_id': notification.targetUserId,
        'admin_id': notification.adminId,
        'created_at': notification.createdAt.millisecondsSinceEpoch,
        'is_read': notification.isRead ? 1 : 0,
        'priority': notification.priority,
        'metadata': notification.metadata != null ? jsonEncode(notification.metadata) : null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AdminNotification>> getAdminNotifications(String? targetUserId, {int limit = 50}) async {
    final db = await database;
    final maps = await db.query(
      'admin_notifications',
      where: targetUserId != null ? 'target_user_id = ?' : null,
      whereArgs: targetUserId != null ? [targetUserId] : null,
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return maps.map((map) => AdminNotification(
      id: map['id'] as String,
      type: map['type'] as String,
      title: map['title'] as String,
      message: map['message'] as String,
      targetUserId: map['target_user_id'] as String?,
      adminId: map['admin_id'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      isRead: (map['is_read'] as int) == 1,
      priority: map['priority'] as String,
      metadata: map['metadata'] != null ? jsonDecode(map['metadata'] as String) : null,
    )).toList();
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    final db = await database;
    await db.update(
      'admin_notifications',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [notificationId],
    );
  }

  Future<int> deleteOldNotifications(Duration age) async {
    final db = await database;
    final threshold = DateTime.now().subtract(age).millisecondsSinceEpoch;
    return await db.delete(
      'admin_notifications',
      where: 'created_at < ?',
      whereArgs: [threshold],
    );
  }

  // System Settings CRUD operations
  Future<void> insertOrUpdateSystemSetting(SystemSettings setting) async {
    final db = await database;
    await db.insert(
      'system_settings',
      {
        'id': setting.id,
        'key': setting.key,
        'value': setting.value.toString(),
        'type': setting.type,
        'description': setting.description,
        'category': setting.category,
        'is_public': setting.isPublic ? 1 : 0,
        'updated_at': setting.updatedAt.millisecondsSinceEpoch,
        'updated_by': setting.updatedBy,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<SystemSettings?> getSystemSetting(String key) async {
    final db = await database;
    final maps = await db.query(
      'system_settings',
      where: 'key = ?',
      whereArgs: [key],
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    return SystemSettings(
      id: map['id'] as String,
      key: map['key'] as String,
      value: map['value'],
      type: map['type'] as String,
      description: map['description'] as String,
      category: map['category'] as String,
      isPublic: (map['is_public'] as int) == 1,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      updatedBy: map['updated_by'] as String?,
    );
  }

  // Admin Audit Logs
  Future<void> insertAdminAuditLog(AdminAuditLog auditLog) async {
    final db = await database;
    await db.insert(
      'admin_audit_logs',
      {
        'id': auditLog.id,
        'admin_id': auditLog.adminId,
        'action': auditLog.action,
        'resource': auditLog.resource,
        'resource_id': auditLog.resourceId,
        'old_values': auditLog.oldValues != null ? jsonEncode(auditLog.oldValues) : null,
        'new_values': auditLog.newValues != null ? jsonEncode(auditLog.newValues) : null,
        'timestamp': auditLog.timestamp.millisecondsSinceEpoch,
        'ip_address': auditLog.ipAddress,
        'user_agent': auditLog.userAgent,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AdminAuditLog>> getAdminAuditLogs({int limit = 100}) async {
    final db = await database;
    final maps = await db.query(
      'admin_audit_logs',
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return maps.map((map) => AdminAuditLog(
      id: map['id'] as String,
      adminId: map['admin_id'] as String,
      action: map['action'] as String,
      resource: map['resource'] as String,
      resourceId: map['resource_id'] as String?,
      oldValues: map['old_values'] != null ? jsonDecode(map['old_values'] as String) : null,
      newValues: map['new_values'] != null ? jsonDecode(map['new_values'] as String) : null,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      ipAddress: map['ip_address'] as String,
      userAgent: map['user_agent'] as String,
    )).toList();
  }

  // Utility methods
  Future<int> getDatabaseSize() async {
    final db = await database;
    final result = await db.rawQuery('PRAGMA page_count');
    final pageCount = result.first['page_count'] as int;
    final pageSizeResult = await db.rawQuery('PRAGMA page_size');
    final pageSize = pageSizeResult.first['page_size'] as int;
    return pageCount * pageSize;
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('admin_users');
      await txn.delete('user_approval_requests');
      await txn.delete('admin_activities');
      await txn.delete('admin_permissions');
      await txn.delete('admin_roles');
      await txn.delete('admin_notifications');
      await txn.delete('system_settings');
      await txn.delete('user_sessions');
      await txn.delete('content_moderation_requests');
      await txn.delete('admin_audit_logs');
    });
  }

  Future<void> closeDatabase() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}