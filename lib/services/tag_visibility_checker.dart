import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_models.dart';
import '../utils/logger.dart';

/// Handles tag visibility and access control for messages
class TagVisibilityChecker {
  static final Logger _logger = Logger('TagVisibilityChecker');
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Check if user can see a message based on its tags
  static Future<bool> canUserSeeMessage(
    String userId, 
    List<MessageTag> tags
  ) async {
    try {
      // If no tags, message is public
      if (tags.isEmpty) return true;
      
      // Check each tag - user can see message if they can see at least one tag
      for (MessageTag tag in tags) {
        if (await canUserSeeTag(userId, tag)) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      _logger.error('Error checking message visibility: $e');
      return false; // Fail closed for security
    }
  }
  
  /// Check if user can see a specific tag
  static Future<bool> canUserSeeTag(
    String userId, 
    MessageTag tag
  ) async {
    try {
      switch (tag.type) {
        case TagType.role:
          return await hasRoleAccess(userId, tag.value);
        case TagType.user:
          return await isUserTagged(userId, tag.value);
        case TagType.special:
          return await hasSpecialAccess(userId, tag.value);
        case TagType.group:
          return await hasGroupAccess(userId, tag.value);
        default:
          return false;
      }
    } catch (e) {
      _logger.error('Error checking tag visibility: $e');
      return false; // Fail closed for security
    }
  }

  /// Check if user has access to a role tag
  static Future<bool> hasRoleAccess(String userId, String roleTag) async {
    try {
      // Get user's roles
      final userRoles = await getUserRoles(userId);
      if (userRoles.isEmpty) return false;

      // Check hierarchical access
      if (await hasHierarchicalAccess(userRoles, roleTag)) {
        return true;
      }

      // Check peer access
      if (await hasPeerAccess(userRoles, roleTag)) {
        return true;
      }

      // Check team access
      if (await hasTeamAccess(userRoles, roleTag)) {
        return true;
      }

      return false;
    } catch (e) {
      _logger.error('Error checking role access: $e');
      return false;
    }
  }

  /// Check if user is tagged individually
  static Future<bool> isUserTagged(String userId, String username) async {
    try {
      // Get user's profile to check username match
      final response = await _supabase
          .from('profiles')
          .select('username, email, full_name')
          .eq('id', userId)
          .single();

      final userProfile = response;
      
      // Check various username formats
      return username.toLowerCase() == userProfile['username']?.toLowerCase() ||
             username.toLowerCase() == userProfile['email']?.toLowerCase() ||
             username.toLowerCase() == userProfile['full_name']?.toLowerCase()?.replaceAll(' ', '.') ||
             username.toLowerCase() == userProfile['full_name']?.toLowerCase()?.replaceAll(' ', '_');
    } catch (e) {
      _logger.error('Error checking user tag: $e');
      return false;
    }
  }

  /// Check if user has access to special tags
  static Future<bool> hasSpecialAccess(String userId, String specialTag) async {
    try {
      switch (specialTag) {
        case 'all':
          return true; // All authenticated users
        case 'online':
          return await isUserOnline(userId);
        case 'active':
          return await isUserRecentlyActive(userId);
        case 'new':
          return await isNewUser(userId);
        case 'meeting':
        case 'conference':
        case 'training':
          return await isEventParticipant(userId, specialTag);
        default:
          return false;
      }
    } catch (e) {
      _logger.error('Error checking special access: $e');
      return false;
    }
  }

  /// Check if user has access to group tags
  static Future<bool> hasGroupAccess(String userId, String groupTag) async {
    try {
      // Check if user is member of the group
      final response = await _supabase
          .from('user_groups')
          .select('group_name')
          .eq('user_id', userId)
          .eq('group_name', groupTag)
          .maybeSingle();

      return response != null;
    } catch (e) {
      _logger.error('Error checking group access: $e');
      return false;
    }
  }

  /// Get user's roles from database
  static Future<List<String>> getUserRoles(String userId) async {
    try {
      final response = await _supabase
          .from('user_roles')
          .select('role_name')
          .eq('user_id', userId);

      return (response as List).map((r) => r['role_name'] as String).toList();
    } catch (e) {
      _logger.error('Error getting user roles: $e');
      return [];
    }
  }

  /// Check hierarchical access (higher roles can see lower role tags)
  static Future<bool> hasHierarchicalAccess(List<String> userRoles, String targetRole) async {
    // Role hierarchy (higher to lower)
    final hierarchy = {
      'bod': 10,
      'trustees': 9,
      'executive': 8,
      'leadership': 7,
      'director': 6,
      'field_director': 6,
      'campus_director': 6,
      'program_director': 6,
      'evangelism_director': 6,
      'amtc_director': 6,
      'chap_coor': 5,
      'field_coor': 5,
      'campus_coor': 5,
      'program_coor': 5,
      'evangelism_coor': 5,
      'amtc_coor': 5,
      'admin': 4,
      'treasurer': 3,
      'secretary': 3,
      'media': 2,
      'tech': 2,
      'health': 2,
      'member': 1,
    };

    final targetLevel = hierarchy[targetRole] ?? 0;
    
    for (final role in userRoles) {
      final userLevel = hierarchy[role] ?? 0;
      if (userLevel >= targetLevel) {
        return true;
      }
    }

    return false;
  }

  /// Check peer access (same-level roles can see each other's tags)
  static Future<bool> hasPeerAccess(List<String> userRoles, String targetRole) async {
    // Director level peers
    final directorRoles = [
      'director', 'field_director', 'campus_director', 
      'program_director', 'evangelism_director', 'amtc_director'
    ];
    
    // Coordinator level peers
    final coordinatorRoles = [
      'chap_coor', 'field_coor', 'campus_coor',
      'program_coor', 'evangelism_coor', 'amtc_coor'
    ];

    // Team level peers
    final teamRoles = ['media', 'tech', 'health'];

    // Check if user has any director role and target is director role
    if (userRoles.any((role) => directorRoles.contains(role)) &&
        directorRoles.contains(targetRole)) {
      return true;
    }

    // Check if user has any coordinator role and target is coordinator role
    if (userRoles.any((role) => coordinatorRoles.contains(role)) &&
        coordinatorRoles.contains(targetRole)) {
      return true;
    }

    // Check if user has any team role and target is team role
    if (userRoles.any((role) => teamRoles.contains(role)) &&
        teamRoles.contains(targetRole)) {
      return true;
    }

    return false;
  }

  /// Check team access (team members can see their team tags)
  static Future<bool> hasTeamAccess(List<String> userRoles, String targetRole) async {
    // Direct role match
    if (userRoles.contains(targetRole)) {
      return true;
    }

    // Chapter access
    if (targetRole.startsWith('chapter_')) {
      return await isChapterMember(userRoles.first, targetRole);
    }

    // Regional access
    final regions = ['north', 'south', 'east', 'west', 'central'];
    if (regions.contains(targetRole)) {
      return await isRegionalMember(userRoles.first, targetRole);
    }

    return false;
  }

  /// Check if user is online
  static Future<bool> isUserOnline(String userId) async {
    try {
      final response = await _supabase
          .from('user_presence')
          .select('is_online')
          .eq('user_id', userId)
          .maybeSingle();

      return response?['is_online'] ?? false;
    } catch (e) {
      _logger.error('Error checking online status: $e');
      return false;
    }
  }

  /// Check if user is recently active (within 24 hours)
  static Future<bool> isUserRecentlyActive(String userId) async {
    try {
      final response = await _supabase
          .from('user_presence')
          .select('last_seen')
          .eq('user_id', userId)
          .maybeSingle();

      if (response?['last_seen'] != null) {
        final lastSeen = DateTime.parse(response['last_seen']);
        final now = DateTime.now();
        return now.difference(lastSeen).inHours < 24;
      }

      return false;
    } catch (e) {
      _logger.error('Error checking recent activity: $e');
      return false;
    }
  }

  /// Check if user is new (joined within 30 days)
  static Future<bool> isNewUser(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('created_at')
          .eq('id', userId)
          .single();

      final createdAt = DateTime.parse(response['created_at']);
      final now = DateTime.now();
      return now.difference(createdAt).inDays < 30;
    } catch (e) {
      _logger.error('Error checking new user status: $e');
      return false;
    }
  }

