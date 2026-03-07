/// Configuration class for meeting URLs
class MeetingLinksConfig {
  /// Board of Directors meeting URL
  static const String bodMeetingUrl = 'https://meet.jit.si/alive-ng-board-meeting';

  /// Leadership meeting URL
  static const String leadershipMeetingUrl = 'https://meet.jit.si/alive-ng-leadership-meeting';

  /// Prayer meeting URL
  static const String prayerMeetingUrl = 'https://meet.jit.si/alive-ng-prayer-meeting';

  /// General meeting URL
  static const String generalMeetingUrl = 'https://meet.jit.si/alive-ng-general-meeting';

  /// Get meeting URL by type
  static String getMeetingUrl(MeetingType type) {
    switch (type) {
      case MeetingType.board:
        return bodMeetingUrl;
      case MeetingType.leadership:
        return leadershipMeetingUrl;
      case MeetingType.prayer:
        return prayerMeetingUrl;
      case MeetingType.general:
        return generalMeetingUrl;
    }
  }
}

/// Enum for different meeting types
enum MeetingType {
  board,
  leadership,
  prayer,
  general,
}

/// Extension to get display names for meeting types
extension MeetingTypeExtension on MeetingType {
  String get displayName {
    switch (this) {
      case MeetingType.board:
        return 'Board of Directors';
      case MeetingType.leadership:
        return 'Leadership Meeting';
      case MeetingType.prayer:
        return 'Prayer Meeting';
      case MeetingType.general:
        return 'General Meeting';
    }
  }
}