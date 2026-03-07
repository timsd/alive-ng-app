// Using Firebase for discipleship data
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/discipleship_models.dart';
import '../utils/logger.dart';
import '../utils/app_exception.dart';

class DiscipleshipService {
  static final DiscipleshipService _instance = DiscipleshipService._internal();
  factory DiscipleshipService() => _instance;
  DiscipleshipService._internal();

  final Uuid _uuid = const Uuid();
  final Logger _logger = Logger('DiscipleshipService');

  // Contact Management
  Future<List<DiscipleshipContact>> getContacts({
    String? discipleMakerId,
    DiscipleshipLevel? level,
    bool? isActive,
    String? searchQuery,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          FirebaseFirestore.instance.collection('discipleship_contacts');

      if (discipleMakerId != null) {
        query = query.where('disciple_maker_id', isEqualTo: discipleMakerId);
      }
      if (level != null) {
        query = query.where('current_level', isEqualTo: level.name);
      }
      if (isActive != null) {
        query = query.where('is_active', isEqualTo: isActive);
      }

      query = query.orderBy('updated_at', descending: true);
      final snapshot = await query.get();
      var contacts = snapshot.docs
          .map((doc) => DiscipleshipContact.fromJson(doc.data()))
          .toList();

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        contacts = contacts.where((c) {
          final name = c.fullName.toLowerCase();
          final notes = (c.notes ?? '').toLowerCase();
          return name.contains(q) || notes.contains(q);
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
      final doc = await FirebaseFirestore.instance
          .collection('discipleship_contacts')
          .doc(contactId)
          .get();

      if (doc.exists) {
        return DiscipleshipContact.fromJson(doc.data()!);
      }
      throw NotFoundException('Contact not found');
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Failed to get contact by id', e);
      throw DatabaseException('Failed to get contact', originalError: e);
    }
  }

  Future<DiscipleshipContact> createContact(DiscipleshipContact contact) async {
    try {
      final newContact = contact.copyWith(
        id: _uuid.v4(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('discipleship_contacts')
          .doc(newContact.id)
          .set(newContact.toJson());
      return newContact;
    } catch (e) {
      _logger.error('Failed to create contact', e);
      throw DatabaseException('Failed to create contact', originalError: e);
    }
  }

  Future<DiscipleshipContact> updateContact(DiscipleshipContact contact) async {
    try {
      final updatedContact = contact.copyWith(updatedAt: DateTime.now());

      await FirebaseFirestore.instance
          .collection('discipleship_contacts')
          .doc(contact.id)
          .update(updatedContact.toJson());

      return updatedContact;
    } catch (e) {
      _logger.error('Failed to update contact', e);
      throw DatabaseException('Failed to update contact', originalError: e);
    }
  }

  Future<void> deleteContact(String contactId) async {
    try {
      await FirebaseFirestore.instance
          .collection('discipleship_contacts')
          .doc(contactId)
          .delete();
    } catch (e) {
      _logger.error('Failed to delete contact', e);
      throw DatabaseException('Failed to delete contact', originalError: e);
    }
  }

  Future<DiscipleshipContact> updateContactLevel(
      String contactId, DiscipleshipLevel newLevel) async {
    try {
      final contact = await getContactById(contactId);

      // Create milestone for level change
      if (contact.currentLevel != newLevel) {
        await createProgressMilestone(ProgressMilestone(
          id: _uuid.v4(),
          contactId: contactId,
          fromLevel: contact.currentLevel,
          toLevel: newLevel,
          date: DateTime.now(),
          createdAt: DateTime.now(),
        ));
      }

      return await updateContact(contact.copyWith(
        currentLevel: newLevel,
        lastContact: DateTime.now(),
        baptismDate: newLevel == DiscipleshipLevel.baptized
            ? DateTime.now()
            : contact.baptismDate,
      ));
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Failed to update contact level', e);
      throw DatabaseException('Failed to update contact level',
          originalError: e);
    }
  }

  // Interaction Management
  Future<List<ContactInteraction>> getInteractions({
    String? contactId,
    String? discipleMakerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          FirebaseFirestore.instance.collection('contact_interactions');

      if (contactId != null) {
        query = query.where('contact_id', isEqualTo: contactId);
      }

      if (discipleMakerId != null) {
        query = query.where('disciple_maker_id', isEqualTo: discipleMakerId);
      }

      if (startDate != null) {
        query = query.where('date',
            isGreaterThanOrEqualTo: startDate.toIso8601String());
      }

      if (endDate != null) {
        query =
            query.where('date', isLessThanOrEqualTo: endDate.toIso8601String());
      }

      query = query.orderBy('date', descending: true);

      final snapshot = await query.get();
      return snapshot.docs
          .map<ContactInteraction>(
              (doc) => ContactInteraction.fromJson(doc.data()))
          .toList();
    } catch (e) {
      _logger.error('Failed to fetch interactions', e);
      throw DatabaseException('Failed to fetch interactions', originalError: e);
    }
  }

  Future<ContactInteraction> createInteraction(
      ContactInteraction interaction) async {
    try {
      final newInteraction = ContactInteraction(
        id: _uuid.v4(),
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
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('contact_interactions')
          .doc(newInteraction.id)
          .set(newInteraction.toJson());

      // Update contact's last contact date
      await FirebaseFirestore.instance
          .collection('discipleship_contacts')
          .doc(interaction.contactId)
          .update({
        'last_contact': newInteraction.date.toIso8601String().split('T')[0],
        'updated_at': DateTime.now().toIso8601String(),
      });

      return newInteraction;
    } catch (e) {
      _logger.error('Failed to create interaction', e);
      throw DatabaseException('Failed to create interaction', originalError: e);
    }
  }

  // Study Session Management
  Future<List<StudySession>> getStudySessions({
    String? contactId,
    String? discipleMakerId,
    StudyType? type,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          FirebaseFirestore.instance.collection('study_sessions');

      if (contactId != null) {
        query = query.where('contact_id', isEqualTo: contactId);
      }

      if (discipleMakerId != null) {
        query = query.where('disciple_maker_id', isEqualTo: discipleMakerId);
      }

      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      }

      if (startDate != null) {
        query = query.where('date',
            isGreaterThanOrEqualTo: startDate.toIso8601String());
      }

      if (endDate != null) {
        query =
            query.where('date', isLessThanOrEqualTo: endDate.toIso8601String());
      }

      query = query.orderBy('date', descending: true);

      final snapshot = await query.get();
      return snapshot.docs
          .map<StudySession>((doc) => StudySession.fromJson(doc.data()))
          .toList();
    } catch (e) {
      _logger.error('Failed to fetch study sessions', e);
      throw DatabaseException('Failed to fetch study sessions',
          originalError: e);
    }
  }

  Future<StudySession> createStudySession(StudySession session) async {
    try {
      final newSession = StudySession(
        id: _uuid.v4(),
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
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('study_sessions')
          .doc(newSession.id)
          .set(newSession.toJson());
      return newSession;
    } catch (e) {
      _logger.error('Failed to create study session', e);
      throw DatabaseException('Failed to create study session',
          originalError: e);
    }
  }

  Future<StudySession> updateStudySession(StudySession session) async {
    try {
      await FirebaseFirestore.instance
          .collection('study_sessions')
          .doc(session.id)
          .update(session.toJson());

      return session;
    } catch (e) {
      _logger.error('Failed to update study session', e);
      throw DatabaseException('Failed to update study session',
          originalError: e);
    }
  }

  // Prayer Request Management
  Future<List<PrayerRequest>> getPrayerRequests({
    String? contactId,
    String? discipleMakerId,
    PrayerRequestStatus? status,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          FirebaseFirestore.instance.collection('prayer_requests');

      if (contactId != null) {
        query = query.where('contact_id', isEqualTo: contactId);
      }

      if (discipleMakerId != null) {
        query = query.where('disciple_maker_id', isEqualTo: discipleMakerId);
      }

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      query = query.orderBy('date_requested', descending: true);

      final snapshot = await query.get();
      return snapshot.docs
          .map<PrayerRequest>((doc) => PrayerRequest.fromJson(doc.data()))
          .toList();
    } catch (e) {
      _logger.error('Failed to fetch prayer requests', e);
      throw DatabaseException('Failed to fetch prayer requests',
          originalError: e);
    }
  }

  Future<PrayerRequest> createPrayerRequest(PrayerRequest request) async {
    try {
      final newRequest = PrayerRequest(
        id: _uuid.v4(),
        contactId: request.contactId,
        discipleMakerId: request.discipleMakerId,
        request: request.request,
        category: request.category,
        status: request.status,
        dateRequested: request.dateRequested,
        dateAnswered: request.dateAnswered,
        answer: request.answer,
        notes: request.notes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('prayer_requests')
          .doc(newRequest.id)
          .set(newRequest.toJson());
      return newRequest;
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
        updatedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('prayer_requests')
          .doc(updatedRequest.id)
          .update(updatedRequest.toJson());

      return updatedRequest;
    } catch (e) {
      _logger.error('Failed to update prayer request', e);
      throw DatabaseException('Failed to update prayer request',
          originalError: e);
    }
  }

  // Progress Milestone Management
  Future<List<ProgressMilestone>> getProgressMilestones(
      String contactId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('progress_milestones')
          .where('contact_id', isEqualTo: contactId)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map<ProgressMilestone>(
              (doc) => ProgressMilestone.fromJson(doc.data()))
          .toList();
    } catch (e) {
      _logger.error('Failed to fetch progress milestones', e);
      throw DatabaseException('Failed to fetch progress milestones',
          originalError: e);
    }
  }

  Future<ProgressMilestone> createProgressMilestone(
      ProgressMilestone milestone) async {
    try {
      await FirebaseFirestore.instance
          .collection('progress_milestones')
          .doc(milestone.id)
          .set(milestone.toJson());
      return milestone;
    } catch (e) {
      _logger.error('Failed to create progress milestone', e);
      throw DatabaseException('Failed to create progress milestone',
          originalError: e);
    }
  }

  // Report Management
  Future<List<DiscipleshipReport>> getReports({
    String? discipleMakerId,
    String? supervisorId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          FirebaseFirestore.instance.collection('discipleship_reports');

      if (discipleMakerId != null) {
        query = query.where('disciple_maker_id', isEqualTo: discipleMakerId);
      }

      if (supervisorId != null) {
        query = query.where('supervisor_id', isEqualTo: supervisorId);
      }

      if (startDate != null) {
        query = query.where('report_period_start',
            isGreaterThanOrEqualTo: startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.where('report_period_end',
            isLessThanOrEqualTo: endDate.toIso8601String());
      }

      query = query.orderBy('created_at', descending: true);

      final snapshot = await query.get();
      return snapshot.docs
          .map<DiscipleshipReport>(
              (doc) => DiscipleshipReport.fromJson(doc.data()))
          .toList();
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
      // Get statistics for the period
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

      // Count new contacts in period
      final newContacts = contacts
          .where((c) =>
              c.firstContact.isAfter(startDate) &&
              c.firstContact.isBefore(endDate.add(const Duration(days: 1))))
          .length;

      // Count baptisms in period
      final baptisms = contacts
          .where((c) =>
              c.baptismDate != null &&
              c.baptismDate!.isAfter(startDate) &&
              c.baptismDate!.isBefore(endDate.add(const Duration(days: 1))))
          .length;

      final report = DiscipleshipReport(
        id: _uuid.v4(),
        discipleMakerId: discipleMakerId,
        supervisorId: supervisorId,
        reportPeriodStart: startDate,
        reportPeriodEnd: endDate,
        totalContacts: contacts.length,
        activeContacts: contacts.where((c) => c.isActive).length,
        newContacts: newContacts,
        baptisms: baptisms,
        studySessions: studySessions.length,
        interactions: interactions.length,
        highlights: highlights,
        challenges: challenges,
        prayerRequests: prayerRequests,
        goals: goals,
        frequency: frequency,
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('discipleship_reports')
          .doc(report.id)
          .set(report.toJson());
      return report;
    } catch (e) {
      _logger.error('Failed to generate report', e);
      throw DatabaseException('Failed to generate report', originalError: e);
    }
  }

  Future<DiscipleshipReport> submitReport(String reportId) async {
    try {
      final now = DateTime.now();
      await FirebaseFirestore.instance
          .collection('discipleship_reports')
          .doc(reportId)
          .update({'submitted_at': now.toIso8601String()});
      final doc = await FirebaseFirestore.instance
          .collection('discipleship_reports')
          .doc(reportId)
          .get();
      return DiscipleshipReport.fromJson(doc.data()!);
    } catch (e) {
      _logger.error('Failed to submit report', e);
      throw DatabaseException('Failed to submit report', originalError: e);
    }
  }

  // Statistics and Analytics
  Future<Map<String, dynamic>> getDiscipleshipStatistics(
      String discipleMakerId) async {
    try {
      final contacts = await getContacts(discipleMakerId: discipleMakerId);
      final interactions =
          await getInteractions(discipleMakerId: discipleMakerId);
      final studySessions =
          await getStudySessions(discipleMakerId: discipleMakerId);
      final prayerRequests =
          await getPrayerRequests(discipleMakerId: discipleMakerId);

      // Level distribution
      final levelCounts = <DiscipleshipLevel, int>{};
      for (final level in DiscipleshipLevel.values) {
        levelCounts[level] =
            contacts.where((c) => c.currentLevel == level).length;
      }

      // Recent activity (last 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final recentInteractions =
          interactions.where((i) => i.date.isAfter(thirtyDaysAgo)).length;
      final recentStudySessions =
          studySessions.where((s) => s.date.isAfter(thirtyDaysAgo)).length;

      return {
        'totalContacts': contacts.length,
        'activeContacts': contacts.where((c) => c.isActive).length,
        'totalBaptisms': contacts
            .where((c) =>
                c.currentLevel == DiscipleshipLevel.baptized ||
                c.currentLevel == DiscipleshipLevel.disciple ||
                c.currentLevel == DiscipleshipLevel.leader)
            .length,
        'levelDistribution': levelCounts.map((k, v) => MapEntry(k.name, v)),
        'totalInteractions': interactions.length,
        'totalStudySessions': studySessions.length,
        'totalPrayerRequests': prayerRequests.length,
        'answeredPrayers': prayerRequests
            .where((p) => p.status == PrayerRequestStatus.answered)
            .length,
        'recentActivity': {
          'interactions': recentInteractions,
          'studySessions': recentStudySessions,
        },
        'averageStudyRating':
            studySessions.where((s) => s.rating != null).isEmpty
                ? 0.0
                : studySessions
                        .where((s) => s.rating != null)
                        .map((s) => s.rating!)
                        .reduce((a, b) => a + b) /
                    studySessions.where((s) => s.rating != null).length,
      };
    } catch (e) {
      _logger.error('Failed to get discipleship statistics', e);
      throw DatabaseException('Failed to get discipleship statistics',
          originalError: e);
    }
  }

  // Helper methods
  String getNextStepsForLevel(DiscipleshipLevel level) {
    return DiscipleshipConstants.nextSteps[level] ??
        'Continue building relationship';
  }

  String getLevelDescription(DiscipleshipLevel level) {
    return DiscipleshipConstants.levelDescriptions[level] ?? 'Unknown level';
  }

  List<String> getStudyTopics() {
    return DiscipleshipConstants.studyTopics;
  }

  List<String> getPrayerCategories() {
    return DiscipleshipConstants.prayerCategories;
  }

  String getBibleVerse(String key) {
    return DiscipleshipConstants.bibleVerses[key] ?? '';
  }
}
