import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_models.dart';
import '../utils/logger.dart';
import '../utils/app_exception.dart';
import 'tag_visibility_checker.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final Logger _logger = Logger('ChatService');
  // Temporary Supabase stub to allow compilation while migrating to Firebase

  // Get all channels for a user
  Future<List<ChatChannel>> getUserChannels(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('chat_channels')
          .where('members', arrayContains: userId)
          .where('is_archived', isEqualTo: false)
          .orderBy('last_message_at', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ChatChannel.fromJson(data);
      }).toList();
    } catch (e) {
      _logger.error('Error fetching user channels: $e');
      throw DatabaseException('Failed to fetch user channels',
          originalError: e);
    }
  }

  // Enhanced get messages method with tag loading
  Future<List<ChatMessage>> getChannelMessages(
    String channelId, {
    int limit = 50,
    String? before,
  }) async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('chat_channels')
          .doc(channelId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (before != null) {
        final doc = await FirebaseFirestore.instance
            .collection('chat_channels')
            .doc(channelId)
            .collection('messages')
            .doc(before)
            .get();
        if (doc.exists) {
          query = query.startAfterDocument(doc);
        }
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return ChatMessage.fromJson(data);
      }).toList();
    } catch (e) {
      _logger.error('Error fetching channel messages: $e');
      throw DatabaseException('Failed to fetch channel messages',
          originalError: e);
    }
  }

  // Send a message
  // Enhanced send message method with new tagging system
  Future<ChatMessage> sendMessage({
    required String channelId,
    required String content,
    MessageType type = MessageType.text,
    List<MessageTag> tags = const [],
    String? replyToId,
    List<String> attachments = const [],
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw AuthException('User not authenticated');

      // Map tags to ChatMessage fields
      final taggedUsers = tags
          .where((t) => t.type == TagType.user)
          .map((t) => t.userId ?? t.value)
          .toList();
      final taggedGroups = tags
          .where((t) =>
              t.type == TagType.group ||
              t.type == TagType.role ||
              t.type == TagType.special)
          .map((t) => t.value)
          .toList();

      final messageData = {
        'sender_id': user.uid,
        'sender_name': user.displayName ?? user.email ?? 'User',
        'sender_avatar': user.photoURL ?? '',
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'type': type.name,
        'tagged_users': taggedUsers,
        'tagged_groups': taggedGroups,
        'reply_to_id': replyToId,
        'attachments': attachments,
        'is_edited': false,
      };

      final ref = await FirebaseFirestore.instance
          .collection('chat_channels')
          .doc(channelId)
          .collection('messages')
          .add(messageData);

      await _storeMessageTags(ref.id, tags);
      await _sendTagNotifications(
        channelId: channelId,
        messageId: ref.id,
        tags: tags,
        content: content,
      );

      // Update channel last message
      await _updateChannelLastMessage(channelId, content);

      return ChatMessage(
        id: ref.id,
        senderId: user.uid,
        senderName: user.displayName ?? user.email ?? 'User',
        senderAvatar: user.photoURL ?? '',
        content: content,
        timestamp: DateTime.now(),
        type: type,
        taggedUsers: taggedUsers,
        taggedGroups: taggedGroups,
        replyToId: replyToId,
        attachments: attachments,
      );
    } catch (e) {
      _logger.error('Error sending message: $e');
      if (e is AuthException) rethrow;
      throw DatabaseException('Failed to send message', originalError: e);
    }
  }

  // Create a new channel
  Future<ChatChannel> createChannel({
    required String name,
    required String description,
    required ChannelType type,
    required List<String> members,
    List<String> admins = const [],
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw AuthException('User not authenticated');

      final channelData = {
        'name': name,
        'description': description,
        'type': type.name,
        'created_by': user.uid,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'is_archived': false,
        'members': [user.uid, ...members],
        'admins': [user.uid, ...admins],
        'last_message': null,
        'last_message_at': FieldValue.serverTimestamp(),
        'last_message_sender_id': null,
      };

      final ref = await FirebaseFirestore.instance
          .collection('chat_channels')
          .add(channelData);

      return ChatChannel(
        id: ref.id,
        name: name,
        description: description,
        type: type,
        members: [user.uid, ...members],
        admins: [user.uid, ...admins],
        createdAt: DateTime.now(),
        lastMessageAt: DateTime.now(),
        isArchived: false,
      );
    } catch (e) {
      _logger.error('Error creating channel: $e');
      if (e is AuthException) rethrow;
      throw DatabaseException('Failed to create channel', originalError: e);
    }
  }

  // Join a channel
  Future<void> joinChannel(String channelId) async {
    try {
      // Stub implementation
      _logger.warning('joinChannel stubbed: no backend call performed.');
    } catch (e) {
      _logger.error('Error joining channel: $e');
      throw DatabaseException('Failed to join channel', originalError: e);
    }
  }

  // Leave a channel
  Future<void> leaveChannel(String channelId) async {
    try {
      // Stub implementation
      _logger.warning('leaveChannel stubbed: no backend call performed.');
    } catch (e) {
      _logger.error('Error leaving channel: $e');
      throw DatabaseException('Failed to leave channel', originalError: e);
    }
  }

  // Enhanced taggable entities method with role-based filtering
  Future<List<TaggedEntity>> getTaggableEntities(String query,
      [TagType? tagType]) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw AuthException('User not authenticated');

      final userRoles = await _getUserRoles(user.uid);
      final entities = <TaggedEntity>[];

      // Get users (for @ tags)
      if (tagType == null || tagType == TagType.user) {
        // Fetch users from Firebase
        final snapshot =
            await FirebaseFirestore.instance.collection('profiles').get();
        final usersResponse = snapshot.docs.map((doc) => doc.data()).toList();

        for (final userJson in usersResponse) {
          entities.add(TaggedEntity(
            id: userJson['id'],
            name: userJson['full_name'] ?? userJson['email'],
            type: TagType.user,
            avatar: userJson['avatar_url'],
          ));
        }
      }

      // Get roles (for # tags)
      if (tagType == null || tagType == TagType.role) {
        const rolesResponse = [];

        for (final roleJson in rolesResponse) {
          // Check if user can tag this role
          if (await TagVisibilityChecker.canUserSeeTag(
            user.uid,
            MessageTag(
              type: TagType.role,
              value: roleJson['role'],
            ),
          )) {
            entities.add(TaggedEntity(
              id: roleJson['role'],
              name: roleJson['role_name'] ?? roleJson['role'],
              type: TagType.role,
            ));
          }
        }
      }

      // Get groups (for # tags)
      if (tagType == null || tagType == TagType.group) {
        const groupsResponse = [];

        for (final groupJson in groupsResponse) {
          entities.add(TaggedEntity(
            id: groupJson['group_name'],
            name: groupJson['group_name'],
            type: TagType.group,
          ));
        }
      }

      // Get special tags (for ! tags)
      if (tagType == null || tagType == TagType.special) {
        final specialTags = _getSpecialTags(query, userRoles);
        entities.addAll(specialTags);
      }

      return entities;
    } catch (e) {
      _logger.error('Error fetching taggable entities: $e');
      return [];
    }
  }

  // Subscribe to channel messages
  Stream<List<ChatMessage>> subscribeToChannelMessages(String channelId) {
    return FirebaseFirestore.instance
        .collection('chat_channels')
        .doc(channelId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ChatMessage.fromJson(data);
      }).toList();
    });
  }

  // Subscribe to user channels
  Stream<List<ChatChannel>> subscribeToUserChannels(String userId) {
    return FirebaseFirestore.instance
        .collection('chat_channels')
        .where('members', arrayContains: userId)
        .where('is_archived', isEqualTo: false)
        .orderBy('last_message_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ChatChannel.fromJson(data);
      }).toList();
    });
  }

  // Get special tags based on user permissions
  List<TaggedEntity> _getSpecialTags(String query, List<String> userRoles) {
    final specialTags = <TaggedEntity>[];

    final availableTags = {
      'all': 'All members',
      'online': 'Online members',
      'active': 'Active members',
      'new': 'New members',
      'meeting': 'Meeting participants',
      'conference': 'Conference attendees',
      'training': 'Training participants',
    };

    for (final entry in availableTags.entries) {
      if (entry.key.toLowerCase().contains(query.toLowerCase()) ||
          entry.value.toLowerCase().contains(query.toLowerCase())) {
        // Check if user has permission to use this special tag
        final canUse = _canUseSpecialTag(entry.key, userRoles);
        if (canUse) {
          specialTags.add(TaggedEntity(
            id: entry.key,
            name: entry.value,
            type: TagType.special,
          ));
        }
      }
    }

    return specialTags;
  }

  bool _canUseSpecialTag(String tagValue, List<String> userRoles) {
    // Define which roles can use which special tags
    final permissions = {
      'all': [
        'coordinator',
        'director',
        'leadership',
        'executive',
        'trustees',
        'bod'
      ],
      'online': ['member'], // Everyone can use
      'active': ['member'], // Everyone can use
      'new': ['member'], // Everyone can use
      'meeting': ['coordinator', 'director', 'leadership'],
      'conference': ['coordinator', 'director', 'leadership'],
      'training': ['coordinator', 'director', 'leadership'],
    };

    final requiredRoles = permissions[tagValue] ?? [];
    return requiredRoles.any((role) => userRoles.contains(role));
  }

  // Store message tags in database
  Future<void> _storeMessageTags(
      String messageId, List<MessageTag> tags) async {
    try {
      if (tags.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      final tagsCollection =
          FirebaseFirestore.instance.collection('message_tags');
      for (final tag in tags) {
        final docRef = tagsCollection.doc();
        batch.set(docRef, {
          'message_id': messageId,
          ...tag.toJson(),
          'created_at': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      _logger.error('Error storing message tags: $e');
    }
  }

  // Get message tags from database
  Future<List<MessageTag>> getMessageTags(String messageId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('message_tags')
          .where('message_id', isEqualTo: messageId)
          .get();
      return snapshot.docs
          .map((doc) => MessageTag.fromJson(doc.data()))
          .toList();
    } catch (e) {
      _logger.error('Error fetching message tags: $e');
      return [];
    }
  }

  // Get user roles
  Future<List<String>> _getUserRoles(String userId) async {
    try {
      return [];
    } catch (e) {
      _logger.error('Error fetching user roles: $e');
      return [];
    }
  }

  Future<void> _updateChannelLastMessage(
      String channelId, String content) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance
          .collection('chat_channels')
          .doc(channelId)
          .update({
        'last_message': content,
        'last_message_at': FieldValue.serverTimestamp(),
        'last_message_sender_id': user?.uid,
      });
    } catch (e) {
      _logger.error('Error updating channel last message: $e');
    }
  }

  // Enhanced tag notifications
  Future<void> _sendTagNotifications({
    required String channelId,
    required String messageId,
    required List<MessageTag> tags,
    required String content,
  }) async {
    try {
      for (final tag in tags) {
        switch (tag.type) {
          case TagType.user:
            if (tag.userId != null) {
              await _sendUserNotification(tag.userId!, messageId, content);
            }
            break;
          case TagType.role:
            await _sendRoleNotification(tag.value, messageId, content);
            break;
          case TagType.group:
            await _sendGroupNotification(tag.value, messageId, content);
            break;
          case TagType.special:
            await _sendSpecialTagNotification(tag.value, messageId, content);
            break;
        }
      }
    } catch (e) {
      _logger.error('Error sending tag notifications: $e');
    }
  }

  Future<void> _sendUserNotification(
      String userId, String messageId, String content) async {
    // Implementation for user notifications
    _logger.info('Sending user notification to $userId for message $messageId');
  }

  Future<void> _sendRoleNotification(
      String role, String messageId, String content) async {
    // Implementation for role-based notifications
    _logger.info('Sending role notification to $role for message $messageId');
  }

  Future<void> _sendGroupNotification(
      String group, String messageId, String content) async {
    // Implementation for group notifications
    _logger.info('Sending group notification to $group for message $messageId');
  }

  Future<void> _sendSpecialTagNotification(
      String specialTag, String messageId, String content) async {
    // Implementation for special tag notifications
    _logger.info(
        'Sending special tag notification for $specialTag for message $messageId');
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String channelId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Update the user's last seen timestamp in the channel members subcollection
      // This requires the subcollection 'members' to exist or we create it
      final memberRef = FirebaseFirestore.instance
          .collection('chat_channels')
          .doc(channelId)
          .collection('members')
          .doc(user.uid);

      await memberRef.set({
        'last_seen': FieldValue.serverTimestamp(),
        'user_id': user.uid,
      }, SetOptions(merge: true));
    } catch (e) {
      _logger.error('Error marking messages as read: $e');
    }
  }

  // Get unread message count
  Future<int> getUnreadCount(String channelId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0;

      // Get user's last seen time
      final memberDoc = await FirebaseFirestore.instance
          .collection('chat_channels')
          .doc(channelId)
          .collection('members')
          .doc(user.uid)
          .get();

      DateTime? lastSeen;
      if (memberDoc.exists && memberDoc.data() != null) {
        final data = memberDoc.data()!;
        if (data['last_seen'] is Timestamp) {
          lastSeen = (data['last_seen'] as Timestamp).toDate();
        }
      }

      // If never seen, count all messages (limit to 100 to avoid excessive reads)
      Query query = FirebaseFirestore.instance
          .collection('chat_channels')
          .doc(channelId)
          .collection('messages');

      if (lastSeen != null) {
        query = query.where('timestamp',
            isGreaterThan: Timestamp.fromDate(lastSeen));
      }

      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      _logger.error('Error getting unread count: $e');
      return 0;
    }
  }

  /// Get a [ChatUser] profile for the given user ID.
  Future<ChatUser?> getChatUser(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('chat_users')
          .doc(userId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return ChatUser.fromJson(data);
      }

      // Fall back to profile collection if no chat_users doc
      final profileDoc = await FirebaseFirestore.instance
          .collection('profiles')
          .doc(userId)
          .get();

      if (profileDoc.exists) {
        final pData = profileDoc.data()!;
        return ChatUser(
          id: userId,
          name: pData['full_name'] ?? pData['email'] ?? 'User',
          email: pData['email'] ?? '',
          avatar: pData['avatar_url'] as String?,
          role: UserRole.member,
          isOnline: false,
          lastSeen: DateTime.now(),
        );
      }
      return null;
    } catch (e) {
      _logger.error('Error getting chat user: $e');
      return null;
    }
  }

  /// Update a [ChatUser]'s online status (e.g. on app foreground/background).
  Future<void> updateChatUserStatus({
    required String userId,
    required bool isOnline,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('chat_users')
          .doc(userId)
          .set({
        'is_online': isOnline,
        'last_seen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      _logger.error('Error updating chat user status: $e');
    }
  }

  /// Get all currently online [ChatUser]s in a channel.
  Future<List<ChatUser>> getOnlineChatUsers(String channelId) async {
    try {
      // Get channel members
      final channelDoc = await FirebaseFirestore.instance
          .collection('chat_channels')
          .doc(channelId)
          .get();

      if (!channelDoc.exists) return [];

      final members =
          List<String>.from(channelDoc.data()?['members'] ?? []);

      // Get online status for each member
      final onlineUsers = <ChatUser>[];
      for (final memberId in members) {
        final chatUser = await getChatUser(memberId);
        if (chatUser != null && chatUser.isOnline) {
          onlineUsers.add(chatUser);
        }
      }
      return onlineUsers;
    } catch (e) {
      _logger.error('Error getting online chat users: $e');
      return [];
    }
  }
}
