/// Stable room definitions for the ALIVE Meet LiveKit experience.
/// These are room identifiers, never external meeting URLs.
class AliveMeetConfig {
  static const String boardRoom = 'alive-meet-board';
  static const String leadershipRoom = 'alive-meet-leadership';
  static const String prayerRoom = 'alive-meet-prayer';
  static const String communityRoom = 'alive-meet-community';

  static String roomFor(MeetingType type) {
    switch (type) {
      case MeetingType.board:
        return boardRoom;
      case MeetingType.leadership:
        return leadershipRoom;
      case MeetingType.prayer:
        return prayerRoom;
      case MeetingType.general:
        return communityRoom;
    }
  }
}

enum MeetingType {
  board,
  leadership,
  prayer,
  general,
}

extension MeetingTypeExtension on MeetingType {
  String get displayName {
    switch (this) {
      case MeetingType.board:
        return 'ALIVE Meet: Board';
      case MeetingType.leadership:
        return 'ALIVE Meet: Leadership';
      case MeetingType.prayer:
        return 'ALIVE Meet: Prayer';
      case MeetingType.general:
        return 'ALIVE Meet';
    }
  }
}
