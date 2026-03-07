class PrayerRequest {
  final String id;
  final String title;
  final String description;
  final String requestedBy;
  final String? requestedById;
  final String status; // pending, approved, answered
  final bool isAnonymous;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? answeredAt;
  final String? answer;

  PrayerRequest({
    required this.id,
    required this.title,
    required this.description,
    required this.requestedBy,
    this.requestedById,
    this.status = 'pending',
    this.isAnonymous = false,
    required this.createdAt,
    this.updatedAt,
    this.answeredAt,
    this.answer,
  });

  factory PrayerRequest.fromJson(Map<String, dynamic> json) {
    return PrayerRequest(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      requestedBy: json['requested_by'] as String,
      requestedById: json['requested_by_id'] as String?,
      status: json['status'] as String? ?? 'pending',
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      answeredAt: json['answered_at'] != null
          ? DateTime.parse(json['answered_at'] as String)
          : null,
      answer: json['answer'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'requested_by': requestedBy,
      'requested_by_id': requestedById,
      'status': status,
      'is_anonymous': isAnonymous,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'answered_at': answeredAt?.toIso8601String(),
      'answer': answer,
    };
  }
}



