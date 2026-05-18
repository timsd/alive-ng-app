import '../models/chat_models.dart';
import 'appwrite_chat_service.dart';

/// Compatibility facade for older UI code.
///
/// The app used to call [ChatService] directly from screens and widgets. The
/// implementation now delegates to Appwrite so we can migrate UI files one at a
/// time without breaking their public method calls.
class ChatService {
  static final ChatService _instance = ChatService._internal();

  factory ChatService() => _instance;

  ChatService._internal();

  final AppwriteChatService _appwrite = AppwriteChatService();

  Future<List<ChatChannel>> getUserChannels(String userId) {
    return _appwrite.getUserChannels(userId);
  }

  Future<List<ChatMessage>> getChannelMessages(
    String channelId, {
    int limit = 50,
    String? before,
  }) {
    return _appwrite.getChannelMessages(
      channelId,
      limit: limit,
      before: before,
    );
  }

  Future<ChatMessage> sendMessage({
    required String channelId,
    required String content,
    MessageType type = MessageType.text,
    List<MessageTag> tags = const [],
    String? replyToId,
    List<String> attachments = const [],
  }) {
    return _appwrite.sendMessage(
      channelId: channelId,
      content: content,
      type: type,
      tags: tags,
      replyToId: replyToId,
      attachments: attachments,
    );
  }

  Future<ChatChannel> createChannel({
    required String name,
    required String description,
    required ChannelType type,
    required List<String> members,
    List<String> admins = const [],
  }) {
    return _appwrite.createChannel(
      name: name,
      description: description,
      type: type,
      members: members,
      admins: admins,
    );
  }

  Future<void> joinChannel(String channelId) {
    return _appwrite.joinChannel(channelId);
  }

  Future<void> leaveChannel(String channelId) {
    return _appwrite.leaveChannel(channelId);
  }

  Future<List<TaggedEntity>> getTaggableEntities(String query,
      [TagType? tagType]) {
    return _appwrite.getTaggableEntities(query, tagType);
  }

  Stream<List<ChatMessage>> subscribeToChannelMessages(String channelId) {
    return _appwrite.subscribeToChannelMessages(channelId);
  }

  Stream<List<ChatChannel>> subscribeToUserChannels(String userId) {
    return _appwrite.subscribeToUserChannels(userId);
  }

  Future<List<MessageTag>> getMessageTags(String messageId) {
    return _appwrite.getMessageTags(messageId);
  }

  Future<void> markMessagesAsRead(String channelId) {
    return _appwrite.markMessagesAsRead(channelId);
  }

  Future<int> getUnreadCount(String channelId) {
    return _appwrite.getUnreadCount(channelId);
  }

  Future<ChatUser?> getChatUser(String userId) {
    return _appwrite.getChatUser(userId);
  }

  Future<void> updateChatUserStatus({
    required String userId,
    required bool isOnline,
  }) {
    return _appwrite.updateChatUserStatus(
      userId: userId,
      isOnline: isOnline,
    );
  }

  Future<List<ChatUser>> getOnlineChatUsers(String channelId) {
    return _appwrite.getOnlineChatUsers(channelId);
  }
}
