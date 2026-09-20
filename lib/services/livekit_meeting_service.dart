/// Legacy compatibility service for LiveKit video meetings.
///
/// Refactored to delegate to [LiveKitMeetingGateway] and [MeetingGateway].
/// This file NO LONGER imports `package:livekit_client`. All third-party SDK
/// code is confined to `lib/services/adapters/livekit_meeting_gateway.dart`.
library;

import 'package:flutter/material.dart';

import '../models/meeting_models.dart';
import 'adapters/livekit_meeting_gateway.dart';
import 'ports/meeting_gateway.dart';

/// Compatibility wrapper delegating to [LiveKitMeetingGateway].
class LiveKitMeetingService extends ChangeNotifier implements MeetingGateway {
  final LiveKitMeetingGateway _gateway;

  LiveKitMeetingService([LiveKitMeetingGateway? gateway])
      : _gateway = gateway ?? LiveKitMeetingGateway() {
    _gateway.addListener(notifyListeners);
  }

  @override
  MeetingSession get currentSession => _gateway.currentSession;

  @override
  Stream<MeetingSession> get sessionStream => _gateway.sessionStream;

  @override
  Stream<RoomStatus> get roomStatus => _gateway.roomStatus;

  @override
  bool get isConnected => _gateway.isConnected;

  @override
  bool get isAudioMuted => _gateway.isAudioMuted;

  @override
  bool get isVideoMuted => _gateway.isVideoMuted;

  @override
  Future<void> executionAndJoin({
    required String roomName,
    required String userId,
    required String userName,
    required String meetingType,
    bool notifyMembers = false,
    String? meetingTitle,
  }) {
    return _gateway.executionAndJoin(
      roomName: roomName,
      userId: userId,
      userName: userName,
      meetingType: meetingType,
      notifyMembers: notifyMembers,
      meetingTitle: meetingTitle,
    );
  }

  @override
  Future<void> joinMeeting({
    required String roomToken,
    String? roomName,
  }) {
    return _gateway.joinMeeting(
      roomToken: roomToken,
      roomName: roomName,
    );
  }

  @override
  Future<void> toggleAudio() => _gateway.toggleAudio();

  @override
  Future<void> toggleVideo() => _gateway.toggleVideo();

  @override
  Future<void> leaveMeeting() => _gateway.leaveMeeting();


  @override
  bool get isBroadcasting => _gateway.isBroadcasting;

  @override
  Stream<bool> get broadcastingStream => _gateway.broadcastingStream;

  @override
  Future<String> startBroadcast({required String meetingType}) =>
      _gateway.startBroadcast(meetingType: meetingType);

  @override
  Future<void> stopBroadcast({required String egressId}) =>
      _gateway.stopBroadcast(egressId: egressId);

  @override
  Future<List<dynamic>> listBroadcasts() => _gateway.listBroadcasts();

  @override
  void dispose() {
    _gateway.removeListener(notifyListeners);
    _gateway.dispose();
    super.dispose();
  }
}
