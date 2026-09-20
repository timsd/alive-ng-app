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

/// Appwrite Function ID for the LiveKit broadcast backend.
const String _broadcastFunctionId = 'start_livekit_broadcast';

/// Concrete [MeetingGateway] backed by LiveKit WebRTC.
class LiveKitMeetingGateway with ChangeNotifier implements MeetingGateway {
  static const String livekitUrl = String.fromEnvironment(
    'LIVEKIT_URL',
    defaultValue: 'wss://livekit.alivenigeria.org',
  );

  /// Connection timeout duration
  static const Duration _connectionTimeout = Duration(seconds: 30);

  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _roomListener;

  bool _isAudioMuted = false;
  bool _isVideoMuted = false;

  MeetingSession _currentSession = MeetingSession.initial();

  final StreamController<MeetingSession> _sessionController =
      StreamController<MeetingSession>.broadcast();

  final StreamController<RoomStatus> _statusController =
      StreamController<RoomStatus>.broadcast();

  // ── Broadcast state ──────────────────────────────────────────
  bool _isBroadcasting = false;
  String? _activeEgressId;
  final StreamController<bool> _broadcastingController =
      StreamController<bool>.broadcast();

  LiveKitMeetingGateway() {
    _emitSession();
  }

  // ──────────────────────────────────────────────────────────
  //  MeetingGateway Getters
  // ──────────────────────────────────────────────────────────

  @override
  MeetingSession get currentSession => _currentSession;

  String? get activeEgressId => _activeEgressId;

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
  //  Broadcast getters
  // ──────────────────────────────────────────────────────────

  @override
  bool get isBroadcasting => _isBroadcasting;

