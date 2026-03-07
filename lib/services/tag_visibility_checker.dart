import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_models.dart';
import '../utils/logger.dart';
import 'firebase_database_service.dart';

/// Handles tag visibility and access control for messages
class TagVisibilityChecker {
  static final Logger _logger = Logger('TagVisibilityChecker');
  static final FirebaseDatabaseService _firebase = FirebaseDatabaseService.instance;

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
      // Get user's profile to check username match from Firebase
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final userProfile = userDoc.data() ?? {};
      final profileUsername = (userProfile['username'] as String?)?.toLowerCase();
      final profileEmail = (userProfile['email'] as String?)?.toLowerCase();
      final fullName = (userProfile['full_name'] as String?)?.toLowerCase();
      final normalizedDot = fullName?.replaceAll(' ', '.');
      final normalizedUnderscore = fullName?.replaceAll(' ', '_');
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
      // Check if user is member of the group from Firebase
      final groups = await getFirebaseGroups(userId);
      return groups.contains(groupTag);
    } catch (e) {
      _logger.error('Error checking group access: $e');
      return false;
    }
  }

  /// Get user's roles from database (Firebase)
  static Future<List<String>> getUserRoles(String userId) async {
    try {
      final rolesSnapshot = await FirebaseFirestore.instance
          .collection('user_roles')
          .where('user_id', isEqualTo: userId)
          .get();

      return rolesSnapshot.docs
          .map((doc) => doc.data()['role_name'] as String)
          .toList();
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

  /// Check peer access (same level roles can see each other's tags)
  static Future<bool> hasPeerAccess(List<String> userRoles, String targetRole) async {
    final rolePeers = {
      'director': ['field_director', 'campus_director', 'program_director', 'evangelism_director', 'amtc_director'],
      'field_director': ['director', 'campus_director', 'program_director', 'evangelism_director', 'amtc_director'],
      'campus_director': ['director', 'field_director', 'program_director', 'evangelism_director', 'amtc_director'],
      'program_director': ['director', 'field_director', 'campus_director', 'evangelism_director', 'amtc_director'],
      'evangelism_director': ['director', 'field_director', 'campus_director', 'program_director', 'amtc_director'],
      'amtc_director': ['director', 'field_director', 'campus_director', 'program_director', 'evangelism_director'],
      'chap_coor': ['field_coor', 'campus_coor', 'program_coor', 'evangelism_coor', 'amtc_coor'],
      'field_coor': ['chap_coor', 'campus_coor', 'program_coor', 'evangelism_coor', 'amtc_coor'],
      'campus_coor': ['chap_coor', 'field_coor', 'program_coor', 'evangelism_coor', 'amtc_coor'],
      'program_coor': ['chap_coor', 'field_coor', 'campus_coor', 'evangelism_coor', 'amtc_coor'],
      'evangelism_coor': ['chap_coor', 'field_coor', 'campus_coor', 'program_coor', 'amtc_coor'],
      'amtc_coor': ['chap_coor', 'field_coor', 'campus_coor', 'program_coor', 'evangelism_coor'],
    };

    for (final role in userRoles) {
      final peers = rolePeers[role] ?? [];
      if (peers.contains(targetRole)) {
        return true;
      }
    }

    return false;
  }

  /// Check team access (team roles can see each other's tags)
  static Future<bool> hasTeamAccess(List<String> userRoles, String targetRole) async {
    final teams = {
      'executive': ['bod', 'trustees'],
      'admin': ['secretary', 'treasurer', 'media', 'tech', 'health'],
      'leadership': ['director', 'chap_coor', 'field_coor', 'campus_coor', 'program_coor', 'evangelism_coor', 'amtc_coor'],
    };

    for (final role in userRoles) {
      final team = teams[role] ?? [];
      if (team.contains(targetRole)) {
        return true;
      }
    }

    return false;
  }

  /// Check if user is currently online (recent activity)
  static Future<bool> isUserOnline(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final lastOnline = userDoc.data()?['last_online'] as Timestamp?;
      if (lastOnline == null) return false;

      final now = Timestamp.now();
      final difference = now.seconds - lastOnline.seconds;
      // Consider online if active within last 5 minutes
      return difference <= 300;
    } catch (e) {
      _logger.error('Error checking user online status: $e');
      return false;
    }
  }

  /// Check if user was recently active (posts/interactions)
  static Future<bool> isUserRecentlyActive(String userId) async {
    try {
      final activityDoc = await FirebaseFirestore.instance.collection('user_activity').doc(userId).get();
      final lastActivity = activityDoc.data()?['last_activity'] as Timestamp?;
      if (lastActivity == null) return false;

      final now = Timestamp.now();
      final difference = now.seconds - lastActivity.seconds;
      // Consider active if within last 24 hours
      return difference <= 86400;
    } catch (e) {
      _logger.error('Error checking user recent activity: $e');
      return false;
    }
  }

  /// Check if user is new (has joined recently)
  static Future<bool> isNewUser(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final createdAt = userDoc.data()?['created_at'] as Timestamp?;
      if (createdAt == null) return false;

      final now = Timestamp.now();
      final difference = now.seconds - createdAt.seconds;
      // Consider new if joined within last 7 days
      return difference <= 604800;
    } catch (e) {
      _logger.error('Error checking new user status: $e');
      return false;
    }
  }

  /// Check if user is participant of specific event type
  static Future<bool> isEventParticipant(String userId, String eventType) async {
    try {
      final eventRegistration = await FirebaseFirestore.instance
          .collection('event_registrations')
          .doc('$userId-$eventType')
          .get();

      return eventRegistration.exists;
    } catch (e) {
      _logger.error('Error checking event participant status: $e');
      return false;
    }
  }

  /// Get user's group memberships from Firebase if Supabase is unavailable
  static Future<List<String>> getFirebaseGroups(String userId) async {
    try {
      final groupsSnapshot = await FirebaseFirestore.instance
          .collection('user_groups')
          .where('user_id', isEqualTo: userId)
          .get();

      return groupsSnapshot.docs.map((doc) => doc.data()['group_name'] as String).toList();
    } catch (e) {
      _logger.error('Error getting Firebase groups: $e');
      return [];
    }
  }

  /// Sync tag visibility info to Firebase cache for faster access
  static Future<void> cacheTagVisibilityInfo(String userId, List<String> visibleTags) async {
    try {
      await _firebase.cacheVisibleTags(userId, visibleTags);
    } catch (e) {
      _logger.error('Error caching tag visibility: $e');
    }
  }
}



