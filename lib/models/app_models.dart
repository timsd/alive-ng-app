// User and Profile Models
class UserProfile {
  final String id;
  final String? email;
  final String? fullName;
  final String? avatarUrl;
  final DateTime? dateOfBirth;
  final String? phoneNumber;
  final String? address;
  final String? bio;
  final String? chapterId;
  final String role; // member, coordinator, leader, admin
  final bool isArchived;
  final bool isNewConvert;
  final DateTime? convertDate;
  
  // Admin approval fields
  final bool isApproved;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String approvalStatus; // pending, approved, rejected
  final String? rejectionReason;
  
  // Verification fields
  final String? localChapter;
  final String? localChurch;
  final String? conference;
  final bool isChapterVerified;
  final bool isChurchVerified;
  final bool isConferenceVerified;
  
  // Commitment tracking
  final String? commitmentType; // financial, active_availability, both
  final double? financialCommitment;
  final String? availabilityCommitment;
  final Map<String, dynamic>? commitmentDetails;
  
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    this.email,
    this.fullName,
    this.avatarUrl,
    this.dateOfBirth,
    this.phoneNumber,
    this.address,
    this.bio,
    this.chapterId,
    this.role = 'member',
    this.isArchived = false,
    this.isNewConvert = false,
    this.convertDate,
    
    // Admin approval fields
    this.isApproved = false,
    this.approvedBy,
    this.approvedAt,
    this.approvalStatus = 'pending',
    this.rejectionReason,
    
    // Verification fields
    this.localChapter,
    this.localChurch,
    this.conference,
    this.isChapterVerified = false,
    this.isChurchVerified = false,
    this.isConferenceVerified = false,
    
    // Commitment tracking
    this.commitmentType,
    this.financialCommitment,
    this.availabilityCommitment,
    this.commitmentDetails,
    
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String?,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'] as String)
          : null,
      phoneNumber: json['phone_number'] as String?,
      address: json['address'] as String?,
      bio: json['bio'] as String?,
      chapterId: json['chapter_id'] as String?,
      role: json['role'] as String? ?? 'member',
      isArchived: json['is_archived'] as bool? ?? false,
      isNewConvert: json['is_new_convert'] as bool? ?? false,
      convertDate: json['convert_date'] != null
          ? DateTime.parse(json['convert_date'] as String)
          : null,
      
      // Admin approval fields
      isApproved: json['is_approved'] as bool? ?? false,
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : null,
      approvalStatus: json['approval_status'] as String? ?? 'pending',
      rejectionReason: json['rejection_reason'] as String?,
      
      // Verification fields
      localChapter: json['local_chapter'] as String?,
      localChurch: json['local_church'] as String?,
      conference: json['conference'] as String?,
      isChapterVerified: json['is_chapter_verified'] as bool? ?? false,
      isChurchVerified: json['is_church_verified'] as bool? ?? false,
      isConferenceVerified: json['is_conference_verified'] as bool? ?? false,
      
      // Commitment tracking
      commitmentType: json['commitment_type'] as String?,
      financialCommitment: json['financial_commitment'] != null
          ? (json['financial_commitment'] as num).toDouble()
          : null,
      availabilityCommitment: json['availability_commitment'] as String?,
      commitmentDetails: json['commitment_details'] as Map<String, dynamic>?,
      
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'phone_number': phoneNumber,
      'address': address,
      'bio': bio,
      'chapter_id': chapterId,
      'role': role,
      'is_archived': isArchived,
      'is_new_convert': isNewConvert,
      'convert_date': convertDate?.toIso8601String(),
      
      // Admin approval fields
      'is_approved': isApproved,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'approval_status': approvalStatus,
      'rejection_reason': rejectionReason,
      
      // Verification fields
      'local_chapter': localChapter,
      'local_church': localChurch,
      'conference': conference,
      'is_chapter_verified': isChapterVerified,
      'is_church_verified': isChurchVerified,
      'is_conference_verified': isConferenceVerified,
      
      // Commitment tracking
      'commitment_type': commitmentType,
      'financial_commitment': financialCommitment,
      'availability_commitment': availabilityCommitment,
      'commitment_details': commitmentDetails,
      
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

// Conference Meeting Model
class ConferenceMeeting {
  final String id;
  final String title;
  final String description;
  final DateTime scheduledTime;
  final int duration; // in minutes
  final String hostId;
  final String hostName;
  final String meetingType;
  final List<String> participants;
  final int maxParticipants;
  final bool isRecurring;
  final String meetingLink;
  final String status;
  final String roomName;
  
