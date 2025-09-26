class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String content;
  final DateTime timestamp;
  final MessageType type;
  final List<String> taggedUsers;
  final List<String> taggedGroups;
  final String? replyToId;
  final List<String> attachments;
  final bool isEdited;
  final DateTime? editedAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.content,
    required this.timestamp,
    required this.type,
    this.taggedUsers = const [],
    this.taggedGroups = const [],
    this.replyToId,
    this.attachments = const [],
    this.isEdited = false,
    this.editedAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String,
      senderAvatar: json['sender_avatar'] as String? ?? '',
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
      taggedUsers: List<String>.from(json['tagged_users'] ?? []),
      taggedGroups: List<String>.from(json['tagged_groups'] ?? []),
      replyToId: json['reply_to_id'] as String?,
      attachments: List<String>.from(json['attachments'] ?? []),
      isEdited: json['is_edited'] as bool? ?? false,
      editedAt: json['edited_at'] != null
          ? DateTime.parse(json['edited_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_avatar': senderAvatar,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'tagged_users': taggedUsers,
      'tagged_groups': taggedGroups,
      'reply_to_id': replyToId,
      'attachments': attachments,
      'is_edited': isEdited,
      'edited_at': editedAt?.toIso8601String(),
    };
  }

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    String? content,
    DateTime? timestamp,
    MessageType? type,
    List<String>? taggedUsers,
    List<String>? taggedGroups,
    String? replyToId,
    List<String>? attachments,
    bool? isEdited,
    DateTime? editedAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      taggedUsers: taggedUsers ?? this.taggedUsers,
      taggedGroups: taggedGroups ?? this.taggedGroups,
      replyToId: replyToId ?? this.replyToId,
      attachments: attachments ?? this.attachments,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
    );
  }
}

enum MessageType {
  text,
  image,
  file,
  audio,
  video,
  system,
}

class ChatChannel {
  final String id;
  final String name;
  final String description;
  final ChannelType type;
  final List<String> members;
  final List<String> admins;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final String? lastMessage;
  final int unreadCount;
  final bool isArchived;
  final Map<String, dynamic> settings;

  const ChatChannel({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.members,
    required this.admins,
    required this.createdAt,
    this.lastMessageAt,
    this.lastMessage,
    this.unreadCount = 0,
    this.isArchived = false,
    this.settings = const {},
  });

  factory ChatChannel.fromJson(Map<String, dynamic> json) {
    return ChatChannel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      type: ChannelType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ChannelType.general,
      ),
      members: List<String>.from(json['members'] ?? []),
      admins: List<String>.from(json['admins'] ?? []),
      createdAt: DateTime.parse(json['created_at'] as String),
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      lastMessage: json['last_message'] as String?,
      unreadCount: json['unread_count'] as int? ?? 0,
      isArchived: json['is_archived'] as bool? ?? false,
      settings: Map<String, dynamic>.from(json['settings'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.name,
      'members': members,
      'admins': admins,
      'created_at': createdAt.toIso8601String(),
      'last_message_at': lastMessageAt?.toIso8601String(),
      'last_message': lastMessage,
      'unread_count': unreadCount,
      'is_archived': isArchived,
      'settings': settings,
    };
  }
}

enum ChannelType {
  general,
  bod,
  directors,
  coordinators,
  chapter,
  team,
  direct,
  announcement,
}

class TaggedEntity {
  final String id;
  final String name;
  final TagType type;
  final String? avatar;

  const TaggedEntity({
    required this.id,
    required this.name,
    required this.type,
    this.avatar,
  });

  factory TaggedEntity.fromJson(Map<String, dynamic> json) {
    return TaggedEntity(
      id: json['id'] as String,
      name: json['name'] as String,
      type: TagType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TagType.user,
      ),
      avatar: json['avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'avatar': avatar,
    };
  }
}

enum TagType {
  user,
  group,
  role,
  special,
}

class MessageTag {
  final TagType type;
  final String value;
  final String? displayName;
  final String? userId;
  final String? roleId;

  const MessageTag({
    required this.type,
    required this.value,
    this.displayName,
    this.userId,
    this.roleId,
  });

  String get prefix {
    switch (type) {
      case TagType.user:
        return '@';
      case TagType.role:
      case TagType.group:
      case TagType.special:
        return '#';
    }
  }

  String get fullTag => '$prefix$value';

  factory MessageTag.fromJson(Map<String, dynamic> json) {
    return MessageTag(
      type: TagType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TagType.user,
      ),
      value: json['value'] as String,
      displayName: json['display_name'] as String?,
      userId: json['user_id'] as String?,
      roleId: json['role_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'value': value,
      'display_name': displayName,
      'user_id': userId,
      'role_id': roleId,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageTag &&
        other.type == type &&
        other.value == value;
  }

  @override
  int get hashCode => type.hashCode ^ value.hashCode;

  @override
  String toString() => fullTag;
}

class ChatUser {
  final String id;
  final String name;
  final String email;
  final String? avatar;
  final UserRole role;
  final bool isOnline;
  final DateTime? lastSeen;
  final String? status;

  const ChatUser({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    required this.role,
    this.isOnline = false,
    this.lastSeen,
    this.status,
  });

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      avatar: json['avatar'] as String?,
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.member,
      ),
      isOnline: json['is_online'] as bool? ?? false,
      lastSeen: json['last_seen'] != null
          ? DateTime.parse(json['last_seen'] as String)
          : null,
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatar': avatar,
      'role': role.name,
      'is_online': isOnline,
      'last_seen': lastSeen?.toIso8601String(),
      'status': status,
    };
  }
}

enum UserRole {
  member,
  coordinator,
  director,
  bod,
  trustee,
  admin,
}
