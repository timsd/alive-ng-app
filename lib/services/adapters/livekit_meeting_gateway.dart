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
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
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
  bool _isScreenSharePermitted = false;
  final Set<String> _screenSharePermittedIdentities = {};
  String? _hostIdentity;
  final Set<String> _coHostIdentities = {};
  bool _isRoomAudioLocked = false;
  bool _isHostOrModerator = false;
  bool _isWaitingRoomEnabled = false;
  bool _isAdmitted = true;
  final List<Map<String, String>> _waitingKnocks = [];
  final Map<String, bool> _handsRaised = {};

  // ── Breakout room state ──────────────────────────────────────
  bool _isBreakoutActive = false;
  List<BreakoutRoom> _breakoutRooms = [];
  String? _mainRoomName;
  String? _activeBreakoutRoomId;
  String? _activeBreakoutRoomName;
  bool _allowBreakoutSelfSelect = true;
  DateTime? _breakoutEndsAt;
  String? _breakoutBroadcastMessage;
  Timer? _breakoutTimer;
  bool _isSwitchingBreakoutRoom = false;

  String _lastUserId = '';
  String _lastUserName = '';
  String _lastMeetingType = 'general';

  MeetingSession _currentSession = MeetingSession.initial();

  final StreamController<MeetingSession> _sessionController =
      StreamController<MeetingSession>.broadcast();

  final StreamController<RoomStatus> _statusController =
      StreamController<RoomStatus>.broadcast();

  final StreamController<String> _moderationPromptsController =
      StreamController<String>.broadcast();

  final StreamController<Map<String, dynamic>> _dataChannelMessagesController =
      StreamController<Map<String, dynamic>>.broadcast();

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
  Stream<Map<String, dynamic>> get dataChannelMessagesStream =>
      _dataChannelMessagesController.stream;

  @override
  Future<void> sendDataChannelMessage(Map<String, dynamic> message,
      {bool reliable = true}) async {
    final bytes = utf8.encode(jsonEncode(message));
    await _room?.localParticipant?.publishData(bytes, reliable: reliable);
  }

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

  @override
  Widget? buildParticipantVideoWidget(String identity, {bool mirror = false}) {
    final room = _room;
    if (room == null) return null;

    lk.Participant? participant;
    if (room.localParticipant?.identity == identity) {
      participant = room.localParticipant;
    } else {
      participant = room.remoteParticipants.values
          .firstWhereOrNull((p) => p.identity == identity);
    }

    if (participant == null) return null;

    final pub = participant.videoTrackPublications.firstWhereOrNull(
      (p) => p.source == lk.TrackSource.camera && p.track != null && !p.muted,
    );

    final track = pub?.track;
    if (track is! lk.VideoTrack) return null;

    final isLocal = participant is lk.LocalParticipant ||
        participant == room.localParticipant;

    return lk.VideoTrackRenderer(
      track,
      fit: lk.VideoViewFit.cover,
      mirrorMode: mirror
          ? lk.VideoViewMirrorMode.mirror
          : (isLocal
              ? lk.VideoViewMirrorMode.mirror
              : lk.VideoViewMirrorMode.off),
    );
  }

  @override
  Widget? buildScreenShareVideoWidget() {
    final room = _room;
    if (room == null) return null;

    // Check local participant first
    final localPub = room.localParticipant?.videoTrackPublications
        .firstWhereOrNull(
      (p) =>
          p.source == lk.TrackSource.screenShareVideo &&
          p.track != null &&
          !p.muted,
    );
    if (localPub?.track is lk.VideoTrack) {
      return lk.VideoTrackRenderer(
        localPub!.track as lk.VideoTrack,
        fit: lk.VideoViewFit.contain,
        mirrorMode: lk.VideoViewMirrorMode.off,
      );
    }

    // Check remote participants
    for (final remote in room.remoteParticipants.values) {
      final remotePub = remote.videoTrackPublications.firstWhereOrNull(
        (p) =>
            p.source == lk.TrackSource.screenShareVideo &&
            p.track != null &&
            !p.muted,
      );
      if (remotePub?.track is lk.VideoTrack) {
        return lk.VideoTrackRenderer(
          remotePub!.track as lk.VideoTrack,
          fit: lk.VideoViewFit.contain,
          mirrorMode: lk.VideoViewMirrorMode.off,
        );
      }
    }

    return null;
  }

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

      final waitingIds = _waitingKnocks.map((k) => k['id']).toSet();
      for (final remote in room.remoteParticipants.values) {
        if (waitingIds.contains(remote.identity)) continue;
        // Filter out ephemeral cross-room relay bots
        if (remote.identity.contains('_relay_')) continue;
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
        if (!_isSwitchingBreakoutRoom) {
          _currentSession = MeetingSession.initial();
          _emitSession();
        }
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
      _currentSession = MeetingSession(
        roomName: roomName,
        status: status,
        isAudioMuted: _isAudioMuted,
        isVideoMuted: _isVideoMuted,
        isScreenShareEnabled: _isScreenShareEnabled,
        isScreenSharePermitted: _isScreenSharePermitted,
        activeScreenShareName: activeScreenShareName,
        isRoomAudioLocked: _isRoomAudioLocked,
        isHandRaised: _handsRaised[localId] ?? false,
        isWaitingRoomEnabled: _isWaitingRoomEnabled,
        isAdmitted: _isAdmitted,
        waitingKnocks: List<Map<String, String>>.from(_waitingKnocks),
        isBreakoutActive: _isBreakoutActive,
        breakoutRooms: List<BreakoutRoom>.from(_breakoutRooms),
        mainRoomName: _mainRoomName,
        activeBreakoutRoomId: _activeBreakoutRoomId,
        activeBreakoutRoomName: _activeBreakoutRoomName,
        allowBreakoutSelfSelect: _allowBreakoutSelfSelect,
        breakoutEndsAt: _breakoutEndsAt,
        breakoutBroadcastMessage: _breakoutBroadcastMessage,
        participants: participants,
        error: _currentSession.error,
      );
      _emitSession();
    } catch (e) {
      debugPrint('[LiveKitMeetingGateway] State sync note: $e');
    }
  }

  Map<String, dynamic> _buildRoomStatePayload() {
    return {
      'action': 'room_state',
      'isWaitingRoomEnabled': _isWaitingRoomEnabled,
      'isRoomAudioLocked': _isRoomAudioLocked,
      'isBreakoutActive': _isBreakoutActive,
      'breakoutRooms': _breakoutRooms.map((r) => r.toJson()).toList(),
      'mainRoomName': _mainRoomName,
      'allowBreakoutSelfSelect': _allowBreakoutSelfSelect,
      'breakoutEndsAt': _breakoutEndsAt?.toIso8601String(),
      'breakoutBroadcastMessage': _breakoutBroadcastMessage,
    };
  }

  void _attachRoomListeners(lk.Room room) {
    _roomListener?.dispose();
    _roomListener = room.createListener();

    _roomListener!
      ..on<lk.RoomConnectedEvent>((_) async {
        try {
          await room.startAudio();
          await room.setSpeakerOn(true);
        } catch (_) {}
        final myId = _room?.localParticipant?.identity ?? '';
        if (!_isHostOrModerator && myId.isNotEmpty) {
          try {
            final queryPayload = utf8.encode(jsonEncode({
              'action': 'query_room_state',
              'userId': myId,
              'userName': _room?.localParticipant?.name ?? myId,
            }));
            await room.localParticipant?.publishData(queryPayload, reliable: true);
          } catch (_) {}
        }
        _syncStateFromRoom();
      })
      ..on<lk.RoomDisconnectedEvent>((_) {
        if (!_isSwitchingBreakoutRoom) {
          _currentSession = MeetingSession.initial();
          _emitSession();
        }
      })
      ..on<lk.RoomReconnectingEvent>((_) {
        _currentSession = _currentSession.copyWith(status: RoomStatus.reconnecting);
        _emitSession();
      })
      ..on<lk.RoomReconnectedEvent>((_) async {
        try {
          await room.startAudio();
          await room.setSpeakerOn(true);
        } catch (_) {}
        _syncStateFromRoom();
      })
      ..on<lk.ParticipantConnectedEvent>((event) {
        if (event.participant.identity.contains('_relay_')) return;
        if (_isHostOrModerator) {
          // Immediately inform the new participant of the current room policies (Waiting room, locked mics, breakout rooms)
          try {
            final statePayload = utf8.encode(jsonEncode(_buildRoomStatePayload()));
            _room?.localParticipant?.publishData(statePayload, reliable: true);
          } catch (_) {}
        }
        _syncStateFromRoom();
      })
      ..on<lk.ParticipantDisconnectedEvent>((event) {
        if (event.participant.identity.contains('_relay_')) return;
        _waitingKnocks.removeWhere((k) => k['id'] == event.participant.identity);
        _syncStateFromRoom();
      })
      ..on<lk.TrackSubscribedEvent>((event) async {
        try {
          if (event.track is lk.AudioTrack) {
            await room.startAudio();
            await room.setSpeakerOn(true);
          }
        } catch (_) {}
        _syncStateFromRoom();
      })
      ..on<lk.TrackUnsubscribedEvent>((_) => _syncStateFromRoom())
      ..on<lk.TrackMutedEvent>((_) => _syncStateFromRoom())
      ..on<lk.TrackUnmutedEvent>((event) async {
        try {
          if (event.publication.track is lk.AudioTrack) {
            await room.startAudio();
            await room.setSpeakerOn(true);
          }
        } catch (_) {}
        _syncStateFromRoom();
      })
      ..on<lk.AudioPlaybackStatusChanged>((event) {
        debugPrint('[LiveKitMeetingGateway] AudioPlaybackStatusChanged: isPlaying=${event.isPlaying}');
      })
      ..on<lk.SpeakingChangedEvent>((_) => _syncStateFromRoom())
      ..on<lk.DataReceivedEvent>((event) {
        try {
          final payloadStr = utf8.decode(event.data);
          final map = jsonDecode(payloadStr);
          if (map is Map<String, dynamic>) {
            _handleControlMessage(map, sender: event.participant?.identity);
            if (!_dataChannelMessagesController.isClosed) {
              _dataChannelMessagesController.add(map);
            }
          }
        } catch (e) {
          debugPrint('[LiveKitMeetingGateway] DataReceived parse note: $e');
        }
      });
  }

  void _scheduleBreakoutTimer() {
    _breakoutTimer?.cancel();
    final endsAt = _breakoutEndsAt;
    if (!_isBreakoutActive || endsAt == null) return;

    final remaining = endsAt.difference(DateTime.now().toUtc());
    if (remaining.isNegative || remaining.inSeconds <= 0) {
      if (_isHostOrModerator) {
        closeBreakoutRooms();
      } else if (_activeBreakoutRoomId != null && _activeBreakoutRoomId!.isNotEmpty) {
        returnToMainRoom();
      }
      return;
    }

    _breakoutTimer = Timer(remaining, () {
      if (_isHostOrModerator) {
        closeBreakoutRooms();
      } else if (_activeBreakoutRoomId != null && _activeBreakoutRoomId!.isNotEmpty) {
        _moderationPromptsController.add('breakout_closed');
        returnToMainRoom();
      }
    });
  }

  void _handleControlMessage(Map<String, dynamic> msg, {String? sender}) {
    final action = msg['action'];
    final myIdentity = _room?.localParticipant?.identity ?? _lastUserId;
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
    } else if (action == 'make_host') {
      if (targetIdentity != null && targetIdentity.isNotEmpty) {
        _hostIdentity = targetIdentity;
      }
      final prevHost = msg['previous_host']?.toString();
      if (targetIdentity == myIdentity) {
        _isHostOrModerator = true;
        _syncStateFromRoom();
        _moderationPromptsController.add('granted_host');
      } else if (prevHost == myIdentity) {
        _moderationPromptsController.add('transferred_host');
      }
    } else if (action == 'make_cohost') {
      if (targetIdentity != null && targetIdentity.isNotEmpty) {
        _coHostIdentities.add(targetIdentity);
      }
      if (targetIdentity == myIdentity) {
        _isHostOrModerator = true;
        _syncStateFromRoom();
        _moderationPromptsController.add('granted_cohost');
      }
    } else if (action == 'revoke_cohost') {
      if (targetIdentity != null && targetIdentity.isNotEmpty) {
        _coHostIdentities.remove(targetIdentity);
      }
      if (targetIdentity == myIdentity) {
        _syncStateFromRoom();
        _moderationPromptsController.add('revoked_cohost');
      }
    } else if (action == 'grant_screenshare') {
      if (targetIdentity != null && targetIdentity.isNotEmpty) {
        _screenSharePermittedIdentities.add(targetIdentity);
      }
      if (targetIdentity == myIdentity) {
        _isScreenSharePermitted = true;
        _syncStateFromRoom();
        _moderationPromptsController.add('granted_screenshare');
      }
    } else if (action == 'revoke_screenshare') {
      if (targetIdentity != null && targetIdentity.isNotEmpty) {
        _screenSharePermittedIdentities.remove(targetIdentity);
      }
      if (targetIdentity == myIdentity) {
        _isScreenSharePermitted = false;
        if (_isScreenShareEnabled) {
          toggleScreenShare();
        }
        _syncStateFromRoom();
        _moderationPromptsController.add('revoked_screenshare');
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
    } else if (action == 'query_room_state') {
      if (_isHostOrModerator) {
        final resp = utf8.encode(jsonEncode(_buildRoomStatePayload()));
        try {
          _room?.localParticipant?.publishData(resp, reliable: true);
        } catch (_) {}
      }
    } else if (action == 'room_state' || action == 'toggle_waiting_room') {
      final waitingEnabled = action == 'toggle_waiting_room'
          ? (msg['enabled'] == true)
          : (msg['isWaitingRoomEnabled'] == true);
      _isWaitingRoomEnabled = waitingEnabled;
      if (action == 'room_state') {
        if (msg['isRoomAudioLocked'] == true) {
          _isRoomAudioLocked = true;
        }
        if (msg['isBreakoutActive'] == true) {
          _isBreakoutActive = true;
          final rawRooms = msg['breakoutRooms'];
          if (rawRooms is List) {
            _breakoutRooms = rawRooms
                .whereType<Map>()
                .map((m) => BreakoutRoom.fromJson(Map<String, dynamic>.from(m)))
                .toList();
          }
          _mainRoomName = msg['mainRoomName']?.toString() ?? _mainRoomName;
          _allowBreakoutSelfSelect = msg['allowBreakoutSelfSelect'] != false;
          final endsAtRaw = msg['breakoutEndsAt']?.toString();
          _breakoutEndsAt = (endsAtRaw != null && endsAtRaw.isNotEmpty)
              ? DateTime.tryParse(endsAtRaw)
              : null;
          _breakoutBroadcastMessage = msg['breakoutBroadcastMessage']?.toString();
          _scheduleBreakoutTimer();
        }
      }
      if (!_isHostOrModerator && waitingEnabled && !_isAdmitted) {
        _room?.localParticipant?.setMicrophoneEnabled(false);
        _room?.localParticipant?.setCameraEnabled(false);
        _isAudioMuted = true;
        _isVideoMuted = true;
        final knockPayload = utf8.encode(jsonEncode({
          'action': 'knock',
          'userId': myIdentity,
          'userName': _room?.localParticipant?.name ?? myIdentity,
        }));
        try {
          _room?.localParticipant?.publishData(knockPayload, reliable: true);
        } catch (_) {}
      }
      _syncStateFromRoom();
    } else if (action == 'breakout_start') {
      final rawRooms = msg['rooms'];
      if (rawRooms is List) {
        _breakoutRooms = rawRooms
            .whereType<Map>()
            .map((m) => BreakoutRoom.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      }
      _isBreakoutActive = true;
      _mainRoomName = msg['mainRoomName']?.toString() ??
          _mainRoomName ??
          _currentSession.roomName;
      _allowBreakoutSelfSelect = msg['allowSelfSelect'] != false;
      final endsAtStr = msg['endsAt']?.toString();
      _breakoutEndsAt = (endsAtStr != null && endsAtStr.isNotEmpty)
          ? DateTime.tryParse(endsAtStr)
          : null;
      _breakoutBroadcastMessage = null;
      _scheduleBreakoutTimer();
      _syncStateFromRoom();

      // Check if local user is assigned to a specific breakout room
      final assignedRoom = _breakoutRooms.firstWhereOrNull(
        (r) => r.assignedParticipantIds.contains(myIdentity),
      );
      if (assignedRoom != null && !_isHostOrModerator) {
        _moderationPromptsController
            .add('breakout_assigned:${assignedRoom.id}|${assignedRoom.name}');
      } else {
        _moderationPromptsController.add('breakout_started');
      }
    } else if (action == 'breakout_close') {
      _breakoutTimer?.cancel();
      _isBreakoutActive = false;
      _breakoutRooms = [];
      _breakoutEndsAt = null;
      _breakoutBroadcastMessage = null;
      _moderationPromptsController.add('breakout_closed');
      if (_activeBreakoutRoomId != null && _activeBreakoutRoomId!.isNotEmpty) {
        returnToMainRoom();
      } else {
        _syncStateFromRoom();
      }
    } else if (action == 'breakout_broadcast') {
      final text = msg['message']?.toString() ?? '';
      if (text.isNotEmpty) {
        _breakoutBroadcastMessage = text;
        _syncStateFromRoom();
        _moderationPromptsController.add('breakout_broadcast:$text');
      }
    } else if (action == 'breakout_help') {
      if (_isHostOrModerator) {
        final roomId = msg['roomId']?.toString() ?? '';
        final roomName = msg['roomName']?.toString() ?? 'Breakout Room';
        final userName = msg['userName']?.toString() ?? sender ?? 'Participant';
        _moderationPromptsController
            .add('breakout_help:$roomId|$roomName|$userName');
      }
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
      _lastUserId = userId;
      _lastUserName = userName;
      _lastMeetingType = meetingType;
      if (!roomName.contains('--br-')) {
        _mainRoomName = roomName;
      }

      _isHostOrModerator = RoleAccessService.instance.canAccessAdmin() ||
          RoleAccessService.instance.canStartConferencing();
      _isWaitingRoomEnabled = isWaitingRoomEnabled;
      // Host / Leader is always admitted immediately; standard attendee in a waiting room starts unadmitted
      _isAdmitted = _isHostOrModerator || !isWaitingRoomEnabled || roomName.contains('--br-');
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

  /// Disconnects only the underlying LiveKit room without wiping breakout session metadata.
  Future<void> _disconnectRoomInstanceOnly() async {
    final room = _room;
    if (room == null) return;
    try {
      _roomListener?.dispose();
      _roomListener = null;
      await room.disconnect();
    } catch (e) {
      debugPrint('[LiveKitMeetingGateway] _disconnectRoomInstanceOnly note: $e');
    } finally {
      _room = null;
      _isScreenShareEnabled = false;
      _handsRaised.clear();
    }
  }

  @override
  Future<void> joinMeeting({
    required String roomToken,
    String? roomName,
  }) async {
    try {
      if (_isSwitchingBreakoutRoom) {
        await _disconnectRoomInstanceOnly();
      } else {
        await leaveMeeting();
      }

      _currentSession = _currentSession.copyWith(
        roomName: roomName ?? '',
        status: RoomStatus.connecting,
        error: null,
      );
      _emitSession();

      final room = lk.Room(
        roomOptions: const lk.RoomOptions(
          defaultAudioPublishOptions: lk.AudioPublishOptions(
            dtx: true,
          ),
          defaultAudioCaptureOptions: lk.AudioCaptureOptions(
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
            highPassFilter: true,
          ),
          defaultVideoPublishOptions: lk.VideoPublishOptions(
            videoEncoding: lk.VideoEncoding(
              maxFramerate: 30,
              maxBitrate: 1500000,
            ),
          ),
          defaultScreenShareCaptureOptions: lk.ScreenShareCaptureOptions(
            captureScreenAudio: true,
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

      // Prime audio playback & speaker routing immediately on connection
      try {
        await room.startAudio();
        await room.setSpeakerOn(true);
      } catch (audioInitErr) {
        debugPrint('[LiveKitMeetingGateway] Audio prime note: $audioInitErr');
      }

      // ── MUTE ON ENTRY BY DEFAULT (Approach A from Video Architecture) ──
      // Hardware access is primed in the browser/OS, but the audio track is initialized
      // in disabled mode (audioTrack.enabled = false) to ensure a quiet, professional entry.
      try {
        await _room!.localParticipant?.setMicrophoneEnabled(
          false,
          audioCaptureOptions: const lk.AudioCaptureOptions(
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
            highPassFilter: true,
          ),
        );
        _isAudioMuted = true;
      } catch (audioErr) {
        debugPrint('Microphone unavailable or permission denied: $audioErr');
        _isAudioMuted = true;
      }

      // Enable camera only if participant is already admitted to the call
      if (_isAdmitted) {
        try {
          await _room!.localParticipant?.setCameraEnabled(true);
          _isVideoMuted = false;
        } catch (videoErr) {
          debugPrint('Camera unavailable or permission denied: $videoErr');
          _isVideoMuted = true;
        }
      } else {
        try {
          await _room!.localParticipant?.setCameraEnabled(false);
        } catch (_) {}
        _isVideoMuted = true;
      }

      final finalRoomName = (room.name != null && room.name!.isNotEmpty)
          ? room.name!
          : (roomName ?? '');

      if (!finalRoomName.contains('--br-') && (_mainRoomName == null || _mainRoomName!.isEmpty)) {
        _mainRoomName = finalRoomName;
      }

      _currentSession = MeetingSession(
        roomName: finalRoomName,
        status: RoomStatus.connected,
        isAudioMuted: _isAudioMuted,
        isVideoMuted: _isVideoMuted,
        isRoomAudioLocked: _isRoomAudioLocked,
        isWaitingRoomEnabled: _isWaitingRoomEnabled,
        isAdmitted: _isAdmitted,
        isBreakoutActive: _isBreakoutActive,
        breakoutRooms: List<BreakoutRoom>.from(_breakoutRooms),
        mainRoomName: _mainRoomName,
        activeBreakoutRoomId: _activeBreakoutRoomId,
        activeBreakoutRoomName: _activeBreakoutRoomName,
        allowBreakoutSelfSelect: _allowBreakoutSelfSelect,
        breakoutEndsAt: _breakoutEndsAt,
        breakoutBroadcastMessage: _breakoutBroadcastMessage,
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
  Future<void> unlockAudio() async {
    try {
      await _room?.startAudio();
      await _room?.setSpeakerOn(true);
    } catch (e) {
      debugPrint('[LiveKitMeetingGateway] unlockAudio error: $e');
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
      // Ensure audio context is running and speakerphone routing is enabled
      try {
        await _room?.startAudio();
        await _room?.setSpeakerOn(true);
      } catch (_) {}

      await participant.setMicrophoneEnabled(
        shouldEnableMicrophone,
        audioCaptureOptions: const lk.AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
          highPassFilter: true,
        ),
      );
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
      // Standard conferencing: stream screen video AND computer/tab audio together
      await participant.setScreenShareEnabled(
        shouldEnable,
        captureScreenAudio: true,
        screenShareCaptureOptions: const lk.ScreenShareCaptureOptions(
          captureScreenAudio: true,
        ),
      );
      _isScreenShareEnabled = shouldEnable;
    } catch (e) {
      debugPrint('[LiveKitMeetingGateway] toggleScreenShare with audio note: $e');
      if (shouldEnable) {
        // Fallback: If browser/platform denies screen audio capture, continue with video share
        try {
          await participant.setScreenShareEnabled(shouldEnable);
          _isScreenShareEnabled = true;
        } catch (innerErr) {
          _isScreenShareEnabled = false;
          final errStr = innerErr.toString();
          if (errStr.contains('Screen sharing is not supported') ||
              errStr.contains('not supported on mobile devices')) {
            throw Exception(
              'Screen sharing on mobile web browsers is restricted by iOS Safari and Android Chrome. To share your screen, please use the installed ALIVE mobile app or join from a desktop browser.',
            );
          }
          rethrow;
        }
      } else {
        _isScreenShareEnabled = false;
      }
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
  bool isParticipantCoHost(String identity) =>
      _coHostIdentities.contains(identity);

  @override
  bool isParticipantHost(String identity) =>
      _hostIdentity == identity;

  @override
  Future<void> makeParticipantHost(String identity) async {
    try {
      final myId = _room?.localParticipant?.identity ?? '';
      _hostIdentity = identity;
      final payload = utf8.encode(jsonEncode({
        'action': 'make_host',
        'target_identity': identity,
        'previous_host': myId,
      }));
      await _room?.localParticipant?.publishData(payload, reliable: true);
      debugPrint('[LiveKitMeetingGateway] Make host sent to $identity');
    } catch (e) {
      debugPrint('[LiveKitMeetingGateway] makeParticipantHost error: $e');
    }
  }

  @override
  Future<void> makeParticipantCoHost(String identity) async {
    try {
      _coHostIdentities.add(identity);
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
  Future<void> revokeParticipantCoHost(String identity) async {
    try {
      _coHostIdentities.remove(identity);
      final payload = utf8.encode(jsonEncode({
        'action': 'revoke_cohost',
        'target_identity': identity,
      }));
      await _room?.localParticipant?.publishData(payload, reliable: true);
      debugPrint('[LiveKitMeetingGateway] Revoke co-host sent to $identity');
    } catch (e) {
      debugPrint('[LiveKitMeetingGateway] revokeParticipantCoHost error: $e');
    }
  }

  @override
  bool isScreenSharePermitted(String identity) =>
      _screenSharePermittedIdentities.contains(identity);

  @override
  Future<void> grantScreenShare(String identity) async {
    try {
      _screenSharePermittedIdentities.add(identity);
      final payload = utf8.encode(jsonEncode({
        'action': 'grant_screenshare',
        'target_identity': identity,
      }));
      await _room?.localParticipant?.publishData(payload, reliable: true);
      debugPrint('[LiveKitMeetingGateway] Grant screen share sent to $identity');
    } catch (e) {
      debugPrint('[LiveKitMeetingGateway] grantScreenShare error: $e');
    }
  }

  @override
  Future<void> revokeScreenShare(String identity) async {
    try {
      _screenSharePermittedIdentities.remove(identity);
      final payload = utf8.encode(jsonEncode({
        'action': 'revoke_screenshare',
        'target_identity': identity,
      }));
      await _room?.localParticipant?.publishData(payload, reliable: true);
      debugPrint('[LiveKitMeetingGateway] Revoke screen share sent to $identity');
    } catch (e) {
      debugPrint('[LiveKitMeetingGateway] revokeScreenShare error: $e');
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
    // 1. If broadcast / egress is active, automatically stop it
    if (_activeEgressId != null && _activeEgressId!.isNotEmpty) {
      try {
        await stopBroadcast(egressId: _activeEgressId!);
        debugPrint('[LiveKitMeetingGateway] Auto-stopped active broadcast on endMeetingForAll');
      } catch (e) {
        debugPrint('[LiveKitMeetingGateway] Auto-stop broadcast note: $e');
      }
    }

    // 2. If breakout rooms are active, relay end_meeting_for_all to all breakout sub-rooms too
    if (_isBreakoutActive && _breakoutRooms.isNotEmpty) {
      final subRoomIds = _breakoutRooms.map((r) => r.id).toList();
      unawaited(_relayControlMessageToRooms(
        {'action': 'end_meeting_for_all'},
        subRoomIds,
      ));
    }

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

  // ──────────────────────────────────────────────────────────
  //  Breakout Rooms Implementation
  // ──────────────────────────────────────────────────────────

  /// Relays a control packet to other LiveKit rooms (e.g., from Main Room to Breakout Sub-Rooms
  /// or from a Breakout Sub-Room back to the Main Room).
  Future<void> _relayControlMessageToRooms(
    Map<String, dynamic> message,
    List<String> targetRoomNames,
  ) async {
    final currentRoomName = _room?.name ?? _currentSession.roomName;
    final bytes = utf8.encode(jsonEncode(message));

    for (final targetRoom in targetRoomNames.toSet()) {
      if (targetRoom.isEmpty) continue;
      if (targetRoom == currentRoomName) {
        try {
          await _room?.localParticipant?.publishData(bytes, reliable: true);
        } catch (_) {}
        continue;
      }

      // Connect an ephemeral headless room client to deliver the control packet
      unawaited(() async {
        lk.Room? relayRoom;
        try {
          final relayId =
              '${_lastUserId.isNotEmpty ? _lastUserId : "host"}_relay_${DateTime.now().millisecondsSinceEpoch % 10000}';
          final decoded = await _executeFunctionSafely(
            functionId: AppwriteBackendConfig.createLiveKitTokenFunctionId,
            body: {
              'roomName': targetRoom,
              'identity': relayId,
              'participantName': 'ALIVE Meet System',
              'meetingType': _lastMeetingType,
            },
          );
          final token = decoded['token'] as String?;
          if (token == null || token.isEmpty) return;

          relayRoom = lk.Room();
          await relayRoom
              .connect(livekitUrl, token)
              .timeout(const Duration(seconds: 10));
          await relayRoom.localParticipant?.publishData(bytes, reliable: true);
          await Future<void>.delayed(const Duration(milliseconds: 350));
        } catch (e) {
          debugPrint('[LiveKitMeetingGateway] Relay to $targetRoom note: $e');
        } finally {
          try {
            await relayRoom?.disconnect();
          } catch (_) {}
        }
      }());
    }
  }

  @override
  Future<void> startBreakoutRooms({
    required List<BreakoutRoom> rooms,
    int? durationMinutes,
    bool allowSelfSelect = true,
  }) async {
    if (rooms.isEmpty) return;

    _mainRoomName ??= _room?.name ?? _currentSession.roomName;
    _isBreakoutActive = true;
    _breakoutRooms = List<BreakoutRoom>.from(rooms);
    _allowBreakoutSelfSelect = allowSelfSelect;
    _breakoutEndsAt = (durationMinutes != null && durationMinutes > 0)
        ? DateTime.now().toUtc().add(Duration(minutes: durationMinutes))
        : null;
    _breakoutBroadcastMessage = null;

    _scheduleBreakoutTimer();
    _syncStateFromRoom();

    final payload = {
      'action': 'breakout_start',
      'mainRoomName': _mainRoomName,
      'rooms': _breakoutRooms.map((r) => r.toJson()).toList(),
      'allowSelfSelect': _allowBreakoutSelfSelect,
      if (_breakoutEndsAt != null) 'endsAt': _breakoutEndsAt!.toIso8601String(),
    };

    try {
      await _room?.localParticipant
          ?.publishData(utf8.encode(jsonEncode(payload)), reliable: true);
      debugPrint(
        '[LiveKitMeetingGateway] Started ${_breakoutRooms.length} breakout rooms',
      );
    } catch (e) {
      debugPrint('[LiveKitMeetingGateway] startBreakoutRooms error: $e');
    }
  }

  @override
  Future<void> closeBreakoutRooms() async {
    final roomsToClose = _breakoutRooms.map((r) => r.id).toList();
    final mainRoom = _mainRoomName;
    if (mainRoom != null && mainRoom.isNotEmpty) {
      roomsToClose.add(mainRoom);
    }

    _breakoutTimer?.cancel();
    _isBreakoutActive = false;
    _breakoutRooms = [];
    _breakoutEndsAt = null;
    _breakoutBroadcastMessage = null;

    final payload = {'action': 'breakout_close'};
    await _relayControlMessageToRooms(payload, roomsToClose);

    if (_activeBreakoutRoomId != null && _activeBreakoutRoomId!.isNotEmpty) {
      await returnToMainRoom();
    } else {
      _syncStateFromRoom();
    }
  }

  @override
  Future<void> joinBreakoutRoom(BreakoutRoom room) async {
    if (room.id.isEmpty) return;
    if (_activeBreakoutRoomId == room.id && isConnected) return;

    _mainRoomName ??= _room?.name ?? _currentSession.roomName;
    final userId = _lastUserId.isNotEmpty
        ? _lastUserId
        : (_room?.localParticipant?.identity ?? 'member');
    final userName = _lastUserName.isNotEmpty
        ? _lastUserName
        : (_room?.localParticipant?.name ?? userId);

    _isSwitchingBreakoutRoom = true;
    _activeBreakoutRoomId = room.id;
    _activeBreakoutRoomName = room.name;
    _syncStateFromRoom();

    try {
      await executionAndJoin(
        roomName: room.id,
        userId: userId,
        userName: userName,
        meetingType: _lastMeetingType,
        isWaitingRoomEnabled: false,
      );
    } finally {
      _isSwitchingBreakoutRoom = false;
      _syncStateFromRoom();
    }
  }

  @override
  Future<void> returnToMainRoom() async {
    final targetMainRoom = _mainRoomName;
    if (targetMainRoom == null || targetMainRoom.isEmpty) return;
    if (_activeBreakoutRoomId == null &&
        (_room?.name == targetMainRoom || _currentSession.roomName == targetMainRoom)) {
      return;
    }

    final userId = _lastUserId.isNotEmpty
        ? _lastUserId
        : (_room?.localParticipant?.identity ?? 'member');
    final userName = _lastUserName.isNotEmpty
        ? _lastUserName
        : (_room?.localParticipant?.name ?? userId);

    _isSwitchingBreakoutRoom = true;
    _activeBreakoutRoomId = null;
    _activeBreakoutRoomName = null;
    _syncStateFromRoom();

    try {
      await executionAndJoin(
        roomName: targetMainRoom,
        userId: userId,
        userName: userName,
        meetingType: _lastMeetingType,
        isWaitingRoomEnabled: false,
      );
    } finally {
      _isSwitchingBreakoutRoom = false;
      _syncStateFromRoom();
    }
  }

  @override
  Future<void> broadcastToBreakoutRooms(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    _breakoutBroadcastMessage = trimmed;
    _syncStateFromRoom();

    final targets = _breakoutRooms.map((r) => r.id).toList();
    if (_mainRoomName != null && _mainRoomName!.isNotEmpty) {
      targets.add(_mainRoomName!);
    }

    await _relayControlMessageToRooms(
      {
        'action': 'breakout_broadcast',
        'message': trimmed,
      },
      targets,
    );
  }

  @override
  Future<void> requestHostHelpInBreakout() async {
    final roomId = _activeBreakoutRoomId;
    final roomName = _activeBreakoutRoomName ?? 'Breakout Room';
    final mainRoom = _mainRoomName;
    if (roomId == null || roomId.isEmpty || mainRoom == null || mainRoom.isEmpty) {
      return;
    }

    final userName = _lastUserName.isNotEmpty
        ? _lastUserName
        : (_room?.localParticipant?.name ?? 'Participant');

    final targets = <String>[mainRoom, ..._breakoutRooms.map((r) => r.id)];
    await _relayControlMessageToRooms(
      {
        'action': 'breakout_help',
        'roomId': roomId,
        'roomName': roomName,
        'userName': userName,
      },
      targets,
    );
  }

  @override
  Future<void> leaveMeeting() async {
    final room = _room;
    _breakoutTimer?.cancel();
    _breakoutTimer = null;

    if (room == null) {
      _isBreakoutActive = false;
      _breakoutRooms = [];
      _mainRoomName = null;
      _activeBreakoutRoomId = null;
      _activeBreakoutRoomName = null;
      _breakoutEndsAt = null;
      _breakoutBroadcastMessage = null;
      _currentSession = MeetingSession.initial();
      _emitSession();
      return;
    }

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
      _isScreenSharePermitted = false;
      _screenSharePermittedIdentities.clear();
      _hostIdentity = null;
      _coHostIdentities.clear();
      _isRoomAudioLocked = false;
      _isWaitingRoomEnabled = false;
      _isAdmitted = true;
      _waitingKnocks.clear();
      _handsRaised.clear();
      _isBreakoutActive = false;
      _breakoutRooms = [];
      _mainRoomName = null;
      _activeBreakoutRoomId = null;
      _activeBreakoutRoomName = null;
      _breakoutEndsAt = null;
      _breakoutBroadcastMessage = null;
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
    _breakoutTimer?.cancel();
    _roomListener?.dispose();
    _roomListener = null;
    _room?.disconnect();
    _room = null;
    _sessionController.close();
    _statusController.close();
    _moderationPromptsController.close();
    _dataChannelMessagesController.close();
    _broadcastingController.close();
    super.dispose();
  }
}
