import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../models/chat_models.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';
import 'auth_service.dart';

class AppwriteChatService extends ChangeNotifier {
  AppwriteChatService() {
    _tables = TablesDB(appwriteClient);
    _realtime = Realtime(appwriteClient);
  }

  late final TablesDB _tables;
  late final Realtime _realtime;
  RealtimeSubscription? _subscription;
  final Logger _logger = Logger('AppwriteChatService');
  final List<models.Document> _messageDocuments = [];

  List<models.Document> get messages => List.unmodifiable(_messageDocuments);

  static const String databaseId = AppwriteBackendConfig.databaseId;
  static const String channelsCollectionId =
      AppwriteBackendConfig.chatChannelsCollectionId;
  static const String messagesCollectionId =
      AppwriteBackendConfig.chatMessagesCollectionId;
  static const String messageTagsCollectionId =
      AppwriteBackendConfig.messageTagsCollectionId;

  Future<List<ChatChannel>> getUserChannels(String userId) async {
    try {
      final response = await _tables.listRows(
        databaseId: databaseId,
        tableId: channelsCollectionId,
        queries: [
          Query.contains('members', [userId]),
          Query.equal('is_archived', false),
          Query.orderDesc('last_message_at'),
          Query.limit(100),
        ],
      );

      return response.rows.map(_channelFromRow).toList();
    } catch (e) {
      _logger.error('Error fetching Appwrite chat channels: $e');
      throw DatabaseException('Failed to fetch chat channels',
          originalError: e);
    }
  }

  Future<List<ChatMessage>> getChannelMessages(
    String channelId, {
    int limit = 50,
    String? before,
  }) async {
    try {
      final queries = [
        Query.equal('channel_id', channelId),
        Query.orderAsc('timestamp'),
        Query.limit(limit),
      ];
      if (before != null) {
        queries.add(Query.cursorBefore(before));
      }

      final response = await _tables.listRows(
        databaseId: databaseId,
        tableId: messagesCollectionId,
        queries: queries,
      );

      _messageDocuments
        ..clear()
        ..addAll(response.rows.map(_rowToDocument));
      notifyListeners();

      return response.rows.map(_messageFromRow).toList();
    } catch (e) {
      _logger.error('Error loading Appwrite chat history: $e');
      throw DatabaseException('Failed to fetch channel messages',
          originalError: e);
    }
  }

  Future<void> loadMessageHistory(String roomId) async {
    await getChannelMessages(roomId);
  }

  void subscribeToRoom(String roomId) {
    _subscription?.close();
    _logger.info('Opening Appwrite realtime channel for room: $roomId');

    _subscription = _realtime.subscribe([
      'databases.$databaseId.tables.$messagesCollectionId.rows',
    ]);

    _subscription!.stream.listen((event) {
      final isCreateEvent = event.events.any((name) =>
          name.endsWith('.create') ||
          name == 'databases.*.tables.*.rows.*.create');
      if (!isCreateEvent) return;

      final document = _rowToDocument(models.Row.fromMap(event.payload));
      final data = document.data;
      final messageRoomId = data['channel_id'] ?? data['roomId'];

      if (messageRoomId == roomId) {
        _messageDocuments.add(document);
        notifyListeners();
      }
    });
  }

  Stream<List<ChatMessage>> subscribeToChannelMessages(String channelId) {
    final controller = StreamController<List<ChatMessage>>();
    final messages = <ChatMessage>[];

    getChannelMessages(channelId).then((history) {
      messages
        ..clear()
        ..addAll(history);
      controller.add(List.unmodifiable(messages));
    }).catchError((error) {
      controller.addError(error);
    });

    final subscription = _realtime.subscribe([
      'databases.$databaseId.tables.$messagesCollectionId.rows',
    ]);

    subscription.stream.listen(
      (event) {
        final isCreateEvent =
            event.events.any((name) => name.endsWith('.create'));
        if (!isCreateEvent) return;

        final row = models.Row.fromMap(event.payload);
        final data = row.data;
        final messageRoomId = data['channel_id'] ?? data['roomId'];
        if (messageRoomId != channelId) return;

        messages.add(_messageFromRow(row));
        controller.add(List.unmodifiable(messages));
      },
      onError: controller.addError,
    );

    controller.onCancel = () async {
      await subscription.close();
    };

    return controller.stream;
  }

