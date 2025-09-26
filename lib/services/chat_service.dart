import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_models.dart';
import '../utils/logger.dart';
import 'tag_parser.dart';
import 'tag_visibility_checker.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final Logger _logger = Logger('ChatService');

  // Get all channels for a user
  Future<List<ChatChannel>> getUserChannels(String userId) async {
    try {
      final response = await _supabase
          .from('chat_channels')
          .select('*, channel_members!inner(*)')
          .eq('channel_members.user_id', userId)
          .eq('is_archived', false)
          .order('last_message_at', ascending: false);

      return (response as List)
          .map((json) => ChatChannel.fromJson(json))
          .toList();
    } catch (e) {
      _logger.error('Error fetching user channels: $e');
      rethrow;
    }
  }

  // Enhanced get messages method with tag loading
  Future<List<ChatMessage>> getChannelMessages(
    String channelId, {
    int limit = 50,
    String? before,
  }) async {
    try {
      dynamic query = _supabase
          .from('chat_messages')
          .select('*, sender:profiles(*)')
          .eq('channel_id', channelId)
          .order('timestamp', ascending: false);

      // Add timestamp filtering for pagination
      if (before != null) {
        query = query.lt('timestamp', before);
      }
      
      query = query.limit(limit);

      final response = await query;
      final messages = <ChatMessage>[];

      for (final messageJson in response) {
        // Load tags for each message
        final messageTags = await _getMessageTags(messageJson['id']);
        
        final message = ChatMessage.fromJson({
          ...messageJson,
          'sender_name':
              messageJson['sender']['full_name'] ?? messageJson['sender']['email'],
          'sender_avatar': messageJson['sender']['avatar_url'] ?? '',
          'tags': messageTags.map((tag) => tag.toJson()).toList(),
        });
        
        messages.add(message);
      }

      return messages.reversed.toList();
    } catch (e) {
      _logger.error('Error fetching channel messages: $e');
      rethrow;
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
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Parse tags from content using the new TagParser
      final parsedTags = TagParser.parseMessage(content);
      final allTags = <MessageTag>[...tags, ...parsedTags];

      // Filter tags based on user's permissions
      final visibleTags = <MessageTag>[];
      for (final tag in allTags) {
        if (await TagVisibilityChecker.canUserSeeTag(
          user.id,
          tag,
        )) {
          visibleTags.add(tag);
        }
      }

      final messageData = {
        'channel_id': channelId,
        'sender_id': user.id,
        'content': content,
        'type': type.name,
        'reply_to_id': replyToId,
        'attachments': attachments,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('chat_messages')
          .insert(messageData)
          .select('*, sender:profiles(*)')
          .single();

      final messageId = response['id'];

      // Store message tags in the database
      if (visibleTags.isNotEmpty) {
        await _storeMessageTags(messageId, visibleTags);
      }

      // Update channel last message
      await _updateChannelLastMessage(channelId, content);

      // Send notifications to tagged users
      if (visibleTags.isNotEmpty) {
        await _sendTagNotifications(
          channelId: channelId,
          messageId: messageId,
          tags: visibleTags,
          content: content,
        );
      }

      return ChatMessage.fromJson({
        ...response,
        'sender_name':
            response['sender']['full_name'] ?? response['sender']['email'],
        'sender_avatar': response['sender']['avatar_url'] ?? '',
        'tags': visibleTags.map((tag) => tag.toJson()).toList(),
      });
    } catch (e) {
      _logger.error('Error sending message: $e');
      rethrow;
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
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final channelData = {
        'name': name,
        'description': description,
        'type': type.name,
        'created_by': user.id,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('chat_channels')
          .insert(channelData)
          .select()
          .single();

      final channelId = response['id'];

      // Add members to channel
      final memberData = members
          .map((memberId) => {
                'channel_id': channelId,
                'user_id': memberId,
                'role': admins.contains(memberId) ? 'admin' : 'member',
                'joined_at': DateTime.now().toIso8601String(),
              })
          .toList();

      await _supabase.from('channel_members').insert(memberData);

      return ChatChannel.fromJson({
        ...response,
        'members': members,
        'admins': admins,
      });
    } catch (e) {
      _logger.error('Error creating channel: $e');
      rethrow;
    }
  }

  // Join a channel
  Future<void> joinChannel(String channelId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _supabase.from('channel_members').insert({
        'channel_id': channelId,
        'user_id': user.id,
        'role': 'member',
        'joined_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _logger.error('Error joining channel: $e');
      rethrow;
    }
  }

  // Leave a channel
  Future<void> leaveChannel(String channelId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _supabase
          .from('channel_members')
          .delete()
          .eq('channel_id', channelId)
          .eq('user_id', user.id);
    } catch (e) {
      _logger.error('Error leaving channel: $e');
      rethrow;
    }
  }

  // Enhanced taggable entities method with role-based filtering
  Future<List<TaggedEntity>> getTaggableEntities(String query, [TagType? tagType]) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userRoles = await _getUserRoles(user.id);
      final entities = <TaggedEntity>[];

      // Get users (for @ tags)
      if (tagType == null || tagType == TagType.user) {
        final usersResponse = await _supabase
            .from('profiles')
            .select('id, full_name, email, avatar_url')
            .or('full_name.ilike.%$query%,email.ilike.%$query%')
            .limit(10);

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
        final rolesResponse = await _supabase
            .from('user_roles')
            .select('DISTINCT role, role_name')
            .ilike('role', '%$query%')
            .limit(10);

        for (final roleJson in rolesResponse) {
          // Check if user can tag this role
          if (await TagVisibilityChecker.canUserSeeTag(
            user.id,
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
        final groupsResponse = await _supabase
            .from('user_groups')
            .select('DISTINCT group_name, group_type')
            .ilike('group_name', '%$query%')
            .limit(10);

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
  Stream<ChatMessage> subscribeToChannelMessages(String channelId) {
    return _supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('channel_id', channelId)
        .order('timestamp')
        .map((data) => ChatMessage.fromJson(data.first));
  }

  // Subscribe to user channels
  Stream<List<ChatChannel>> subscribeToUserChannels(String userId) {
    return _supabase
        .from('chat_channels')
        .stream(primaryKey: ['id'])
        .order('last_message_at', ascending: false)
        .map((data) => data.map((json) => ChatChannel.fromJson(json)).toList());
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
      'all': ['coordinator', 'director', 'leadership', 'executive', 'trustees', 'bod'],
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
  Future<void> _storeMessageTags(String messageId, List<MessageTag> tags) async {
    try {
      final tagData = tags.map((tag) => {
        'message_id': messageId,
        'tag_type': tag.type.name,
        'tag_value': tag.value,
        'display_name': tag.displayName,
        'user_id': tag.userId,
        'role_id': tag.roleId,
        'created_at': DateTime.now().toIso8601String(),
      }).toList();

      await _supabase.from('message_tags').insert(tagData);
    } catch (e) {
      _logger.error('Error storing message tags: $e');
    }
  }

  // Get message tags from database
  Future<List<MessageTag>> _getMessageTags(String messageId) async {
    try {
      final response = await _supabase
          .from('message_tags')
          .select('*')
          .eq('message_id', messageId);

      return (response as List).map((json) => MessageTag.fromJson(json)).toList();
    } catch (e) {
      _logger.error('Error fetching message tags: $e');
      return [];
    }
  }

  // Get user roles
  Future<List<String>> _getUserRoles(String userId) async {
    try {
      final response = await _supabase
          .from('user_roles')
          .select('role')
          .eq('user_id', userId)
          .eq('is_active', true);

      return (response as List).map((json) => json['role'] as String).toList();
    } catch (e) {
      _logger.error('Error fetching user roles: $e');
      return [];
    }
  }

  Future<void> _updateChannelLastMessage(
      String channelId, String content) async {
    try {
      await _supabase.from('chat_channels').update({
        'last_message':
            content.length > 100 ? '${content.substring(0, 100)}...' : content,
        'last_message_at': DateTime.now().toIso8601String(),
      }).eq('id', channelId);
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

  Future<void> _sendUserNotification(String userId, String messageId, String content) async {
    // Implementation for user notifications
    _logger.info('Sending user notification to $userId for message $messageId');
  }

  Future<void> _sendRoleNotification(String role, String messageId, String content) async {
    // Implementation for role-based notifications
    _logger.info('Sending role notification to $role for message $messageId');
  }

  Future<void> _sendGroupNotification(String group, String messageId, String content) async {
    // Implementation for group notifications
    _logger.info('Sending group notification to $group for message $messageId');
  }

  Future<void> _sendSpecialTagNotification(String specialTag, String messageId, String content) async {
    // Implementation for special tag notifications
    _logger.info('Sending special tag notification for $specialTag for message $messageId');
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String channelId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('message_reads').upsert({
        'user_id': user.id,
        'channel_id': channelId,
        'last_read_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _logger.error('Error marking messages as read: $e');
    }
  }

  // Get unread message count
  Future<int> getUnreadCount(String channelId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0;

      final lastReadResponse = await _supabase
          .from('message_reads')
          .select('last_read_at')
          .eq('user_id', user.id)
          .eq('channel_id', channelId)
          .maybeSingle();

      final lastReadAt = lastReadResponse?['last_read_at'];

      var query = _supabase
          .from('chat_messages')
          .select('id')
          .eq('channel_id', channelId)
          .neq('sender_id', user.id);

      if (lastReadAt != null) {
        query = query.gt('timestamp', lastReadAt);
      }

      final response = await query;
      return (response as List).length;
    } catch (e) {
      _logger.error('Error getting unread count: $e');
      return 0;
    }
  }
}




