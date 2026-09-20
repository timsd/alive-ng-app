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

import '../../models/meeting_models.dart';

/// Abstract gateway representing video/audio conferencing capabilities.
abstract class MeetingGateway {
  /// Current snapshot of the meeting session.
  MeetingSession get currentSession;

  /// Stream of meeting session state changes.
  Stream<MeetingSession> get sessionStream;

  /// Stream of room connection status changes.
  Stream<RoomStatus> get roomStatus;

  /// Whether the client is currently connected to an active room.
  bool get isConnected;

  /// Whether the local microphone is currently muted.
  bool get isAudioMuted;

  /// Whether the local video camera is currently muted / disabled.
  bool get isVideoMuted;

  /// Requests a token from the backend for [roomName] and joins the meeting room.
  Future<void> executionAndJoin({
    required String roomName,
    required String userId,
    required String userName,
    required String meetingType,
    bool notifyMembers = false,
    String? meetingTitle,
  });

  /// Joins a meeting room directly using a pre-fetched [roomToken].
  Future<void> joinMeeting({
    required String roomToken,
    String? roomName,
  });

  /// Mutes or unmutes the local participant's microphone.
  Future<void> toggleAudio();

  /// Enables or disables the local participant's video camera.
  Future<void> toggleVideo();

  /// Leaves the current meeting room and resets local media state.
  Future<void> leaveMeeting();

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
