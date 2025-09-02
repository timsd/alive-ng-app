import 'package:equatable/equatable.dart';

enum LeadershipPosition {
  bod,
  director,
  chapterCoordinator,
  campusMissionCoordinator,
  fieldworkCoordinator,
  programmingCoordinator,
  treasurer,
  evangelismCoordinator,
  amtcCoordinator,
  trustee,
}

enum ServiceStatus {
  active,
  completed,
  archived,
}

class LeadershipRecord extends Equatable {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String? userPhone;
  final LeadershipPosition position;
  final String positionTitle;
  final DateTime startDate;
  final DateTime? endDate;
  final int yearsOfService;
  final ServiceStatus status;
  final String? notes;
  final String? achievements;
  final Map<String, dynamic>? contactInfo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const LeadershipRecord({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.userPhone,
    required this.position,
    required this.positionTitle,
    required this.startDate,
    this.endDate,
    required this.yearsOfService,
    required this.status,
    this.notes,
    this.achievements,
    this.contactInfo,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory LeadershipRecord.fromJson(Map<String, dynamic> json) {
    return LeadershipRecord(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String,
      userEmail: json['user_email'] as String,
      userPhone: json['user_phone'] as String?,
      position: LeadershipPosition.values.firstWhere(
        (e) => e.name == json['position'],
        orElse: () => LeadershipPosition.bod,
      ),
      positionTitle: json['position_title'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      yearsOfService: json['years_of_service'] as int,
      status: ServiceStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ServiceStatus.active,
      ),
      notes: json['notes'] as String?,
      achievements: json['achievements'] as String?,
      contactInfo: json['contact_info'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'user_email': userEmail,
      'user_phone': userPhone,
      'position': position.name,
      'position_title': positionTitle,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'years_of_service': yearsOfService,
      'status': status.name,
      'notes': notes,
      'achievements': achievements,
      'contact_info': contactInfo,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
    };
  }

  LeadershipRecord copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userEmail,
    String? userPhone,
    LeadershipPosition? position,
    String? positionTitle,
    DateTime? startDate,
    DateTime? endDate,
    int? yearsOfService,
    ServiceStatus? status,
    String? notes,
    String? achievements,
    Map<String, dynamic>? contactInfo,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return LeadershipRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userPhone: userPhone ?? this.userPhone,
      position: position ?? this.position,
      positionTitle: positionTitle ?? this.positionTitle,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      yearsOfService: yearsOfService ?? this.yearsOfService,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      achievements: achievements ?? this.achievements,
      contactInfo: contactInfo ?? this.contactInfo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  String get positionDisplayName {
    switch (position) {
      case LeadershipPosition.bod:
        return 'Board of Directors';
      case LeadershipPosition.director:
        return 'Director';
      case LeadershipPosition.chapterCoordinator:
        return 'Chapter Coordinator';
      case LeadershipPosition.campusMissionCoordinator:
        return 'Campus Mission Coordinator';
      case LeadershipPosition.fieldworkCoordinator:
        return 'Fieldwork Coordinator';
      case LeadershipPosition.programmingCoordinator:
        return 'Programming Coordinator';
      case LeadershipPosition.treasurer:
        return 'Treasurer';
      case LeadershipPosition.evangelismCoordinator:
        return 'Evangelism Coordinator';
      case LeadershipPosition.amtcCoordinator:
        return 'AMTC Coordinator';
      case LeadershipPosition.trustee:
        return 'Trustee';
    }
  }

  String get statusDisplayName {
    switch (status) {
      case ServiceStatus.active:
        return 'Active';
      case ServiceStatus.completed:
        return 'Completed';
      case ServiceStatus.archived:
        return 'Archived';
    }
  }

  bool get isActive => status == ServiceStatus.active;
  bool get isCompleted => status == ServiceStatus.completed;
  bool get isArchived => status == ServiceStatus.archived;

  Duration get serviceDuration {
    final end = endDate ?? DateTime.now();
    return end.difference(startDate);
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        userName,
        userEmail,
        userPhone,
        position,
        positionTitle,
        startDate,
        endDate,
        yearsOfService,
        status,
        notes,
        achievements,
        contactInfo,
        createdAt,
        updatedAt,
        createdBy,
        updatedBy,
      ];
}

class LeadershipTransition extends Equatable {
  final String id;
  final String userId;
  final LeadershipPosition? fromPosition;
  final LeadershipPosition toPosition;
  final String? fromPositionTitle;
  final String toPositionTitle;
  final DateTime transitionDate;
  final String reason;
  final String? notes;
  final String? approvedBy;
  final DateTime createdAt;

  const LeadershipTransition({
    required this.id,
    required this.userId,
    this.fromPosition,
    required this.toPosition,
    this.fromPositionTitle,
    required this.toPositionTitle,
    required this.transitionDate,
    required this.reason,
    this.notes,
    this.approvedBy,
    required this.createdAt,
  });

  factory LeadershipTransition.fromJson(Map<String, dynamic> json) {
    return LeadershipTransition(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      fromPosition: json['from_position'] != null
          ? LeadershipPosition.values.firstWhere(
              (e) => e.name == json['from_position'],
              orElse: () => LeadershipPosition.bod,
            )
          : null,
      toPosition: LeadershipPosition.values.firstWhere(
        (e) => e.name == json['to_position'],
        orElse: () => LeadershipPosition.bod,
      ),
      fromPositionTitle: json['from_position_title'] as String?,
      toPositionTitle: json['to_position_title'] as String,
      transitionDate: DateTime.parse(json['transition_date'] as String),
      reason: json['reason'] as String,
      notes: json['notes'] as String?,
      approvedBy: json['approved_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'from_position': fromPosition?.name,
      'to_position': toPosition.name,
      'from_position_title': fromPositionTitle,
      'to_position_title': toPositionTitle,
      'transition_date': transitionDate.toIso8601String(),
      'reason': reason,
      'notes': notes,
      'approved_by': approvedBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        fromPosition,
        toPosition,
        fromPositionTitle,
        toPositionTitle,
        transitionDate,
        reason,
        notes,
        approvedBy,
        createdAt,
      ];
}

class LeadershipSummary extends Equatable {
  final String userId;
  final String userName;
  final LeadershipPosition? currentPosition;
  final String? currentPositionTitle;
  final DateTime? currentPositionStartDate;
  final List<LeadershipRecord> serviceHistory;
  final int totalYearsOfService;
  final int totalPositionsHeld;
  final List<LeadershipTransition> transitions;

  const LeadershipSummary({
    required this.userId,
    required this.userName,
    this.currentPosition,
    this.currentPositionTitle,
    this.currentPositionStartDate,
    required this.serviceHistory,
    required this.totalYearsOfService,
    required this.totalPositionsHeld,
    required this.transitions,
  });

  bool get hasCurrentPosition => currentPosition != null;
  bool get hasServiceHistory => serviceHistory.isNotEmpty;

  LeadershipRecord? get currentRecord {
    return serviceHistory.where((record) => record.isActive).firstOrNull;
  }

  List<LeadershipRecord> get completedRecords {
    return serviceHistory.where((record) => record.isCompleted).toList();
  }

  List<LeadershipRecord> get archivedRecords {
    return serviceHistory.where((record) => record.isArchived).toList();
  }

  @override
  List<Object?> get props => [
        userId,
        userName,
        currentPosition,
        currentPositionTitle,
        currentPositionStartDate,
        serviceHistory,
        totalYearsOfService,
        totalPositionsHeld,
        transitions,
      ];
}

extension LeadershipPositionExtension on LeadershipPosition {
  String get displayName {
    switch (this) {
      case LeadershipPosition.bod:
        return 'Board of Directors';
      case LeadershipPosition.director:
        return 'Director';
      case LeadershipPosition.chapterCoordinator:
        return 'Chapter Coordinator';
      case LeadershipPosition.campusMissionCoordinator:
        return 'Campus Mission Coordinator';
      case LeadershipPosition.fieldworkCoordinator:
        return 'Fieldwork Coordinator';
      case LeadershipPosition.programmingCoordinator:
        return 'Programming Coordinator';
      case LeadershipPosition.treasurer:
        return 'Treasurer';
      case LeadershipPosition.evangelismCoordinator:
        return 'Evangelism Coordinator';
      case LeadershipPosition.amtcCoordinator:
        return 'AMTC Coordinator';
      case LeadershipPosition.trustee:
        return 'Trustee';
    }
  }

  String get shortName {
    switch (this) {
      case LeadershipPosition.bod:
        return 'BOD';
      case LeadershipPosition.director:
        return 'Director';
      case LeadershipPosition.chapterCoordinator:
        return 'Chapter Coord.';
      case LeadershipPosition.campusMissionCoordinator:
        return 'Campus Coord.';
      case LeadershipPosition.fieldworkCoordinator:
        return 'Fieldwork Coord.';
      case LeadershipPosition.programmingCoordinator:
        return 'Programming Coord.';
      case LeadershipPosition.treasurer:
        return 'Treasurer';
      case LeadershipPosition.evangelismCoordinator:
        return 'Evangelism Coord.';
      case LeadershipPosition.amtcCoordinator:
        return 'AMTC Coord.';
      case LeadershipPosition.trustee:
        return 'Trustee';
    }
  }

  int get hierarchyLevel {
    switch (this) {
      case LeadershipPosition.bod:
        return 1;
      case LeadershipPosition.trustee:
        return 1;
      case LeadershipPosition.director:
        return 2;
      case LeadershipPosition.chapterCoordinator:
      case LeadershipPosition.campusMissionCoordinator:
      case LeadershipPosition.fieldworkCoordinator:
      case LeadershipPosition.programmingCoordinator:
      case LeadershipPosition.evangelismCoordinator:
      case LeadershipPosition.amtcCoordinator:
        return 3;
      case LeadershipPosition.treasurer:
        return 3;
    }
  }
}
