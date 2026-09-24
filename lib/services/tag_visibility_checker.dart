import 'package:appwrite/appwrite.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../models/chat_models.dart';
import '../utils/logger.dart';

  /// Handles tag visibility and access control for messages.
class TagVisibilityChecker {
  static final Logger _logger = Logger('TagVisibilityChecker');
  static final TablesDB _tables = TablesDB(appwriteClient);

  /// Check if user can see a message based on its tags.
  static Future<bool> canUserSeeMessage(
    String userId,
    List<MessageTag> tags,
  ) async {
    try {
      // If no tags, message is public.
      if (tags.isEmpty) return true;

      // User can see a message if at least one tag is visible to them.
      for (final tag in tags) {
        if (await canUserSeeTag(userId, tag)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      _logger.error('Error checking message visibility: $e');
      return false;
    }
  }

  /// Check if user can see a specific tag.
  static Future<bool> canUserSeeTag(
    String userId,
    MessageTag tag,
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
      }
    } catch (e) {
      _logger.error('Error checking tag visibility: $e');
      return false;
    }
  }

  /// Check if user has access to a role tag.
  static Future<bool> hasRoleAccess(String userId, String roleTag) async {
    try {
      final userRoles = await getUserRoles(userId);
      if (userRoles.isEmpty) return false;

      if (await hasHierarchicalAccess(userRoles, roleTag)) return true;
      if (await hasPeerAccess(userRoles, roleTag)) return true;
      if (await hasTeamAccess(userRoles, roleTag)) return true;

      return false;
    } catch (e) {
      _logger.error('Error checking role access: $e');
      return false;
    }
  }

  /// Check if user is tagged individually.
  static Future<bool> isUserTagged(String userId, String username) async {
    try {
      final userProfile = await _getUserProfile(userId);
      final profileUsername =
          (userProfile['username'] as String?)?.toLowerCase();
      final profileEmail = (userProfile['email'] as String?)?.toLowerCase();
      final fullName = (userProfile['full_name'] as String?)?.toLowerCase();
      final alternateFullName =
          (userProfile['fullName'] as String?)?.toLowerCase();
      final name = fullName ?? alternateFullName;
      final normalizedDot = name?.replaceAll(' ', '.');
      final normalizedUnderscore = name?.replaceAll(' ', '_');
      final target = username.toLowerCase();

      return target == profileUsername ||
          target == profileEmail ||
          (normalizedDot != null && target == normalizedDot) ||
          (normalizedUnderscore != null && target == normalizedUnderscore);
    } catch (e) {
      _logger.error('Error checking user tag: $e');
      return false;
    }
  }