  /// Check if user is event participant
  static Future<bool> isEventParticipant(String userId, String eventType) async {
    try {
      final response = await _supabase
          .from('event_participants')
          .select('event_type')
          .eq('user_id', userId)
          .eq('event_type', eventType)
          .maybeSingle();

      return response != null;
    } catch (e) {
      _logger.error('Error checking event participation: $e');
      return false;
    }
  }

  /// Check if user is chapter member
  static Future<bool> isChapterMember(String userId, String chapterTag) async {
    try {
      final chapterName = chapterTag.substring(8); // Remove 'chapter_' prefix
      
      final response = await _supabase
          .from('user_chapters')
          .select('chapter_name')
          .eq('user_id', userId)
          .eq('chapter_name', chapterName)
          .maybeSingle();

      return response != null;
    } catch (e) {
      _logger.error('Error checking chapter membership: $e');
      return false;
    }
  }

  /// Check if user is regional member
  static Future<bool> isRegionalMember(String userId, String region) async {
    try {
      final response = await _supabase
          .from('user_regions')
          .select('region')
          .eq('user_id', userId)
          .eq('region', region)
          .maybeSingle();

      return response != null;
    } catch (e) {
      _logger.error('Error checking regional membership: $e');
      return false;
    }
  }

  /// Filter messages based on user's tag visibility
  static Future<List<Map<String, dynamic>>> filterVisibleMessages(
    String userId,
    List<Map<String, dynamic>> messages
  ) async {
    final visibleMessages = <Map<String, dynamic>>[];

    for (final message in messages) {
      final taggedUsers = (message['tagged_users'] as List?)?.cast<String>() ?? [];
      final taggedGroups = (message['tagged_groups'] as List?)?.cast<String>() ?? [];
      
      // Convert to MessageTag objects
      final tags = <MessageTag>[
        ...taggedUsers.map((user) => MessageTag(type: TagType.user, value: user)),
        ...taggedGroups.map((group) => MessageTag(type: TagType.role, value: group)),
      ];

      if (await canUserSeeMessage(userId, tags)) {
        visibleMessages.add(message);
      }
    }

    return visibleMessages;
  }
}