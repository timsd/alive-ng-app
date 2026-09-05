/// Appwrite Chat Configuration
/// Contains client-side chat options and role/channel permissions.
class ChatConfig {
  /// Chat configuration options
  static const Map<String, dynamic> chatOptions = {
    'typing_events': true,
    'read_events': true,
    'connect_user_details_timeout': 5000,
    // Messages persist indefinitely unless explicitly deleted by user/admin
    'max_message_length': 5000,
    'file_upload_config': {
      'allowed_file_extensions': [
        'jpg',
        'jpeg',
        'png',
        'gif',
        'pdf',
        'doc',
        'docx'
      ],
      'allowed_mime_types': [
        'image/jpeg',
        'image/png',
        'image/gif',
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      ],
      'size_limit': 20 * 1024 * 1024, // 20MB
    },
  };

  /// Default channel types for the app
  static const Map<String, String> channelTypes = {
    'general': 'General Discussion',
    'chapter': 'Chapter Channels',
    'discipleship': 'Discipleship Groups',
    'health': 'Health & Wellness',
    'study': 'Study Groups',
    'prayer': 'Prayer Requests',
    'announcements': 'Announcements',
    'leadership': 'Leadership Team',
  };

  /// Channel permissions based on user roles
  static Map<String, List<String>> getChannelPermissions(String userRole) {
    switch (userRole.toLowerCase()) {
      case 'admin':
      case 'director':
        return {
          'can_create': [
            'general',
            'chapter',
            'discipleship',
            'health',
            'study',
            'prayer',
            'announcements',
            'leadership'
          ],
          'can_moderate': [
            'general',
            'chapter',
            'discipleship',
            'health',
            'study',
            'prayer',
            'announcements',
            'leadership'
          ],
          'can_delete': [
            'general',
            'chapter',
            'discipleship',
            'health',
            'study',
            'prayer',
            'announcements',
            'leadership'
          ],
        };
      case 'coordinator':
        return {
          'can_create': ['chapter', 'discipleship', 'study', 'prayer'],
          'can_moderate': ['chapter', 'discipleship', 'study', 'prayer'],
          'can_delete': ['chapter', 'discipleship', 'study'],
        };
      case 'member':
      default:
        return {
          'can_create': ['discipleship', 'study', 'prayer'],
          'can_moderate': [],
          'can_delete': [],
        };
    }
  }

  /// Get user roles that can be tagged in messages
  static List<String> getTaggableRoles() {
    return [
      'admin',
      'director',
      'coordinator',
      'assistant',
      'bod',
      'trustees',
      'chap_coor',
      'member',
    ];
  }

  /// Get special tags available in the system
  static List<String> getSpecialTags() {
    return [
      '#everyone',
      '#online',
      '#here',
      '#chapter',
      '#leadership',
      '#prayer_team',
      '#health_team',
      '#study_team',
    ];
  }

  /// Message formatting options
  static const Map<String, dynamic> messageFormatting = {
    'enable_markdown': true,
    'enable_mentions': true,
    'enable_emojis': true,
    'enable_reactions': true,
    'enable_threads': true,
    'enable_quotes': true,
  };

  /// Notification settings for different message types
  static const Map<String, bool> notificationSettings = {
    'direct_messages': true,
    'mentions': true,
    'channel_messages': false,
    'reactions': true,
    'threads': true,
  };
}