  Future<ChatMessage> sendMessage({
    required String channelId,
    required String content,
    MessageType type = MessageType.text,
    List<MessageTag> tags = const [],
    String? replyToId,
    List<String> attachments = const [],
  }) async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) throw AuthException('User not authenticated');

      final taggedUsers = tags
          .where((tag) => tag.type == TagType.user)
          .map((tag) => tag.userId ?? tag.value)
          .toList();
      final taggedGroups = tags
          .where((tag) => tag.type != TagType.user)
          .map((tag) => tag.value)
          .toList();
      final now = DateTime.now();

      final row = await _tables.createRow(
        databaseId: databaseId,
        tableId: messagesCollectionId,
        rowId: ID.unique(),
        data: {
          'channel_id': channelId,
          'roomId': channelId,
          'sender_id': user.$id,
          'senderId': user.$id,
          'sender_name':
              user.name.isNotEmpty ? user.name : user.email.split('@').first,
          'sender_avatar': '',
          'content': content,
          'messageText': content,
          'timestamp': now.millisecondsSinceEpoch,
          'type': type.name,
          'tagged_users': taggedUsers,
          'tagged_groups': taggedGroups,
          'reply_to_id': replyToId,
          'attachments': attachments,
          'is_edited': false,
        },
      );

      await _storeMessageTags(row.$id, tags);
      await _updateChannelLastMessage(channelId, content, user.$id);

      return _messageFromRow(row);
    } catch (e) {
      _logger.error('Failed to send Appwrite chat message: $e');
      if (e is AuthException) rethrow;
      throw DatabaseException('Failed to send message', originalError: e);
    }
  }

  Future<ChatMessage> sendTextMessage({
    required String roomId,
    required String senderId,
    required String text,
  }) async {
    return sendMessage(channelId: roomId, content: text);
  }

  Future<ChatChannel> createChannel({
    required String name,
    required String description,
    required ChannelType type,
    required List<String> members,
    List<String> admins = const [],
  }) async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) throw AuthException('User not authenticated');

      final now = DateTime.now().toIso8601String();
      final allMembers = <String>{user.$id, ...members}.toList();
      final allAdmins = <String>{user.$id, ...admins}.toList();

      final row = await _tables.createRow(
        databaseId: databaseId,
        tableId: channelsCollectionId,
        rowId: ID.unique(),
        data: {
          'name': name,
          'description': description,
          'type': type.name,
          'created_by': user.$id,
          'created_at': now,
          'updated_at': now,
          'is_archived': false,
          'members': allMembers,
          'admins': allAdmins,
          'last_message': null,
          'last_message_at': now,
          'last_message_sender_id': null,
          'settings': <String, dynamic>{},
        },
      );

      return _channelFromRow(row);
    } catch (e) {
      _logger.error('Error creating Appwrite chat channel: $e');
      if (e is AuthException) rethrow;
      throw DatabaseException('Failed to create channel', originalError: e);
    }
  }

  Future<List<TaggedEntity>> getTaggableEntities(String query,
      [TagType? tagType]) async {
    try {
      if (tagType != null && tagType != TagType.user) {
        return _getSpecialTags(query);
      }

      final response = await _tables.listRows(
        databaseId: databaseId,
        tableId: AppwriteBackendConfig.usersCollectionId,
        queries: [
          if (query.trim().isNotEmpty) Query.search('fullName', query.trim()),
          Query.limit(20),
        ],
      );

      final users = response.rows.map((row) {
        final data = row.data;
        return TaggedEntity(
          id: row.$id,
          name:
              (data['fullName'] ?? data['full_name'] ?? data['email'] ?? 'User')
                  .toString(),
          type: TagType.user,
          avatar: data['avatar_url'] as String?,
        );
      }).toList();

      if (tagType == TagType.user) return users;
      return [...users, ..._getSpecialTags(query)];
    } catch (e) {
      _logger.error('Error fetching Appwrite taggable entities: $e');
      return [];
    }
  }

  Stream<List<ChatChannel>> subscribeToUserChannels(String userId) async* {
    yield await getUserChannels(userId);
  }

  Future<void> joinChannel(String channelId) async {
    final user = AuthService.instance.currentUser;
    if (user == null) throw AuthException('User not authenticated');
    final channel = await _getChannel(channelId);
    if (channel == null || channel.members.contains(user.$id)) return;
    await _tables.updateRow(
      databaseId: databaseId,
      tableId: channelsCollectionId,
      rowId: channelId,
      data: {
        'members': [...channel.members, user.$id]
      },
    );
  }

  Future<void> leaveChannel(String channelId) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    final channel = await _getChannel(channelId);
    if (channel == null) return;
    await _tables.updateRow(
      databaseId: databaseId,
      tableId: channelsCollectionId,
      rowId: channelId,
      data: {
        'members': channel.members.where((id) => id != user.$id).toList(),
      },
    );
  }

  Future<void> markMessagesAsRead(String channelId) async {
    _logger.debug('markMessagesAsRead pending Appwrite read-receipt schema.');
  }

  Future<int> getUnreadCount(String channelId) async => 0;

  Future<List<MessageTag>> getMessageTags(String messageId) async {
    try {
      final response = await _tables.listRows(
        databaseId: databaseId,
        tableId: messageTagsCollectionId,
        queries: [
          Query.equal('message_id', messageId),
          Query.limit(100),
        ],
      );
      return response.rows.map((row) {
        return MessageTag.fromJson({
          'id': row.$id,
          ...row.data,
        });
      }).toList();
    } catch (e) {
      _logger.error('Error fetching Appwrite message tags: $e');
      return [];
    }
  }

  Future<ChatUser?> getChatUser(String userId) async {
    try {
      final row = await _tables.getRow(
        databaseId: databaseId,
        tableId: AppwriteBackendConfig.usersCollectionId,
        rowId: userId,
      );
      final data = row.data;
      return ChatUser(
        id: row.$id,
        name: (data['fullName'] ?? data['full_name'] ?? data['email'] ?? 'User')
            .toString(),
        email: (data['email'] ?? '').toString(),
        avatar: data['avatar_url'] as String?,
        role: UserRole.values.firstWhere(
          (role) => role.name == (data['role'] ?? 'member').toString(),
          orElse: () => UserRole.member,
        ),
        isOnline: data['is_online'] as bool? ?? false,
        lastSeen: data['last_seen'] != null
            ? DateTime.tryParse(data['last_seen'].toString())
            : null,
      );
    } catch (e) {
      _logger.error('Error getting Appwrite chat user: $e');
      return null;
    }
  }

  Future<void> updateChatUserStatus({
    required String userId,
    required bool isOnline,
  }) async {
    try {
      await _tables.updateRow(
        databaseId: databaseId,
        tableId: AppwriteBackendConfig.usersCollectionId,
        rowId: userId,
        data: {
          'is_online': isOnline,
          'last_seen': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      _logger.error('Error updating Appwrite chat user status: $e');
    }
  }

  Future<List<ChatUser>> getOnlineChatUsers(String channelId) async {
    final channel = await _getChannel(channelId);
    if (channel == null) return [];

    final users = <ChatUser>[];
    for (final memberId in channel.members) {
      final user = await getChatUser(memberId);
      if (user != null && user.isOnline) users.add(user);
    }
    return users;
  }

  ChatChannel _channelFromRow(models.Row row) {
    return ChatChannel.fromJson({
      'id': row.$id,
      ...row.data,
    });
  }

  Future<ChatChannel?> _getChannel(String channelId) async {
    try {
      final row = await _tables.getRow(
        databaseId: databaseId,
        tableId: channelsCollectionId,
        rowId: channelId,
      );
      return _channelFromRow(row);
    } catch (e) {
      _logger.error('Error loading Appwrite chat channel: $e');
      return null;
    }
  }

  ChatMessage _messageFromRow(models.Row row) {
    final data = row.data;
    return ChatMessage.fromJson({
      'id': row.$id,
      'sender_id': data['sender_id'] ?? data['senderId'],
      'sender_name': data['sender_name'] ?? data['senderName'] ?? 'User',
      'sender_avatar': data['sender_avatar'] ?? data['senderAvatar'] ?? '',
      'content': data['content'] ?? data['messageText'] ?? '',
      'timestamp': data['timestamp'] ?? row.$createdAt,
      'type': data['type'] ?? MessageType.text.name,
      'tagged_users': data['tagged_users'] ?? const <String>[],
      'tagged_groups': data['tagged_groups'] ?? const <String>[],
      'reply_to_id': data['reply_to_id'],
      'attachments': data['attachments'] ?? const <String>[],
      'is_edited': data['is_edited'] ?? false,
      'edited_at': data['edited_at'],
    });
  }

  models.Document _rowToDocument(models.Row row) {
    return models.Document(
      $id: row.$id,
      $sequence: row.$sequence,
      $collectionId: row.$tableId,
      $databaseId: row.$databaseId,
      $createdAt: row.$createdAt,
      $updatedAt: row.$updatedAt,
      $permissions: row.$permissions,
      data: row.data,
    );
  }

  Future<void> _storeMessageTags(
      String messageId, List<MessageTag> tags) async {
    for (final tag in tags) {
      try {
        await _tables.createRow(
          databaseId: databaseId,
          tableId: messageTagsCollectionId,
          rowId: ID.unique(),
          data: {
            'message_id': messageId,
            ...tag.toJson(),
            'created_at': DateTime.now().toIso8601String(),
          },
        );
      } catch (e) {
        _logger.error('Error storing Appwrite message tag: $e');
      }
    }
  }

  Future<void> _updateChannelLastMessage(
    String channelId,
    String content,
    String senderId,
  ) async {
    try {
      await _tables.updateRow(
        databaseId: databaseId,
        tableId: channelsCollectionId,
        rowId: channelId,
        data: {
          'last_message': content,
          'last_message_at': DateTime.now().toIso8601String(),
          'last_message_sender_id': senderId,
        },
      );
    } catch (e) {
      _logger.error('Error updating Appwrite channel last message: $e');
    }
  }

  List<TaggedEntity> _getSpecialTags(String query) {
    const availableTags = {
      'all': 'All members',
      'online': 'Online members',
      'active': 'Active members',
      'new': 'New members',
      'meeting': 'Meeting participants',
      'conference': 'Conference attendees',
      'training': 'Training participants',
    };

    return availableTags.entries
        .where((entry) =>
            entry.key.toLowerCase().contains(query.toLowerCase()) ||
            entry.value.toLowerCase().contains(query.toLowerCase()))
        .map((entry) => TaggedEntity(
              id: entry.key,
              name: entry.value,
              type: TagType.special,
            ))
        .toList();
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }
}
