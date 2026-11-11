import 'dart:async';
import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../models/chat_models.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';
import 'auth_service.dart';
import 'role_access_service.dart';

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
    // Admin, Super Admin, Board of Directors (BOD), Directors, and Trustees
    // have automatic organization-wide visibility across all channels,
    // except channels explicitly configured as private/secluded from leadership.
    final hasLeadershipPrivilege = RoleAccessService.instance.hasAllChannelsLeadershipAccess();

    if (hasLeadershipPrivilege) {
      try {
        final allActive = await getActiveChannels();
        return allActive.where((c) {
          if (c.excludeLeadership || c.isSecluded) {
            return c.members.contains(userId) || c.admins.contains(userId);
          }
          return true;
        }).toList();
      } catch (e) {
        _logger.warning('Leader channel access fetch note: $e');
      }
    }

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
      _logger.warning('Direct query for user channels failed, falling back to full list: $e');
      try {
        final fallback = await _tables.listRows(
          databaseId: databaseId,
          tableId: channelsCollectionId,
          queries: [Query.limit(100)],
        );
        final list = fallback.rows.map(_channelFromRow).where((c) {
          final isMember = c.members.contains(userId) || c.admins.contains(userId);
          return isMember && !c.isArchived;
        }).toList();
        return list;
      } catch (inner) {
        _logger.error('Error fetching Appwrite chat channels: $inner');
        throw DatabaseException('Failed to fetch chat channels',
            originalError: inner);
      }
    }
  }

  /// Fetches all active non-archived chat channels (General, Singles, Married, BOD, custom channels)
  Future<List<ChatChannel>> getActiveChannels() async {
    try {
      final response = await _tables.listRows(
        databaseId: databaseId,
        tableId: channelsCollectionId,
        queries: [
          Query.equal('is_archived', false),
          Query.orderAsc('name'),
          Query.limit(100),
        ],
      );
      return response.rows.map(_channelFromRow).toList();
    } catch (e) {
      _logger.warning('Active channels query failed, falling back to full list: $e');
      try {
        final fallback = await _tables.listRows(
          databaseId: databaseId,
          tableId: channelsCollectionId,
          queries: [Query.limit(100)],
        );
        return fallback.rows
            .map(_channelFromRow)
            .where((c) => !c.isArchived)
            .toList();
      } catch (inner) {
        _logger.error('Error fetching all active channels: $inner');
        return [];
      }
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

    _subscription!.stream.listen(
      (event) {
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
      },
      onError: (err) {
        _logger.warning('Appwrite realtime room error: $err');
      },
      cancelOnError: false,
    );
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

      String senderAvatar = '';
      final authUser = AuthService.instance.currentUser;
      if (authUser?.photoUrl != null && authUser!.photoUrl!.trim().isNotEmpty) {
        senderAvatar = authUser.photoUrl!.trim();
      }
      if (senderAvatar.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final cached = prefs.getString('cached_avatar_url_${user.$id}');
          if (cached != null && cached.trim().isNotEmpty) {
            senderAvatar = cached.trim();
          }
        } catch (_) {}
      }

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
          'sender_avatar': senderAvatar,
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

  Future<void> deleteMessage(String messageId) async {
    try {
      await _tables.deleteRow(
        databaseId: databaseId,
        tableId: messagesCollectionId,
        rowId: messageId,
      );
    } catch (e) {
      _logger.error('Failed to delete Appwrite chat message: $e');
      throw DatabaseException('Failed to delete message', originalError: e);
    }
  }

  Future<ChatMessage> editMessage(String messageId, String newContent) async {
    try {
      final row = await _tables.updateRow(
        databaseId: databaseId,
        tableId: messagesCollectionId,
        rowId: messageId,
        data: {
          'content': newContent,
          'messageText': newContent,
          'is_edited': true,
        },
      );
      return _messageFromRow(row);
    } catch (e) {
      _logger.error('Failed to edit Appwrite chat message: $e');
      throw DatabaseException('Failed to edit message', originalError: e);
    }
  }

  Future<ChatChannel> createChannel({
    required String name,
    required String description,
    required ChannelType type,
    required List<String> members,
    List<String> admins = const [],
    bool excludeLeadership = false,
  }) async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) throw AuthException('User not authenticated');

      final now = DateTime.now().toIso8601String();
      final allMembers = <String>{user.uid, ...members};
      final allAdmins = <String>{user.uid, ...admins};

      // Auto-include organization leadership (Admin, Super Admin, BOD, Directors, Trustees)
      // unless this channel is explicitly secluded
      if (!excludeLeadership && type != ChannelType.direct) {
        try {
          final leadershipRows = await _tables.listRows(
            databaseId: databaseId,
            tableId: AppwriteBackendConfig.usersCollectionId,
            queries: [
              Query.equal('is_archived', false),
              Query.limit(100),
            ],
          );
          const leaderKeywords = {'admin', 'super_admin', 'bod', 'director', 'trustee', 'president'};
          for (final doc in leadershipRows.rows) {
            final role = (doc.data['role'] ?? '').toString().toLowerCase();
            final email = (doc.data['email'] ?? '').toString().toLowerCase();
            final isLeader = leaderKeywords.contains(role) ||
                role.contains('bod') ||
                role.contains('director') ||
                AppwriteBackendConfig.isSuperAdminEmail(email);
            if (isLeader) {
              allMembers.add(doc.$id);
              allAdmins.add(doc.$id);
            }
          }
        } catch (e) {
          _logger.warning('Could not auto-populate leadership members for new channel: $e');
        }
      }

      final channelSettings = <String, dynamic>{
        'exclude_leadership': excludeLeadership,
        'is_secluded': excludeLeadership,
      };

      final row = await _tables.createRow(
        databaseId: databaseId,
        tableId: channelsCollectionId,
        rowId: ID.unique(),
        data: {
          'name': name,
          'description': description,
          'type': type.name,
          'created_by': user.uid,
          'created_at': now,
          'updated_at': now,
          'is_archived': false,
          'members': allMembers.toList(),
          'admins': allAdmins.toList(),
          'last_message_at': now,
          'settings': jsonEncode(channelSettings),
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

      final seenNames = <String>{};
      final users = <TaggedEntity>[];
      for (final row in response.rows) {
        final data = row.data;
        final rawName =
            (data['fullName'] ?? data['full_name'] ?? data['email'] ?? 'User')
                .toString()
                .trim();
        final displayName = rawName.contains('@')
            ? rawName.split('@').first
            : rawName;
        if (displayName.isEmpty) continue;
        final key = displayName.toLowerCase();
        if (!seenNames.add(key)) continue;
        users.add(
          TaggedEntity(
            id: row.$id,
            name: displayName,
            type: TagType.user,
            avatar: (data['avatar_url'] ?? data['photo_url']) as String?,
          ),
        );
      }

      if (tagType == TagType.user || tagType == null) return users;
      return _getSpecialTags(query);
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

  Future<void> addMemberToChannel(String channelId, String userId) async {
    final channel = await _getChannel(channelId);
    if (channel == null || channel.members.contains(userId)) return;
    final updatedMembers = [...channel.members, userId];
    await _tables.updateRow(
      databaseId: databaseId,
      tableId: channelsCollectionId,
      rowId: channelId,
      data: {
        'members': updatedMembers,
      },
    );
  }

  Future<void> removeMemberFromChannel(String channelId, String userId) async {
    final channel = await _getChannel(channelId);
    if (channel == null) return;
    final updatedMembers = channel.members.where((id) => id != userId).toList();
    await _tables.updateRow(
      databaseId: databaseId,
      tableId: channelsCollectionId,
      rowId: channelId,
      data: {
        'members': updatedMembers,
      },
    );
  }

  Future<List<ChatUser>> getAllCommunityUsers({int limit = 100}) async {
    try {
      final response = await _tables.listRows(
        databaseId: databaseId,
        tableId: AppwriteBackendConfig.usersCollectionId,
        queries: [
          Query.limit(limit),
        ],
      );
      return response.rows.map((row) {
        final data = row.data;
        return ChatUser(
          id: row.$id,
          name: (data['fullName'] ??
                  data['full_name'] ??
                  data['name'] ??
                  data['email'] ??
                  'Member')
              .toString(),
          email: (data['email'] ?? '').toString(),
          avatar: data['avatar_url'] as String?,
          role: UserRole.values.firstWhere(
            (role) => role.name == (data['role'] ?? 'member').toString(),
            orElse: () => UserRole.member,
          ),
          isOnline: data['is_online'] as bool? ?? false,
        );
      }).toList();
    } catch (e) {
      _logger.error('Error getting community users: $e');
      return [];
    }
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
