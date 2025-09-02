import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/discipleship_models.dart';

class DiscipleshipService {
  static final DiscipleshipService _instance = DiscipleshipService._internal();
  factory DiscipleshipService() => _instance;
  DiscipleshipService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  // Contact Management
  Future<List<DiscipleshipContact>> getContacts({
    String? discipleMakerId,
    DiscipleshipLevel? level,
    bool? isActive,
    String? searchQuery,
  }) async {
    try {
      dynamic query = _supabase.from('discipleship_contacts').select();

      if (discipleMakerId != null) {
        query = query.eq('disciple_maker_id', discipleMakerId);
      }

      if (level != null) {
        query = query.eq('current_level', level.name);
      }

      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or(
            'first_name.ilike.%$searchQuery%,last_name.ilike.%$searchQuery%,email.ilike.%$searchQuery%');
      }

      query = query.order('updated_at', ascending: false);

      final response = await query;
      return response
          .map<DiscipleshipContact>(
              (json) => DiscipleshipContact.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch contacts: $e');
    }
  }

  Future<DiscipleshipContact?> getContactById(String contactId) async {
    try {
      final response = await _supabase
          .from('discipleship_contacts')
          .select()
          .eq('id', contactId)
          .single();

      return DiscipleshipContact.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<DiscipleshipContact> createContact(DiscipleshipContact contact) async {
    try {
      final newContact = contact.copyWith(
        id: _uuid.v4(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _supabase.from('discipleship_contacts').insert(newContact.toJson());
      return newContact;
    } catch (e) {
      throw Exception('Failed to create contact: $e');
    }
  }

  Future<DiscipleshipContact> updateContact(DiscipleshipContact contact) async {
    try {
      final updatedContact = contact.copyWith(updatedAt: DateTime.now());

      await _supabase
          .from('discipleship_contacts')
          .update(updatedContact.toJson())
          .eq('id', contact.id);

      return updatedContact;
    } catch (e) {
      throw Exception('Failed to update contact: $e');
    }
  }

  Future<void> deleteContact(String contactId) async {
    try {
      await _supabase
          .from('discipleship_contacts')
          .delete()
          .eq('id', contactId);
    } catch (e) {
      throw Exception('Failed to delete contact: $e');
    }
  }

  Future<DiscipleshipContact> updateContactLevel(
      String contactId, DiscipleshipLevel newLevel) async {
    try {
      final contact = await getContactById(contactId);
      if (contact == null) {
        throw Exception('Contact not found');
      }

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
      throw Exception('Failed to update contact level: $e');
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
      dynamic query = _supabase.from('contact_interactions').select();

      if (contactId != null) {
        query = query.eq('contact_id', contactId);
      }

      if (discipleMakerId != null) {
        query = query.eq('disciple_maker_id', discipleMakerId);
      }

      if (startDate != null) {
        query = query.gte('date', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('date', endDate.toIso8601String());
      }

      query = query.order('date', ascending: false);

      final response = await query;
      return response
          .map<ContactInteraction>((json) => ContactInteraction.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch interactions: $e');
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

      await _supabase
          .from('contact_interactions')
          .insert(newInteraction.toJson());

      // Update contact's last contact date
      await _supabase.from('discipleship_contacts').update({
        'last_contact': newInteraction.date.toIso8601String().split('T')[0]
      }).eq('id', interaction.contactId);

      return newInteraction;
    } catch (e) {
      throw Exception('Failed to create interaction: $e');
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
      dynamic query = _supabase.from('study_sessions').select();

      if (contactId != null) {
        query = query.eq('contact_id', contactId);
      }

      if (discipleMakerId != null) {
        query = query.eq('disciple_maker_id', discipleMakerId);
      }

      if (type != null) {
        query = query.eq('type', type.name);
      }

      if (startDate != null) {
        query = query.gte('date', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('date', endDate.toIso8601String());
      }

      query = query.order('date', ascending: false);

      final response = await query;
      return response
          .map<StudySession>((json) => StudySession.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch study sessions: $e');
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

      await _supabase.from('study_sessions').insert(newSession.toJson());
      return newSession;
    } catch (e) {
      throw Exception('Failed to create study session: $e');
    }
  }

  Future<StudySession> updateStudySession(StudySession session) async {
    try {
      await _supabase
          .from('study_sessions')
          .update(session.toJson())
          .eq('id', session.id);

      return session;
    } catch (e) {
      throw Exception('Failed to update study session: $e');
    }
  }

  // Prayer Request Management
  Future<List<PrayerRequest>> getPrayerRequests({
    String? contactId,
    String? discipleMakerId,
    PrayerRequestStatus? status,
  }) async {
    try {
      dynamic query = _supabase.from('prayer_requests').select();

      if (contactId != null) {
        query = query.eq('contact_id', contactId);
      }

      if (discipleMakerId != null) {
        query = query.eq('disciple_maker_id', discipleMakerId);
      }

      if (status != null) {
        query = query.eq('status', status.name);
      }

      query = query.order('date_requested', ascending: false);

      final response = await query;
      return response
          .map<PrayerRequest>((json) => PrayerRequest.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch prayer requests: $e');
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

      await _supabase.from('prayer_requests').insert(newRequest.toJson());
      return newRequest;
    } catch (e) {
      throw Exception('Failed to create prayer request: $e');
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

      await _supabase
          .from('prayer_requests')
          .update(updatedRequest.toJson())
          .eq('id', request.id);

      return updatedRequest;
    } catch (e) {
      throw Exception('Failed to update prayer request: $e');
    }
  }

  // Progress Milestone Management
  Future<List<ProgressMilestone>> getProgressMilestones(
      String contactId) async {
    try {
      final response = await _supabase
          .from('progress_milestones')
          .select()
          .eq('contact_id', contactId)
          .order('date', ascending: false);

      return response
          .map<ProgressMilestone>((json) => ProgressMilestone.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch progress milestones: $e');
    }
  }

  Future<ProgressMilestone> createProgressMilestone(
      ProgressMilestone milestone) async {
    try {
      await _supabase.from('progress_milestones').insert(milestone.toJson());
      return milestone;
    } catch (e) {
      throw Exception('Failed to create progress milestone: $e');
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
      dynamic query = _supabase.from('discipleship_reports').select();

      if (discipleMakerId != null) {
        query = query.eq('disciple_maker_id', discipleMakerId);
      }

      if (supervisorId != null) {
        query = query.eq('supervisor_id', supervisorId);
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
          .map<DiscipleshipReport>((json) => DiscipleshipReport.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch reports: $e');
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

      await _supabase.from('discipleship_reports').insert(report.toJson());
      return report;
    } catch (e) {
      throw Exception('Failed to generate report: $e');
    }
  }

  Future<DiscipleshipReport> submitReport(String reportId) async {
    try {
      final now = DateTime.now();
      await _supabase
          .from('discipleship_reports')
          .update({'submitted_at': now.toIso8601String()}).eq('id', reportId);

      final response = await _supabase
          .from('discipleship_reports')
          .select()
          .eq('id', reportId)
          .single();

      return DiscipleshipReport.fromJson(response);
    } catch (e) {
      throw Exception('Failed to submit report: $e');
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
      throw Exception('Failed to get discipleship statistics: $e');
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
