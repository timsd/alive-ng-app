import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:uuid/uuid.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../models/discipleship_models.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';

class DiscipleshipService {
  static final DiscipleshipService _instance = DiscipleshipService._internal();
  factory DiscipleshipService() => _instance;
  DiscipleshipService._internal();

  final Uuid _uuid = const Uuid();
  final Logger _logger = Logger('DiscipleshipService');
  final TablesDB _tables = TablesDB(appwriteClient);

  static const _contactsCollection =
      AppwriteBackendConfig.discipleshipContactsCollectionId;
  static const _interactionsCollection =
      AppwriteBackendConfig.contactInteractionsCollectionId;
  static const _studySessionsCollection =
      AppwriteBackendConfig.discipleshipStudySessionsCollectionId;
  static const _prayerRequestsCollection =
      AppwriteBackendConfig.discipleshipPrayerRequestsCollectionId;
  static const _milestonesCollection =
      AppwriteBackendConfig.progressMilestonesCollectionId;
  static const _reportsCollection =
      AppwriteBackendConfig.discipleshipReportsCollectionId;

  Future<List<DiscipleshipContact>> getContacts({
    String? discipleMakerId,
    DiscipleshipLevel? level,
    bool? isActive,
    String? searchQuery,
  }) async {
    try {
      final queries = <String>[Query.orderDesc('updated_at')];
      if (discipleMakerId != null) {
        queries.add(Query.equal('disciple_maker_id', discipleMakerId));
      }
      if (level != null) {
        queries.add(Query.equal('current_level', level.name));
      }
      if (isActive != null) {
        queries.add(Query.equal('is_active', isActive));
      }

      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _contactsCollection,
        queries: queries,
      );

      var contacts = response.rows.map(_contactFromDocument).toList();
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        contacts = contacts.where((contact) {
          return contact.fullName.toLowerCase().contains(q) ||
              (contact.notes ?? '').toLowerCase().contains(q);
        }).toList();
      }

