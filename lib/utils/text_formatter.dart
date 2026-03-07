/// Utility class for formatting text strings properly
class TextFormatter {
  /// Formats text by replacing underscores with spaces and applying proper capitalization
  static String formatText(String text) {
    if (text.isEmpty) return text;
    
    // Replace underscores with spaces
    String formatted = text.replaceAll('_', ' ');
    
    // Apply title case (capitalize first letter of each word)
    return formatted.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Formats text for display in UI components
  static String formatForDisplay(String text) {
    return formatText(text);
  }

  /// Formats text for headers and titles
  static String formatTitle(String text) {
    return formatText(text);
  }

  /// Formats text for subtitles and descriptions
  static String formatSubtitle(String text) {
    return formatText(text);
  }

  /// Formats text for buttons and actions
  static String formatAction(String text) {
    return formatText(text);
  }

  /// Formats category names
  static String formatCategory(String text) {
    return formatText(text);
  }

  /// Formats status text
  static String formatStatus(String text) {
    return formatText(text);
  }

  /// Formats role names for display
  static String formatRole(String role) {
    // Handle special role formatting
    String formatted = role.replaceAll('_', ' ');
    
    // Special cases for common roles
    switch (role.toLowerCase()) {
      case 'field_director':
        return 'Field Director';
      case 'campus_mission':
        return 'Campus Mission';
      case 'chapter_leader':
        return 'Chapter Leader';
      case 'board_member':
        return 'Board Member';
      case 'admin_only':
        return 'Admin Only';
      case 'trustees_only':
        return 'Trustees Only';
      case 'board_only':
        return 'Board Only';
      default:
        return formatText(formatted);
    }
  }

  /// Formats database field names for display
  static String formatFieldName(String fieldName) {
    // Handle common database field patterns
    String formatted = fieldName.replaceAll('_', ' ');
    
    // Special cases for common fields
    switch (fieldName.toLowerCase()) {
      case 'full_name':
        return 'Full Name';
      case 'created_at':
        return 'Created At';
      case 'updated_at':
        return 'Updated At';
      case 'user_id':
        return 'User ID';
      case 'prayer_count':
        return 'Prayer Count';
      case 'is_anonymous':
        return 'Anonymous';
      case 'is_public':
        return 'Public';
      case 'is_active':
        return 'Active';
      default:
        return formatText(formatted);
    }
  }

  /// Formats notification types for display
  static String formatNotificationType(String type) {
    String formatted = type.replaceAll('_', ' ');
    
    switch (type.toLowerCase()) {
      case 'daily_verse_notification':
        return 'Daily Verse';
      case 'prayer_reminder_notification':
        return 'Prayer Reminder';
      case 'study_reminder_notification':
        return 'Study Reminder';
      case 'health_tracking_notification':
        return 'Health Tracking';
      case 'mission_reminder_notification':
        return 'Mission Reminder';
      default:
        return formatText(formatted);
    }
  }

  /// Formats activity types for display
  static String formatActivityType(String activity) {
    String formatted = activity.replaceAll('_', ' ');
    
    switch (activity.toLowerCase()) {
      case 'bible_study':
        return 'Bible Study';
      case 'prayer_requests':
        return 'Prayer Requests';
      case 'wellness_tracking':
        return 'Wellness Tracking';
      case 'global_outreach':
        return 'Global Outreach';
      case 'daily_verse':
        return 'Daily Verse';
      case 'health_tracking':
        return 'Health Tracking';
      default:
        return formatText(formatted);
    }
  }

  /// Formats health categories for display
  static String formatHealthCategory(String category) {
    String formatted = category.replaceAll('_', ' ');
    
    switch (category.toLowerCase()) {
      case 'natural_remedies':
        return 'Natural Remedies';
      case 'gods_natural_healing':
        return "God's Natural Healing";
      case 'todays_wellness':
        return "Today's Wellness";
      case 'activities_completed':
        return 'Activities Completed';
      case 'wellness_tracking':
        return 'Wellness Tracking';
      case 'health_wellness':
        return 'Health & Wellness';
      default:
        return formatText(formatted);
    }
  }

  /// Formats time-related text
  static String formatTimeText(String timeText) {
    String formatted = timeText.replaceAll('_', ' ');
    
    switch (timeText.toLowerCase()) {
      case 'todays_activities':
        return "Today's Activities";
      case 'good_morning':
        return 'Good Morning';
      case 'good_afternoon':
        return 'Good Afternoon';
      case 'good_evening':
        return 'Good Evening';
      default:
        return formatText(formatted);
    }
  }
}

/// Extension to make text formatting easier in widgets
extension StringFormatting on String {
  /// Format this string for display
  String get formatted => TextFormatter.formatText(this);
  
  /// Format this string as a title
  String get asTitle => TextFormatter.formatTitle(this);
  
  /// Format this string as a subtitle
  String get asSubtitle => TextFormatter.formatSubtitle(this);
  
  /// Format this string as an action
  String get asAction => TextFormatter.formatAction(this);
  
  /// Format this string as a category
  String get asCategory => TextFormatter.formatCategory(this);
  
  /// Format this string as a role
  String get asRole => TextFormatter.formatRole(this);
  
  /// Format this string as a field name
  String get asFieldName => TextFormatter.formatFieldName(this);
  
  /// Format this string as a notification type
  String get asNotificationType => TextFormatter.formatNotificationType(this);
  
  /// Format this string as an activity type
  String get asActivityType => TextFormatter.formatActivityType(this);
  
  /// Format this string as a health category
  String get asHealthCategory => TextFormatter.formatHealthCategory(this);
  
  /// Format this string as time-related text
  String get asTimeText => TextFormatter.formatTimeText(this);
}



