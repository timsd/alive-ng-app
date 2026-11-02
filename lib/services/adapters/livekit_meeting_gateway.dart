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
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart' as lk;

import '../../config/appwrite_backend_config.dart';
import '../../main.dart';
import '../../models/meeting_models.dart';
import '../ports/meeting_gateway.dart';
import '../role_access_service.dart';

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

  bool _isAudioMuted = true; // "Mute on Entry by Default"
  bool _isVideoMuted = false;
  bool _isScreenShareEnabled = false;
  bool _isRoomAudioLocked = false;
  bool _isHostOrModerator = false;
  bool _isWaitingRoomEnabled = false;
  bool _isAdmitted = true;
  final List<Map<String, String>> _waitingKnocks = [];
  final Map<String, bool> _handsRaised = {};

  MeetingSession _currentSession = MeetingSession.initial();

  final StreamController<MeetingSession> _sessionController =
      StreamController<MeetingSession>.broadcast();

  final StreamController<RoomStatus> _statusController =
      StreamController<RoomStatus>.broadcast();

  final StreamController<String> _moderationPromptsController =
      StreamController<String>.broadcast();

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
  Stream<String> get moderationPromptsStream =>
      _moderationPromptsController.stream;

  @override
  bool get isConnected => _room != null && _currentSession.isConnected;

  @override
  bool get isAudioMuted => _isAudioMuted;

  @override
  bool get isVideoMuted => _isVideoMuted;

  @override
  bool get isScreenShareEnabled => _isScreenShareEnabled;

  @override
  bool get isRoomAudioLocked => _isRoomAudioLocked;

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
    bool isAudioEnabled = false;
    try {
      isAudioEnabled = isLocal ? !_isAudioMuted : participant.isMicrophoneEnabled();
    } catch (_) {
      isAudioEnabled = isLocal ? !_isAudioMuted : false;
    }

    bool isVideoEnabled = false;
    try {
      isVideoEnabled = isLocal ? !_isVideoMuted : participant.isCameraEnabled();
    } catch (_) {
      isVideoEnabled = isLocal ? !_isVideoMuted : false;
    }

    bool isScreenShare = false;
    try {
      isScreenShare = isLocal ? _isScreenShareEnabled : participant.isScreenShareEnabled();
    } catch (_) {
      isScreenShare = isLocal ? _isScreenShareEnabled : false;
    }

    final identity = participant.identity;
    final isHandRaised = _handsRaised[identity] ?? false;

    return ParticipantInfo(
      identity: identity,
      name: participant.name.isNotEmpty ? participant.name : participant.identity,
      isSpeaking: participant.isSpeaking,
      isAudioEnabled: isAudioEnabled,
      isVideoEnabled: isVideoEnabled,
      isLocal: isLocal,
      isHandRaised: isHandRaised,
      isScreenShareEnabled: isScreenShare,
    );
  }

  List<ParticipantInfo> _collectParticipants() {
    final list = <ParticipantInfo>[];
    final room = _room;
    if (room == null) return list;

    try {
      final local = room.localParticipant;
      if (local != null) {
        list.add(_mapParticipant(local, isLocal: true));
      }

      for (final remote in room.remoteParticipants.values) {
        list.add(_mapParticipant(remote, isLocal: false));
      }
    } catch (e) {
      debugPrint('[LiveKitMeetingGateway] Participant collection note: $e');
    }

    return list;
  }

  void _syncStateFromRoom() {
    try {
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

      final participants = _collectParticipants();
      String? activeScreenShareName;
      for (final p in participants) {
        if (p.isScreenShareEnabled) {
          activeScreenShareName = p.name;
          break;
        }
      }

      final localId = _room?.localParticipant?.identity ?? '';
      _currentSession = _currentSession.copyWith(
        roomName: roomName,
        status: status,
        isAudioMuted: _isAudioMuted,
        isVideoMuted: _isVideoMuted,
        isScreenShareEnabled: _isScreenShareEnabled,
        activeScreenShareName: activeScreenShareName,
        isRoomAudioLocked: _isRoomAudioLocked,
        isHandRaised: _handsRaised[localId] ?? false,
        isWaitingRoomEnabled: _isWaitingRoomEnabled,
        isAdmitted: _isAdmitted,
        waitingKnocks: List<Map<String, String>>.from(_waitingKnocks),
        participants: participants,
      );
      _emitSession();
    } catch (e) {
      debugPrint('[LiveKitMeetingGateway] State sync note: $e');
    }
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
      ..on<lk.SpeakingChangedEvent>((_) => _syncStateFromRoom())
      ..on<lk.DataReceivedEvent>((event) {
        try {
          final payloadStr = utf8.decode(event.data);
          final map = jsonDecode(payloadStr);
          if (map is Map<String, dynamic>) {
            _handleControlMessage(map, sender: event.participant?.identity);
          }
        } catch (e) {
          debugPrint('[LiveKitMeetingGateway] DataReceived parse note: $e');
        }
      });
  }

  void _handleControlMessage(Map<String, dynamic> msg, {String? sender}) {
    final action = msg['action'];
    final myIdentity = _room?.localParticipant?.identity ?? '';
    final targetIdentity = msg['target_identity']?.toString();

    if (action == 'mute_all') {
      debugPrint('[LiveKitMeetingGateway] Received mute_all control message from $sender');
      if (!_isHostOrModerator && !_isAudioMuted) {
        _room?.localParticipant?.setMicrophoneEnabled(false);
        _isAudioMuted = true;
        _syncStateFromRoom();
      }
    } else if (action == 'room_audio_lock') {
      final locked = msg['locked'] == true;
      _isRoomAudioLocked = locked;
      debugPrint('[LiveKitMeetingGateway] Received room_audio_lock: $locked from $sender');
      if (locked && !_isHostOrModerator && !_isAudioMuted) {
        _room?.localParticipant?.setMicrophoneEnabled(false);
        _isAudioMuted = true;
      }
      _syncStateFromRoom();
    } else if (action == 'raise_hand') {
      final participantId = msg['participant_id']?.toString() ?? sender;
      final raised = msg['raised'] == true;
      if (participantId != null && participantId.isNotEmpty) {
        _handsRaised[participantId] = raised;
        _syncStateFromRoom();
      }
    } else if (action == 'ask_unmute') {
      if (targetIdentity == myIdentity) {
        _moderationPromptsController.add('ask_unmute');
      }
    } else if (action == 'ask_video') {
      if (targetIdentity == myIdentity) {
        _moderationPromptsController.add('ask_video');
      }
    } else if (action == 'mute_participant') {
      if (targetIdentity == myIdentity && !_isAudioMuted) {
        _room?.localParticipant?.setMicrophoneEnabled(false);
        _isAudioMuted = true;
        _syncStateFromRoom();
        _moderationPromptsController.add('muted_by_host');
      }
    } else if (action == 'stop_video') {
      if (targetIdentity == myIdentity && !_isVideoMuted) {
        _room?.localParticipant?.setCameraEnabled(false);
        _isVideoMuted = true;
        _syncStateFromRoom();
        _moderationPromptsController.add('video_stopped_by_host');
      }
    } else if (action == 'make_cohost') {
      if (targetIdentity == myIdentity) {
        _isHostOrModerator = true;
        _syncStateFromRoom();
        _moderationPromptsController.add('granted_cohost');
      }
    } else if (action == 'remove_participant') {
      if (targetIdentity == myIdentity) {
        _moderationPromptsController.add('removed_by_host');
        leaveMeeting();
      }
    } else if (action == 'end_meeting_for_all') {
      debugPrint('[LiveKitMeetingGateway] Meeting ended for all by host $sender');
      _moderationPromptsController.add('ended_by_host');
      leaveMeeting();
    } else if (action == 'lower_hand') {
      final target = targetIdentity ?? sender;
      if (target != null && target.isNotEmpty) {
        _handsRaised[target] = false;
        _syncStateFromRoom();
      }
    } else if (action == 'knock') {
      if (_isHostOrModerator) {
        final uId = msg['userId']?.toString() ?? sender ?? '';
        final uName = msg['userName']?.toString() ?? uId;
        if (uId.isNotEmpty) {
          _waitingKnocks.removeWhere((k) => k['id'] == uId);
          _waitingKnocks.add({'id': uId, 'name': uName});
          _syncStateFromRoom();
        }
      }
    } else if (action == 'admit') {
      final target = targetIdentity ?? msg['userId']?.toString();
      if (target == myIdentity) {
        _isAdmitted = true;
        _syncStateFromRoom();
        _moderationPromptsController.add('admitted_by_host');
      } else if (_isHostOrModerator) {
        _waitingKnocks.removeWhere((k) => k['id'] == target);
        _syncStateFromRoom();
      }
    } else if (action == 'decline') {
      final target = targetIdentity ?? msg['userId']?.toString();
      if (target == myIdentity) {
        _moderationPromptsController.add('declined_by_host');
        leaveMeeting();
      } else if (_isHostOrModerator) {
        _waitingKnocks.removeWhere((k) => k['id'] == target);
        _syncStateFromRoom();
      }
    } else if (action == 'toggle_waiting_room') {
      _isWaitingRoomEnabled = msg['enabled'] == true;
      _syncStateFromRoom();
    }
  }

  // ──────────────────────────────────────────────────────────
  //  MeetingGateway Actions
  // ──────────────────────────────────────────────────────────

  /// Safely executes an Appwrite function with automatic fallback to direct HTTP.
  /// This prevents crashes when Appwrite Dart SDK's Execution.fromMap fails with
  /// "Bad state: No element" due to enum variations on self-hosted Appwrite instances.
  Future<Map<String, dynamic>> _executeFunctionSafely({
    required String functionId,
    required Map<String, dynamic> body,
  }) async {
    final bodyJson = jsonEncode(body);

    // 1. Attempt standard SDK execution first
    try {
      final functions = Functions(appwriteClient);
      final execution = await functions.createExecution(
        functionId: functionId,
        body: bodyJson,
        xasync: false,
        method: appwrite_enums.ExecutionMethod.pOST,
      );

      final rawBody = execution.responseBody;
      if (rawBody.isNotEmpty) {
        final decoded = jsonDecode(rawBody);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (sdkErr) {
      debugPrint(
        '[LiveKitMeetingGateway] Functions SDK createExecution note: $sdkErr. '
        'Falling back to robust direct HTTP execution...',
      );
    }

    // 2. Direct HTTP execution fallback
    try {
      final uri = Uri.parse(
        '${appwriteClient.endPoint}/functions/$functionId/executions',
      );
      final reqHeaders = <String, String>{
        'X-Appwrite-Project': AppwriteBackendConfig.projectId,
        'content-type': 'application/json',
      };
      try {
        final jwt = await Account(appwriteClient).createJWT();
        reqHeaders['X-Appwrite-JWT'] = jwt.jwt;
      } catch (_) {}

      final client = http.Client();
      try {
        final response = await client.post(
          uri,
          headers: reqHeaders,
          body: jsonEncode({
            'body': bodyJson,
            'async': false,
            'method': 'POST',
          }),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final execMap = jsonDecode(response.body);
          if (execMap is Map<String, dynamic>) {
            final respBody = execMap['responseBody']?.toString() ?? '';
            if (respBody.isNotEmpty) {
              final decodedBody = jsonDecode(respBody);
              if (decodedBody is Map<String, dynamic>) return decodedBody;
            }
          }
        } else {
          final errorMap = jsonDecode(response.body);
          if (errorMap is Map<String, dynamic> && errorMap['message'] != null) {
            throw Exception(errorMap['message']);
          }
        }
      } finally {
        client.close();
      }
    } catch (httpErr) {
      debugPrint('[LiveKitMeetingGateway] Direct HTTP function note: $httpErr');
      if (httpErr is Exception && !httpErr.toString().contains('No element')) {
        rethrow;
      }
    }

    throw Exception('Failed to obtain meeting access credentials from server.');
  }

  @override
  Future<void> executionAndJoin({
    required String roomName,
    required String userId,
    required String userName,
    required String meetingType,
    bool notifyMembers = false,
    String? meetingTitle,
    String targetAudience = 'general',
    String? targetChapter,
    bool isWaitingRoomEnabled = false,
  }) async {
    try {
      _isHostOrModerator = RoleAccessService.instance.canAccessAdmin() ||
          RoleAccessService.instance.canStartConferencing();
      _isWaitingRoomEnabled = isWaitingRoomEnabled;
      // Host / Leader is always admitted immediately; standard attendee in a waiting room starts unadmitted
      _isAdmitted = _isHostOrModerator || !isWaitingRoomEnabled;
      _waitingKnocks.clear();

      _currentSession = _currentSession.copyWith(
        roomName: roomName,
        status: RoomStatus.connecting,
        isWaitingRoomEnabled: _isWaitingRoomEnabled,
        isAdmitted: _isAdmitted,
        waitingKnocks: [],
        error: null,
      );
      _emitSession();

      final decoded = await _executeFunctionSafely(
        functionId: AppwriteBackendConfig.createLiveKitTokenFunctionId,
        body: {
          'roomName': roomName,
          'identity': userId,
          'participantName': userName,
          'meetingType': meetingType,
          if (notifyMembers) 'notifyMembers': true,
          if (meetingTitle != null) 'meetingTitle': meetingTitle,
          'targetAudience': targetAudience,
          if (targetChapter != null) 'targetChapter': targetChapter,
          'isWaitingRoomEnabled': isWaitingRoomEnabled,
        },
      );

      if (decoded['error'] != null) {
        throw Exception(decoded['error']);
      }

      final token = decoded['token'] as String?;
      if (token == null || token.isEmpty) {
        throw Exception('Token not found in ALIVE Meet response.');
      }

      await joinMeeting(roomToken: token, roomName: roomName);

      // If this attendee is in waiting room and not yet admitted, knock on the door
      if (!_isAdmitted) {
        final local = _room?.localParticipant;
        if (local != null) {
          final knockMsg = jsonEncode({
            'action': 'knock',
            'userId': userId,
            'userName': userName,
          });
          try {
            await local.publishData(utf8.encode(knockMsg), reliable: true);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Failed executing LiveKit token function: $e');
      String errStr = e.toString().replaceAll('Exception: ', '').trim();
      if (errStr.contains('No element') || errStr.contains('Bad state')) {
        errStr =
            'ALIVE Meet connection interrupted. Please verify your internet and try again.';
      }
      _currentSession = _currentSession.copyWith(
        status: RoomStatus.disconnected,
        error: errStr,
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
        error: null,
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

      // ── MUTE ON ENTRY BY DEFAULT (Approach A from Video Architecture) ──
      // Hardware access is primed in the browser/OS, but the audio track is initialized
      // in disabled mode (audioTrack.enabled = false) to ensure a quiet, professional entry.
      try {
        await _room!.localParticipant?.setMicrophoneEnabled(false);
        _isAudioMuted = true;
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
            'LiveKit meeting connection interrupted. Please check your network and try again.';
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

    // Hard Lockout enforcement: If room audio is locked by host and user is not a host/moderator,
    // block unmuting and raise informative exception.
    if (_isRoomAudioLocked && _isAudioMuted && !_isHostOrModerator) {
      debugPrint('[LiveKitMeetingGateway] Unmute prevented: Room audio is locked by host.');
      throw Exception('Microphones are locked by the host. Raise your hand to speak.');
    }

    // Fix inverted boolean logic:
    // If currently muted (_isAudioMuted == true), enable microphone (true).
    // If currently unmuted (_isAudioMuted == false), disable microphone (false).
    final shouldEnableMicrophone = _isAudioMuted;
    try {
      await participant.setMicrophoneEnabled(shouldEnableMicrophone);
      _isAudioMuted = !shouldEnableMicrophone;
    } catch (e) {
      debugPrint('[LiveKitMeetingGateway] toggleAudio note: $e');
      if (shouldEnableMicrophone) {
        _isAudioMuted = true;
      }
      rethrow;
    }
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

    // Fix inverted boolean logic:
    // If currently muted (_isVideoMuted == true), enable camera (true).
    // If currently unmuted (_isVideoMuted == false), disable camera (false).
    final shouldEnableCamera = _isVideoMuted;
    try {
      await participant.setCameraEnabled(shouldEnableCamera);
      _isVideoMuted = !shouldEnableCamera;
    } catch (e) {
      debugPrint('[LiveKitMeetingGateway] toggleVideo note: $e');
      if (shouldEnableCamera) {
        _isVideoMuted = true;
      }
      rethrow;
    }
    _currentSession = _currentSession.copyWith(
      isVideoMuted: _isVideoMuted,
      participants: _collectParticipants(),
    );
    _emitSession();
  }

  @override
  Future<void> toggleScreenShare() async {
    final participant = _room?.localParticipant;
    if (participant == null) return;

    final shouldEnable = !_isScreenShareEnabled;
    try {
      await participant.setScreenShareEnabled(shouldEnable);
      _isScreenShareEnabled = shouldEnable;
    } catch (e) {
      debugPrint('[LiveKitMeetingGateway] toggleScreenShare note: $e');
      _isScreenShareEnabled = false;
      rethrow;
    }
    _syncStateFromRoom();
  }

  @override
  Future<void> muteAll() async {
    try {
      final payload = utf8.encode(jsonEncode({'action': 'mute_all'}));
      await _room?.localParticipant?.publishData(payload, reliable: true);
      debugPrint('[LiveKitMeetingGateway] Broadcast mute_all command dispatched');
    } catch (e) {
      debugPrint('[LiveKitMeetingGateway] muteAll error: $e');
    }
  }

  @override
  Future<void> setRoomAudioLock(bool locked) async {
    _isRoomAudioLocked = locked;
    try {
      final payload = utf8.encode(jsonEncode({
        'action': 'room_audio_lock',
        'locked': locked,
      }));
      await _room?.localParticipant?.publishData(payload, reliable: true);
      debugPrint('[LiveKitMeetingGateway] Broadcast room_audio_lock: $locked dispatched');
    } catch (e) {
      debugPrint('[LiveKitMeetingGateway] setRoomAudioLock error: $e');
    }
    _syncStateFromRoom();
  }

  @override
  Future<void> raiseHand({bool raised = true}) async {
    final identity = _room?.localParticipant?.identity ?? '';
    if (identity.isNotEmpty) {
      _handsRaised[identity] = raised;
    }
    try {
      final payload = utf8.encode(jsonEncode({
        'action': 'raise_hand',
        'participant_id': identity,
        'raised': raised,
      }));
      await _room?.localParticipant?.publishData(payload, reliable: true);
      debugPrint('[LiveKitMeetingGateway] Hand raise status: $raised for $identity');
    } catch (e) {
      debugPrint('[LiveKitMeetingGateway] raiseHand error: $e');
    }
    _syncStateFromRoom();
  }

  @override
  Future<void> askParticipantToUnmute(String identity) async {
    try {
      final payload = utf8.encode(jsonEncode({
        'action': 'ask_unmute',
        'target_identity': identity,
      }));
      await _room?.localParticipant?.publishData(payload, reliable: true);
      debugPrint('[LiveKitMeetingGateway] Ask to unmute sent to $identity');
    } catch (e) {
      debugPrint('[LiveKitMeetingGateway] askParticipantToUnmute error: $e');
    }
  }

  @override
  Future<void> muteParticipant(String identity) async {
    try {
      final payload = utf8.encode(jsonEncode({
        'action': 'mute_participant',
        'target_identity': identity,
      }));
      await _room?.localParticipant?.publishData(payload, reliable: true);
      debugPrint('[LiveKitMeetingGateway] Force mute sent to $identity');
    } catch (e) {
      debugPrint('[LiveKitMeetingGateway] muteParticipant error: $e');
    }
  }

  @override
  Future<void> askParticipantToStartVideo(String identity) async {
    try {
      final payload = utf8.encode(jsonEncode({
        'action': 'ask_video',
        'target_identity': identity,
      }));
      await _room?.localParticipant?.publishData(payload, reliable: true);
      debugPrint('[LiveKitMeetingGateway] Ask video sent to $identity');
    } catch (e) {
      debugPrint('[LiveKitMeetingGateway] askParticipantToStartVideo error: $e');
    }
  }

  @override
  Future<void> stopParticipantVideo(String identity) async {
    try {
      final payload = utf8.encode(jsonEncode({
        'action': 'stop_video',
        'target_identity': identity,
      }));
      await _room?.localParticipant?.publishData(payload, reliable: true);
      debugPrint('[LiveKitMeetingGateway] Stop video sent to $identity');
    } catch (e) {
      debugPrint('[LiveKitMeetingGateway] stopParticipantVideo error: $e');
    }
  }

  @override
  Future<void> makeParticipantCoHost(String identity) async {
    try {
      final payload = utf8.encode(jsonEncode({
        'action': 'make_cohost',
        'target_identity': identity,
      }));
      await _room?.localParticipant?.publishData(payload, reliable: true);
      debugPrint('[LiveKitMeetingGateway] Make co-host sent to $identity');
    } catch (e) {
      debugPrint('[LiveKitMeetingGateway] makeParticipantCoHost error: $e');
    }
  }

  @override
  Future<void> removeParticipant(String identity) async {
    try {
      final payload = utf8.encode(jsonEncode({
        'action': 'remove_participant',
        'target_identity': identity,
      }));
      await _room?.localParticipant?.publishData(payload, reliable: true);
      debugPrint('[LiveKitMeetingGateway] Remove participant sent to $identity');
    } catch (e) {
      debugPrint('[LiveKitMeetingGateway] removeParticipant error: $e');
    }
  }

  @override
  Future<void> endMeetingForAll() async {
    try {
      final payload = utf8.encode(jsonEncode({
        'action': 'end_meeting_for_all',
      }));
      await _room?.localParticipant?.publishData(payload, reliable: true);
      debugPrint('[LiveKitMeetingGateway] End meeting for all broadcast sent');
    } catch (e) {
      debugPrint('[LiveKitMeetingGateway] endMeetingForAll error: $e');
    }
    await leaveMeeting();
  }

  @override
  Future<void> lowerParticipantHand(String identity) async {
    _handsRaised[identity] = false;
    _syncStateFromRoom();
    try {
      final payload = utf8.encode(jsonEncode({
        'action': 'lower_hand',
        'target_identity': identity,
      }));
      await _room?.localParticipant?.publishData(payload, reliable: true);
      debugPrint('[LiveKitMeetingGateway] Lower hand sent to $identity');
    } catch (e) {
      debugPrint('[LiveKitMeetingGateway] lowerParticipantHand error: $e');
    }
  }

  @override
  Future<void> admitParticipant(String identity) async {
    _waitingKnocks.removeWhere((k) => k['id'] == identity);
    _syncStateFromRoom();
    try {
      final payload = utf8.encode(jsonEncode({
        'action': 'admit',
        'target': identity,
        'target_identity': identity,
        'userId': identity,
      }));
      await _room?.localParticipant?.publishData(payload, reliable: true);
      debugPrint('[LiveKitMeetingGateway] Admit participant broadcast sent for $identity');
    } catch (e) {
      debugPrint('[LiveKitMeetingGateway] admitParticipant error: $e');
    }
  }

  @override
  Future<void> declineParticipant(String identity) async {
    _waitingKnocks.removeWhere((k) => k['id'] == identity);
    _syncStateFromRoom();
    try {
      final payload = utf8.encode(jsonEncode({
        'action': 'decline',
        'target': identity,
        'target_identity': identity,
        'userId': identity,
      }));
      await _room?.localParticipant?.publishData(payload, reliable: true);
      debugPrint('[LiveKitMeetingGateway] Decline participant broadcast sent for $identity');
    } catch (e) {
      debugPrint('[LiveKitMeetingGateway] declineParticipant error: $e');
    }
  }

  @override
  Future<void> setWaitingRoom(bool enabled) async {
    _isWaitingRoomEnabled = enabled;
    _syncStateFromRoom();
    try {
      final payload = utf8.encode(jsonEncode({
        'action': 'toggle_waiting_room',
        'enabled': enabled,
      }));
      await _room?.localParticipant?.publishData(payload, reliable: true);
      debugPrint('[LiveKitMeetingGateway] Toggle waiting room broadcast sent: $enabled');
    } catch (e) {
      debugPrint('[LiveKitMeetingGateway] setWaitingRoom error: $e');
    }
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
      _isAudioMuted = true;
      _isVideoMuted = false;
      _isScreenShareEnabled = false;
      _isRoomAudioLocked = false;
      _isWaitingRoomEnabled = false;
      _isAdmitted = true;
      _waitingKnocks.clear();
      _handsRaised.clear();
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
      final activeRoom = _room?.name;
      final response = await _executeFunctionSafely(
        functionId: _broadcastFunctionId,
        body: {
          'action': 'start',
          'meetingType': meetingType,
          if (activeRoom != null && activeRoom.isNotEmpty) 'roomName': activeRoom,
        },
      );

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
      await _executeFunctionSafely(
        functionId: _broadcastFunctionId,
        body: {'action': 'stop', 'egressId': egressId},
      );

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
      final response = await _executeFunctionSafely(
        functionId: _broadcastFunctionId,
        body: {'action': 'list'},
      );

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
    _moderationPromptsController.close();
    _broadcastingController.close();
    super.dispose();
  }
}
