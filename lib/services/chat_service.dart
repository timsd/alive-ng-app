import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_models.dart';
import '../utils/logger.dart';

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

  // Get messages for a channel
  Future<List<ChatMessage>> getChannelMessages(
    String channelId, {
    int limit = 50,
    String? before,
  }) async {
    try {
      var query = _supabase
          .from('chat_messages')
          .select('*, sender:profiles(*)')
          .eq('channel_id', channelId)
          .order('timestamp', ascending: false)
          .limit(limit);

      if (before != null) {
        query = query.lt('timestamp', before);
      }

      final response = await query;

      return (response as List)
          .map((json) => ChatMessage.fromJson({
                ...json,
                'sender_name':
                    json['sender']['full_name'] ?? json['sender']['email'],
                'sender_avatar': json['sender']['avatar_url'] ?? '',
              }))
          .toList()
          .reversed
          .toList();
    } catch (e) {
      _logger.error('Error fetching channel messages: $e');
      rethrow;
    }
  }

  // Send a message
  Future<ChatMessage> sendMessage({
    required String channelId,
    required String content,
    MessageType type = MessageType.text,
    List<String> taggedUsers = const [],
    List<String> taggedGroups = const [],
    String? replyToId,
    List<String> attachments = const [],
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Parse tags from content
      final parsedTags = _parseTagsFromContent(content);
      final allTaggedUsers = [...taggedUsers, ...parsedTags['users']];
      final allTaggedGroups = [...taggedGroups, ...parsedTags['groups']];

      final messageData = {
        'channel_id': channelId,
        'sender_id': user.id,
        'content': content,
        'type': type.name,
        'tagged_users': allTaggedUsers,
        'tagged_groups': allTaggedGroups,
        'reply_to_id': replyToId,
        'attachments': attachments,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('chat_messages')
          .insert(messageData)
          .select('*, sender:profiles(*)')
          .single();

      // Update channel last message
      await _updateChannelLastMessage(channelId, content);

      // Send notifications to tagged users
      if (allTaggedUsers.isNotEmpty || allTaggedGroups.isNotEmpty) {
        await _sendTagNotifications(
          channelId: channelId,
          messageId: response['id'],
          taggedUsers: allTaggedUsers,
          taggedGroups: allTaggedGroups,
          content: content,
        );
      }

      return ChatMessage.fromJson({
        ...response,
        'sender_name':
            response['sender']['full_name'] ?? response['sender']['email'],
        'sender_avatar': response['sender']['avatar_url'] ?? '',
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

  // Get users that can be tagged
  Future<List<TaggedEntity>> getTaggableEntities(String query) async {
    try {
      final entities = <TaggedEntity>[];

      // Get users
      final usersResponse = await _supabase
          .from('profiles')
          .select('id, full_name, email, avatar_url, role')
          .or('full_name.ilike.%$query%,email.ilike.%$query%')
          .limit(10);

      for (final user in usersResponse) {
        entities.add(TaggedEntity(
          id: user['id'],
          name: user['full_name'] ?? user['email'],
          type: TagType.user,
          avatar: user['avatar_url'],
        ));
      }

      // Get groups/roles
      final groupsResponse = await _supabase
          .from('user_groups')
          .select('id, name, type')
          .ilike('name', '%$query%')
          .limit(10);

      for (final group in groupsResponse) {
        entities.add(TaggedEntity(
          id: group['id'],
          name: group['name'],
          type: group['type'] == 'role' ? TagType.role : TagType.group,
        ));
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

  // Private helper methods
  Map<String, List<String>> _parseTagsFromContent(String content) {
    final users = <String>[];
    final groups = <String>[];

    // Parse @username tags
    final userRegex = RegExp(r'@(\w+)');
    final userMatches = userRegex.allMatches(content);
    for (final match in userMatches) {
      users.add(match.group(1)!);
    }

    // Parse #group tags
    final groupRegex = RegExp(r'#(\w+)');
    final groupMatches = groupRegex.allMatches(content);
    for (final match in groupMatches) {
      groups.add(match.group(1)!);
    }

    return {'users': users, 'groups': groups};
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

  Future<void> _sendTagNotifications({
    required String channelId,
    required String messageId,
    required List<String> taggedUsers,
    required List<String> taggedGroups,
    required String content,
  }) async {
    try {
      // Implementation for sending notifications to tagged users/groups
      // This would integrate with your notification service
      _logger.info('Sending tag notifications for message $messageId');
    } catch (e) {
      _logger.error('Error sending tag notifications: $e');
    }
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
          .select('id', const FetchOptions(count: CountOption.exact))
          .eq('channel_id', channelId)
          .neq('sender_id', user.id);

      if (lastReadAt != null) {
        query = query.gt('timestamp', lastReadAt);
      }

      final response = await query;
      return response.count ?? 0;
    } catch (e) {
      _logger.error('Error getting unread count: $e');
      return 0;
    }
  }
}
