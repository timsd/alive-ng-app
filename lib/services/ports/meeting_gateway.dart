/// Abstract port interface for video meeting rooms.
///
/// This port defines the contract for meeting connections, media toggling,
/// participant events, and lifecycle management without referencing any
/// concrete WebRTC or video SDK (such as `package:livekit_client`).
///
/// ```text
///   UI / Providers  ──▶  MeetingGateway (port)  ◀──  LiveKitMeetingGateway (adapter)
/// ```
library;

import 'package:flutter/widgets.dart';

import '../../models/meeting_models.dart';

/// Abstract gateway representing video/audio conferencing capabilities.
abstract class MeetingGateway {
  /// Current snapshot of the meeting session.
  MeetingSession get currentSession;

  /// Stream of meeting session state changes.
  Stream<MeetingSession> get sessionStream;

  /// Stream of room connection status changes.
  Stream<RoomStatus> get roomStatus;

  /// Returns a widget rendering the participant's camera video, or null if no active video track exists.
  Widget? buildParticipantVideoWidget(String identity, {bool mirror = false});

  /// Returns a widget rendering the active screen share video feed, or null if no screen is being shared.
  Widget? buildScreenShareVideoWidget();

  /// Whether the client is currently connected to an active room.
  bool get isConnected;

  /// Whether the local microphone is currently muted.
  bool get isAudioMuted;

  /// Whether the local video camera is currently muted / disabled.
  bool get isVideoMuted;

  /// Whether screen sharing is currently active on this device.
  bool get isScreenShareEnabled;

  /// Whether the host has locked audio for standard participants.
  bool get isRoomAudioLocked;

  /// Requests a token from the backend for [roomName] and joins the meeting room.
  Future<void> executionAndJoin({
    required String roomName,
    required String userId,
    required String userName,
    String? avatarUrl,
    required String meetingType,
    bool notifyMembers = false,
    String? meetingTitle,
    String targetAudience = 'general',
    String? targetChapter,
    bool isWaitingRoomEnabled = false,
  });

  /// Joins a meeting room directly using a pre-fetched [roomToken].
  Future<void> joinMeeting({
    required String roomToken,
    String? roomName,
  });

  /// Unlocks audio playback and ensures speaker routing is active (e.g. after user gesture on join).
  Future<void> unlockAudio();

  /// Mutes or unmutes the local participant's microphone.
  Future<void> toggleAudio();

  /// Enables or disables the local participant's video camera.
  Future<void> toggleVideo();

  /// Toggles screen sharing for host or co-host.
  Future<void> toggleScreenShare();

  /// Leaves the current meeting room and resets local media state.
  Future<void> leaveMeeting();

  /// Host / Moderator command: Mutes all remote participants in the room.
  Future<void> muteAll();

  /// Host / Moderator command: Hard-locks microphone unmuting for standard participants.
  Future<void> setRoomAudioLock(bool locked);

  /// Participant action: Raises or lowers hand to request permission to speak.
  Future<void> raiseHand({bool raised = true});

  /// Host command: Asks a specific participant to unmute their microphone.
  Future<void> askParticipantToUnmute(String identity);

  /// Host command: Force mutes a specific participant.
  Future<void> muteParticipant(String identity);

  /// Host command: Asks a specific participant to turn on their camera.
  Future<void> askParticipantToStartVideo(String identity);

  /// Host command: Stops a specific participant's video.
  Future<void> stopParticipantVideo(String identity);

  /// Host command: Transfers primary host ownership to a specific participant.
  Future<void> makeParticipantHost(String identity);

  /// Host command: Designates a participant as a co-host.
  Future<void> makeParticipantCoHost(String identity);

  /// Host command: Revokes co-host status from a specific participant.
  Future<void> revokeParticipantCoHost(String identity);

  /// Whether a specific participant is currently designated as a co-host.
  bool isParticipantCoHost(String identity);

  /// Whether a specific participant is currently the primary host.
  bool isParticipantHost(String identity);

  /// Host command: Grants a specific participant permission to share their screen.
  Future<void> grantScreenShare(String identity);

  /// Host command: Revokes screen sharing permission from a specific participant.
  Future<void> revokeScreenShare(String identity);

  /// Whether a specific participant has been granted screen sharing permission.
  bool isScreenSharePermitted(String identity);

  /// Host command: Removes a participant from the meeting room.
  Future<void> removeParticipant(String identity);

  /// Host command: Ends the meeting for all participants in the room.
  Future<void> endMeetingForAll();

  /// Host command: Lowers a participant's raised hand.
  Future<void> lowerParticipantHand(String identity);

  /// Host command: Admits a participant waiting in the waiting room.
  Future<void> admitParticipant(String identity);

  /// Host command: Declines admission for a waiting participant.
  Future<void> declineParticipant(String identity);

  /// Host command: Toggles whether the room requires host approval (waiting room).
  Future<void> setWaitingRoom(bool enabled);

  // ──────────────────────────────────────────────────────────
  //  Breakout Rooms
  // ──────────────────────────────────────────────────────────

  /// Host command: Opens breakout sub-rooms and broadcasts room assignments.
  Future<void> startBreakoutRooms({
    required List<BreakoutRoom> rooms,
    int? durationMinutes,
    bool allowSelfSelect = true,
  });

  /// Host command: Closes all breakout rooms and recalls everyone to the main room.
  Future<void> closeBreakoutRooms();

  /// Participant / Host action: Switches connection into the specified breakout [room].
  Future<void> joinBreakoutRoom(BreakoutRoom room);

  /// Participant / Host action: Leaves the current breakout sub-room and reconnects to the main room.
  Future<void> returnToMainRoom();

  /// Host command: Broadcasts a text announcement across all active breakout rooms.
  Future<void> broadcastToBreakoutRooms(String message);

  /// Participant action: Alerts the host that the current breakout room needs assistance.
  Future<void> requestHostHelpInBreakout();

  /// Stream of user-facing moderation prompts (e.g. host ask-to-unmute requests).
  Stream<String> get moderationPromptsStream;

  /// Stream of arbitrary data channel messages (e.g. ALIVE Scribe transcript packets).
  Stream<Map<String, dynamic>> get dataChannelMessagesStream;

  /// Broadcasts a data channel packet to all meeting attendees.
  Future<void> sendDataChannelMessage(Map<String, dynamic> message, {bool reliable = true});

  /// Releases resources, disconnects from room, and closes streams.
  void dispose();

  // ──────────────────────────────────────────────────────────
  //  LiveKit → YouTube broadcast (server-side via Appwrite)
  // ──────────────────────────────────────────────────────────

  /// Whether the current room is being broadcast to an external platform.
  bool get isBroadcasting;

  /// Stream of broadcast status changes.
  Stream<bool> get broadcastingStream;

  /// Starts broadcasting the current room to YouTube via LiveKit egress.
  ///
  /// [meetingType] selects the broadcast room policy (e.g. 'general', 'leadership').
  /// Returns the egress ID on success.
  Future<String> startBroadcast({required String meetingType});

  /// Stops an active broadcast.
  ///
  /// [egressId] is the identifier returned by [startBroadcast].
  Future<void> stopBroadcast({required String egressId});

  /// Lists all active egress instances.
  Future<List<dynamic>> listBroadcasts();
}
