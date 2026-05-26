import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:uuid/uuid.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../models/app_models.dart' show TaskAssignment;
import '../models/chapter_models.dart';
import '../utils/app_exception.dart';

class ChapterService {
  static final ChapterService _instance = ChapterService._internal();
  factory ChapterService() => _instance;
  ChapterService._internal();

  final Uuid _uuid = const Uuid();
  final TablesDB _tables = TablesDB(appwriteClient);

  static const _chaptersCollection = AppwriteBackendConfig.chaptersCollectionId;
  static const _membersCollection =
      AppwriteBackendConfig.chapterMembersCollectionId;
  static const _activitiesCollection =
      AppwriteBackendConfig.chapterActivitiesCollectionId;
  static const _tasksCollection =
      AppwriteBackendConfig.chapterTasksCollectionId;
  static const _reportsCollection =
      AppwriteBackendConfig.chapterReportsCollectionId;
  static const _taskAssignmentsCollection =
      AppwriteBackendConfig.taskAssignmentsCollectionId;

  Future<List<Chapter>> getChapters({
    WorkersType? type,
    bool? isActive,
    String? searchQuery,
  }) async {
    try {
      final queries = <String>[Query.orderAsc('name'), Query.limit(500)];
      if (type != null) queries.add(Query.equal('type', type.name));
      if (isActive != null) queries.add(Query.equal('is_active', isActive));

      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _chaptersCollection,
        queries: queries,
      );

      var chapters = response.rows.map(_chapterFromDocument).toList();
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final queryLower = searchQuery.toLowerCase();
        chapters = chapters
            .where((c) =>
                c.name.toLowerCase().contains(queryLower) ||
                c.description.toLowerCase().contains(queryLower))
            .toList();
      }