      return contacts;
    } catch (e) {
      _logger.error('Failed to fetch contacts', e);
      throw DatabaseException('Failed to fetch contacts', originalError: e);
    }
  }

  Future<DiscipleshipContact> getContactById(String contactId) async {
    try {
      final document = await _tables.getRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _contactsCollection,
        rowId: contactId,
      );
      return _contactFromDocument(document);
    } on AppwriteException catch (e) {
      if (e.code == 404) throw NotFoundException('Contact not found');
      _logger.error('Failed to get contact by id', e);
      throw DatabaseException('Failed to get contact', originalError: e);
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Failed to get contact by id', e);
      throw DatabaseException('Failed to get contact', originalError: e);
    }
  }

  Future<DiscipleshipContact> createContact(DiscipleshipContact contact) async {
    try {
      final now = DateTime.now().toUtc();
      final newContact = contact.copyWith(
        id: contact.id.isNotEmpty ? contact.id : _uuid.v4(),
        createdAt: now,
        updatedAt: now,
      );

      final document = await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _contactsCollection,
        rowId: newContact.id,
        data: _contactData(newContact),
      );
      return _contactFromDocument(document);
    } catch (e) {
      _logger.error('Failed to create contact', e);
      throw DatabaseException('Failed to create contact', originalError: e);
    }
  }

  Future<DiscipleshipContact> updateContact(DiscipleshipContact contact) async {
    try {
      final updatedContact =
          contact.copyWith(updatedAt: DateTime.now().toUtc());
      final document = await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _contactsCollection,
        rowId: updatedContact.id,
        data: _contactData(updatedContact),
      );
      return _contactFromDocument(document);
    } catch (e) {
      _logger.error('Failed to update contact', e);
      throw DatabaseException('Failed to update contact', originalError: e);
    }
  }

  Future<void> deleteContact(String contactId) async {
    try {
      await _tables.deleteRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _contactsCollection,
        rowId: contactId,
      );
    } catch (e) {
      _logger.error('Failed to delete contact', e);
      throw DatabaseException('Failed to delete contact', originalError: e);
    }
  }

  Future<DiscipleshipContact> updateContactLevel(
      String contactId, DiscipleshipLevel newLevel) async {
    try {
      final contact = await getContactById(contactId);
      final now = DateTime.now().toUtc();

      if (contact.currentLevel != newLevel) {
        await createProgressMilestone(ProgressMilestone(
          id: _uuid.v4(),
          contactId: contactId,
          fromLevel: contact.currentLevel,
          toLevel: newLevel,
          date: now,
          createdAt: now,
        ));
      }

      return updateContact(contact.copyWith(
        currentLevel: newLevel,
        lastContact: now,
        baptismDate:
            newLevel == DiscipleshipLevel.baptized ? now : contact.baptismDate,
      ));
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Failed to update contact level', e);
      throw DatabaseException('Failed to update contact level',
          originalError: e);
    }
  }

  Future<List<ContactInteraction>> getInteractions({
    String? contactId,
    String? discipleMakerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queries = _dateRangeQueries(
        orderKey: 'date',
        startDate: startDate,
        endDate: endDate,
      );
      if (contactId != null) queries.add(Query.equal('contact_id', contactId));
      if (discipleMakerId != null) {
        queries.add(Query.equal('disciple_maker_id', discipleMakerId));
      }

      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _interactionsCollection,
        queries: queries,
      );
      return response.rows.map(_interactionFromDocument).toList();
    } catch (e) {
      _logger.error('Failed to fetch interactions', e);
      throw DatabaseException('Failed to fetch interactions', originalError: e);
    }
  }

  Future<ContactInteraction> createInteraction(
      ContactInteraction interaction) async {
    try {
      final newInteraction = ContactInteraction(
        id: interaction.id.isNotEmpty ? interaction.id : _uuid.v4(),
        contactId: interaction.contactId,
        discipleMakerId: interaction.discipleMakerId,
        method: interaction.method,
        title: interaction.title,
        description: interaction.description,
        date: interaction.date,
        durationMinutes: interaction.durationMinutes,
        outcome: interaction.outcome,
        nextSteps: interaction.nextSteps,
        attachments: interaction.attachments,
        createdAt: DateTime.now().toUtc(),
      );

      final document = await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _interactionsCollection,
        rowId: newInteraction.id,
        data: _interactionData(newInteraction),
      );

      await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _contactsCollection,
        rowId: interaction.contactId,
        data: {
          'last_contact': _iso(interaction.date),
          'updated_at': _iso(DateTime.now()),
        },
      );

      return _interactionFromDocument(document);
    } catch (e) {
      _logger.error('Failed to create interaction', e);
      throw DatabaseException('Failed to create interaction', originalError: e);
    }
  }

  Future<List<StudySession>> getStudySessions({
    String? contactId,
    String? discipleMakerId,
    StudyType? type,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queries = _dateRangeQueries(
        orderKey: 'date',
        startDate: startDate,
        endDate: endDate,
      );
      if (contactId != null) queries.add(Query.equal('contact_id', contactId));
      if (discipleMakerId != null) {
        queries.add(Query.equal('disciple_maker_id', discipleMakerId));
      }
      if (type != null) queries.add(Query.equal('type', type.name));

      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _studySessionsCollection,
        queries: queries,
      );
      return response.rows.map(_studySessionFromDocument).toList();
    } catch (e) {
      _logger.error('Failed to fetch study sessions', e);
      throw DatabaseException('Failed to fetch study sessions',
          originalError: e);
    }
  }

  Future<StudySession> createStudySession(StudySession session) async {
    try {
      final newSession = StudySession(
        id: session.id.isNotEmpty ? session.id : _uuid.v4(),
        contactId: session.contactId,
        discipleMakerId: session.discipleMakerId,
        type: session.type,
        title: session.title,
        topic: session.topic,
        bibleTexts: session.bibleTexts,
        date: session.date,
        durationMinutes: session.durationMinutes,
        notes: session.notes,
        homework: session.homework,
        rating: session.rating,
        completed: session.completed,
        createdAt: DateTime.now().toUtc(),
      );

      final document = await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _studySessionsCollection,
        rowId: newSession.id,
        data: _studySessionData(newSession),
      );
      return _studySessionFromDocument(document);
    } catch (e) {
      _logger.error('Failed to create study session', e);
      throw DatabaseException('Failed to create study session',
          originalError: e);
    }
  }

  Future<StudySession> updateStudySession(StudySession session) async {
    try {
      final document = await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _studySessionsCollection,
        rowId: session.id,
        data: _studySessionData(session),
      );
      return _studySessionFromDocument(document);
    } catch (e) {
      _logger.error('Failed to update study session', e);
      throw DatabaseException('Failed to update study session',
          originalError: e);
    }
  }

  Future<List<PrayerRequest>> getPrayerRequests({
    String? contactId,
    String? discipleMakerId,
    PrayerRequestStatus? status,
  }) async {
    try {
      final queries = <String>[Query.orderDesc('date_requested')];
      if (contactId != null) queries.add(Query.equal('contact_id', contactId));
      if (discipleMakerId != null) {
        queries.add(Query.equal('disciple_maker_id', discipleMakerId));
      }
      if (status != null) queries.add(Query.equal('status', status.name));

      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _prayerRequestsCollection,
        queries: queries,
      );
      return response.rows.map(_prayerRequestFromDocument).toList();
    } catch (e) {
      _logger.error('Failed to fetch prayer requests', e);
      throw DatabaseException('Failed to fetch prayer requests',
          originalError: e);
    }
  }

  Future<PrayerRequest> createPrayerRequest(PrayerRequest request) async {
    try {
      final now = DateTime.now().toUtc();
      final newRequest = PrayerRequest(
        id: request.id.isNotEmpty ? request.id : _uuid.v4(),
        contactId: request.contactId,
        discipleMakerId: request.discipleMakerId,
        request: request.request,
        category: request.category,
        status: request.status,
        dateRequested: request.dateRequested,
        dateAnswered: request.dateAnswered,
        answer: request.answer,
        notes: request.notes,
        createdAt: now,
        updatedAt: now,
      );

      final document = await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _prayerRequestsCollection,
        rowId: newRequest.id,
        data: _prayerRequestData(newRequest),
      );
      return _prayerRequestFromDocument(document);
    } catch (e) {
      _logger.error('Failed to create prayer request', e);
      throw DatabaseException('Failed to create prayer request',
          originalError: e);
    }
  }

  Future<PrayerRequest> updatePrayerRequest(PrayerRequest request) async {
    try {
      final updatedRequest = PrayerRequest(
        id: request.id,
        contactId: request.contactId,
        discipleMakerId: request.discipleMakerId,
        request: request.request,
        category: request.category,
        status: request.status,
        dateRequested: request.dateRequested,
        dateAnswered: request.dateAnswered,
        answer: request.answer,
        notes: request.notes,
        createdAt: request.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );

      final document = await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _prayerRequestsCollection,
        rowId: updatedRequest.id,
        data: _prayerRequestData(updatedRequest),
      );
      return _prayerRequestFromDocument(document);
    } catch (e) {
      _logger.error('Failed to update prayer request', e);
      throw DatabaseException('Failed to update prayer request',
          originalError: e);
    }
  }

  Future<List<ProgressMilestone>> getProgressMilestones(
      String contactId) async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _milestonesCollection,
        queries: [
          Query.equal('contact_id', contactId),
          Query.orderDesc('date'),
        ],
      );
      return response.rows.map(_milestoneFromDocument).toList();
    } catch (e) {
      _logger.error('Failed to fetch progress milestones', e);
      throw DatabaseException('Failed to fetch progress milestones',
          originalError: e);
    }
  }

  Future<ProgressMilestone> createProgressMilestone(
      ProgressMilestone milestone) async {
    try {
      final id = milestone.id.isNotEmpty ? milestone.id : _uuid.v4();
      final document = await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _milestonesCollection,
        rowId: id,
        data: _milestoneData(milestone),
      );
      return _milestoneFromDocument(document);
    } catch (e) {
      _logger.error('Failed to create progress milestone', e);
      throw DatabaseException('Failed to create progress milestone',
          originalError: e);
    }
  }

  Future<List<DiscipleshipReport>> getReports({
    String? discipleMakerId,
    String? supervisorId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queries = _dateRangeQueries(
        orderKey: 'created_at',
        startKey: 'report_period_start',
        endKey: 'report_period_end',
        startDate: startDate,
        endDate: endDate,
      );
      if (discipleMakerId != null) {
        queries.add(Query.equal('disciple_maker_id', discipleMakerId));
      }
      if (supervisorId != null) {
        queries.add(Query.equal('supervisor_id', supervisorId));
      }

      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _reportsCollection,
        queries: queries,
      );
      return response.rows.map(_reportFromDocument).toList();
    } catch (e) {
      _logger.error('Failed to fetch reports', e);
      throw DatabaseException('Failed to fetch reports', originalError: e);
    }
  }

  Future<DiscipleshipReport> generateReport({
    required String discipleMakerId,
    String? supervisorId,
    required DateTime startDate,
    required DateTime endDate,
    required ReportFrequency frequency,
    String? highlights,
    String? challenges,
    String? prayerRequests,
    String? goals,
  }) async {
    try {
      final contacts = await getContacts(discipleMakerId: discipleMakerId);
      final interactions = await getInteractions(
        discipleMakerId: discipleMakerId,
        startDate: startDate,
        endDate: endDate,
      );
      final studySessions = await getStudySessions(
        discipleMakerId: discipleMakerId,
        startDate: startDate,
        endDate: endDate,
      );

      final endInclusive = endDate.add(const Duration(days: 1));
      final report = DiscipleshipReport(
        id: _uuid.v4(),
        discipleMakerId: discipleMakerId,
        supervisorId: supervisorId,
        reportPeriodStart: startDate,
        reportPeriodEnd: endDate,
        totalContacts: contacts.length,
        activeContacts: contacts.where((c) => c.isActive).length,
        newContacts: contacts
            .where((c) =>
                c.firstContact.isAfter(startDate) &&
                c.firstContact.isBefore(endInclusive))
            .length,
        baptisms: contacts
            .where((c) =>
                c.baptismDate != null &&
                c.baptismDate!.isAfter(startDate) &&
                c.baptismDate!.isBefore(endInclusive))
            .length,
        studySessions: studySessions.length,
        interactions: interactions.length,
        highlights: highlights,
        challenges: challenges,
        prayerRequests: prayerRequests,
        goals: goals,
        frequency: frequency,
        createdAt: DateTime.now().toUtc(),
      );

      final document = await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _reportsCollection,
        rowId: report.id,
        data: _reportData(report),
      );
      return _reportFromDocument(document);
    } catch (e) {
      _logger.error('Failed to generate report', e);
      throw DatabaseException('Failed to generate report', originalError: e);
    }
  }

  Future<DiscipleshipReport> submitReport(String reportId) async {
    try {
      final document = await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _reportsCollection,
        rowId: reportId,
        data: {'submitted_at': _iso(DateTime.now())},
      );
      return _reportFromDocument(document);
    } catch (e) {
      _logger.error('Failed to submit report', e);
      throw DatabaseException('Failed to submit report', originalError: e);
    }
  }

  Future<DiscipleshipStatistics> getDiscipleshipStatistics(
      String discipleMakerId) async {
    try {
      final contacts = await getContacts(discipleMakerId: discipleMakerId);
      final interactions =
          await getInteractions(discipleMakerId: discipleMakerId);
      final studySessions =
          await getStudySessions(discipleMakerId: discipleMakerId);
      final prayerRequests =
          await getPrayerRequests(discipleMakerId: discipleMakerId);

      final levelCounts = <String, int>{};
      for (final level in DiscipleshipLevel.values) {
        levelCounts[level.name] =
            contacts.where((c) => c.currentLevel == level).length;
      }

      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final recentInteractions =
          interactions.where((i) => i.date.isAfter(thirtyDaysAgo)).length;
      final recentStudySessions =
          studySessions.where((s) => s.date.isAfter(thirtyDaysAgo)).length;
      final ratedSessions = studySessions.where((s) => s.rating != null);

      return DiscipleshipStatistics(
        totalContacts: contacts.length,
        activeContacts: contacts.where((c) => c.isActive).length,
        totalBaptisms: contacts
            .where((c) =>
                c.currentLevel == DiscipleshipLevel.baptized ||
                c.currentLevel == DiscipleshipLevel.disciple ||
                c.currentLevel == DiscipleshipLevel.leader)
            .length,
        levelDistribution: levelCounts,
        totalInteractions: interactions.length,
        totalStudySessions: studySessions.length,
        totalPrayerRequests: prayerRequests.length,
        answeredPrayers: prayerRequests
            .where((p) => p.status == PrayerRequestStatus.answered)
            .length,
        recentInteractions: recentInteractions,
        recentStudySessions: recentStudySessions,
        averageStudyRating: ratedSessions.isEmpty
            ? 0.0
            : ratedSessions.map((s) => s.rating!).reduce((a, b) => a + b) /
                ratedSessions.length,
      );
    } catch (e) {
      _logger.error('Failed to get discipleship statistics', e);
      throw DatabaseException('Failed to get discipleship statistics',
          originalError: e);
    }
  }

  String getNextStepsForLevel(DiscipleshipLevel level) {
    return DiscipleshipConstants.nextSteps[level] ??
        'Continue building relationship';
  }

  String getLevelDescription(DiscipleshipLevel level) {
    return DiscipleshipConstants.levelDescriptions[level] ?? 'Unknown level';
  }

  List<String> getStudyTopics() => DiscipleshipConstants.studyTopics;

  List<String> getPrayerCategories() => DiscipleshipConstants.prayerCategories;

  String getBibleVerse(String key) =>
      DiscipleshipConstants.bibleVerses[key] ?? '';

  DiscipleshipContact _contactFromDocument(dynamic document) {
    final data = _documentData(document);
    data['custom_fields'] = _decodeJsonMap(data['custom_fields']);
    data['tags'] = _stringList(data['tags']);
    return DiscipleshipContact.fromJson(data);
  }

  ContactInteraction _interactionFromDocument(dynamic document) {
    final data = _documentData(document);
    data['attachments'] = _stringList(data['attachments']);
    return ContactInteraction.fromJson(data);
  }

  StudySession _studySessionFromDocument(dynamic document) {
    return StudySession.fromJson(_documentData(document));
  }

  PrayerRequest _prayerRequestFromDocument(dynamic document) {
    return PrayerRequest.fromJson(_documentData(document));
  }

  ProgressMilestone _milestoneFromDocument(dynamic document) {
    return ProgressMilestone.fromJson(_documentData(document));
  }

  DiscipleshipReport _reportFromDocument(dynamic document) {
    return DiscipleshipReport.fromJson(_documentData(document));
  }

  Map<String, dynamic> _contactData(DiscipleshipContact contact) {
    return _stripNulls({
      'disciple_maker_id': contact.discipleMakerId,
      'first_name': contact.firstName,
      'last_name': contact.lastName,
      'email': contact.email,
      'phone': contact.phone,
      'address': contact.address,
      'date_of_birth': _nullableIso(contact.dateOfBirth),
      'occupation': contact.occupation,
      'interests': contact.interests,
      'current_level': contact.currentLevel.name,
      'first_contact': _iso(contact.firstContact),
      'last_contact': _nullableIso(contact.lastContact),
      'baptism_date': _nullableIso(contact.baptismDate),
      'notes': contact.notes,
      'is_active': contact.isActive,
      'tags': contact.tags,
      'custom_fields': jsonEncode(contact.customFields),
      'created_at': _iso(contact.createdAt),
      'updated_at': _iso(contact.updatedAt),
    });
  }

  Map<String, dynamic> _interactionData(ContactInteraction interaction) {
    return _stripNulls({
      'contact_id': interaction.contactId,
      'disciple_maker_id': interaction.discipleMakerId,
      'method': interaction.method.name,
      'title': interaction.title,
      'description': interaction.description,
      'date': _iso(interaction.date),
      'duration_minutes': interaction.durationMinutes,
      'outcome': interaction.outcome,
      'next_steps': interaction.nextSteps,
      'attachments': interaction.attachments,
      'created_at': _iso(interaction.createdAt),
    });
  }

  Map<String, dynamic> _studySessionData(StudySession session) {
    return _stripNulls({
      'contact_id': session.contactId,
      'disciple_maker_id': session.discipleMakerId,
      'type': session.type.name,
      'title': session.title,
      'topic': session.topic,
      'bible_texts': session.bibleTexts,
      'date': _iso(session.date),
      'duration_minutes': session.durationMinutes,
      'notes': session.notes,
      'homework': session.homework,
      'rating': session.rating,
      'completed': session.completed,
      'created_at': _iso(session.createdAt),
    });
  }

  Map<String, dynamic> _prayerRequestData(PrayerRequest request) {
    return _stripNulls({
      'contact_id': request.contactId,
      'disciple_maker_id': request.discipleMakerId,
      'request': request.request,
      'category': request.category,
      'status': request.status.name,
      'date_requested': _iso(request.dateRequested),
      'date_answered': _nullableIso(request.dateAnswered),
      'answer': request.answer,
      'notes': request.notes,
      'created_at': _iso(request.createdAt),
      'updated_at': _iso(request.updatedAt),
    });
  }

  Map<String, dynamic> _milestoneData(ProgressMilestone milestone) {
    return _stripNulls({
      'contact_id': milestone.contactId,
      'from_level': milestone.fromLevel.name,
      'to_level': milestone.toLevel.name,
      'date': _iso(milestone.date),
      'notes': milestone.notes,
      'celebration_plan': milestone.celebrationPlan,
      'created_at': _iso(milestone.createdAt),
    });
  }

  Map<String, dynamic> _reportData(DiscipleshipReport report) {
    return _stripNulls({
      'disciple_maker_id': report.discipleMakerId,
      'supervisor_id': report.supervisorId,
      'report_period_start': _iso(report.reportPeriodStart),
      'report_period_end': _iso(report.reportPeriodEnd),
      'total_contacts': report.totalContacts,
      'active_contacts': report.activeContacts,
      'new_contacts': report.newContacts,
      'baptisms': report.baptisms,
      'study_sessions': report.studySessions,
      'interactions': report.interactions,
      'highlights': report.highlights,
      'challenges': report.challenges,
      'prayer_requests': report.prayerRequests,
      'goals': report.goals,
      'frequency': report.frequency.name,
      'created_at': _iso(report.createdAt),
      'submitted_at': _nullableIso(report.submittedAt),
    });
  }

  Map<String, dynamic> _documentData(dynamic document) {
    final data = Map<String, dynamic>.from(document.data as Map);
    data['id'] = document.$id;
    return data;
  }

  List<String> _dateRangeQueries({
    required String orderKey,
    String? startKey,
    String? endKey,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final queries = <String>[Query.orderDesc(orderKey)];
    if (startDate != null) {
      queries
          .add(Query.greaterThanEqual(startKey ?? orderKey, _iso(startDate)));
    }
    if (endDate != null) {
      queries.add(Query.lessThanEqual(endKey ?? orderKey, _iso(endDate)));
    }
    return queries;
  }

  Map<String, dynamic> _stripNulls(Map<String, dynamic> data) {
    return Map<String, dynamic>.fromEntries(
      data.entries.where((entry) => entry.value != null),
    );
  }

  String _iso(DateTime date) => date.toUtc().toIso8601String();

  String? _nullableIso(DateTime? date) => date == null ? null : _iso(date);

  Map<String, dynamic> _decodeJsonMap(dynamic value) {
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
}
