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

/// Represents a breakout sub-room within a meeting session.
class BreakoutRoom {
  /// Unique LiveKit sub-room identifier (e.g. `<mainRoomSlug>--br-1`).
  final String id;

  /// Human-readable room name (e.g. "Room 1: Prayer & Intercession").
  final String name;

  /// Optional topic or discussion prompt for this breakout room.
  final String topic;

  /// Participant identities pre-assigned to this breakout room.
  final List<String> assignedParticipantIds;

  /// Lookup map of assigned participant identity -> display name.
  final Map<String, String> assignedParticipantNames;

  const BreakoutRoom({
    required this.id,
    required this.name,
    this.topic = '',
    this.assignedParticipantIds = const [],
    this.assignedParticipantNames = const {},
  });

  BreakoutRoom copyWith({
    String? id,
    String? name,
    String? topic,
    List<String>? assignedParticipantIds,
    Map<String, String>? assignedParticipantNames,
  }) {
    return BreakoutRoom(
      id: id ?? this.id,
      name: name ?? this.name,
      topic: topic ?? this.topic,
      assignedParticipantIds:
          assignedParticipantIds ?? this.assignedParticipantIds,
      assignedParticipantNames:
          assignedParticipantNames ?? this.assignedParticipantNames,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'topic': topic,
        'assignedParticipantIds': assignedParticipantIds,
        'assignedParticipantNames': assignedParticipantNames,
      };

  factory BreakoutRoom.fromJson(Map<String, dynamic> json) {
    final rawIds = json['assignedParticipantIds'];
    final rawNames = json['assignedParticipantNames'];
    return BreakoutRoom(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Breakout Room').toString(),
      topic: (json['topic'] ?? '').toString(),
      assignedParticipantIds: rawIds is List
          ? rawIds.map((e) => e.toString()).toList()
          : const <String>[],
      assignedParticipantNames: rawNames is Map
          ? rawNames.map((k, v) => MapEntry(k.toString(), v.toString()))
          : const <String, String>{},
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BreakoutRoom &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          topic == other.topic;

  @override
  int get hashCode => Object.hash(id, name, topic);
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

  /// Whether this participant the local user on this device.
  final bool isLocal;

  /// Whether this participant currently has their hand raised.
  final bool isHandRaised;

  /// Whether this participant is currently sharing their screen.
  final bool isScreenShareEnabled;

  const ParticipantInfo({
    required this.identity,
    required this.name,
    this.isSpeaking = false,
    this.isAudioEnabled = true,
    this.isVideoEnabled = true,
    this.isLocal = false,
    this.isHandRaised = false,
    this.isScreenShareEnabled = false,
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
    bool? isHandRaised,
    bool? isScreenShareEnabled,
  }) {
    return ParticipantInfo(
      identity: identity ?? this.identity,
      name: name ?? this.name,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isAudioEnabled: isAudioEnabled ?? this.isAudioEnabled,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      isLocal: isLocal ?? this.isLocal,
      isHandRaised: isHandRaised ?? this.isHandRaised,
      isScreenShareEnabled: isScreenShareEnabled ?? this.isScreenShareEnabled,
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
          isLocal == other.isLocal &&
          isHandRaised == other.isHandRaised;

  @override
  int get hashCode => Object.hash(
        identity,
        name,
        isSpeaking,
        isAudioEnabled,
        isVideoEnabled,
        isLocal,
        isHandRaised,
      );

  @override
  String toString() =>
      'ParticipantInfo(identity: $identity, name: $name, isSpeaking: $isSpeaking, '
      'isAudioEnabled: $isAudioEnabled, isVideoEnabled: $isVideoEnabled, isLocal: $isLocal, '
      'isHandRaised: $isHandRaised)';
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

  /// Whether the host has locked audio (preventing standard participants from unmuting).
  final bool isRoomAudioLocked;

  /// Whether the session adheres to mute-on-entry policy.
  final bool isMuteOnEntry;

  /// Whether the local participant currently has their hand raised.
  final bool isHandRaised;

  /// Whether this meeting requires host approval before entering (Waiting Room).
  final bool isWaitingRoomEnabled;

  /// Whether this participant has been admitted to the live meeting.
  final bool isAdmitted;

  /// Whether local screen sharing is active.
  final bool isScreenShareEnabled;

  /// Display name of the participant currently presenting their screen, if any.
  final String? activeScreenShareName;

  /// Waiting knocks for hosts to approve (list of maps with id, name).
  final List<Map<String, String>> waitingKnocks;

  /// Whether breakout rooms are currently open for this meeting.
  final bool isBreakoutActive;

  /// Configured breakout rooms when active.
  final List<BreakoutRoom> breakoutRooms;

  /// Name of the main plenary room when breakout rooms are active.
  final String? mainRoomName;

  /// ID of the breakout sub-room the local user is currently inside, if any.
  final String? activeBreakoutRoomId;

  /// Display name of the breakout sub-room the local user is currently inside, if any.
  final String? activeBreakoutRoomName;

  /// Whether participants are permitted to self-select or switch breakout rooms.
  final bool allowBreakoutSelfSelect;

  /// Optional UTC timestamp when breakout rooms automatically close.
  final DateTime? breakoutEndsAt;

  /// Latest announcement broadcast by the host to all breakout rooms.
  final String? breakoutBroadcastMessage;

  /// Optional error message if connection or operation failed.
  final String? error;

  const MeetingSession({
    this.roomName = '',
    this.status = RoomStatus.disconnected,
    this.isAudioMuted = true,
    this.isVideoMuted = false,
    this.participants = const [],
    this.isRoomAudioLocked = false,
    this.isMuteOnEntry = true,
    this.isHandRaised = false,
    this.isWaitingRoomEnabled = false,
    this.isAdmitted = true,
    this.isScreenShareEnabled = false,
    this.activeScreenShareName,
    this.waitingKnocks = const [],
    this.isBreakoutActive = false,
    this.breakoutRooms = const [],
    this.mainRoomName,
    this.activeBreakoutRoomId,
    this.activeBreakoutRoomName,
    this.allowBreakoutSelfSelect = true,
    this.breakoutEndsAt,
    this.breakoutBroadcastMessage,
    this.error,
  });

  /// Initial disconnected session.
  factory MeetingSession.initial() => const MeetingSession();

  /// Whether the session is currently connected.
  bool get isConnected => status == RoomStatus.connected;

  /// Whether the session is currently connecting or reconnecting.
  bool get isConnecting =>
      status == RoomStatus.connecting || status == RoomStatus.reconnecting;

  /// Whether the local user is currently inside a breakout sub-room.
  bool get isInBreakoutRoom =>
      activeBreakoutRoomId != null && activeBreakoutRoomId!.isNotEmpty;

  /// Local participant, if one exists in [participants].
  ParticipantInfo? get localParticipant {
    for (final p in participants) {
      if (p.isLocal) return p;
    }
    return null;
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
    bool? isRoomAudioLocked,
    bool? isMuteOnEntry,
    bool? isHandRaised,
    bool? isWaitingRoomEnabled,
    bool? isAdmitted,
    bool? isScreenShareEnabled,
    String? activeScreenShareName,
    List<Map<String, String>>? waitingKnocks,
    bool? isBreakoutActive,
    List<BreakoutRoom>? breakoutRooms,
    String? mainRoomName,
    String? activeBreakoutRoomId,
    String? activeBreakoutRoomName,
    bool? allowBreakoutSelfSelect,
    DateTime? breakoutEndsAt,
    String? breakoutBroadcastMessage,
    String? error,
  }) {
    return MeetingSession(
      roomName: roomName ?? this.roomName,
      status: status ?? this.status,
      isAudioMuted: isAudioMuted ?? this.isAudioMuted,
      isVideoMuted: isVideoMuted ?? this.isVideoMuted,
      participants: participants ?? this.participants,
      isRoomAudioLocked: isRoomAudioLocked ?? this.isRoomAudioLocked,
      isMuteOnEntry: isMuteOnEntry ?? this.isMuteOnEntry,
      isHandRaised: isHandRaised ?? this.isHandRaised,
      isWaitingRoomEnabled: isWaitingRoomEnabled ?? this.isWaitingRoomEnabled,
      isAdmitted: isAdmitted ?? this.isAdmitted,
      isScreenShareEnabled: isScreenShareEnabled ?? this.isScreenShareEnabled,
      activeScreenShareName:
          activeScreenShareName ?? this.activeScreenShareName,
      waitingKnocks: waitingKnocks ?? this.waitingKnocks,
      isBreakoutActive: isBreakoutActive ?? this.isBreakoutActive,
      breakoutRooms: breakoutRooms ?? this.breakoutRooms,
      mainRoomName: mainRoomName ?? this.mainRoomName,
      activeBreakoutRoomId: activeBreakoutRoomId ?? this.activeBreakoutRoomId,
      activeBreakoutRoomName:
          activeBreakoutRoomName ?? this.activeBreakoutRoomName,
      allowBreakoutSelfSelect:
          allowBreakoutSelfSelect ?? this.allowBreakoutSelfSelect,
      breakoutEndsAt: breakoutEndsAt ?? this.breakoutEndsAt,
      breakoutBroadcastMessage:
          breakoutBroadcastMessage ?? this.breakoutBroadcastMessage,
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
          isRoomAudioLocked == other.isRoomAudioLocked &&
          isMuteOnEntry == other.isMuteOnEntry &&
          isHandRaised == other.isHandRaised &&
          isWaitingRoomEnabled == other.isWaitingRoomEnabled &&
          isAdmitted == other.isAdmitted &&
          isBreakoutActive == other.isBreakoutActive &&
          activeBreakoutRoomId == other.activeBreakoutRoomId &&
          allowBreakoutSelfSelect == other.allowBreakoutSelfSelect &&
          breakoutBroadcastMessage == other.breakoutBroadcastMessage &&
          error == other.error;

  @override
  int get hashCode => Object.hash(
        roomName,
        status,
        isAudioMuted,
        isVideoMuted,
        isRoomAudioLocked,
        isMuteOnEntry,
        isHandRaised,
        isWaitingRoomEnabled,
        isAdmitted,
        isBreakoutActive,
        activeBreakoutRoomId,
        allowBreakoutSelfSelect,
        breakoutBroadcastMessage,
        error,
      );

  @override
  String toString() =>
      'MeetingSession(roomName: $roomName, status: $status, '
      'isAudioMuted: $isAudioMuted, isVideoMuted: $isVideoMuted, '
      'isRoomAudioLocked: $isRoomAudioLocked, '
      'isBreakoutActive: $isBreakoutActive, activeBreakoutRoomId: $activeBreakoutRoomId, '
      'participants: ${participants.length}, error: $error)';
}