      return chapters;
    } catch (e) {
      throw DatabaseException('Failed to fetch chapters', originalError: e);
    }
  }

  Future<Chapter?> getChapterById(String chapterId) async {
    try {
      final document = await _tables.getRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _chaptersCollection,
        rowId: chapterId,
      );
      return _chapterFromDocument(document);
    } on AppwriteException catch (e) {
      if (e.code == 404) return null;
      throw DatabaseException('Failed to get chapter by ID', originalError: e);
    } catch (e) {
      throw DatabaseException('Failed to get chapter by ID', originalError: e);
    }
  }

  Future<List<Chapter>> getUserChapters(String userId) async {
    try {
      final memberships = await getUserMemberships(userId);
      final chapterIds = memberships.map((m) => m.chapterId).toSet().toList();
      final chapters = <Chapter>[];

      for (final chapterId in chapterIds) {
        final chapter = await getChapterById(chapterId);
        if (chapter != null && chapter.isActive) chapters.add(chapter);
      }

      return chapters;
    } catch (e) {
      throw DatabaseException('Failed to fetch user chapters',
          originalError: e);
    }
  }

  Future<Chapter> createChapter(Chapter chapter) async {
    try {
      final now = DateTime.now().toUtc();
      final id = chapter.id.isNotEmpty ? chapter.id : _uuid.v4();
      final newChapter = chapter.copyWith(
        id: id,
        createdAt: now,
        updatedAt: now,
      );

      final document = await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _chaptersCollection,
        rowId: id,
        data: _chapterData(newChapter),
      );
      return _chapterFromDocument(document);
    } catch (e) {
      throw DatabaseException('Failed to create chapter', originalError: e);
    }
  }

  Future<Chapter> updateChapter(Chapter chapter) async {
    try {
      final updatedChapter =
          chapter.copyWith(updatedAt: DateTime.now().toUtc());
      final document = await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _chaptersCollection,
        rowId: updatedChapter.id,
        data: _chapterData(updatedChapter),
      );
      return _chapterFromDocument(document);
    } catch (e) {
      throw DatabaseException('Failed to update chapter', originalError: e);
    }
  }

  Future<void> updateChapterFields(String id, Map<String, dynamic> data) async {
    try {
      await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _chaptersCollection,
        rowId: id,
        data: _normalizeChapterUpdates({
          ...data,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }),
      );
    } catch (e) {
      throw DatabaseException('Failed to update chapter fields',
          originalError: e);
    }
  }

  Future<void> deleteChapter(String chapterId) async {
    try {
      await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _chaptersCollection,
        rowId: chapterId,
        data: {
          'is_active': false,
          'updated_at': _iso(DateTime.now()),
        },
      );
    } catch (e) {
      throw DatabaseException('Failed to delete chapter', originalError: e);
    }
  }

  Future<List<ChapterMember>> getChapterMembers(String chapterId,
      {bool? isActive}) async {
    try {
      final queries = <String>[
        Query.equal('chapter_id', chapterId),
        Query.orderDesc('joined_at'),
        Query.limit(500),
      ];
      if (isActive != null) queries.add(Query.equal('is_active', isActive));

      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _membersCollection,
        queries: queries,
      );
      return response.rows.map(_memberFromDocument).toList();
    } catch (e) {
      throw DatabaseException('Failed to get chapter members',
          originalError: e);
    }
  }

  Future<ChapterMember?> getChapterMember(
      String chapterId, String userId) async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _membersCollection,
        queries: [
          Query.equal('chapter_id', chapterId),
          Query.equal('user_id', userId),
          Query.limit(1),
        ],
      );
      if (response.rows.isEmpty) return null;
      return _memberFromDocument(response.rows.first);
    } catch (e) {
      throw DatabaseException('Failed to get chapter member', originalError: e);
    }
  }

  Future<List<ChapterMember>> getUserMemberships(String userId) async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _membersCollection,
        queries: [
          Query.equal('user_id', userId),
          Query.equal('is_active', true),
          Query.orderDesc('joined_at'),
          Query.limit(500),
        ],
      );
      return response.rows.map(_memberFromDocument).toList();
    } catch (e) {
      throw DatabaseException('Failed to get user memberships',
          originalError: e);
    }
  }

  Future<ChapterMember> addMember(
      String chapterId, String userId, MemberRole role) async {
    final now = DateTime.now().toUtc();
    final member = ChapterMember(
      id: _uuid.v4(),
      chapterId: chapterId,
      userId: userId,
      role: role,
      joinedAt: now,
      isActive: true,
      permissions: _rolePermissions(role),
      metadata: {},
    );

    try {
      final document = await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _membersCollection,
        rowId: member.id,
        data: _memberData(member),
      );
      return _memberFromDocument(document);
    } catch (e) {
      throw DatabaseException('Failed to add chapter member', originalError: e);
    }
  }

  Future<ChapterMember> updateMemberRole(
      String chapterId, String userId, MemberRole newRole) async {
    final member = await getChapterMember(chapterId, userId);
    if (member == null) {
      throw NotFoundException('Member not found');
    }

    try {
      final document = await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _membersCollection,
        rowId: member.id,
        data: {
          'role': newRole.name,
          'permissions': jsonEncode(_rolePermissions(newRole)),
          'updated_at': _iso(DateTime.now()),
        },
      );
      return _memberFromDocument(document);
    } catch (e) {
      throw DatabaseException('Failed to update member role', originalError: e);
    }
  }

  Future<void> removeMember(String chapterId, String userId) async {
    try {
      final member = await getChapterMember(chapterId, userId);
      if (member == null) return;

      await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _membersCollection,
        rowId: member.id,
        data: {
          'is_active': false,
          'left_at': _iso(DateTime.now()),
          'updated_at': _iso(DateTime.now()),
        },
      );
    } catch (e) {
      throw DatabaseException('Failed to remove member', originalError: e);
    }
  }

  Future<List<ChapterActivity>> getChapterActivities(
    String chapterId, {
    ActivityType? type,
    ActivityStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queries = _dateRangeQueries(
        orderKey: 'scheduled_at',
        startDate: startDate,
        endDate: endDate,
      );
      queries.add(Query.equal('chapter_id', chapterId));
      if (type != null) queries.add(Query.equal('type', type.name));
      if (status != null) queries.add(Query.equal('status', status.name));

      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _activitiesCollection,
        queries: queries,
      );
      return response.rows.map(_activityFromDocument).toList();
    } catch (e) {
      throw DatabaseException('Failed to get chapter activities',
          originalError: e);
    }
  }

  Future<List<ChapterActivity>> getUserActivities(String userId) async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _activitiesCollection,
        queries: [
          Query.containsAny('assigned_member_ids', [userId]),
          Query.orderDesc('scheduled_at'),
          Query.limit(500),
        ],
      );
      return response.rows.map(_activityFromDocument).toList();
    } catch (e) {
      throw DatabaseException('Failed to get user activities',
          originalError: e);
    }
  }

  Future<ChapterActivity> createActivity(ChapterActivity activity) async {
    try {
      final now = DateTime.now().toUtc();
      final newActivity = activity.copyWith(
        id: activity.id.isNotEmpty ? activity.id : _uuid.v4(),
        createdAt: now,
        updatedAt: now,
      );
      final document = await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _activitiesCollection,
        rowId: newActivity.id,
        data: _activityData(newActivity),
      );
      return _activityFromDocument(document);
    } catch (e) {
      throw DatabaseException('Failed to create activity', originalError: e);
    }
  }

  Future<ChapterActivity> updateActivity(ChapterActivity activity) async {
    try {
      final updatedActivity =
          activity.copyWith(updatedAt: DateTime.now().toUtc());
      final document = await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _activitiesCollection,
        rowId: updatedActivity.id,
        data: _activityData(updatedActivity),
      );
      return _activityFromDocument(document);
    } catch (e) {
      throw DatabaseException('Failed to update activity', originalError: e);
    }
  }

  Future<ChapterActivity> updateActivityStatus(
      String activityId, ActivityStatus status) async {
    try {
      final document = await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _activitiesCollection,
        rowId: activityId,
        data: {
          'status': status.name,
          'updated_at': _iso(DateTime.now()),
        },
      );
      return _activityFromDocument(document);
    } catch (e) {
      throw DatabaseException('Failed to update activity status',
          originalError: e);
    }
  }

  Future<List<ChapterTask>> getChapterTasks(
    String chapterId, {
    String? assignedTo,
    ActivityStatus? status,
    int? priority,
  }) async {
    try {
      final queries = <String>[
        Query.equal('chapter_id', chapterId),
        Query.orderAsc('due_date'),
        Query.limit(500),
      ];
      if (assignedTo != null) {
        queries.add(Query.equal('assigned_to', assignedTo));
      }
      if (status != null) queries.add(Query.equal('status', status.name));
      if (priority != null) queries.add(Query.equal('priority', priority));

      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _tasksCollection,
        queries: queries,
      );
      return response.rows.map(_taskFromDocument).toList();
    } catch (e) {
      throw DatabaseException('Failed to get chapter tasks', originalError: e);
    }
  }

  Future<List<ChapterTask>> getUserTasks(String userId) async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _tasksCollection,
        queries: [
          Query.equal('assigned_to', userId),
          Query.orderAsc('due_date'),
          Query.limit(500),
        ],
      );
      return response.rows
          .map(_taskFromDocument)
          .where((task) => task.status != ActivityStatus.completed)
          .toList();
    } catch (e) {
      throw DatabaseException('Failed to get user tasks', originalError: e);
    }
  }

  Future<ChapterTask> createTask(ChapterTask task) async {
    try {
      final now = DateTime.now().toUtc();
      final newTask = task.copyWith(
        id: task.id.isNotEmpty ? task.id : _uuid.v4(),
        createdAt: now,
        updatedAt: now,
      );
      final document = await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _tasksCollection,
        rowId: newTask.id,
        data: _taskData(newTask),
      );
      return _taskFromDocument(document);
    } catch (e) {
      throw DatabaseException('Failed to create task', originalError: e);
    }
  }

  Future<ChapterTask> updateTask(ChapterTask task) async {
    try {
      final updatedTask = task.copyWith(updatedAt: DateTime.now().toUtc());
      final document = await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _tasksCollection,
        rowId: updatedTask.id,
        data: _taskData(updatedTask),
      );
      return _taskFromDocument(document);
    } catch (e) {
      throw DatabaseException('Failed to update task', originalError: e);
    }
  }

  Future<ChapterTask> completeTask(String taskId) async {
    try {
      final now = DateTime.now().toUtc();
      final document = await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _tasksCollection,
        rowId: taskId,
        data: {
          'status': ActivityStatus.completed.name,
          'completed_at': _iso(now),
          'updated_at': _iso(now),
        },
      );
      return _taskFromDocument(document);
    } catch (e) {
      throw DatabaseException('Failed to complete task', originalError: e);
    }
  }

  Future<List<ChapterReport>> getChapterReports(
    String chapterId, {
    ReportStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queries = _dateRangeQueries(
        orderKey: 'created_at',
        startDate: startDate,
        endDate: endDate,
      );
      queries.add(Query.equal('chapter_id', chapterId));
      if (status != null) queries.add(Query.equal('status', status.name));

      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _reportsCollection,
        queries: queries,
      );
      return response.rows.map(_reportFromDocument).toList();
    } catch (e) {
      throw DatabaseException('Failed to get chapter reports',
          originalError: e);
    }
  }

  Future<List<ChapterReport>> getReportsForReview(String reviewerId) async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _reportsCollection,
        queries: [
          Query.equal('status', ReportStatus.submitted.name),
          Query.orderAsc('created_at'),
          Query.limit(500),
        ],
      );
      return response.rows.map(_reportFromDocument).toList();
    } catch (e) {
      throw DatabaseException('Failed to get reports for review',
          originalError: e);
    }
  }

  Future<ChapterReport> createReport(ChapterReport report) async {
    try {
      final now = DateTime.now().toUtc();
      final newReport = report.copyWith(
        id: report.id.isNotEmpty ? report.id : _uuid.v4(),
        createdAt: now,
        updatedAt: now,
      );
      final document = await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _reportsCollection,
        rowId: newReport.id,
        data: _reportData(newReport),
      );
      return _reportFromDocument(document);
    } catch (e) {
      throw DatabaseException('Failed to create report', originalError: e);
    }
  }

  Future<ChapterReport> updateReport(ChapterReport report) async {
    try {
      final updatedReport = report.copyWith(updatedAt: DateTime.now().toUtc());
      final document = await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _reportsCollection,
        rowId: updatedReport.id,
        data: _reportData(updatedReport),
      );
      return _reportFromDocument(document);
    } catch (e) {
      throw DatabaseException('Failed to update report', originalError: e);
    }
  }

  Future<ChapterReport> submitReport(String reportId) async {
    try {
      final now = DateTime.now().toUtc();
      final document = await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _reportsCollection,
        rowId: reportId,
        data: {
          'status': ReportStatus.submitted.name,
          'submitted_at': _iso(now),
          'updated_at': _iso(now),
        },
      );
      return _reportFromDocument(document);
    } catch (e) {
      throw DatabaseException('Failed to submit report', originalError: e);
    }
  }

  Future<ChapterReport> reviewReport(
    String reportId,
    String reviewerId,
    ReportStatus status,
    String? comments,
  ) async {
    try {
      final now = DateTime.now().toUtc();
      final document = await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _reportsCollection,
        rowId: reportId,
        data: _stripNulls({
          'status': status.name,
          'reviewed_by': reviewerId,
          'reviewed_at': _iso(now),
          'review_comments': comments,
          'updated_at': _iso(now),
        }),
      );
      return _reportFromDocument(document);
    } catch (e) {
      throw DatabaseException('Failed to review report', originalError: e);
    }
  }

  Future<Map<String, dynamic>> getChapterStatistics(String chapterId) async {
    try {
      final results = await Future.wait([
        getChapterMembers(chapterId, isActive: true),
        getChapterActivities(chapterId),
        getChapterTasks(chapterId),
        getChapterReports(chapterId),
      ]);

      final members = results[0] as List<ChapterMember>;
      final activities = results[1] as List<ChapterActivity>;
      final tasks = results[2] as List<ChapterTask>;
      final reports = results[3] as List<ChapterReport>;

      final completedActivities =
          activities.where((a) => a.status == ActivityStatus.completed).length;
      final ongoingActivities =
          activities.where((a) => a.status == ActivityStatus.ongoing).length;
      final plannedActivities =
          activities.where((a) => a.status == ActivityStatus.planned).length;
      final completedTasks =
          tasks.where((t) => t.status == ActivityStatus.completed).length;
      final pendingTasks =
          tasks.where((t) => t.status != ActivityStatus.completed).length;
      final submittedReports =
          reports.where((r) => r.status == ReportStatus.submitted).length;
      final approvedReports =
          reports.where((r) => r.status == ReportStatus.approved).length;
      final roleDistribution = <MemberRole, int>{};
      for (final member in members) {
        roleDistribution[member.role] =
            (roleDistribution[member.role] ?? 0) + 1;
      }

      return {
        'totalMembers': members.length,
        'totalActivities': activities.length,
        'completedActivities': completedActivities,
        'ongoingActivities': ongoingActivities,
        'plannedActivities': plannedActivities,
        'totalTasks': tasks.length,
        'completedTasks': completedTasks,
        'pendingTasks': pendingTasks,
        'totalReports': reports.length,
        'submittedReports': submittedReports,
        'approvedReports': approvedReports,
        'roleDistribution': roleDistribution.map((k, v) => MapEntry(k.name, v)),
        'activityCompletionRate': activities.isEmpty
            ? 0
            : (completedActivities / activities.length * 100).round(),
        'taskCompletionRate':
            tasks.isEmpty ? 0 : (completedTasks / tasks.length * 100).round(),
      };
    } catch (e) {
      throw DatabaseException('Failed to get chapter statistics',
          originalError: e);
    }
  }

  Future<Map<String, dynamic>> getUserChapterStatistics(String userId) async {
    try {
      final results = await Future.wait([
        getUserMemberships(userId),
        getUserActivities(userId),
        getUserTasks(userId),
      ]);

      final memberships = results[0] as List<ChapterMember>;
      final activities = results[1] as List<ChapterActivity>;
      final tasks = results[2] as List<ChapterTask>;
      final completedActivities =
          activities.where((a) => a.status == ActivityStatus.completed).length;
      final completedTasks =
          tasks.where((t) => t.status == ActivityStatus.completed).length;

      return {
        'totalChapters': memberships.length,
        'totalActivities': activities.length,
        'completedActivities': completedActivities,
        'totalTasks': tasks.length,
        'completedTasks': completedTasks,
        'pendingTasks': tasks.length - completedTasks,
        'activityCompletionRate': activities.isEmpty
            ? 0
            : (completedActivities / activities.length * 100).round(),
        'taskCompletionRate':
            tasks.isEmpty ? 0 : (completedTasks / tasks.length * 100).round(),
      };
    } catch (e) {
      throw DatabaseException('Failed to get user chapter statistics',
          originalError: e);
    }
  }

  bool hasPermission(ChapterMember member, String permission) {
    final permissions =
        member.permissions['permissions'] as List<dynamic>? ?? [];
    return permissions.contains(permission);
  }

  String getTypeDescription(WorkersType type) =>
      ChapterConstants.typeDescriptions[type] ?? 'Chapter';

  String getRoleDescription(MemberRole role) =>
      ChapterConstants.roleDescriptions[role] ?? 'Member';

  String getActivityDescription(ActivityType type) =>
      ChapterConstants.activityDescriptions[type] ?? 'Activity';

  List<String> getDefaultTags() => ChapterConstants.defaultTags;

  String getReportTemplate(String templateType) =>
      ChapterConstants.reportTemplates[templateType] ?? 'Report Template';

  String getBibleVerse(int index) {
    if (index >= 0 && index < ChapterConstants.bibleVerses.length) {
      return ChapterConstants.bibleVerses[index];
    }
    return ChapterConstants.bibleVerses[0];
  }

  Future<ChapterReport> generateMonthlyReport(
      String chapterId, DateTime month) async {
    try {
      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 0);
      final activities = await getChapterActivities(
        chapterId,
        startDate: startDate,
        endDate: endDate,
      );
      final statistics = await getChapterStatistics(chapterId);
      final content =
          _generateReportContent(activities, statistics, startDate, endDate);

      final report = ChapterReport(
        id: _uuid.v4(),
        chapterId: chapterId,
        title: 'Monthly Report - ${_formatMonth(month)}',
        content: content,
        status: ReportStatus.draft,
        reportPeriodStart: startDate,
        reportPeriodEnd: endDate,
        activityIds: activities.map((a) => a.id).toList(),
        statistics: statistics,
        attachments: {},
        submittedBy: '',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      return createReport(report);
    } catch (e) {
      throw DatabaseException('Failed to generate monthly report',
          originalError: e);
    }
  }

  String _generateReportContent(
    List<ChapterActivity> activities,
    Map<String, dynamic> statistics,
    DateTime startDate,
    DateTime endDate,
  ) {
    final buffer = StringBuffer();

    buffer.writeln('# Chapter Report');
    buffer.writeln(
        '**Period:** ${_formatDate(startDate)} - ${_formatDate(endDate)}');
    buffer.writeln();
    buffer.writeln('## Summary');
    buffer.writeln('- Total Activities: ${activities.length}');
    buffer.writeln(
        '- Completed Activities: ${statistics['completedActivities']}');
    buffer.writeln('- Total Members: ${statistics['totalMembers']}');
    buffer
        .writeln('- Completion Rate: ${statistics['activityCompletionRate']}%');
    buffer.writeln();
    buffer.writeln('## Activities');

    for (final activity in activities) {
      buffer.writeln('### ${activity.title}');
      buffer.writeln('- **Type:** ${activity.type.name.toUpperCase()}');
      buffer.writeln('- **Status:** ${activity.status.name.toUpperCase()}');
      buffer.writeln('- **Date:** ${_formatDate(activity.scheduledAt)}');
      if (activity.location != null) {
        buffer.writeln('- **Location:** ${activity.location}');
      }
      buffer.writeln('- **Description:** ${activity.description}');
      buffer.writeln();
    }

    return buffer.toString();
  }

  Chapter _chapterFromDocument(dynamic document) {
    final data = _documentData(document);
    data['member_ids'] = _stringList(data['member_ids']);
    data['settings'] = _decodeMap(data['settings']);
    return Chapter.fromJson(data);
  }

  ChapterMember _memberFromDocument(dynamic document) {
    final data = _documentData(document);
    data['permissions'] = _decodeMap(data['permissions']);
    data['metadata'] = _decodeMap(data['metadata']);
    return ChapterMember.fromJson(data);
  }

  ChapterActivity _activityFromDocument(dynamic document) {
    final data = _documentData(document);
    data['assigned_member_ids'] = _stringList(data['assigned_member_ids']);
    data['resources'] = _decodeMap(data['resources']);
    data['results'] = _decodeMap(data['results']);
    return ChapterActivity.fromJson(data);
  }

  ChapterTask _taskFromDocument(dynamic document) {
    final data = _documentData(document);
    data['tags'] = _stringList(data['tags']);
    data['metadata'] = _decodeMap(data['metadata']);
    return ChapterTask.fromJson(data);
  }

  ChapterReport _reportFromDocument(dynamic document) {
    final data = _documentData(document);
    data['activity_ids'] = _stringList(data['activity_ids']);
    data['statistics'] = _decodeMap(data['statistics']);
    data['attachments'] = _decodeMap(data['attachments']);
    return ChapterReport.fromJson(data);
  }

  TaskAssignment _taskAssignmentFromDocument(dynamic document) {
    return TaskAssignment.fromJson(_documentData(document));
  }

  Map<String, dynamic> _chapterData(Chapter chapter) {
    return _stripNulls({
      'name': chapter.name,
      'description': chapter.description,
      'type': chapter.type.name,
      'coordinator_id': chapter.coordinatorId,
      'director_id': chapter.directorId,
      'member_ids': chapter.memberIds,
      'settings': jsonEncode(chapter.settings),
      'is_active': chapter.isActive,
      'created_at': _iso(chapter.createdAt),
      'updated_at': _iso(chapter.updatedAt),
    });
  }

  Map<String, dynamic> _memberData(ChapterMember member) {
    return _stripNulls({
      'chapter_id': member.chapterId,
      'user_id': member.userId,
      'role': member.role.name,
      'joined_at': _iso(member.joinedAt),
      'left_at': _nullableIso(member.leftAt),
      'is_active': member.isActive,
      'permissions': jsonEncode(member.permissions),
      'metadata': jsonEncode(member.metadata),
    });
  }

  Map<String, dynamic> _activityData(ChapterActivity activity) {
    return _stripNulls({
      'chapter_id': activity.chapterId,
      'title': activity.title,
      'description': activity.description,
      'type': activity.type.name,
      'status': activity.status.name,
      'scheduled_at': _iso(activity.scheduledAt),
      'started_at': _nullableIso(activity.startedAt),
      'completed_at': _nullableIso(activity.completedAt),
      'location': activity.location,
      'assigned_member_ids': activity.assignedMemberIds,
      'resources': jsonEncode(activity.resources),
      'results': jsonEncode(activity.results),
      'created_by': activity.createdBy,
      'created_at': _iso(activity.createdAt),
      'updated_at': _iso(activity.updatedAt),
    });
  }

  Map<String, dynamic> _taskData(ChapterTask task) {
    return _stripNulls({
      'chapter_id': task.chapterId,
      'title': task.title,
      'description': task.description,
      'assigned_to': task.assignedTo,
      'assigned_by': task.assignedBy,
      'due_date': _iso(task.dueDate),
      'status': task.status.name,
      'priority': task.priority,
      'tags': task.tags,
      'metadata': jsonEncode(task.metadata),
      'completed_at': _nullableIso(task.completedAt),
      'created_at': _iso(task.createdAt),
      'updated_at': _iso(task.updatedAt),
    });
  }

  Map<String, dynamic> _reportData(ChapterReport report) {
    return _stripNulls({
      'chapter_id': report.chapterId,
      'title': report.title,
      'content': report.content,
      'status': report.status.name,
      'report_period_start': _iso(report.reportPeriodStart),
      'report_period_end': _iso(report.reportPeriodEnd),
      'activity_ids': report.activityIds,
      'statistics': jsonEncode(report.statistics),
      'attachments': jsonEncode(report.attachments),
      'submitted_by': report.submittedBy,
      'submitted_at': _nullableIso(report.submittedAt),
      'reviewed_by': report.reviewedBy,
      'reviewed_at': _nullableIso(report.reviewedAt),
      'review_comments': report.reviewComments,
      'created_at': _iso(report.createdAt),
      'updated_at': _iso(report.updatedAt),
    });
  }

  Map<String, dynamic> _taskAssignmentData(TaskAssignment assignment) {
    return _stripNulls(Map<String, dynamic>.from(assignment.toJson())
      ..remove('id')
      ..update('due_date', (value) => _iso(DateTime.parse(value as String)))
      ..update('created_at', (value) => _iso(DateTime.parse(value as String)))
      ..update('updated_at', (value) => _iso(DateTime.parse(value as String)))
      ..update(
        'completed_at',
        (value) => value == null ? null : _iso(DateTime.parse(value as String)),
        ifAbsent: () => null,
      ));
  }

  Map<String, dynamic> _normalizeChapterUpdates(Map<String, dynamic> updates) {
    final normalized = <String, dynamic>{};
    for (final entry in updates.entries) {
      if (entry.key == 'id') continue;
      final value = entry.value;
      if (value == null) continue;
      if (value is DateTime) {
        normalized[entry.key] = _iso(value);
      } else if (value is Enum) {
        normalized[entry.key] = value.name;
      } else if (entry.key == 'settings' && value is Map) {
        normalized[entry.key] = jsonEncode(value);
      } else {
        normalized[entry.key] = value;
      }
    }
    return normalized;
  }

  Map<String, dynamic> _rolePermissions(MemberRole role) {
    return {
      'permissions': List<String>.from(
          ChapterConstants.rolePermissions[role.name] ?? const []),
    };
  }

  Map<String, dynamic> _documentData(dynamic document) {
    final data = Map<String, dynamic>.from(document.data as Map);
    data['id'] = document.$id;
    return data;
  }

  List<String> _dateRangeQueries({
    required String orderKey,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final queries = <String>[Query.orderDesc(orderKey), Query.limit(500)];
    if (startDate != null) {
      queries.add(Query.greaterThanEqual(orderKey, _iso(startDate)));
    }
    if (endDate != null) {
      queries.add(Query.lessThanEqual(orderKey, _iso(endDate)));
    }
    return queries;
  }

  Map<String, dynamic> _stripNulls(Map<String, dynamic> data) {
    return Map<String, dynamic>.fromEntries(
      data.entries.where((entry) => entry.value != null),
    );
  }

  Map<String, dynamic> _decodeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.trim().isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    return <String, dynamic>{};
  }

  List<String> _stringList(dynamic value) {
    if (value is List) return value.map((item) => item.toString()).toList();
    return <String>[];
  }

  String _iso(DateTime date) => date.toUtc().toIso8601String();

  String? _nullableIso(DateTime? date) => date == null ? null : _iso(date);

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatMonth(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

extension ChapterServiceTaskAssignment on ChapterService {
  Future<TaskAssignment> createTaskAssignment({
    required String title,
    required String description,
    required String assignedById,
    required String assignedToId,
    required String chapterId,
    required DateTime dueDate,
    String priority = 'medium',
    String? teamId,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      final assignment = TaskAssignment(
        id: const Uuid().v4(),
        title: title,
        description: description,
        assignedById: assignedById,
        assignedToId: assignedToId,
        teamId: teamId,
        chapterId: chapterId,
        priority: priority,
        status: 'assigned',
        dueDate: dueDate,
        createdAt: now,
        updatedAt: now,
      );

      final document = await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: ChapterService._taskAssignmentsCollection,
        rowId: assignment.id,
        data: _taskAssignmentData(assignment),
      );
      return _taskAssignmentFromDocument(document);
    } catch (e) {
      throw DatabaseException('Failed to create task assignment',
          originalError: e);
    }
  }

  Future<List<TaskAssignment>> getChapterTaskAssignments(
      String chapterId) async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: ChapterService._taskAssignmentsCollection,
        queries: [
          Query.equal('chapter_id', chapterId),
          Query.orderAsc('due_date'),
          Query.limit(500),
        ],
      );
      return response.rows.map(_taskAssignmentFromDocument).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<TaskAssignment>> getUserTaskAssignments(String userId) async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: ChapterService._taskAssignmentsCollection,
        queries: [
          Query.equal('assigned_to_id', userId),
          Query.orderAsc('due_date'),
          Query.limit(500),
        ],
      );
      return response.rows.map(_taskAssignmentFromDocument).toList();
    } catch (e) {
      return [];
    }
  }
}
