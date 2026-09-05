/// LiveKit-specific adapter implementation of [MeetingGateway].
///
/// This is the ONLY file in the entire project permitted to import
/// `package:livekit_client`. It encapsulates all LiveKit WebRTC connection
/// handling, tracks, participants, and room lifecycle events, mapping them
/// to our domain-owned [MeetingSession], [ParticipantInfo], and [RoomStatus].
library;

import 'dart:async';
import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart' as appwrite_enums;
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import '../../config/appwrite_backend_config.dart';
import '../../main.dart';
import '../../models/meeting_models.dart';
import '../ports/meeting_gateway.dart';

/// Concrete [MeetingGateway] backed by LiveKit WebRTC.
class LiveKitMeetingGateway with ChangeNotifier implements MeetingGateway {
  static const String livekitUrl = String.fromEnvironment(
    'LIVEKIT_URL',
    defaultValue: 'wss://livekit.alivenigeria.org',
  );

  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _roomListener;

  bool _isAudioMuted = false;
  bool _isVideoMuted = false;

  MeetingSession _currentSession = MeetingSession.initial();

  final StreamController<MeetingSession> _sessionController =
      StreamController<MeetingSession>.broadcast();

  final StreamController<RoomStatus> _statusController =
      StreamController<RoomStatus>.broadcast();

  LiveKitMeetingGateway() {
    _emitSession();
  }

  // ──────────────────────────────────────────────────────────
  //  MeetingGateway Getters
  // ──────────────────────────────────────────────────────────

  @override
  MeetingSession get currentSession => _currentSession;

  @override
  Stream<MeetingSession> get sessionStream => _sessionController.stream;

  @override
  Stream<RoomStatus> get roomStatus => _statusController.stream;

  @override
  bool get isConnected => _room != null && _currentSession.isConnected;

  @override
  bool get isAudioMuted => _isAudioMuted;

  @override
  bool get isVideoMuted => _isVideoMuted;

  /// Exposes the underlying room strictly for adapter-level consumers
  /// if specialized widgets need it, though UI should avoid direct usage.
  lk.Room? get rawRoom => _room;

  // ──────────────────────────────────────────────────────────
  //  Internal state updates & mappings
  // ──────────────────────────────────────────────────────────

  void _emitSession() {
    _sessionController.add(_currentSession);
    _statusController.add(_currentSession.status);
    notifyListeners();
  }

  ParticipantInfo _mapParticipant(lk.Participant participant, {bool isLocal = false}) {
    return ParticipantInfo(
      identity: participant.identity,
      name: participant.name.isNotEmpty ? participant.name : participant.identity,
      isSpeaking: participant.isSpeaking,
      isAudioEnabled: participant.isMicrophoneEnabled(),
      isVideoEnabled: participant.isCameraEnabled(),
      isLocal: isLocal,
    );
  }

  List<ParticipantInfo> _collectParticipants() {
    final list = <ParticipantInfo>[];
    final room = _room;
    if (room == null) return list;

    final local = room.localParticipant;
    if (local != null) {
      list.add(_mapParticipant(local, isLocal: true));
    }

    for (final remote in room.remoteParticipants.values) {
      list.add(_mapParticipant(remote, isLocal: false));
    }

    return list;
  }

  void _syncStateFromRoom() {
    final room = _room;
    if (room == null) {
      _currentSession = MeetingSession.initial();
      _emitSession();
      return;
    }

    RoomStatus status;
    switch (room.connectionState) {
      case lk.ConnectionState.connected:
        status = RoomStatus.connected;
        break;
      case lk.ConnectionState.connecting:
        status = RoomStatus.connecting;
        break;
      case lk.ConnectionState.reconnecting:
        status = RoomStatus.reconnecting;
        break;
      case lk.ConnectionState.disconnected:
        status = RoomStatus.disconnected;
        break;
    }

    final roomName = (room.name != null && room.name!.isNotEmpty)
        ? room.name!
        : _currentSession.roomName;

    _currentSession = _currentSession.copyWith(
      roomName: roomName,
      status: status,
      isAudioMuted: _isAudioMuted,
      isVideoMuted: _isVideoMuted,
      participants: _collectParticipants(),
    );
    _emitSession();
  }

  void _attachRoomListeners(lk.Room room) {
    _roomListener?.dispose();
    _roomListener = room.createListener();

    _roomListener!
      ..on<lk.RoomConnectedEvent>((_) => _syncStateFromRoom())
      ..on<lk.RoomDisconnectedEvent>((_) {
        _currentSession = MeetingSession.initial();
        _emitSession();
      })
      ..on<lk.RoomReconnectingEvent>((_) {
        _currentSession = _currentSession.copyWith(status: RoomStatus.reconnecting);
        _emitSession();
      })
      ..on<lk.RoomReconnectedEvent>((_) => _syncStateFromRoom())
      ..on<lk.ParticipantConnectedEvent>((_) => _syncStateFromRoom())
      ..on<lk.ParticipantDisconnectedEvent>((_) => _syncStateFromRoom())
      ..on<lk.TrackSubscribedEvent>((_) => _syncStateFromRoom())
      ..on<lk.TrackUnsubscribedEvent>((_) => _syncStateFromRoom())
      ..on<lk.TrackMutedEvent>((_) => _syncStateFromRoom())
      ..on<lk.TrackUnmutedEvent>((_) => _syncStateFromRoom())
      ..on<lk.SpeakingChangedEvent>((_) => _syncStateFromRoom());
  }

