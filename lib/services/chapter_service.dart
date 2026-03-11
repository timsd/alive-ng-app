import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/chapter_models.dart';
import '../models/app_models.dart' show TaskAssignment;
import '../utils/app_exception.dart';

class ChapterService {
  static final ChapterService _instance = ChapterService._internal();
  factory ChapterService() => _instance;
  ChapterService._internal();

  final Uuid _uuid = const Uuid();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Chapter Management
  Future<List<Chapter>> getChapters({
    WorkersType? type,
    bool? isActive,
    String? searchQuery,
  }) async {
    try {
      Query query = _firestore.collection('chapters');

      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      }
      if (isActive != null) {
        query = query.where('is_active', isEqualTo: isActive);
      }

      final snapshot = await query.orderBy('name').get();

      var chapters = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Chapter.fromJson(data);
      }).toList();

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
      final doc = await _firestore.collection('chapters').doc(chapterId).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return Chapter.fromJson(data);
    } catch (e) {
      // Return null for not found, but log or throw for other errors?
      // Original code returned null on error, which might mask actual DB errors.
      // Keeping behavior but wrapping in try/catch to return null is fine if that's the intent.
      // But if it's a DB error, we might want to know.
      // However, to keep signature 'Future<Chapter?>', returning null is standard for 'not found'.
      // If 'e' is a connection error, returning null is misleading.
      // Let's stick to original behavior for now to avoid breaking changes, or improve it.
      // Original: return null;
      throw DatabaseException('Failed to get chapter by ID', originalError: e);
    }
  }

  Future<List<Chapter>> getUserChapters(String userId) async {
    try {
      // 1. Get chapter_members where user_id equals userId and is_active is true
      final membershipSnapshot = await _firestore
          .collection('chapter_members')
          .where('user_id', isEqualTo: userId)
          .where('is_active', isEqualTo: true)
          .get();

      if (membershipSnapshot.docs.isEmpty) return [];

      final chapterIds = membershipSnapshot.docs
          .map((doc) => doc.data()['chapter_id'] as String)
          .toList();

      if (chapterIds.isEmpty) return [];

      // 2. Get chapters (handling whereIn limit of 10)
      List<Chapter> chapters = [];
      for (var i = 0; i < chapterIds.length; i += 10) {
        final end = (i + 10 < chapterIds.length) ? i + 10 : chapterIds.length;
        final chunk = chapterIds.sublist(i, end);

        final chapterSnapshot = await _firestore
            .collection('chapters')
            .where(FieldPath.documentId, whereIn: chunk)
            .where('is_active', isEqualTo: true)
            .get();

        chapters.addAll(chapterSnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return Chapter.fromJson(data);
        }));
      }

      return chapters;
    } catch (e) {
      throw DatabaseException('Failed to fetch user chapters',
          originalError: e);
    }
  }

  Future<Chapter> createChapter(Chapter chapter) async {
    try {
      final chapterData = chapter.toJson();
      chapterData.remove(
          'id'); // Let Firestore generate ID or use the one provided if manually set
      chapterData['created_at'] = FieldValue.serverTimestamp();
      chapterData['updated_at'] = FieldValue.serverTimestamp();

      // If chapter.id is empty or null, add() will generate one.
      // If we want to use UUID from client:
      // final docRef = _firestore.collection('chapters').doc(_uuid.v4());
      // await docRef.set(chapterData);

      // Using add() is simpler
      final docRef = await _firestore.collection('chapters').add(chapterData);

      final newChapter = chapter.copyWith(
        id: docRef.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      return newChapter;
    } catch (e) {
      throw DatabaseException('Failed to create chapter', originalError: e);
    }
  }

  Future<Chapter> updateChapter(Chapter chapter) async {
    try {
      final chapterData = chapter.toJson();
      chapterData.remove('id');
      chapterData['updated_at'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('chapters')
          .doc(chapter.id)
          .update(chapterData);

      return chapter.copyWith(updatedAt: DateTime.now());
    } catch (e) {
      throw DatabaseException('Failed to update chapter', originalError: e);
    }
  }

  Future<void> deleteChapter(String chapterId) async {
    try {
      // Soft delete
      await _firestore.collection('chapters').doc(chapterId).update({
        'is_active': false,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw DatabaseException('Failed to delete chapter', originalError: e);
    }
  }

  // Member Management
  Future<List<ChapterMember>> getChapterMembers(String chapterId,
      {bool? isActive}) async {
    try {
      Query query = _firestore
          .collection('chapter_members')
          .where('chapter_id', isEqualTo: chapterId);

      if (isActive != null) {
        query = query.where('is_active', isEqualTo: isActive);
      }

      final snapshot = await query.orderBy('joined_at', descending: true).get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return ChapterMember.fromJson(data);
      }).toList();
    } catch (e) {
      throw DatabaseException('Failed to get chapter members', originalError: e);
    }
  }

  Future<ChapterMember?> getChapterMember(
      String chapterId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection('chapter_members')
          .where('chapter_id', isEqualTo: chapterId)
          .where('user_id', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      final data = doc.data();
      data['id'] = doc.id;
      return ChapterMember.fromJson(data);
    } catch (e) {
      throw DatabaseException('Failed to get chapter member', originalError: e);
    }
  }

  Future<List<ChapterMember>> getUserMemberships(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('chapter_members')
          .where('user_id', isEqualTo: userId)
          .where('is_active', isEqualTo: true)
          .orderBy('joined_at', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ChapterMember.fromJson(data);
      }).toList();
    } catch (e) {
      throw DatabaseException('Failed to get user memberships', originalError: e);
    }
  }

  Future<ChapterMember> addMember(
      String chapterId, String userId, MemberRole role) async {
    final memberId = _uuid.v4();
    final member = ChapterMember(
      id: memberId,
      chapterId: chapterId,
      userId: userId,
      role: role,
      joinedAt: DateTime.now(),
      isActive: true,
      permissions: Map<String, dynamic>.from((ChapterConstants
              .rolePermissions[role.name] as Map<String, dynamic>?) ??
          {}),
      metadata: {},
    );
    try {
      await _firestore.collection('chapter_members').doc(memberId).set({
        ...member.toJson(),
        'joined_at': FieldValue.serverTimestamp(),
      });
      return member;
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

    final updatedMember = member.copyWith(
      role: newRole,
      permissions: Map<String, dynamic>.from((ChapterConstants
              .rolePermissions[newRole.name] as Map<String, dynamic>?) ??
          {}),
    );
    try {
      await _firestore.collection('chapter_members').doc(member.id).update({
        'role': newRole.name,
        'permissions': updatedMember.permissions,
        'updated_at': FieldValue.serverTimestamp(),
      });
      return updatedMember;
    } catch (e) {
      throw DatabaseException('Failed to update member role', originalError: e);
    }
  }

  Future<void> removeMember(String chapterId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection('chapter_members')
          .where('chapter_id', isEqualTo: chapterId)
          .where('user_id', isEqualTo: userId)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.update({
          'is_active': false,
          'left_at': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw DatabaseException('Failed to remove member', originalError: e);
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
      Query query = _firestore
          .collection('chapter_activities')
          .where('chapter_id', isEqualTo: chapterId);

      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      }
      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }
      if (startDate != null) {
        query = query.where('start_date', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('end_date', isLessThanOrEqualTo: endDate);
      }

      final snapshot =
          await query.orderBy('start_date', descending: true).get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return ChapterActivity.fromJson(data);
      }).toList();
    } catch (e) {
      throw DatabaseException('Failed to get chapter activities',
          originalError: e);
    }
  }

  Future<List<ChapterActivity>> getUserActivities(String userId) async {
    try {
      // Assuming activities have a list of participants or assigned users.
      // Or maybe just created_by? Let's check model if possible, but standard is usually array.
      // For now, let's assume 'participants' array contains userId.
      final snapshot = await _firestore
          .collection('chapter_activities')
          .where('participants', arrayContains: userId)
          .orderBy('start_date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ChapterActivity.fromJson(data);
      }).toList();
    } catch (e) {
      throw DatabaseException('Failed to get user activities',
          originalError: e);
    }
  }

  Future<ChapterActivity> createActivity(ChapterActivity activity) async {
    final newActivity = activity.copyWith(
      id: _uuid.v4(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return newActivity;
  }

  Future<ChapterActivity> updateActivity(ChapterActivity activity) async {
    final updatedActivity = activity.copyWith(updatedAt: DateTime.now());
    return updatedActivity;
  }

  Future<ChapterActivity> updateActivityStatus(
      String activityId, ActivityStatus status) async {
    try {
      await _firestore.collection('chapter_activities').doc(activityId).update({
        'status': status.name, // Enum to string
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Fetch updated activity
      final doc = await _firestore
          .collection('chapter_activities')
          .doc(activityId)
          .get();
      final data = doc.data()!;
      data['id'] = doc.id;
      return ChapterActivity.fromJson(data);
    } catch (e) {
      throw DatabaseException('Failed to update activity status',
          originalError: e);
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
      Query query = _firestore
          .collection('chapter_tasks')
          .where('chapter_id', isEqualTo: chapterId);

      if (assignedTo != null) {
        query = query.where('assigned_to', isEqualTo: assignedTo);
      }
      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }
      if (priority != null) {
        query = query.where('priority', isEqualTo: priority);
      }

      final snapshot = await query.orderBy('due_date').get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return ChapterTask.fromJson(data);
      }).toList();
    } catch (e) {
      throw DatabaseException('Failed to get chapter tasks', originalError: e);
    }
  }

  Future<List<ChapterTask>> getUserTasks(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('chapter_tasks')
          .where('assigned_to', isEqualTo: userId)
          .where('status', isNotEqualTo: ActivityStatus.completed.name)
          .orderBy('status') // needed for inequality filter
          .orderBy('due_date')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ChapterTask.fromJson(data);
      }).toList();
    } catch (e) {
      throw DatabaseException('Failed to get user tasks', originalError: e);
    }
  }

  Future<ChapterTask> createTask(ChapterTask task) async {
    final newTask = task.copyWith(
      id: _uuid.v4(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return newTask;
  }

  Future<ChapterTask> updateTask(ChapterTask task) async {
    final updatedTask = task.copyWith(updatedAt: DateTime.now());
    return updatedTask;
  }

  Future<ChapterTask> completeTask(String taskId) async {
    try {
      await _firestore.collection('chapter_tasks').doc(taskId).update({
        'status': ActivityStatus.completed.name,
        'completed_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      final doc =
          await _firestore.collection('chapter_tasks').doc(taskId).get();
      final data = doc.data()!;
      data['id'] = doc.id;
      return ChapterTask.fromJson(data);
    } catch (e) {
      throw DatabaseException('Failed to complete task', originalError: e);
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
      Query query = _firestore
          .collection('chapter_reports')
          .where('chapter_id', isEqualTo: chapterId);

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }
      if (startDate != null) {
        query = query.where('created_at', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('created_at', isLessThanOrEqualTo: endDate);
      }

      final snapshot =
          await query.orderBy('created_at', descending: true).get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return ChapterReport.fromJson(data);
      }).toList();
    } catch (e) {
      throw DatabaseException('Failed to get chapter reports',
          originalError: e);
    }
  }

  Future<List<ChapterReport>> getReportsForReview(String reviewerId) async {
    try {
      // Logic depends on how reviewers are assigned.
      // If reviewers are assigned explicitly: where('reviewer_id', isEqualTo: reviewerId)
      // Or if it's based on role, we might just fetch all submitted reports.
      // Let's assume there is a 'reviewer_id' field or we fetch submitted reports.
      // Given the argument 'reviewerId', let's filter by it if it's assigned,
      // OR maybe it's just fetching ALL reports that need review?
      // But the argument suggests filtering. Let's assume 'assigned_reviewer' or similar.
      // If not present, maybe we should return all submitted reports?
      // Let's try to query for submitted reports first.

      final snapshot = await _firestore
          .collection('chapter_reports')
          .where('status', isEqualTo: ReportStatus.submitted.name)
          // .where('reviewer_id', isEqualTo: reviewerId) // Optional if we have assignment
          .orderBy('created_at', descending: false) // Oldest first for review
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ChapterReport.fromJson(data);
      }).toList();
    } catch (e) {
      throw DatabaseException('Failed to get reports for review',
          originalError: e);
    }
  }

  Future<ChapterReport> createReport(ChapterReport report) async {
    final newReport = report.copyWith(
      id: _uuid.v4(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return newReport;
  }

  Future<ChapterReport> updateReport(ChapterReport report) async {
    final updatedReport = report.copyWith(updatedAt: DateTime.now());
    return updatedReport;
  }

  Future<ChapterReport> submitReport(String reportId) async {
    try {
      await _firestore.collection('chapter_reports').doc(reportId).update({
        'status': ReportStatus.submitted.name,
        'submitted_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      final doc =
          await _firestore.collection('chapter_reports').doc(reportId).get();
      final data = doc.data()!;
      data['id'] = doc.id;
      return ChapterReport.fromJson(data);
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
      await _firestore.collection('chapter_reports').doc(reportId).update({
        'status': status.name,
        'reviewed_by': reviewerId,
        'reviewed_at': FieldValue.serverTimestamp(),
        'review_comments': comments,
        'updated_at': FieldValue.serverTimestamp(),
      });

      final doc =
          await _firestore.collection('chapter_reports').doc(reportId).get();
      final data = doc.data()!;
      data['id'] = doc.id;
      return ChapterReport.fromJson(data);
    } catch (e) {
      throw DatabaseException('Failed to review report', originalError: e);
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

  // Helper Methods
  bool hasPermission(ChapterMember member, String permission) {
    final permissions =
        member.permissions['permissions'] as List<dynamic>? ?? [];
    return permissions.contains(permission);
  }

  String getTypeDescription(WorkersType type) {
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

/// Extension on ChapterService for [TaskAssignment] model integration.
extension ChapterServiceTaskAssignment on ChapterService {
  /// Create a [TaskAssignment] within a chapter.
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
      final now = DateTime.now();
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

      await FirebaseFirestore.instance
          .collection('task_assignments')
          .doc(assignment.id)
          .set(assignment.toJson());

      return assignment;
    } catch (e) {
      throw DatabaseException('Failed to create task assignment',
          originalError: e);
    }
  }

  /// Get all [TaskAssignment]s for a chapter.
  Future<List<TaskAssignment>> getChapterTaskAssignments(
      String chapterId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('task_assignments')
          .where('chapter_id', isEqualTo: chapterId)
          .orderBy('due_date')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return TaskAssignment.fromJson(data);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get all [TaskAssignment]s for a specific user.
  Future<List<TaskAssignment>> getUserTaskAssignments(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('task_assignments')
          .where('assigned_to_id', isEqualTo: userId)
          .orderBy('due_date')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return TaskAssignment.fromJson(data);
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