  @override
  Stream<bool> get broadcastingStream => _broadcastingController.stream;

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
    bool notifyMembers = false,
    String? meetingTitle,
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
          if (notifyMembers) 'notifyMembers': true,
          if (meetingTitle != null) 'meetingTitle': meetingTitle,
        }),
        xasync: false,
        method: appwrite_enums.ExecutionMethod.pOST,
      );

      dynamic decoded;
      try {
        decoded = jsonDecode(execution.responseBody);
      } catch (_) {
        throw Exception(
          'Invalid response from server (${execution.responseStatusCode}): '
          '${execution.responseBody}',
        );
      }

      if (decoded is Map<String, dynamic> && decoded['error'] != null) {
        throw Exception(decoded['error']);
      }

      final token = (decoded is Map<String, dynamic>)
          ? decoded['token'] as String?
          : null;
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
          // Enable adaptive stream for better connection quality
          adaptiveStream: true,
          // Enable dynacast for better bandwidth management
          dynacast: true,
        ),
      );

      _attachRoomListeners(room);

      // Connect with timeout
      await room.connect(
        livekitUrl,
        roomToken,
      ).timeout(
        _connectionTimeout,
        onTimeout: () {
          throw TimeoutException(
            'Connection to LiveKit timed out after ${_connectionTimeout.inSeconds} seconds. '
            'Please check your internet connection and try again.',
            _connectionTimeout,
          );
        },
      );

      _room = room;

      // Enable microphone defensively so hardware/permission absence does not abort meeting join
      try {
        await _room!.localParticipant?.setMicrophoneEnabled(true);
        _isAudioMuted = false;
      } catch (audioErr) {
        debugPrint('Microphone unavailable or permission denied: $audioErr');
        _isAudioMuted = true;
      }

      // Enable camera defensively so hardware/permission absence does not abort meeting join
      try {
        await _room!.localParticipant?.setCameraEnabled(true);
        _isVideoMuted = false;
      } catch (videoErr) {
        debugPrint('Camera unavailable or permission denied: $videoErr');
        _isVideoMuted = true;
      }

      final finalRoomName = (room.name != null && room.name!.isNotEmpty)
          ? room.name!
          : (roomName ?? '');

      _currentSession = MeetingSession(
        roomName: finalRoomName,
        status: RoomStatus.connected,
        isAudioMuted: _isAudioMuted,
        isVideoMuted: _isVideoMuted,
        participants: _collectParticipants(),
      );
      _emitSession();

      debugPrint('Successfully connected to LiveKit room: $finalRoomName');
    } catch (e) {
      debugPrint('Failed to connect to LiveKit Room: $e');
      await _room?.disconnect();
      _room = null;

      // Provide user-friendly error messages
      String errorMessage = e.toString();
      if (e.toString().contains('certificate') ||
          e.toString().contains('SSL') ||
          e.toString().contains('TLS')) {
        errorMessage =
            'SSL certificate error. Please ensure the LiveKit server has a valid SSL certificate.';
      } else if (e.toString().contains('timeout') ||
          e.toString().contains('TimeoutException')) {
        errorMessage =
            'Connection timed out. Please check your internet connection and try again.';
      } else if (e.toString().contains('WebSocket') ||
          e.toString().contains('connection')) {
        errorMessage =
            'Could not connect to LiveKit server. Please check your connection and try again.';
      } else if (e.toString().contains('No element') ||
          e.toString().contains('Bad state')) {
        errorMessage =
            'Audio/video device not detected. Please verify your camera and microphone connections.';
      }

      _currentSession = MeetingSession(
        roomName: roomName ?? '',
        status: RoomStatus.disconnected,
        error: errorMessage,
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

  // ──────────────────────────────────────────────────────────
  //  Broadcast implementations (server-side via Appwrite)
  // ──────────────────────────────────────────────────────────

  void _updateBroadcastState(bool broadcasting, {String? egressId}) {
    _isBroadcasting = broadcasting;
    _activeEgressId = egressId;
    _broadcastingController.add(broadcasting);
    notifyListeners();
  }

  @override
  Future<String> startBroadcast({required String meetingType}) async {
    try {
      final functions = Functions(appwriteClient);
      final result = await functions.createExecution(
        functionId: _broadcastFunctionId,
        body: jsonEncode({'action': 'start', 'meetingType': meetingType}),
        xasync: false,
      );

      if (result.responseStatusCode != 200) {
        throw Exception('Broadcast failed (${result.responseStatusCode}): ${result.responseBody}');
      }

      final response = jsonDecode(result.responseBody);
      if (response['error'] != null) {
        throw Exception(response['error']);
      }

      final egressId = response['egressId'] as String?;
      if (egressId == null) {
        throw Exception('No egressId returned from broadcast function.');
      }

      _updateBroadcastState(true, egressId: egressId);
      debugPrint('Broadcast started: egressId=$egressId, room=${response['roomName']}');
      return egressId;
    } catch (e) {
      debugPrint('Failed to start broadcast: $e');
      rethrow;
    }
  }

  @override
  Future<void> stopBroadcast({required String egressId}) async {
    try {
      final functions = Functions(appwriteClient);
      final result = await functions.createExecution(
        functionId: _broadcastFunctionId,
        body: jsonEncode({'action': 'stop', 'egressId': egressId}),
        xasync: false,
      );

      if (result.responseStatusCode != 200) {
        throw Exception('Stop broadcast failed (${result.responseStatusCode}): ${result.responseBody}');
      }

      _updateBroadcastState(false);
      debugPrint('Broadcast stopped: egressId=$egressId');
    } catch (e) {
      debugPrint('Failed to stop broadcast: $e');
      rethrow;
    }
  }

  @override
  Future<List<dynamic>> listBroadcasts() async {
    try {
      final functions = Functions(appwriteClient);
      final result = await functions.createExecution(
        functionId: _broadcastFunctionId,
        body: jsonEncode({'action': 'list'}),
        xasync: false,
      );

      if (result.responseStatusCode != 200) {
        throw Exception('List broadcasts failed (${result.responseStatusCode}): ${result.responseBody}');
      }

      final response = jsonDecode(result.responseBody);
      return (response['egresses'] as List?) ?? [];
    } catch (e) {
      debugPrint('Failed to list broadcasts: $e');
      rethrow;
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
    _broadcastingController.close();
    super.dispose();
  }
}
