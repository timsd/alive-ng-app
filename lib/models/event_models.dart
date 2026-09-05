// Domain models for events and announcements.
//
// These models are SDK-agnostic: they MUST NOT import `package:appwrite`
// or any other backend SDK. The service layer maps raw rows into these
// objects before returning them to the UI.

/// A ministry event shown on the Events screen.
class Event {
  final String id;
  final String title;
  final String description;
  final String? location;
  final String status;
  final DateTime? scheduledTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Event({
    required this.id,
    required this.title,
    required this.description,
    this.location,
    this.status = 'published',
    this.scheduledTime,
    this.createdAt,
    this.updatedAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      location: json['location'] as String?,
      status: json['status'] as String? ?? 'published',
      scheduledTime: _tryParseDate(
        json['scheduled_time'] ?? json['scheduled_for'],
      ),
      createdAt: _tryParseDate(json['created_at']),
      updatedAt: _tryParseDate(json['updated_at']),
    );
  }

  static DateTime? _tryParseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  /// Sort key used by the service layer (newest first).
  DateTime get sortDate => createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
}

/// An announcement broadcast to app users.
class Announcement {
  final String id;
  final String title;
  final String content;
  final String audience;
  final String priority;
  final String? actionText;
  final String? actionUrl;
  final DateTime? createdAt;

  const Announcement({
    required this.id,
    required this.title,
    required this.content,
    this.audience = 'all',
    this.priority = 'normal',
    this.actionText,
    this.actionUrl,
    this.createdAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      content: (json['content'] ?? json['message'] ?? json['body'] ?? '')
          .toString(),
      audience: json['audience'] as String? ?? 'all',
      priority: json['priority'] as String? ?? 'normal',
      actionText: json['action_text'] as String?,
      actionUrl: json['action_url'] as String?,
      createdAt: _tryParseDate(
        json['created_at'] ?? json['published_at'],
      ),
    );
  }

  static DateTime? _tryParseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  /// Sort key used by the service layer (newest first).
  DateTime get sortDate => createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
}