  // ──────────────────────────────────────────────────────────
  //  MeetingGateway Actions
  // ──────────────────────────────────────────────────────────

  @override
  Future<void> executionAndJoin({
    required String roomName,
    required String userId,
    required String userName,
    required String meetingType,
  }) async {
    try {
      _currentSession = _currentSession.copyWith(
        roomName: roomName,
        status: RoomStatus.connecting,
      );
      _emitSession();

      final functions = Functions(appwriteClient);
      final execution = await functions.createExecution(
        functionId: AppwriteBackendConfig.createLiveKitTokenFunctionId,
        body: jsonEncode({
          'roomName': roomName,
          'identity': userId,
          'participantName': userName,
          'meetingType': meetingType,
        }),
        xasync: false,
        method: appwrite_enums.ExecutionMethod.pOST,
      );

      final responseData =
          jsonDecode(execution.responseBody) as Map<String, dynamic>;
      final token = responseData['token'] as String?;
      if (token == null || token.isEmpty) {
        throw Exception(
          'Token not found in Appwrite Function response: '
          '${execution.responseBody}',
        );
      }

      await joinMeeting(roomToken: token, roomName: roomName);
    } catch (e) {
      debugPrint('Failed executing LiveKit token function: $e');
      _currentSession = _currentSession.copyWith(
        status: RoomStatus.disconnected,
        error: e.toString(),
      );
      _emitSession();
      rethrow;
    }
  }

  @override
  Future<void> joinMeeting({
    required String roomToken,
    String? roomName,
  }) async {
    try {
      await leaveMeeting();

      _currentSession = _currentSession.copyWith(
        roomName: roomName ?? '',
        status: RoomStatus.connecting,
      );
      _emitSession();

      final room = lk.Room(
        roomOptions: const lk.RoomOptions(
          defaultAudioPublishOptions: lk.AudioPublishOptions(),
          defaultVideoPublishOptions: lk.VideoPublishOptions(
            videoEncoding: lk.VideoEncoding(
              maxFramerate: 30,
              maxBitrate: 1500000,
            ),
          ),
        ),
      );

      _attachRoomListeners(room);

      await room.connect(
        livekitUrl,
        roomToken,
      );

      _room = room;
      await _room!.localParticipant?.setMicrophoneEnabled(true);
      await _room!.localParticipant?.setCameraEnabled(true);

      _isAudioMuted = false;
      _isVideoMuted = false;

      final finalRoomName = (room.name != null && room.name!.isNotEmpty)
          ? room.name!
          : (roomName ?? '');

      _currentSession = MeetingSession(
        roomName: finalRoomName,
        status: RoomStatus.connected,
        isAudioMuted: false,
        isVideoMuted: false,
        participants: _collectParticipants(),
      );
      _emitSession();

      debugPrint('Successfully connected to LiveKit room: $finalRoomName');
    } catch (e) {
      debugPrint('Failed to connect to LiveKit Room: $e');
      await _room?.disconnect();
      _room = null;
      _currentSession = MeetingSession(
        roomName: roomName ?? '',
        status: RoomStatus.disconnected,
        error: e.toString(),
      );
      _emitSession();
      rethrow;
    }
  }

  @override
  Future<void> toggleAudio() async {
    final participant = _room?.localParticipant;
    if (participant == null) return;

    _isAudioMuted = !_isAudioMuted;
    await participant.setMicrophoneEnabled(!_isAudioMuted);
    _currentSession = _currentSession.copyWith(
      isAudioMuted: _isAudioMuted,
      participants: _collectParticipants(),
    );
    _emitSession();
  }

  @override
  Future<void> toggleVideo() async {
    final participant = _room?.localParticipant;
    if (participant == null) return;

    _isVideoMuted = !_isVideoMuted;
    await participant.setCameraEnabled(!_isVideoMuted);
    _currentSession = _currentSession.copyWith(
      isVideoMuted: _isVideoMuted,
      participants: _collectParticipants(),
    );
    _emitSession();
  }

  @override
  Future<void> leaveMeeting() async {
    final room = _room;
    if (room == null) return;

    try {
      _roomListener?.dispose();
      _roomListener = null;
      await room.disconnect();
      debugPrint('Disconnected from LiveKit meeting room safely.');
    } catch (e) {
      debugPrint('Error leaving meeting: $e');
    } finally {
      _room = null;
      _isAudioMuted = false;
      _isVideoMuted = false;
      _currentSession = MeetingSession.initial();
      _emitSession();
    }
  }

  @override
  void dispose() {
    _roomListener?.dispose();
    _roomListener = null;
    _room?.disconnect();
    _room = null;
    _sessionController.close();
    _statusController.close();
    super.dispose();
  }
}
