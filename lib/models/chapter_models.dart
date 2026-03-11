import 'package:cloud_firestore/cloud_firestore.dart';

// Helper function for parsing DateTime from Firestore Timestamp or String
DateTime _parseDateTime(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  } else if (value is String) {
    return DateTime.parse(value);
  } else if (value is DateTime) {
    return value;
  }
  return DateTime.now();
}

enum WorkersType {
  main,
  campus,
  fieldwork,
  amtc,
}

enum MemberRole {
  member,
  coordinator,
  director,
  bod,
  trustee,
}

enum ActivityType {
  evangelism,
  outreach,
  training,
  meeting,
  conference,
  workshop,
  service,
  other,
}

enum ActivityStatus {
  planned,
  ongoing,
  completed,
  cancelled,
}

enum ReportStatus {
  draft,
  submitted,
  reviewed,
  approved,
  rejected,
}

class Chapter {
  final String id;
  final String name;
  final String description;
  final WorkersType type;
  final String? coordinatorId;
  final String? directorId;
  final List<String> memberIds;
  final Map<String, dynamic> settings;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Chapter({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.coordinatorId,
    this.directorId,
    required this.memberIds,
    required this.settings,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      type: WorkersType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => WorkersType.main,
      ),
      coordinatorId: json['coordinator_id'] as String?,
      directorId: json['director_id'] as String?,
      memberIds: List<String>.from(json['member_ids'] ?? []),
      settings: Map<String, dynamic>.from(json['settings'] ?? {}),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.name,
      'coordinator_id': coordinatorId,
      'director_id': directorId,
      'member_ids': memberIds,
      'settings': settings,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Chapter copyWith({
    String? id,
    String? name,
    String? description,
    WorkersType? type,
    String? coordinatorId,
    String? directorId,
    List<String>? memberIds,
    Map<String, dynamic>? settings,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Chapter(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      coordinatorId: coordinatorId ?? this.coordinatorId,
      directorId: directorId ?? this.directorId,
      memberIds: memberIds ?? this.memberIds,
      settings: settings ?? this.settings,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ChapterMember {
  final String id;
  final String chapterId;
  final String userId;
  final MemberRole role;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final bool isActive;
  final Map<String, dynamic> permissions;
  final Map<String, dynamic> metadata;

  const ChapterMember({
    required this.id,
    required this.chapterId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.leftAt,
    required this.isActive,
    required this.permissions,
    required this.metadata,
  });

  factory ChapterMember.fromJson(Map<String, dynamic> json) {
    return ChapterMember(
      id: json['id'] as String,
      chapterId: json['chapter_id'] as String,
      userId: json['user_id'] as String,
      role: MemberRole.values.firstWhere(
        (role) => role.name == json['role'],
        orElse: () => MemberRole.member,
      ),
      joinedAt: _parseDateTime(json['joined_at']),
      leftAt: json['left_at'] != null ? _parseDateTime(json['left_at']) : null,
      isActive: json['is_active'] as bool? ?? true,
      permissions: Map<String, dynamic>.from(json['permissions'] ?? {}),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chapter_id': chapterId,
      'user_id': userId,
      'role': role.name,
      'joined_at': joinedAt.toIso8601String(),
      'left_at': leftAt?.toIso8601String(),
      'is_active': isActive,
      'permissions': permissions,
      'metadata': metadata,
    };
  }

  ChapterMember copyWith({
    String? id,
    String? chapterId,
    String? userId,
    MemberRole? role,
    DateTime? joinedAt,
    DateTime? leftAt,
    bool? isActive,
    Map<String, dynamic>? permissions,
    Map<String, dynamic>? metadata,
  }) {
    return ChapterMember(
      id: id ?? this.id,
      chapterId: chapterId ?? this.chapterId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      leftAt: leftAt ?? this.leftAt,
      isActive: isActive ?? this.isActive,
      permissions: permissions ?? this.permissions,
      metadata: metadata ?? this.metadata,
    );
  }
}

class ChapterActivity {
  final String id;
  final String chapterId;
  final String title;
  final String description;
  final ActivityType type;
  final ActivityStatus status;
  final DateTime scheduledAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? location;
  final List<String> assignedMemberIds;
  final Map<String, dynamic> resources;
  final Map<String, dynamic> results;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChapterActivity({
    required this.id,
    required this.chapterId,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    required this.scheduledAt,
    this.startedAt,
    this.completedAt,
    this.location,
    required this.assignedMemberIds,
    required this.resources,
    required this.results,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChapterActivity.fromJson(Map<String, dynamic> json) {
    return ChapterActivity(
      id: json['id'] as String,
      chapterId: json['chapter_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      type: ActivityType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => ActivityType.other,
      ),
      status: ActivityStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => ActivityStatus.planned,
      ),
      scheduledAt: _parseDateTime(json['scheduled_at']),
      startedAt: json['started_at'] != null
          ? _parseDateTime(json['started_at'])
          : null,
      completedAt: json['completed_at'] != null
          ? _parseDateTime(json['completed_at'])
          : null,
      location: json['location'] as String?,
      assignedMemberIds: List<String>.from(json['assigned_member_ids'] ?? []),
      resources: Map<String, dynamic>.from(json['resources'] ?? {}),
      results: Map<String, dynamic>.from(json['results'] ?? {}),
      createdBy: json['created_by'] as String,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chapter_id': chapterId,
      'title': title,
      'description': description,
      'type': type.name,
      'status': status.name,
      'scheduled_at': scheduledAt.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'location': location,
      'assigned_member_ids': assignedMemberIds,
      'resources': resources,
      'results': results,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ChapterActivity copyWith({
    String? id,
    String? chapterId,
    String? title,
    String? description,
    ActivityType? type,
    ActivityStatus? status,
    DateTime? scheduledAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? location,
    List<String>? assignedMemberIds,
    Map<String, dynamic>? resources,
    Map<String, dynamic>? results,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChapterActivity(
      id: id ?? this.id,
      chapterId: chapterId ?? this.chapterId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      location: location ?? this.location,
      assignedMemberIds: assignedMemberIds ?? this.assignedMemberIds,
      resources: resources ?? this.resources,
      results: results ?? this.results,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ChapterReport {
  final String id;
  final String chapterId;
  final String title;
  final String content;
  final ReportStatus status;
  final DateTime reportPeriodStart;
  final DateTime reportPeriodEnd;
  final List<String> activityIds;
  final Map<String, dynamic> statistics;
  final Map<String, dynamic> attachments;
  final String submittedBy;
  final DateTime? submittedAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewComments;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChapterReport({
    required this.id,
    required this.chapterId,
    required this.title,
    required this.content,
    required this.status,
    required this.reportPeriodStart,
    required this.reportPeriodEnd,
    required this.activityIds,
    required this.statistics,
    required this.attachments,
    required this.submittedBy,
    this.submittedAt,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewComments,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChapterReport.fromJson(Map<String, dynamic> json) {
    return ChapterReport(
      id: json['id'] as String,
      chapterId: json['chapter_id'] as String,
      title: json['title'] as String,
      content: json['content'] as String? ?? '',
      status: ReportStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => ReportStatus.draft,
      ),
      reportPeriodStart: _parseDateTime(json['report_period_start']),
      reportPeriodEnd: _parseDateTime(json['report_period_end']),
      activityIds: List<String>.from(json['activity_ids'] ?? []),
      statistics: Map<String, dynamic>.from(json['statistics'] ?? {}),
      attachments: Map<String, dynamic>.from(json['attachments'] ?? {}),
      submittedBy: json['submitted_by'] as String,
      submittedAt: json['submitted_at'] != null
          ? _parseDateTime(json['submitted_at'])
          : null,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? _parseDateTime(json['reviewed_at'])
          : null,
      reviewComments: json['review_comments'] as String?,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chapter_id': chapterId,
      'title': title,
      'content': content,
      'status': status.name,
      'report_period_start': reportPeriodStart.toIso8601String(),
      'report_period_end': reportPeriodEnd.toIso8601String(),
      'activity_ids': activityIds,
      'statistics': statistics,
      'attachments': attachments,
      'submitted_by': submittedBy,
      'submitted_at': submittedAt?.toIso8601String(),
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'review_comments': reviewComments,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ChapterReport copyWith({
    String? id,
    String? chapterId,
    String? title,
    String? content,
    ReportStatus? status,
    DateTime? reportPeriodStart,
    DateTime? reportPeriodEnd,
    List<String>? activityIds,
    Map<String, dynamic>? statistics,
    Map<String, dynamic>? attachments,
    String? submittedBy,
    DateTime? submittedAt,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? reviewComments,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChapterReport(
      id: id ?? this.id,
      chapterId: chapterId ?? this.chapterId,
      title: title ?? this.title,
      content: content ?? this.content,
      status: status ?? this.status,
      reportPeriodStart: reportPeriodStart ?? this.reportPeriodStart,
      reportPeriodEnd: reportPeriodEnd ?? this.reportPeriodEnd,
      activityIds: activityIds ?? this.activityIds,
      statistics: statistics ?? this.statistics,
      attachments: attachments ?? this.attachments,
      submittedBy: submittedBy ?? this.submittedBy,
      submittedAt: submittedAt ?? this.submittedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewComments: reviewComments ?? this.reviewComments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ChapterTask {
  final String id;
  final String chapterId;
  final String title;
  final String description;
  final String assignedTo;
  final String assignedBy;
  final DateTime dueDate;
  final ActivityStatus status;
  final int priority; // 1-5, 5 being highest
  final List<String> tags;
  final Map<String, dynamic> metadata;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChapterTask({
    required this.id,
    required this.chapterId,
    required this.title,
    required this.description,
    required this.assignedTo,
    required this.assignedBy,
    required this.dueDate,
    required this.status,
    required this.priority,
    required this.tags,
    required this.metadata,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChapterTask.fromJson(Map<String, dynamic> json) {
    return ChapterTask(
      id: json['id'] as String,
      chapterId: json['chapter_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      assignedTo: json['assigned_to'] as String,
      assignedBy: json['assigned_by'] as String,
      dueDate: _parseDateTime(json['due_date']),
      status: ActivityStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => ActivityStatus.planned,
      ),
      priority: json['priority'] as int? ?? 3,
      tags: List<String>.from(json['tags'] ?? []),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      completedAt: json['completed_at'] != null
          ? _parseDateTime(json['completed_at'])
          : null,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chapter_id': chapterId,
      'title': title,
      'description': description,
      'assigned_to': assignedTo,
      'assigned_by': assignedBy,
      'due_date': dueDate.toIso8601String(),
      'status': status.name,
      'priority': priority,
      'tags': tags,
      'metadata': metadata,
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ChapterTask copyWith({
    String? id,
    String? chapterId,
    String? title,
    String? description,
    String? assignedTo,
    String? assignedBy,
    DateTime? dueDate,
    ActivityStatus? status,
    int? priority,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChapterTask(
      id: id ?? this.id,
      chapterId: chapterId ?? this.chapterId,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedBy: assignedBy ?? this.assignedBy,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ChapterConstants {
  static const Map<WorkersType, String> typeDescriptions = {
    WorkersType.main: 'Main Chapter - General organizational activities',
    WorkersType.campus: 'Campus Chapter - University and college outreach',
    WorkersType.fieldwork: 'Field Work - Community evangelism and service',
    WorkersType.amtc: 'AMTC - Alive Missionary Training Center activities',
  };

  static const Map<MemberRole, String> roleDescriptions = {
    MemberRole.member: 'Chapter Member - Participates in activities',
    MemberRole.coordinator: 'Chapter Coordinator - Manages chapter operations',
    MemberRole.director: 'Director - Oversees multiple chapters',
    MemberRole.bod: 'Board of Directors - Strategic leadership',
    MemberRole.trustee: 'Trustee - Governance and oversight',
  };

  static const Map<ActivityType, String> activityDescriptions = {
    ActivityType.evangelism: 'Evangelistic meetings and outreach',
    ActivityType.outreach: 'Community service and outreach programs',
    ActivityType.training: 'Training sessions and workshops',
    ActivityType.meeting: 'Regular chapter meetings',
    ActivityType.conference: 'Conferences and conventions',
    ActivityType.workshop: 'Educational workshops',
    ActivityType.service: 'Community service projects',
    ActivityType.other: 'Other activities',
  };

  static const Map<String, List<String>> rolePermissions = {
    'member': ['view_activities', 'participate'],
    'coordinator': [
      'view_activities',
      'create_activities',
      'edit_activities',
      'assign_tasks',
      'create_reports',
      'manage_members',
    ],
    'director': [
      'view_activities',
      'create_activities',
      'edit_activities',
      'assign_tasks',
      'create_reports',
      'manage_members',
      'review_reports',
      'manage_chapters',
    ],
    'bod': [
      'view_activities',
      'create_activities',
      'edit_activities',
      'assign_tasks',
      'create_reports',
      'manage_members',
      'review_reports',
      'manage_chapters',
      'approve_reports',
      'strategic_planning',
    ],
    'trustee': [
      'view_activities',
      'create_activities',
      'edit_activities',
      'assign_tasks',
      'create_reports',
      'manage_members',
      'review_reports',
      'manage_chapters',
      'approve_reports',
      'strategic_planning',
      'governance',
    ],
  };

  static const List<String> defaultTags = [
    'evangelism',
    'outreach',
    'training',
    'youth',
    'health',
    'education',
    'community',
    'urgent',
    'recurring',
  ];

  static const Map<String, String> reportTemplates = {
    'monthly': 'Monthly Chapter Report Template',
    'quarterly': 'Quarterly Chapter Report Template',
    'annual': 'Annual Chapter Report Template',
    'activity': 'Activity Report Template',
  };

  static const List<String> bibleVerses = [
    'Matthew 28:19-20 - Go therefore and make disciples of all nations',
    'Acts 1:8 - You will be my witnesses in Jerusalem, Judea, Samaria, and to the ends of the earth',
    '1 Corinthians 12:12 - For just as the body is one and has many members',
    'Ephesians 4:11-12 - He gave some to be apostles, prophets, evangelists, pastors and teachers',
    'Philippians 2:3-4 - Do nothing from selfish ambition or conceit',
  ];
}
