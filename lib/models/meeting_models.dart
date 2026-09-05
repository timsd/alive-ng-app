/// Domain models for the video meeting service.
///
/// These models are SDK-agnostic: they MUST NOT import `package:livekit_client`
/// or any other third-party WebRTC/video SDK.
/// They form the innermost core of our Hexagonal Architecture for meetings.
library;

/// Represents the connection lifecycle of a meeting room.
enum RoomStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// Represents a participant in a meeting room.
class ParticipantInfo {
  /// Unique identifier of the participant (e.g. user ID).
  final String identity;

  /// Human-readable display name.
  final String name;

  /// Whether this participant is currently speaking.
  final bool isSpeaking;

  /// Whether this participant's microphone is enabled (unmuted).
  final bool isAudioEnabled;

  /// Whether this participant's camera is enabled.
  final bool isVideoEnabled;

  /// Whether this participant is the local user on this device.
  final bool isLocal;

  const ParticipantInfo({
    required this.identity,
    required this.name,
    this.isSpeaking = false,
    this.isAudioEnabled = true,
    this.isVideoEnabled = true,
    this.isLocal = false,
  });

  /// Convenience getter to check if audio is muted.
  bool get isAudioMuted => !isAudioEnabled;

  /// Convenience getter to check if video is muted/disabled.
  bool get isVideoMuted => !isVideoEnabled;

  ParticipantInfo copyWith({
    String? identity,
    String? name,
    bool? isSpeaking,
    bool? isAudioEnabled,
    bool? isVideoEnabled,
    bool? isLocal,
  }) {
    return ParticipantInfo(
      identity: identity ?? this.identity,
      name: name ?? this.name,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isAudioEnabled: isAudioEnabled ?? this.isAudioEnabled,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      isLocal: isLocal ?? this.isLocal,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParticipantInfo &&
          runtimeType == other.runtimeType &&
          identity == other.identity &&
          name == other.name &&
          isSpeaking == other.isSpeaking &&
          isAudioEnabled == other.isAudioEnabled &&
          isVideoEnabled == other.isVideoEnabled &&
          isLocal == other.isLocal;

  @override
  int get hashCode => Object.hash(
        identity,
        name,
        isSpeaking,
        isAudioEnabled,
        isVideoEnabled,
        isLocal,
      );

  @override
  String toString() =>
      'ParticipantInfo(identity: $identity, name: $name, isSpeaking: $isSpeaking, '
      'isAudioEnabled: $isAudioEnabled, isVideoEnabled: $isVideoEnabled, isLocal: $isLocal)';
}

/// Snapshot of an active or pending meeting session.
class MeetingSession {
  /// The name or identifier of the room.
  final String roomName;

  /// Current connection status of the room.
  final RoomStatus status;

  /// Whether the local microphone is currently muted.
  final bool isAudioMuted;

  /// Whether the local camera is currently muted / disabled.
  final bool isVideoMuted;

  /// List of all participants currently in the room (local + remote).
  final List<ParticipantInfo> participants;

  /// Optional error message if connection or operation failed.
  final String? error;

  const MeetingSession({
    this.roomName = '',
    this.status = RoomStatus.disconnected,
    this.isAudioMuted = false,
    this.isVideoMuted = false,
    this.participants = const [],
    this.error,
  });

  /// Initial disconnected session.
  factory MeetingSession.initial() => const MeetingSession();

  /// Whether the session is currently connected.
  bool get isConnected => status == RoomStatus.connected;

  /// Whether the session is currently connecting or reconnecting.
  bool get isConnecting =>
      status == RoomStatus.connecting || status == RoomStatus.reconnecting;

  /// Local participant, if one exists in [participants].
  ParticipantInfo? get localParticipant {
    try {
      return participants.firstWhere((p) => p.isLocal);
    } catch (_) {
      return null;
    }
  }

  /// Remote participants (excluding local).
  List<ParticipantInfo> get remoteParticipants =>
      participants.where((p) => !p.isLocal).toList();

  MeetingSession copyWith({
    String? roomName,
    RoomStatus? status,
    bool? isAudioMuted,
    bool? isVideoMuted,
    List<ParticipantInfo>? participants,
    String? error,
  }) {
    return MeetingSession(
      roomName: roomName ?? this.roomName,
      status: status ?? this.status,
      isAudioMuted: isAudioMuted ?? this.isAudioMuted,
      isVideoMuted: isVideoMuted ?? this.isVideoMuted,
      participants: participants ?? this.participants,
      error: error,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeetingSession &&
          runtimeType == other.runtimeType &&
          roomName == other.roomName &&
          status == other.status &&
          isAudioMuted == other.isAudioMuted &&
          isVideoMuted == other.isVideoMuted &&
          error == other.error;

  @override
  int get hashCode => Object.hash(
        roomName,
        status,
        isAudioMuted,
        isVideoMuted,
        error,
      );

  @override
  String toString() =>
      'MeetingSession(roomName: $roomName, status: $status, '
      'isAudioMuted: $isAudioMuted, isVideoMuted: $isVideoMuted, '
      'participants: ${participants.length}, error: $error)';
}
