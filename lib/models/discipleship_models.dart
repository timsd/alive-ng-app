// Enums for discipleship tracking
enum DiscipleshipLevel {
  prospect,
  interested,
  studying,
  convinced,
  committed,
  baptized,
  disciple,
  leader
}

enum ContactMethod { inPerson, phone, video, email, text, socialMedia, other }

enum StudyType {
  bibleStudy,
  prophecySeminar,
  healthSeminar,
  evangelisticSeries,
  personalStudy,
  smallGroup,
  other
}

enum PrayerRequestStatus { active, answered, ongoing, closed }

enum ReportFrequency { weekly, biweekly, monthly, quarterly }

// Main discipleship contact model
class DiscipleshipContact {
  final String id;
  final String discipleMakerId;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? address;
  final DateTime? dateOfBirth;
  final String? occupation;
  final String? interests;
  final DiscipleshipLevel currentLevel;
  final DateTime firstContact;
  final DateTime? lastContact;
  final DateTime? baptismDate;
  final String? notes;
  final bool isActive;
  final List<String> tags;
  final Map<String, dynamic> customFields;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DiscipleshipContact({
    required this.id,
    required this.discipleMakerId,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.address,
    this.dateOfBirth,
    this.occupation,
    this.interests,
    required this.currentLevel,
    required this.firstContact,
    this.lastContact,
    this.baptismDate,
    this.notes,
    this.isActive = true,
    this.tags = const [],
    this.customFields = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  String get fullName => '$firstName $lastName';

  factory DiscipleshipContact.fromJson(Map<String, dynamic> json) {
    return DiscipleshipContact(
      id: json['id'] as String,
      discipleMakerId: json['disciple_maker_id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'] as String)
          : null,
      occupation: json['occupation'] as String?,
      interests: json['interests'] as String?,
      currentLevel: DiscipleshipLevel.values.firstWhere(
        (level) => level.name == json['current_level'],
        orElse: () => DiscipleshipLevel.prospect,
      ),
      firstContact: DateTime.parse(json['first_contact'] as String),
      lastContact: json['last_contact'] != null
          ? DateTime.parse(json['last_contact'] as String)
          : null,
      baptismDate: json['baptism_date'] != null
          ? DateTime.parse(json['baptism_date'] as String)
          : null,
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      tags: List<String>.from(json['tags'] ?? []),
      customFields: Map<String, dynamic>.from(json['custom_fields'] ?? {}),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'disciple_maker_id': discipleMakerId,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'address': address,
      'date_of_birth': dateOfBirth?.toIso8601String().split('T')[0],
      'occupation': occupation,
      'interests': interests,
      'current_level': currentLevel.name,
      'first_contact': firstContact.toIso8601String().split('T')[0],
      'last_contact': lastContact?.toIso8601String().split('T')[0],
      'baptism_date': baptismDate?.toIso8601String().split('T')[0],
      'notes': notes,
      'is_active': isActive,
      'tags': tags,
      'custom_fields': customFields,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  DiscipleshipContact copyWith({
    String? id,
    String? discipleMakerId,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? address,
    DateTime? dateOfBirth,
    String? occupation,
    String? interests,
    DiscipleshipLevel? currentLevel,
    DateTime? firstContact,
    DateTime? lastContact,
    DateTime? baptismDate,
    String? notes,
    bool? isActive,
    List<String>? tags,
    Map<String, dynamic>? customFields,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiscipleshipContact(
      id: id ?? this.id,
      discipleMakerId: discipleMakerId ?? this.discipleMakerId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      occupation: occupation ?? this.occupation,
      interests: interests ?? this.interests,
      currentLevel: currentLevel ?? this.currentLevel,
      firstContact: firstContact ?? this.firstContact,
      lastContact: lastContact ?? this.lastContact,
      baptismDate: baptismDate ?? this.baptismDate,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      tags: tags ?? this.tags,
      customFields: customFields ?? this.customFields,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Contact interaction/activity model
class ContactInteraction {
  final String id;
  final String contactId;
  final String discipleMakerId;
  final ContactMethod method;
  final String title;
  final String? description;
  final DateTime date;
  final int durationMinutes;
  final String? outcome;
  final String? nextSteps;
  final List<String> attachments;
  final DateTime createdAt;

  const ContactInteraction({
    required this.id,
    required this.contactId,
    required this.discipleMakerId,
    required this.method,
    required this.title,
    this.description,
    required this.date,
    this.durationMinutes = 0,
    this.outcome,
    this.nextSteps,
    this.attachments = const [],
    required this.createdAt,
  });

  factory ContactInteraction.fromJson(Map<String, dynamic> json) {
    return ContactInteraction(
      id: json['id'] as String,
      contactId: json['contact_id'] as String,
      discipleMakerId: json['disciple_maker_id'] as String,
      method: ContactMethod.values.firstWhere(
        (method) => method.name == json['method'],
        orElse: () => ContactMethod.other,
      ),
      title: json['title'] as String,
      description: json['description'] as String?,
      date: DateTime.parse(json['date'] as String),
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      outcome: json['outcome'] as String?,
      nextSteps: json['next_steps'] as String?,
      attachments: List<String>.from(json['attachments'] ?? []),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contact_id': contactId,
      'disciple_maker_id': discipleMakerId,
      'method': method.name,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'duration_minutes': durationMinutes,
      'outcome': outcome,
      'next_steps': nextSteps,
      'attachments': attachments,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// Study session model
class StudySession {
  final String id;
  final String contactId;
  final String discipleMakerId;
  final StudyType type;
  final String title;
  final String? topic;
  final String? bibleTexts;
  final DateTime date;
  final int durationMinutes;
  final String? notes;
  final String? homework;
  final int? rating; // 1-5 scale for engagement
  final bool completed;
  final DateTime createdAt;

  const StudySession({
    required this.id,
    required this.contactId,
    required this.discipleMakerId,
    required this.type,
    required this.title,
    this.topic,
    this.bibleTexts,
    required this.date,
    this.durationMinutes = 0,
    this.notes,
    this.homework,
    this.rating,
    this.completed = false,
    required this.createdAt,
  });

  factory StudySession.fromJson(Map<String, dynamic> json) {
    return StudySession(
      id: json['id'] as String,
      contactId: json['contact_id'] as String,
      discipleMakerId: json['disciple_maker_id'] as String,
      type: StudyType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => StudyType.other,
      ),
      title: json['title'] as String,
      topic: json['topic'] as String?,
      bibleTexts: json['bible_texts'] as String?,
      date: DateTime.parse(json['date'] as String),
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      notes: json['notes'] as String?,
      homework: json['homework'] as String?,
      rating: json['rating'] as int?,
      completed: json['completed'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contact_id': contactId,
      'disciple_maker_id': discipleMakerId,
      'type': type.name,
      'title': title,
      'topic': topic,
      'bible_texts': bibleTexts,
      'date': date.toIso8601String(),
      'duration_minutes': durationMinutes,
      'notes': notes,
      'homework': homework,
      'rating': rating,
      'completed': completed,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// Prayer request model
class PrayerRequest {
  final String id;
  final String contactId;
  final String discipleMakerId;
  final String request;
  final String? category;
  final PrayerRequestStatus status;
  final DateTime dateRequested;
  final DateTime? dateAnswered;
  final String? answer;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PrayerRequest({
    required this.id,
    required this.contactId,
    required this.discipleMakerId,
    required this.request,
    this.category,
    required this.status,
    required this.dateRequested,
    this.dateAnswered,
    this.answer,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PrayerRequest.fromJson(Map<String, dynamic> json) {
    return PrayerRequest(
      id: json['id'] as String,
      contactId: json['contact_id'] as String,
      discipleMakerId: json['disciple_maker_id'] as String,
      request: json['request'] as String,
      category: json['category'] as String?,
      status: PrayerRequestStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => PrayerRequestStatus.active,
      ),
      dateRequested: DateTime.parse(json['date_requested'] as String),
      dateAnswered: json['date_answered'] != null
          ? DateTime.parse(json['date_answered'] as String)
          : null,
      answer: json['answer'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contact_id': contactId,
      'disciple_maker_id': discipleMakerId,
      'request': request,
      'category': category,
      'status': status.name,
      'date_requested': dateRequested.toIso8601String().split('T')[0],
      'date_answered': dateAnswered?.toIso8601String().split('T')[0],
      'answer': answer,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

// Progress milestone model
class ProgressMilestone {
  final String id;
  final String contactId;
  final DiscipleshipLevel fromLevel;
  final DiscipleshipLevel toLevel;
  final DateTime date;
  final String? notes;
  final String? celebrationPlan;
  final DateTime createdAt;

  const ProgressMilestone({
    required this.id,
    required this.contactId,
    required this.fromLevel,
    required this.toLevel,
    required this.date,
    this.notes,
    this.celebrationPlan,
    required this.createdAt,
  });

  factory ProgressMilestone.fromJson(Map<String, dynamic> json) {
    return ProgressMilestone(
      id: json['id'] as String,
      contactId: json['contact_id'] as String,
      fromLevel: DiscipleshipLevel.values.firstWhere(
        (level) => level.name == json['from_level'],
        orElse: () => DiscipleshipLevel.prospect,
      ),
      toLevel: DiscipleshipLevel.values.firstWhere(
        (level) => level.name == json['to_level'],
        orElse: () => DiscipleshipLevel.interested,
      ),
      date: DateTime.parse(json['date'] as String),
      notes: json['notes'] as String?,
      celebrationPlan: json['celebration_plan'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contact_id': contactId,
      'from_level': fromLevel.name,
      'to_level': toLevel.name,
      'date': date.toIso8601String().split('T')[0],
      'notes': notes,
      'celebration_plan': celebrationPlan,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// Discipleship report model
class DiscipleshipReport {
  final String id;
  final String discipleMakerId;
  final String? supervisorId;
  final DateTime reportPeriodStart;
  final DateTime reportPeriodEnd;
  final int totalContacts;
  final int activeContacts;
  final int newContacts;
  final int baptisms;
  final int studySessions;
  final int interactions;
  final String? highlights;
  final String? challenges;
  final String? prayerRequests;
  final String? goals;
  final ReportFrequency frequency;
  final DateTime createdAt;
  final DateTime? submittedAt;

  const DiscipleshipReport({
    required this.id,
    required this.discipleMakerId,
    this.supervisorId,
    required this.reportPeriodStart,
    required this.reportPeriodEnd,
    required this.totalContacts,
    required this.activeContacts,
    required this.newContacts,
    required this.baptisms,
    required this.studySessions,
    required this.interactions,
    this.highlights,
    this.challenges,
    this.prayerRequests,
    this.goals,
    required this.frequency,
    required this.createdAt,
    this.submittedAt,
  });

  factory DiscipleshipReport.fromJson(Map<String, dynamic> json) {
    return DiscipleshipReport(
      id: json['id'] as String,
      discipleMakerId: json['disciple_maker_id'] as String,
      supervisorId: json['supervisor_id'] as String?,
      reportPeriodStart: DateTime.parse(json['report_period_start'] as String),
      reportPeriodEnd: DateTime.parse(json['report_period_end'] as String),
      totalContacts: json['total_contacts'] as int,
      activeContacts: json['active_contacts'] as int,
      newContacts: json['new_contacts'] as int,
      baptisms: json['baptisms'] as int,
      studySessions: json['study_sessions'] as int,
      interactions: json['interactions'] as int,
      highlights: json['highlights'] as String?,
      challenges: json['challenges'] as String?,
      prayerRequests: json['prayer_requests'] as String?,
      goals: json['goals'] as String?,
      frequency: ReportFrequency.values.firstWhere(
        (freq) => freq.name == json['frequency'],
        orElse: () => ReportFrequency.monthly,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'disciple_maker_id': discipleMakerId,
      'supervisor_id': supervisorId,
      'report_period_start': reportPeriodStart.toIso8601String().split('T')[0],
      'report_period_end': reportPeriodEnd.toIso8601String().split('T')[0],
      'total_contacts': totalContacts,
      'active_contacts': activeContacts,
      'new_contacts': newContacts,
      'baptisms': baptisms,
      'study_sessions': studySessions,
      'interactions': interactions,
      'highlights': highlights,
      'challenges': challenges,
      'prayer_requests': prayerRequests,
      'goals': goals,
      'frequency': frequency.name,
      'created_at': createdAt.toIso8601String(),
      'submitted_at': submittedAt?.toIso8601String(),
    };
  }
}

// Constants for discipleship tracking
class DiscipleshipConstants {
  static const Map<DiscipleshipLevel, String> levelDescriptions = {
    DiscipleshipLevel.prospect: 'Initial contact, showing some interest',
    DiscipleshipLevel.interested: 'Actively interested in learning more',
    DiscipleshipLevel.studying: 'Regularly attending Bible studies',
    DiscipleshipLevel.convinced:
        'Convinced of Bible truths, considering commitment',
    DiscipleshipLevel.committed:
        'Committed to following Christ, preparing for baptism',
    DiscipleshipLevel.baptized: 'Baptized member of the church',
    DiscipleshipLevel.disciple: 'Growing disciple, actively serving',
    DiscipleshipLevel.leader: 'Leading others in discipleship',
  };

  static const Map<DiscipleshipLevel, String> nextSteps = {
    DiscipleshipLevel.prospect: 'Build relationship, assess interest level',
    DiscipleshipLevel.interested:
        'Invite to Bible study or evangelistic series',
    DiscipleshipLevel.studying: 'Continue regular studies, address questions',
    DiscipleshipLevel.convinced: 'Discuss commitment and baptism',
    DiscipleshipLevel.committed: 'Prepare for baptism, connect with church',
    DiscipleshipLevel.baptized: 'Provide discipleship training and mentoring',
    DiscipleshipLevel.disciple: 'Encourage service and leadership development',
    DiscipleshipLevel.leader: 'Support in training others',
  };

  static const List<String> studyTopics = [
    'God\'s Love',
    'The Bible',
    'Prayer',
    'Second Coming',
    'Death and Resurrection',
    'Millennium',
    'Judgment',
    'Salvation',
    'Law of God',
    'Sabbath',
    'Baptism',
    'Spiritual Gifts',
    'Church',
    'Prophecy',
    'Health and Temperance',
    'Stewardship',
    'Christian Living',
  ];

  static const List<String> prayerCategories = [
    'Health',
    'Family',
    'Work/Career',
    'Spiritual Growth',
    'Relationships',
    'Financial',
    'Decision Making',
    'Protection',
    'Thanksgiving',
    'Other',
  ];

  static const Map<String, String> bibleVerses = {
    'discipleship':
        'Go therefore and make disciples of all nations, baptizing them in the name of the Father and of the Son and of the Holy Spirit. - Matthew 28:19',
    'love':
        'By this all people will know that you are my disciples, if you have love for one another. - John 13:35',
    'growth':
        'But grow in the grace and knowledge of our Lord and Savior Jesus Christ. - 2 Peter 3:18',
    'prayer': 'Pray without ceasing. - 1 Thessalonians 5:17',
    'study':
        'Study to show yourself approved to God, a worker who does not need to be ashamed, rightly dividing the word of truth. - 2 Timothy 2:15',
  };
}



/// Strongly-typed discipleship statistics.
///
/// Replaces the previous untyped `Map<String, dynamic>` returned by
/// `DiscipleshipService.getDiscipleshipStatistics`. SDK-agnostic domain object.
class DiscipleshipStatistics {
  final int totalContacts;
  final int activeContacts;
  final int totalBaptisms;
  final int totalInteractions;
  final int totalStudySessions;
  final int totalPrayerRequests;
  final int answeredPrayers;
  final int recentInteractions;
  final int recentStudySessions;
  final double averageStudyRating;
  final Map<String, int> levelDistribution;

  const DiscipleshipStatistics({
    this.totalContacts = 0,
    this.activeContacts = 0,
    this.totalBaptisms = 0,
    this.totalInteractions = 0,
    this.totalStudySessions = 0,
    this.totalPrayerRequests = 0,
    this.answeredPrayers = 0,
    this.recentInteractions = 0,
    this.recentStudySessions = 0,
    this.averageStudyRating = 0,
    this.levelDistribution = const {},
  });

  factory DiscipleshipStatistics.fromMap(Map<String, dynamic> json) {
    final levelJson =
        json['levelDistribution'] as Map<String, dynamic>? ?? const {};
    final levelDistribution = <String, int>{};
    levelJson.forEach((k, v) {
      levelDistribution[k] = (v as num?)?.toInt() ?? 0;
    });

    final recent = json['recentActivity'] as Map<String, dynamic>? ?? const {};
    return DiscipleshipStatistics(
      totalContacts: (json['totalContacts'] as num?)?.toInt() ?? 0,
      activeContacts: (json['activeContacts'] as num?)?.toInt() ?? 0,
      totalBaptisms: (json['totalBaptisms'] as num?)?.toInt() ?? 0,
      totalInteractions: (json['totalInteractions'] as num?)?.toInt() ?? 0,
      totalStudySessions: (json['totalStudySessions'] as num?)?.toInt() ?? 0,
      totalPrayerRequests: (json['totalPrayerRequests'] as num?)?.toInt() ?? 0,
      answeredPrayers: (json['answeredPrayers'] as num?)?.toInt() ?? 0,
      recentInteractions: (recent['interactions'] as num?)?.toInt() ?? 0,
      recentStudySessions: (recent['studySessions'] as num?)?.toInt() ?? 0,
      averageStudyRating:
          (json['averageStudyRating'] as num?)?.toDouble() ?? 0,
      levelDistribution: levelDistribution,
    );
  }

  static const DiscipleshipStatistics empty = DiscipleshipStatistics();
}