  ConferenceMeeting({
    required this.id,
    required this.title,
    required this.description,
    required this.scheduledTime,
    required this.duration,
    required this.hostId,
    required this.hostName,
    required this.meetingType,
    required this.participants,
    required this.maxParticipants,
    required this.isRecurring,
    required this.meetingLink,
    required this.status,
    required this.roomName,
  });

  factory ConferenceMeeting.fromJson(Map<String, dynamic> json) {
    return ConferenceMeeting(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      scheduledTime: DateTime.parse(json['scheduled_time'] as String),
      duration: json['duration'] as int,
      hostId: json['host_id'] as String,
      hostName: json['host_name'] as String,
      meetingType: json['meeting_type'] as String,
      participants: List<String>.from(json['participants'] as List? ?? []),
      maxParticipants: json['max_participants'] as int,
      isRecurring: json['is_recurring'] as bool? ?? false,
      meetingLink: json['meeting_link'] as String,
      status: json['status'] as String,
      roomName: json['room_name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'scheduled_time': scheduledTime.toIso8601String(),
      'duration': duration,
      'host_id': hostId,
      'host_name': hostName,
      'meeting_type': meetingType,
      'participants': participants,
      'max_participants': maxParticipants,
      'is_recurring': isRecurring,
      'meeting_link': meetingLink,
      'status': status,
      'room_name': roomName,
    };
  }
}

// Chapter Model
class Chapter {
  final String id;
  final String name;
  final String location;
  final String description;
  final String coordinatorId;
  final List<String> memberIds;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Chapter({
    required this.id,
    required this.name,
    required this.location,
    required this.description,
    required this.coordinatorId,
    required this.memberIds,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] as String,
      name: json['name'] as String,
      location: json['location'] as String,
      description: json['description'] as String,
      coordinatorId: json['coordinator_id'] as String,
      memberIds: List<String>.from(json['member_ids'] as List),
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'description': description,
      'coordinator_id': coordinatorId,
      'member_ids': memberIds,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

// Chapter Member Model
class ChapterMember {
  final String id;
  final String userId;
  final String chapterId;
  final String role; // member, coordinator, leader
  final DateTime joinedAt;
  final bool isActive;

  ChapterMember({
    required this.id,
    required this.userId,
    required this.chapterId,
    required this.role,
    required this.joinedAt,
    required this.isActive,
  });

  factory ChapterMember.fromJson(Map<String, dynamic> json) {
    return ChapterMember(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      chapterId: json['chapter_id'] as String,
      role: json['role'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      isActive: json['is_active'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'chapter_id': chapterId,
      'role': role,
      'joined_at': joinedAt.toIso8601String(),
      'is_active': isActive,
    };
  }
}

// Team Model
class Team {
  final String id;
  final String name;
  final String type; // field_workers, campus_missionary, amtc
  final String description;
  final String coordinatorId;
  final List<String> memberIds;
  final String chapterId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Team({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.coordinatorId,
    required this.memberIds,
    required this.chapterId,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      description: json['description'] as String,
      coordinatorId: json['coordinator_id'] as String,
      memberIds: List<String>.from(json['member_ids'] as List),
      chapterId: json['chapter_id'] as String,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'description': description,
      'coordinator_id': coordinatorId,
      'member_ids': memberIds,
      'chapter_id': chapterId,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

// Daily Verse Model
class DailyVerse {
  final String id;
  final String verse;
  final String reference;
  final String translation;
  final DateTime date;
  final String? reflection;
  final DateTime createdAt;

  DailyVerse({
    required this.id,
    required this.verse,
    required this.reference,
    required this.translation,
    required this.date,
    this.reflection,
    required this.createdAt,
  });

  factory DailyVerse.fromJson(Map<String, dynamic> json) {
    return DailyVerse(
      id: json['id'] as String,
      verse: json['verse'] as String,
      reference: json['reference'] as String,
      translation: json['translation'] as String,
      date: DateTime.parse(json['date'] as String),
      reflection: json['reflection'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'verse': verse,
      'reference': reference,
      'translation': translation,
      'date': date.toIso8601String(),
      'reflection': reflection,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// Report Model
class Report {
  final String id;
  final String title;
  final String content;
  final String type; // chapter_activity, team_report, task_assignment
  final String authorId;
  final String? chapterId;
  final String? teamId;
  final String status; // draft, submitted, reviewed, approved
  final List<String> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  Report({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.authorId,
    this.chapterId,
    this.teamId,
    required this.status,
    required this.attachments,
    required this.createdAt,
    required this.updatedAt,
    this.submittedAt,
    this.reviewedAt,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      type: json['type'] as String,
      authorId: json['author_id'] as String,
      chapterId: json['chapter_id'] as String?,
      teamId: json['team_id'] as String?,
      status: json['status'] as String,
      attachments: List<String>.from(json['attachments'] as List),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : null,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'type': type,
      'author_id': authorId,
      'chapter_id': chapterId,
      'team_id': teamId,
      'status': status,
      'attachments': attachments,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'submitted_at': submittedAt?.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
    };
  }
}

// Task Assignment Model
class TaskAssignment {
  final String id;
  final String title;
  final String description;
  final String assignedById;
  final String assignedToId;
  final String? teamId;
  final String? chapterId;
  final String priority; // low, medium, high, urgent
  final String status; // assigned, in_progress, completed, overdue
  final DateTime dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  TaskAssignment({
    required this.id,
    required this.title,
    required this.description,
    required this.assignedById,
    required this.assignedToId,
    this.teamId,
    this.chapterId,
    required this.priority,
    required this.status,
    required this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  factory TaskAssignment.fromJson(Map<String, dynamic> json) {
    return TaskAssignment(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      assignedById: json['assigned_by_id'] as String,
      assignedToId: json['assigned_to_id'] as String,
      teamId: json['team_id'] as String?,
      chapterId: json['chapter_id'] as String?,
      priority: json['priority'] as String,
      status: json['status'] as String,
      dueDate: DateTime.parse(json['due_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'assigned_by_id': assignedById,
      'assigned_to_id': assignedToId,
      'team_id': teamId,
      'chapter_id': chapterId,
      'priority': priority,
      'status': status,
      'due_date': dueDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }
}

// Bible Verse Model
class BibleVerse {
  final String reference;
  final String kjv;
  final String nkjv;
  final String niv;

  BibleVerse({
    required this.reference,
    required this.kjv,
    required this.nkjv,
    required this.niv,
  });

  factory BibleVerse.fromJson(Map<String, dynamic> json) {
    return BibleVerse(
      reference: json['reference'] as String,
      kjv: json['kjv'] as String,
      nkjv: json['nkjv'] as String,
      niv: json['niv'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reference': reference,
      'kjv': kjv,
      'nkjv': nkjv,
      'niv': niv,
    };
  }

  String getTextForVersion(String version) {
    switch (version.toUpperCase()) {
      case 'KJV':
        return kjv;
      case 'NKJV':
        return nkjv;
      case 'NIV':
        return niv;
      default:
        return kjv;
    }
  }
}

// Prayer Request Model
class PrayerRequest {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String category;
  final bool isAnonymous;
  final bool isAnswered;
  final int prayerCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserProfile? user;

  PrayerRequest({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.category,
    this.isAnonymous = false,
    this.isAnswered = false,
    this.prayerCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.user,
  });

  factory PrayerRequest.fromJson(Map<String, dynamic> json) {
    return PrayerRequest(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      isAnswered: json['is_answered'] as bool? ?? false,
      prayerCount: json['prayer_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      user: json['user'] != null
          ? UserProfile.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'category': category,
      'is_anonymous': isAnonymous,
      'is_answered': isAnswered,
      'prayer_count': prayerCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

// Study Program Model
class StudyProgram {
  final String id;
  final String title;
  final String description;
  final String category;
  final String difficulty;
  final int duration; // in days
  final int totalLessons;
  final String imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudyProgram({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.duration,
    required this.totalLessons,
    required this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudyProgram.fromJson(Map<String, dynamic> json) {
    return StudyProgram(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      difficulty: json['difficulty'] as String,
      duration: json['duration'] as int,
      totalLessons: json['total_lessons'] as int,
      imageUrl: json['image_url'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'difficulty': difficulty,
      'duration': duration,
      'total_lessons': totalLessons,
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

// Study Progress Model
class StudyProgress {
  final String id;
  final String userId;
  final String programId;
  final int currentLesson;
  final int completedLessons;
  final double progressPercentage;
  final DateTime lastAccessedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final StudyProgram? program;

  StudyProgress({
    required this.id,
    required this.userId,
    required this.programId,
    required this.currentLesson,
    required this.completedLessons,
    required this.progressPercentage,
    required this.lastAccessedAt,
    required this.createdAt,
    required this.updatedAt,
    this.program,
  });

  factory StudyProgress.fromJson(Map<String, dynamic> json) {
    return StudyProgress(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      programId: json['program_id'] as String,
      currentLesson: json['current_lesson'] as int,
      completedLessons: json['completed_lessons'] as int,
      progressPercentage: (json['progress_percentage'] as num).toDouble(),
      lastAccessedAt: DateTime.parse(json['last_accessed_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      program: json['program'] != null
          ? StudyProgram.fromJson(json['program'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'program_id': programId,
      'current_lesson': currentLesson,
      'completed_lessons': completedLessons,
      'progress_percentage': progressPercentage,
      'last_accessed_at': lastAccessedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

// Health Tracking Model
class HealthTracking {
  final String id;
  final String userId;
  final String category;
  final double value;
  final String unit;
  final String? notes;
  final DateTime trackedAt;
  final DateTime createdAt;

  HealthTracking({
    required this.id,
    required this.userId,
    required this.category,
    required this.value,
    required this.unit,
    this.notes,
    required this.trackedAt,
    required this.createdAt,
  });

  factory HealthTracking.fromJson(Map<String, dynamic> json) {
    return HealthTracking(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      category: json['category'] as String,
      value: (json['value'] as num).toDouble(),
      unit: json['unit'] as String,
      notes: json['notes'] as String?,
      trackedAt: DateTime.parse(json['tracked_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'category': category,
      'value': value,
      'unit': unit,
      'notes': notes,
      'tracked_at': trackedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// Mission Model
class Mission {
  final String id;
  final String title;
  final String description;
  final String location;
  final String category;
  final String? difficulty;
  final int? duration; // in minutes
  final int? points;
  final String? status;
  final List<String>? instructions;
  final String? verificationMethod;
  final DateTime startDate;
  final DateTime? endDate;
  final int participantsCount;
  final int maxParticipants;
  final String? imageUrl;
  final List<String> requirements;
  final String contactInfo;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Mission({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.category,
    this.difficulty,
    this.duration,
    this.points,
    this.status,
    this.instructions,
    this.verificationMethod,
    required this.startDate,
    this.endDate,
    required this.participantsCount,
    required this.maxParticipants,
    this.imageUrl,
    required this.requirements,
    required this.contactInfo,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory Mission.fromJson(Map<String, dynamic> json) {
    return Mission(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      location: json['location'] as String,
      category: json['category'] as String,
      difficulty: json['difficulty'] as String?,
      duration: json['duration'] as int?,
      points: json['points'] as int?,
      status: json['status'] as String?,
      instructions: json['instructions'] != null
          ? List<String>.from(json['instructions'] as List)
          : null,
      verificationMethod: json['verification_method'] as String?,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      participantsCount: json['participants_count'] as int,
      maxParticipants: json['max_participants'] as int,
      imageUrl: json['image_url'] as String?,
      requirements: List<String>.from(json['requirements'] as List),
      contactInfo: json['contact_info'] as String,
      isActive: json['is_active'] as bool,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'location': location,
      'category': category,
      'difficulty': difficulty,
      'duration': duration,
      'points': points,
      'status': status,
      'instructions': instructions,
      'verification_method': verificationMethod,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'participants_count': participantsCount,
      'max_participants': maxParticipants,
      'image_url': imageUrl,
      'requirements': requirements,
      'contact_info': contactInfo,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

// Bible Story Model
class BibleStory {
  final String id;
  final String title;
  final String subtitle;
  final String ageGroup;
  final int duration; // in minutes
  final String description;
  final String moralLesson;
  final String bibleReference;
  final List<String> categories;
  final String imageUrl;

  BibleStory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.ageGroup,
    required this.duration,
    required this.description,
    required this.moralLesson,
    required this.bibleReference,
    required this.categories,
    required this.imageUrl,
  });

  factory BibleStory.fromJson(Map<String, dynamic> json) {
    return BibleStory(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      ageGroup: json['age_group'] as String,
      duration: json['duration'] as int,
      description: json['description'] as String,
      moralLesson: json['moral_lesson'] as String,
      bibleReference: json['bible_reference'] as String,
      categories: List<String>.from(json['categories'] as List),
      imageUrl: json['image_url'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'age_group': ageGroup,
      'duration': duration,
      'description': description,
      'moral_lesson': moralLesson,
      'bible_reference': bibleReference,
      'categories': categories,
      'image_url': imageUrl,
    };
  }
}