  /// Check if user has access to special tags.
  static Future<bool> hasSpecialAccess(String userId, String specialTag) async {
    try {
      switch (specialTag) {
        case 'all':
          return true;
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

  /// Check if user has access to group tags.
  static Future<bool> hasGroupAccess(String userId, String groupTag) async {
    try {
      final groups = await getAppwriteGroups(userId);
      return groups.contains(groupTag.toLowerCase());
    } catch (e) {
      _logger.error('Error checking group access: $e');
      return false;
    }
  }

  /// Get user's roles from the Appwrite users table.
  static Future<List<String>> getUserRoles(String userId) async {
    try {
      final userProfile = await _getUserProfile(userId);
      final roles = <String>{};
      for (final key in ['role', 'commitment_type', 'commitmentType']) {
        final value = userProfile[key];
        if (value is String && value.trim().isNotEmpty) {
          roles.add(value.trim().toLowerCase());
        }
      }
      return roles.toList();
    } catch (e) {
      _logger.error('Error getting user roles: $e');
      return [];
    }
  }

  /// Check hierarchical access (higher roles can see lower role tags).
  static Future<bool> hasHierarchicalAccess(
    List<String> userRoles,
    String targetRole,
  ) async {
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

    final targetLevel = hierarchy[targetRole.toLowerCase()] ?? 0;

    for (final role in userRoles) {
      final userLevel = hierarchy[role] ?? 0;
      if (userLevel >= targetLevel) {
        return true;
      }
    }

    return false;
  }

  /// Check peer access (same level roles can see each other's tags).
  static Future<bool> hasPeerAccess(
    List<String> userRoles,
    String targetRole,
  ) async {
    final normalizedTargetRole = targetRole.toLowerCase();
    final rolePeers = {
      'director': [
        'field_director',
        'campus_director',
        'program_director',
        'evangelism_director',
        'amtc_director',
      ],
      'field_director': [
        'director',
        'campus_director',
        'program_director',
        'evangelism_director',
        'amtc_director',
      ],
      'campus_director': [
        'director',
        'field_director',
        'program_director',
        'evangelism_director',
        'amtc_director',
      ],
      'program_director': [
        'director',
        'field_director',
        'campus_director',
        'evangelism_director',
        'amtc_director',
      ],
      'evangelism_director': [
        'director',
        'field_director',
        'campus_director',
        'program_director',
        'amtc_director',
      ],
      'amtc_director': [
        'director',
        'field_director',
        'campus_director',
        'program_director',
        'evangelism_director',
      ],
      'chap_coor': [
        'field_coor',
        'campus_coor',
        'program_coor',
        'evangelism_coor',
        'amtc_coor',
      ],
      'field_coor': [
        'chap_coor',
        'campus_coor',
        'program_coor',
        'evangelism_coor',
        'amtc_coor',
      ],
      'campus_coor': [
        'chap_coor',
        'field_coor',
        'program_coor',
        'evangelism_coor',
        'amtc_coor',
      ],
      'program_coor': [
        'chap_coor',
        'field_coor',
        'campus_coor',
        'evangelism_coor',
        'amtc_coor',
      ],
      'evangelism_coor': [
        'chap_coor',
        'field_coor',
        'campus_coor',
        'program_coor',
        'amtc_coor',
      ],
      'amtc_coor': [
        'chap_coor',
        'field_coor',
        'campus_coor',
        'program_coor',
        'evangelism_coor',
      ],
    };

    for (final role in userRoles) {
      final peers = rolePeers[role] ?? [];
      if (peers.contains(normalizedTargetRole)) {
        return true;
      }
    }

    return false;
  }

  /// Check team access (team roles can see each other's tags).
  static Future<bool> hasTeamAccess(
    List<String> userRoles,
    String targetRole,
  ) async {
    final normalizedTargetRole = targetRole.toLowerCase();
    final teams = {
      'executive': ['bod', 'trustees'],
      'admin': ['secretary', 'treasurer', 'media', 'tech', 'health'],
      'leadership': [
        'director',
        'chap_coor',
        'field_coor',
        'campus_coor',
        'program_coor',
        'evangelism_coor',
        'amtc_coor',
      ],
    };

    for (final role in userRoles) {
      final team = teams[role] ?? [];
      if (team.contains(normalizedTargetRole)) {
        return true;
      }
    }

    return false;
  }

  /// Check if user is currently online (recent activity).
  static Future<bool> isUserOnline(String userId) async {
    try {
      final userProfile = await _getUserProfile(userId);
      if (userProfile['is_online'] == true) return true;

      final lastSeen = _parseDateTime(userProfile['last_seen']) ??
          _parseDateTime(userProfile['last_online']);
      if (lastSeen == null) return false;

      return DateTime.now().toUtc().difference(lastSeen.toUtc()).inSeconds <=
          300;
    } catch (e) {
      _logger.error('Error checking user online status: $e');
      return false;
    }
  }

  /// Check if user was recently active (posts/interactions).
  static Future<bool> isUserRecentlyActive(String userId) async {
    try {
      final userProfile = await _getUserProfile(userId);
      final lastActivity = _parseDateTime(userProfile['last_activity']) ??
          _parseDateTime(userProfile['last_seen']) ??
          _parseDateTime(userProfile['updated_at']);
      if (lastActivity == null) return false;

      return DateTime.now().toUtc().difference(lastActivity.toUtc()).inSeconds <=
          86400;
    } catch (e) {
      _logger.error('Error checking user recent activity: $e');
      return false;
    }
  }

  /// Check if user is new (has joined recently).
  static Future<bool> isNewUser(String userId) async {
    try {
      final userProfile = await _getUserProfile(userId);
      final createdAt = _parseDateTime(userProfile['created_at']);
      if (createdAt == null) return false;

      return DateTime.now().toUtc().difference(createdAt.toUtc()).inSeconds <=
          604800;
    } catch (e) {
      _logger.error('Error checking new user status: $e');
      return false;
    }
  }

  /// Check if user is participant of a specific event type.
  static Future<bool> isEventParticipant(String userId, String eventType) async {
    try {
      final registrations = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.userEventsCollectionId,
        queries: [
          Query.equal('user_id', userId),
          Query.limit(100),
        ],
      );
      final normalizedEventType = eventType.toLowerCase();

      return registrations.rows.any((registration) {
        final data = registration.data;
        final status = (data['status'] as String?)?.toLowerCase();
        if (status == 'cancelled' || status == 'declined') return false;

        final eventId = (data['event_id'] as String?)?.toLowerCase();
        final type = (data['type'] as String?)?.toLowerCase();
        return eventId == normalizedEventType || type == normalizedEventType;
      });
    } catch (e) {
      _logger.error('Error checking event participant status: $e');
      return false;
    }
  }

  /// Get user's group memberships from the Appwrite user profile.
  static Future<List<String>> getAppwriteGroups(String userId) async {
    try {
      final userProfile = await _getUserProfile(userId);
      final groups = <String>{};

      for (final key in [
        'role',
        'chapter_id',
        'local_chapter',
        'conference',
        'commitment_type',
      ]) {
        final value = userProfile[key];
        if (value is String && value.trim().isNotEmpty) {
          groups.add(value.trim().toLowerCase());
        }
      }

      return groups.toList();
    } catch (e) {
      _logger.error('Error getting Appwrite groups: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> _getUserProfile(String userId) async {
    final user = await _tables.getRow(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: AppwriteBackendConfig.usersCollectionId,
      rowId: userId,
    );
    return user.data;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    return null;
  }
}
