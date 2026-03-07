class Testimony {
  final String id;
  final String content;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final DateTime createdAt;
  final bool isAnonymous;
  final int likesCount;
  final bool isApproved;

  Testimony({
    required this.id,
    required this.content,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.createdAt,
    this.isAnonymous = false,
    this.likesCount = 0,
    this.isApproved = false,
  });

  factory Testimony.fromJson(Map<String, dynamic> json) {
    return Testimony(
      id: json['id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      userName: json['user_name'] as String? ?? 'Anonymous',
      userAvatarUrl: json['user_avatar_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      likesCount: json['likes_count'] as int? ?? 0,
      isApproved: json['is_approved'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'user_id': userId,
      'user_name': userName,
      'user_avatar_url': userAvatarUrl,
      'created_at': createdAt.toIso8601String(),
      'is_anonymous': isAnonymous,
      'likes_count': likesCount,
      'is_approved': isApproved,
    };
  }
}
