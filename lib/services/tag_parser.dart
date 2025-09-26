import '../models/chat_models.dart';
import '../config/chat_config.dart';

/// Parser for extracting tags from message content
class TagParser {
  /// Parse message content and extract all tags
  static List<MessageTag> parseMessage(String content) {
    List<MessageTag> tags = [];
    
    // Parse role tags (#tag)
    final roleTagRegex = RegExp(r'#([a-zA-Z0-9_]+)');
    roleTagRegex.allMatches(content).forEach((match) {
      final tagValue = match.group(1)!;
      
      // Check if it's a valid role tag
      if (_isValidRoleTag(tagValue)) {
        tags.add(MessageTag(
          type: TagType.role,
          value: tagValue,
          displayName: _getRoleDisplayName(tagValue),
        ));
      } else if (_isSpecialTag(tagValue)) {
        tags.add(MessageTag(
          type: TagType.special,
          value: tagValue,
          displayName: _getSpecialTagDisplayName(tagValue),
        ));
      } else {
        // Treat as group tag
        tags.add(MessageTag(
          type: TagType.group,
          value: tagValue,
          displayName: _getGroupDisplayName(tagValue),
        ));
      }
    });
    
    // Parse user tags (@username)
    final userTagRegex = RegExp(r'@([a-zA-Z0-9_.]+)');
    userTagRegex.allMatches(content).forEach((match) {
      final username = match.group(1)!;
      tags.add(MessageTag(
        type: TagType.user,
        value: username,
        displayName: username,
      ));
    });
    
    return tags;
  }

  /// Extract unique tags from message content
  static List<MessageTag> parseUniqueMessage(String content) {
    final tags = parseMessage(content);
    final uniqueTags = <MessageTag>[];
    final seenTags = <String>{};

    for (final tag in tags) {
      final key = '${tag.type.name}:${tag.value}';
      if (!seenTags.contains(key)) {
        seenTags.add(key);
        uniqueTags.add(tag);
      }
    }

    return uniqueTags;
  }

  /// Check if a tag value is a valid role tag
  static bool _isValidRoleTag(String tagValue) {
    final validRoles = [
      'bod', 'trustees', 'executive', 'leadership',
      'director', 'field_director', 'campus_director', 'program_director',
      'evangelism_director', 'amtc_director',
      'chap_coor', 'field_coor', 'campus_coor', 'program_coor',
      'evangelism_coor', 'amtc_coor',
      'admin', 'treasurer', 'secretary', 'media', 'tech', 'health',
      'fieldwork', 'campus_mission', 'amtc', 'youth', 'women', 'men',
      'north', 'south', 'east', 'west', 'central'
    ];
    
    // Check for chapter tags (chapter_[name])
    if (tagValue.startsWith('chapter_')) {
      return true;
    }
    
    // Check for event tags (event_[name])
    if (tagValue.startsWith('event_')) {
      return true;
    }
    
    return validRoles.contains(tagValue);
  }

  /// Check if a tag value is a special tag
  static bool _isSpecialTag(String tagValue) {
    final specialTags = [
      'all', 'online', 'active', 'new',
      'meeting', 'conference', 'training'
    ];
    return specialTags.contains(tagValue);
  }

  /// Get display name for role tags
  static String _getRoleDisplayName(String roleValue) {
    final roleDisplayNames = {
      'bod': 'Board of Directors',
      'trustees': 'Board Trustees',
      'executive': 'Executive Committee',
      'leadership': 'Leadership',
      'director': 'Directors',
      'field_director': 'Field Work Director',
      'campus_director': 'Campus Mission Director',
      'program_director': 'Programming Director',
      'evangelism_director': 'Evangelism Director',
      'amtc_director': 'AMTC Director',
      'chap_coor': 'Chapter Coordinators',
      'field_coor': 'Field Work Coordinators',
      'campus_coor': 'Campus Mission Coordinators',
      'program_coor': 'Programming Coordinators',
      'evangelism_coor': 'Evangelism Coordinators',
      'amtc_coor': 'AMTC Coordinators',
      'admin': 'Administrative Team',
      'treasurer': 'Treasurers',
      'secretary': 'Secretaries',
      'media': 'Media Team',
      'tech': 'Technical Team',
      'health': 'Health Ministry Team',
      'fieldwork': 'Field Work Team',
      'campus_mission': 'Campus Mission Team',
      'amtc': 'AMTC Team',
      'youth': 'Youth Ministry',
      'women': 'Women\'s Ministry',
      'men': 'Men\'s Ministry',
      'north': 'Northern Region',
      'south': 'Southern Region',
      'east': 'Eastern Region',
      'west': 'Western Region',
      'central': 'Central Region',
    };

    // Handle chapter tags
    if (roleValue.startsWith('chapter_')) {
      final chapterName = roleValue.substring(8);
      return 'Chapter ${chapterName.toUpperCase()}';
    }

    // Handle event tags
    if (roleValue.startsWith('event_')) {
      final eventName = roleValue.substring(6);
      return 'Event ${eventName.replaceAll('_', ' ').toUpperCase()}';
    }

    return roleDisplayNames[roleValue] ?? roleValue.toUpperCase();
  }

  /// Get display name for special tags
  static String _getSpecialTagDisplayName(String specialValue) {
    final specialDisplayNames = {
      'all': 'All Users',
      'online': 'Online Users',
      'active': 'Recently Active',
      'new': 'New Users',
      'meeting': 'Meeting Participants',
      'conference': 'Conference Attendees',
      'training': 'Training Participants',
    };

    return specialDisplayNames[specialValue] ?? specialValue.toUpperCase();
  }

  /// Get display name for group tags
  static String _getGroupDisplayName(String groupValue) {
    return groupValue.replaceAll('_', ' ').toUpperCase();
  }

  /// Get all tags from a list of messages
  static List<MessageTag> getAllTagsFromMessages(List<String> messages) {
    final allTags = <MessageTag>[];
    final seenTags = <String>{};

    for (final message in messages) {
      final tags = parseMessage(message);
      for (final tag in tags) {
        final key = '${tag.type.name}:${tag.value}';
        if (!seenTags.contains(key)) {
          seenTags.add(key);
          allTags.add(tag);
        }
      }
    }

    return allTags;
  }

  /// Check if message contains any tags
  static bool hasAnyTags(String content) {
    return parseMessage(content).isNotEmpty;
  }

  /// Get tag count in message
  static int getTagCount(String content) {
    return parseMessage(content).length;
  }

  /// Remove tags from message content
  static String removeTagsFromContent(String content) {
    String cleanContent = content;
    
    // Remove role/group/special tags
    cleanContent = cleanContent.replaceAll(RegExp(r'#[a-zA-Z0-9_]+'), '');
    
    // Remove user tags
    cleanContent = cleanContent.replaceAll(RegExp(r'@[a-zA-Z0-9_.]+'), '');
    
    // Clean up extra spaces
    cleanContent = cleanContent.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return cleanContent;
  }
}