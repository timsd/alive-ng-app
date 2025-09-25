import 'dart:async';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../config/chat_config.dart';
import '../utils/logger.dart' as app_logger;

/// GetStream Chat Service - Integrates with existing Supabase chat system
/// This service provides real-time messaging capabilities using GetStream
/// while maintaining compatibility with the existing chat system
class GetStreamChatService {
  static final GetStreamChatService _instance =
      GetStreamChatService._internal();
  factory GetStreamChatService() => _instance;
  GetStreamChatService._internal();

  StreamChatClient? _client;
  StreamSubscription<supabase.AuthState>? _authSubscription;
  bool _isInitialized = false;
  final app_logger.Logger _logger = app_logger.Logger('GetStreamChatService');

  /// Get the Stream Chat client instance
  StreamChatClient? get client => _client;

  /// Check if GetStream chat service is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the GetStream chat service
  Future<void> initialize() async {
    try {
      if (_isInitialized) return;

      _client = ChatConfig.createClient();

      // Listen to Supabase auth changes
      _authSubscription =
          supabase.Supabase.instance.client.auth.onAuthStateChange.listen(
        (data) async {
          final session = data.session;
          if (session?.user != null) {
            await _connectUser(session!.user);
          } else {
            await _disconnectUser();
          }
        },
      );

      // Connect current user if already authenticated
      final currentUser = supabase.Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        await _connectUser(currentUser);
      }

      _isInitialized = true;
      _logger.info('GetStream chat service initialized successfully');
    } catch (e) {
      _logger.error('Error initializing GetStream chat service: $e');
      rethrow;
    }
  }

  /// Connect user to Stream Chat
  Future<void> _connectUser(supabase.User supabaseUser) async {
    try {
      if (_client == null) return;

      // Get user profile from Supabase
      final userProfile = await _getUserProfile(supabaseUser.id);

      // Create Stream Chat user
      final streamUser = User(
        id: supabaseUser.id,
        name: userProfile['full_name'] ??
            supabaseUser.email?.split('@').first ??
            'User',
        image: userProfile['avatar_url'],
        extraData: {
          'email': supabaseUser.email,
          'phone': userProfile['phone'],
          'roles': userProfile['roles'] ?? ['member'],
          'chapters': userProfile['chapters'] ?? [],
          'region': userProfile['region'],
          'is_active': userProfile['is_active'] ?? true,
          'last_seen': DateTime.now().toIso8601String(),
          'app_version': '1.0.0',
        },
      );

      // Generate user token (in production, this should be done server-side)
      final token = _generateUserToken(supabaseUser.id);

      // Connect to Stream Chat
      await _client!.connectUser(streamUser, token);

      // Update user's online status
      await _updateUserStatus(true);

      _logger.info('User connected to GetStream chat: ${streamUser.name}');
    } catch (e) {
      _logger.error('Error connecting user to GetStream chat: $e');
      rethrow;
    }
  }

  /// Disconnect user from Stream Chat
  Future<void> _disconnectUser() async {
    try {
      if (_client?.wsConnectionStatus == ConnectionStatus.connected) {
        await _updateUserStatus(false);
        await _client!.disconnectUser();
        _logger.info('User disconnected from GetStream chat');
      }
    } catch (e) {
      _logger.error('Error disconnecting user from GetStream chat: $e');
    }
  }

  /// Get user profile from Supabase
  Future<Map<String, dynamic>> _getUserProfile(String userId) async {
    try {
      final response = await supabase.Supabase.instance.client
          .from('user_profile_view')
          .select()
          .eq('id', userId)
          .maybeSingle();

      return response ?? {};
    } catch (e) {
      _logger.error('Error fetching user profile: $e');
      return {};
    }
  }

  /// Generate user token for Stream Chat (should be done server-side in production)
  String _generateUserToken(String userId) {
    // WARNING: This is for development only!
    // In production, tokens should be generated server-side using the API secret
    return _client!.devToken(userId).rawValue;
  }

  /// Update user's online status
  Future<void> _updateUserStatus(bool isOnline) async {
    try {
      if (_client?.state.currentUser != null) {
        await _client!.updateUser(_client!.state.currentUser!.copyWith(
          extraData: {
            ..._client!.state.currentUser!.extraData,
            'is_online': isOnline,
            'last_seen': DateTime.now().toIso8601String(),
          },
        ));
      }
    } catch (e) {
      _logger.error('Error updating user status: $e');
    }
  }

  /// Create a new GetStream channel (synced with Supabase)
  Future<Channel?> createChannel({
    required String type,
    required String name,
    String? description,
    List<String>? memberIds,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      if (_client == null) {
        throw Exception('GetStream chat client not initialized');
      }

      final channelId = '${type}_${DateTime.now().millisecondsSinceEpoch}';

      final channel = _client!.channel(
        type,
        id: channelId,
        extraData: {
          'name': name,
          'description': description ?? '',
          'created_by': _client!.state.currentUser!.id,
          'created_at': DateTime.now().toIso8601String(),
          'sync_with_supabase': true,
          ...?extraData,
        },
      );

      await channel.create();

      // Add members if specified
      if (memberIds != null && memberIds.isNotEmpty) {
        await channel.addMembers(memberIds);
      }

      // Sync with Supabase chat system
      await _syncChannelWithSupabase(channel, memberIds ?? []);

      _logger.info('GetStream channel created: $name');
      return channel;
    } catch (e) {
      _logger.error('Error creating GetStream channel: $e');
      return null;
    }
  }

  /// Sync GetStream channel with Supabase
  Future<void> _syncChannelWithSupabase(
      Channel channel, List<String> memberIds) async {
    try {
      // This would create corresponding entries in Supabase tables
      // Implementation depends on your specific sync requirements
      _logger.info('Syncing channel ${channel.id} with Supabase');
    } catch (e) {
      _logger.error('Error syncing channel with Supabase: $e');
    }
  }

  /// Send a message with enhanced tagging support
  Future<Message?> sendMessage({
    required Channel channel,
    required String text,
    List<String>? mentionedUsers,
    Message? quotedMessage,
    List<Attachment>? attachments,
  }) async {
    try {
      // Process tags in the message
      final processedData = _processMessageTags(text);
      final mentions = await _resolveMentions(processedData['mentions']);

      final message = Message(
        text: processedData['text'],
        mentionedUsers: [...mentionedUsers?.map((id) => User(id: id)).toList() ?? [], ...mentions],
        quotedMessage: quotedMessage,
        attachments: attachments ?? [],
        extraData: {
          'original_text': text,
          'has_tags': processedData['has_tags'],
          'tag_types': processedData['tag_types'],
          'sent_at': DateTime.now().toIso8601String(),
          'sender_role':
              (_client!.state.currentUser?.extraData['roles'] as List?)?.first ?? 'member',
        },
      );

      final response = await channel.sendMessage(message);
      final sentMessage = response.message;

      // Sync with Supabase if needed
      await _syncMessageWithSupabase(sentMessage, channel.id!);

      return sentMessage;
    } catch (e) {
      _logger.error('Error sending GetStream message: $e');
      return null;
    }
  }

  /// Process message tags (Discord-like tagging system)
  Map<String, dynamic> _processMessageTags(String text) {
    final mentions = <String>[];
    final tagTypes = <String>[];
    String processedText = text;
    bool hasTags = false;

    // Process role tags (#role)
    final roleTagRegex = RegExp(r'#(\w+)');
    final roleMatches = roleTagRegex.allMatches(text);
    for (final match in roleMatches) {
      final role = match.group(1)!;
      if (ChatConfig.getTaggableRoles().contains(role)) {
        mentions.add('@role:$role');
        tagTypes.add('role');
        hasTags = true;
      }
    }

    // Process user mentions (@username)
    final userMentionRegex = RegExp(r'@(\w+)');
    final userMatches = userMentionRegex.allMatches(text);
    for (final match in userMatches) {
      final username = match.group(1)!;
      mentions.add('@user:$username');
      tagTypes.add('user');
      hasTags = true;
    }

    // Process special tags
    for (final specialTag in ChatConfig.getSpecialTags()) {
      if (text.contains(specialTag)) {
        mentions.add(specialTag);
        tagTypes.add('special');
        hasTags = true;
      }
    }

    return {
      'text': processedText,
      'mentions': mentions,
      'tag_types': tagTypes,
      'has_tags': hasTags,
    };
  }

  /// Resolve mentions to actual users
  Future<List<User>> _resolveMentions(List<String> mentions) async {
    final resolvedUsers = <User>[];

    for (final mention in mentions) {
      if (mention.startsWith('@user:')) {
        final username = mention.substring(6);
        final user = await _findUserByUsername(username);
        if (user != null) resolvedUsers.add(user);
      } else if (mention.startsWith('@role:')) {
        final role = mention.substring(6);
        final users = await _findUsersByRole(role);
        resolvedUsers.addAll(users);
      }
    }

    return resolvedUsers;
  }

  /// Find user by username
  Future<User?> _findUserByUsername(String username) async {
    try {
      final users = await _client!.queryUsers(
        filter: Filter.equal('name', username),
        pagination: const PaginationParams(limit: 1),
      );
      return users.users.isNotEmpty ? users.users.first : null;
    } catch (e) {
      _logger.error('Error finding user by username: $e');
      return null;
    }
  }

  /// Find users by role
  Future<List<User>> _findUsersByRole(String role) async {
    try {
      final users = await _client!.queryUsers(
        filter: Filter.in_('roles', [role]),
        pagination: const PaginationParams(limit: 50),
      );
      return users.users;
    } catch (e) {
      _logger.error('Error finding users by role: $e');
      return [];
    }
  }

  /// Sync message with Supabase
  Future<void> _syncMessageWithSupabase(
      Message message, String channelId) async {
    try {
      // This would sync the message with Supabase tables if needed
      _logger.debug('Syncing message ${message.id} with Supabase');
    } catch (e) {
      _logger.error('Error syncing message with Supabase: $e');
    }
  }

  /// Get channels for current user
  Future<List<Channel>> getUserChannels() async {
    try {
      if (_client == null) {
        throw Exception('GetStream chat client not initialized');
      }

      final filter = Filter.in_(
        'members',
        [_client!.state.currentUser!.id],
      );

      final channels = await _client!
          .queryChannels(
            filter: filter,
          )
          .first;

      return channels;
    } catch (e) {
      _logger.error('Error fetching GetStream user channels: $e');
      return [];
    }
  }

  /// Search for users in GetStream
  Future<List<User>> searchUsers(String query) async {
    try {
      if (_client == null) {
        throw Exception('GetStream chat client not initialized');
      }

      final users = await _client!.queryUsers(
        filter: Filter.or([
          Filter.autoComplete('name', query),
          Filter.autoComplete('id', query),
        ]),
        sort: [SortOption.asc('name')],
        pagination: const PaginationParams(limit: 20),
      );

      return users.users;
    } catch (e) {
      _logger.error('Error searching GetStream users: $e');
      return [];
    }
  }

  /// Check if user can access channel based on roles
  bool canUserAccessChannel(String channelType, List<String> userRoles) {
    final permissions = ChatConfig.getChannelPermissions(userRoles.first);
    return permissions['can_create']?.contains(channelType) ?? false;
  }

  /// Get user's channel permissions
  Map<String, List<String>> getUserChannelPermissions() {
    final userRoles =
        _client?.state.currentUser?.extraData['roles'] as List<String>? ?? ['member'];
    return ChatConfig.getChannelPermissions(userRoles.first);
  }

  /// Dispose the GetStream chat service
  Future<void> dispose() async {
    try {
      await _authSubscription?.cancel();
      await _disconnectUser();
      _client = null;
      _isInitialized = false;
      _logger.info('GetStream chat service disposed');
    } catch (e) {
      _logger.error('Error disposing GetStream chat service: $e');
    }
  }
}
