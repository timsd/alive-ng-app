import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/chapter_models.dart';

class ChapterService {
  static final ChapterService _instance = ChapterService._internal();
  factory ChapterService() => _instance;
  ChapterService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  // Chapter Management
  Future<List<Chapter>> getChapters({
    ChapterType? type,
    bool? isActive,
    String? searchQuery,
  }) async {
    try {
      dynamic query = _supabase.from('chapters').select();

      if (type != null) {
        query = query.eq('type', type.name);
      }

      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query
            .or('name.ilike.%$searchQuery%,description.ilike.%$searchQuery%');
      }

      query = query.order('name');

      final response = await query;
      return response.map<Chapter>((json) => Chapter.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch chapters: $e');
    }
  }

  Future<Chapter?> getChapterById(String chapterId) async {
    try {
      final response = await _supabase
          .from('chapters')
          .select()
          .eq('id', chapterId)
          .single();

      return Chapter.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<List<Chapter>> getUserChapters(String userId) async {
    try {
      // Get chapters where user is a member
      final membershipResponse = await _supabase
          .from('chapter_members')
          .select('chapter_id')
          .eq('user_id', userId)
          .eq('is_active', true);

      final chapterIds = membershipResponse
          .map<String>((row) => row['chapter_id'] as String)
          .toList();

      if (chapterIds.isEmpty) return [];

      final chaptersResponse = await _supabase
          .from('chapters')
          .select()
          .inFilter('id', chapterIds)
          .eq('is_active', true)
          .order('name');

      return chaptersResponse
          .map<Chapter>((json) => Chapter.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch user chapters: $e');
    }
  }

  Future<Chapter> createChapter(Chapter chapter) async {
    try {
      final newChapter = chapter.copyWith(
        id: _uuid.v4(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _supabase.from('chapters').insert(newChapter.toJson());
      return newChapter;
    } catch (e) {
      throw Exception('Failed to create chapter: $e');
    }
  }

  Future<Chapter> updateChapter(Chapter chapter) async {
    try {
      final updatedChapter = chapter.copyWith(updatedAt: DateTime.now());

      await _supabase
          .from('chapters')
          .update(updatedChapter.toJson())
          .eq('id', chapter.id);

      return updatedChapter;
    } catch (e) {
      throw Exception('Failed to update chapter: $e');
    }
  }

  Future<void> deleteChapter(String chapterId) async {
    try {
      await _supabase.from('chapters').update({
        'is_active': false,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', chapterId);
    } catch (e) {
      throw Exception('Failed to delete chapter: $e');
    }
  }

  // Member Management
  Future<List<ChapterMember>> getChapterMembers(String chapterId,
      {bool? isActive}) async {
    try {
      var query = _supabase
          .from('chapter_members')
          .select()
          .eq('chapter_id', chapterId);

      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      query = query.order('joined_at');

      final response = await query;
      return response
          .map<ChapterMember>((json) => ChapterMember.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch chapter members: $e');
    }
  }

  Future<ChapterMember?> getChapterMember(
      String chapterId, String userId) async {
    try {
      final response = await _supabase
          .from('chapter_members')
          .select()
          .eq('chapter_id', chapterId)
          .eq('user_id', userId)
          .eq('is_active', true)
          .single();

      return ChapterMember.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<List<ChapterMember>> getUserMemberships(String userId) async {
    try {
      final response = await _supabase
          .from('chapter_members')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('joined_at', ascending: false);

      return response
          .map<ChapterMember>((json) => ChapterMember.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch user memberships: $e');
    }
  }

  Future<ChapterMember> addMember(
      String chapterId, String userId, MemberRole role) async {
    try {
      // Check if member already exists
      final existingMember = await getChapterMember(chapterId, userId);
      if (existingMember != null) {
        throw Exception('User is already a member of this chapter');
      }

      final member = ChapterMember(
        id: _uuid.v4(),
        chapterId: chapterId,
        userId: userId,
        role: role,
        joinedAt: DateTime.now(),
        isActive: true,
        permissions: Map<String, dynamic>.from(
            ChapterConstants.rolePermissions[role.name] ?? []),
        metadata: {},
      );

      await _supabase.from('chapter_members').insert(member.toJson());
      return member;
    } catch (e) {
      throw Exception('Failed to add member: $e');
    }
  }

  Future<ChapterMember> updateMemberRole(
      String chapterId, String userId, MemberRole newRole) async {
    try {
      final member = await getChapterMember(chapterId, userId);
      if (member == null) {
        throw Exception('Member not found');
      }

      final updatedMember = member.copyWith(
        role: newRole,
        permissions: Map<String, dynamic>.from(
            ChapterConstants.rolePermissions[newRole.name] ?? []),
      );

      await _supabase
          .from('chapter_members')
          .update(updatedMember.toJson())
          .eq('id', member.id);

      return updatedMember;
    } catch (e) {
      throw Exception('Failed to update member role: $e');
    }
  }

  Future<void> removeMember(String chapterId, String userId) async {
    try {
      await _supabase
          .from('chapter_members')
          .update({
            'is_active': false,
            'left_at': DateTime.now().toIso8601String(),
          })
          .eq('chapter_id', chapterId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to remove member: $e');
    }
  }

  // Activity Management
  Future<List<ChapterActivity>> getChapterActivities(
    String chapterId, {
    ActivityType? type,
    ActivityStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabase
          .from('chapter_activities')
          .select()
          .eq('chapter_id', chapterId);

      if (type != null) {
        query = query.eq('type', type.name);
      }

      if (status != null) {
        query = query.eq('status', status.name);
      }

      if (startDate != null) {
        query = query.gte('scheduled_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('scheduled_at', endDate.toIso8601String());
      }

      query = query.order('scheduled_at');

      final response = await query;
      return response
          .map<ChapterActivity>((json) => ChapterActivity.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch chapter activities: $e');
    }
  }

  Future<List<ChapterActivity>> getUserActivities(String userId) async {
    try {
      final response = await _supabase
          .from('chapter_activities')
          .select()
          .contains('assigned_member_ids', [userId]).order('scheduled_at');

      return response
          .map<ChapterActivity>((json) => ChapterActivity.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch user activities: $e');
    }
  }

  Future<ChapterActivity> createActivity(ChapterActivity activity) async {
    try {
      final newActivity = activity.copyWith(
        id: _uuid.v4(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _supabase.from('chapter_activities').insert(newActivity.toJson());
      return newActivity;
    } catch (e) {
      throw Exception('Failed to create activity: $e');
    }
  }

  Future<ChapterActivity> updateActivity(ChapterActivity activity) async {
    try {
      final updatedActivity = activity.copyWith(updatedAt: DateTime.now());

      await _supabase
          .from('chapter_activities')
          .update(updatedActivity.toJson())
          .eq('id', activity.id);

      return updatedActivity;
    } catch (e) {
      throw Exception('Failed to update activity: $e');
    }
  }

  Future<ChapterActivity> updateActivityStatus(
      String activityId, ActivityStatus status) async {
    try {
      final updates = {
        'status': status.name,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (status == ActivityStatus.ongoing) {
        updates['started_at'] = DateTime.now().toIso8601String();
      } else if (status == ActivityStatus.completed) {
        updates['completed_at'] = DateTime.now().toIso8601String();
      }

      await _supabase
          .from('chapter_activities')
          .update(updates)
          .eq('id', activityId);

      // Fetch and return updated activity
      final response = await _supabase
          .from('chapter_activities')
          .select()
          .eq('id', activityId)
          .single();

      return ChapterActivity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update activity status: $e');
    }
  }

  // Task Management
  Future<List<ChapterTask>> getChapterTasks(
    String chapterId, {
    String? assignedTo,
    ActivityStatus? status,
    int? priority,
  }) async {
    try {
      var query =
          _supabase.from('chapter_tasks').select().eq('chapter_id', chapterId);

      if (assignedTo != null) {
        query = query.eq('assigned_to', assignedTo);
      }

      if (status != null) {
        query = query.eq('status', status.name);
      }

      if (priority != null) {
        query = query.eq('priority', priority);
      }

      query = query.order('priority', ascending: false).order('due_date');

      final response = await query;
      return response
          .map<ChapterTask>((json) => ChapterTask.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch chapter tasks: $e');
    }
  }

  Future<List<ChapterTask>> getUserTasks(String userId) async {
    try {
      final response = await _supabase
          .from('chapter_tasks')
          .select()
          .eq('assigned_to', userId)
          .neq('status', ActivityStatus.completed.name)
          .order('priority', ascending: false)
          .order('due_date');

      return response
          .map<ChapterTask>((json) => ChapterTask.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch user tasks: $e');
    }
  }

  Future<ChapterTask> createTask(ChapterTask task) async {
    try {
      final newTask = task.copyWith(
        id: _uuid.v4(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _supabase.from('chapter_tasks').insert(newTask.toJson());
      return newTask;
    } catch (e) {
      throw Exception('Failed to create task: $e');
    }
  }

  Future<ChapterTask> updateTask(ChapterTask task) async {
    try {
      final updatedTask = task.copyWith(updatedAt: DateTime.now());

      await _supabase
          .from('chapter_tasks')
          .update(updatedTask.toJson())
          .eq('id', task.id);

      return updatedTask;
    } catch (e) {
      throw Exception('Failed to update task: $e');
    }
  }

  Future<ChapterTask> completeTask(String taskId) async {
    try {
      await _supabase.from('chapter_tasks').update({
        'status': ActivityStatus.completed.name,
        'completed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', taskId);

      // Fetch and return updated task
      final response = await _supabase
          .from('chapter_tasks')
          .select()
          .eq('id', taskId)
          .single();

      return ChapterTask.fromJson(response);
    } catch (e) {
      throw Exception('Failed to complete task: $e');
    }
  }

  // Report Management
  Future<List<ChapterReport>> getChapterReports(
    String chapterId, {
    ReportStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabase
          .from('chapter_reports')
          .select()
          .eq('chapter_id', chapterId);

      if (status != null) {
        query = query.eq('status', status.name);
      }

      if (startDate != null) {
        query = query.gte('report_period_start', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('report_period_end', endDate.toIso8601String());
      }

      query = query.order('created_at', ascending: false);

      final response = await query;
      return response
          .map<ChapterReport>((json) => ChapterReport.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch chapter reports: $e');
    }
  }

  Future<List<ChapterReport>> getReportsForReview(String reviewerId) async {
    try {
      final response = await _supabase
          .from('chapter_reports')
          .select()
          .eq('status', ReportStatus.submitted.name)
          .order('submitted_at');

      return response
          .map<ChapterReport>((json) => ChapterReport.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch reports for review: $e');
    }
  }

  Future<ChapterReport> createReport(ChapterReport report) async {
    try {
      final newReport = report.copyWith(
        id: _uuid.v4(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _supabase.from('chapter_reports').insert(newReport.toJson());
      return newReport;
    } catch (e) {
      throw Exception('Failed to create report: $e');
    }
  }

  Future<ChapterReport> updateReport(ChapterReport report) async {
    try {
      final updatedReport = report.copyWith(updatedAt: DateTime.now());

      await _supabase
          .from('chapter_reports')
          .update(updatedReport.toJson())
          .eq('id', report.id);

      return updatedReport;
    } catch (e) {
      throw Exception('Failed to update report: $e');
    }
  }

  Future<ChapterReport> submitReport(String reportId) async {
    try {
      await _supabase.from('chapter_reports').update({
        'status': ReportStatus.submitted.name,
        'submitted_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', reportId);

      // Fetch and return updated report
      final response = await _supabase
          .from('chapter_reports')
          .select()
          .eq('id', reportId)
          .single();

      return ChapterReport.fromJson(response);
    } catch (e) {
      throw Exception('Failed to submit report: $e');
    }
  }

  Future<ChapterReport> reviewReport(
    String reportId,
    String reviewerId,
    ReportStatus status,
    String? comments,
  ) async {
    try {
      await _supabase.from('chapter_reports').update({
        'status': status.name,
        'reviewed_by': reviewerId,
        'reviewed_at': DateTime.now().toIso8601String(),
        'review_comments': comments,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', reportId);

      // Fetch and return updated report
      final response = await _supabase
          .from('chapter_reports')
          .select()
          .eq('id', reportId)
          .single();

      return ChapterReport.fromJson(response);
    } catch (e) {
      throw Exception('Failed to review report: $e');
    }
  }

  // Statistics and Analytics
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

      // Calculate activity statistics
      final completedActivities =
          activities.where((a) => a.status == ActivityStatus.completed).length;
      final ongoingActivities =
          activities.where((a) => a.status == ActivityStatus.ongoing).length;
      final plannedActivities =
          activities.where((a) => a.status == ActivityStatus.planned).length;

      // Calculate task statistics
      final completedTasks =
          tasks.where((t) => t.status == ActivityStatus.completed).length;
      final pendingTasks =
          tasks.where((t) => t.status != ActivityStatus.completed).length;

      // Calculate report statistics
      final submittedReports =
          reports.where((r) => r.status == ReportStatus.submitted).length;
      final approvedReports =
          reports.where((r) => r.status == ReportStatus.approved).length;

      // Role distribution
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
      throw Exception('Failed to get chapter statistics: $e');
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
      throw Exception('Failed to get user chapter statistics: $e');
    }
  }

  // Helper Methods
  bool hasPermission(ChapterMember member, String permission) {
    final permissions =
        member.permissions['permissions'] as List<dynamic>? ?? [];
    return permissions.contains(permission);
  }

  String getTypeDescription(ChapterType type) {
    return ChapterConstants.typeDescriptions[type] ?? 'Chapter';
  }

  String getRoleDescription(MemberRole role) {
    return ChapterConstants.roleDescriptions[role] ?? 'Member';
  }

  String getActivityDescription(ActivityType type) {
    return ChapterConstants.activityDescriptions[type] ?? 'Activity';
  }

  List<String> getDefaultTags() {
    return ChapterConstants.defaultTags;
  }

  String getReportTemplate(String templateType) {
    return ChapterConstants.reportTemplates[templateType] ?? 'Report Template';
  }

  String getBibleVerse(int index) {
    if (index >= 0 && index < ChapterConstants.bibleVerses.length) {
      return ChapterConstants.bibleVerses[index];
    }
    return ChapterConstants.bibleVerses[0];
  }

  // Generate automatic reports
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
        submittedBy: '', // Will be set when submitted
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      return await createReport(report);
    } catch (e) {
      throw Exception('Failed to generate monthly report: $e');
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
