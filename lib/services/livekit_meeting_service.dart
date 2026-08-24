import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart' as appwrite_enums;
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';

class LiveKitMeetingService extends ChangeNotifier {
  static const String livekitUrl = String.fromEnvironment(
    'LIVEKIT_URL',
    defaultValue: 'wss://livekit.alivenigeria.org',
  );

  Room? _room;
  bool _isAudioMuted = false;
  bool _isVideoMuted = false;

  Room? get room => _room;
  bool get isAudioMuted => _isAudioMuted;
  bool get isVideoMuted => _isVideoMuted;
  bool get isConnected => _room != null;

  Future<void> executionAndJoin({
    required String roomName,
    required String userId,
    required String userName,
    required String meetingType,
  }) async {
    try {
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

      await joinMeeting(roomToken: token);
    } catch (e) {
      debugPrint('Failed executing LiveKit token function: $e');
      rethrow;
    }
  }

  Future<void> joinMeeting({
    required String roomToken,
  }) async {
    try {
      await leaveMeeting();

      final room = Room(
        roomOptions: const RoomOptions(
          defaultAudioPublishOptions: AudioPublishOptions(),
          defaultVideoPublishOptions: VideoPublishOptions(
            videoEncoding: VideoEncoding(
              maxFramerate: 30,
              maxBitrate: 1500000,
            ),
          ),
        ),
      );
      await room.connect(
        livekitUrl,
        roomToken,
      );

      _room = room;
      await _room!.localParticipant?.setMicrophoneEnabled(true);
      await _room!.localParticipant?.setCameraEnabled(true);

      _isAudioMuted = false;
      _isVideoMuted = false;
      notifyListeners();

      debugPrint('Successfully connected to LiveKit room: ${_room!.name}');
    } catch (e) {
      debugPrint('Failed to connect to LiveKit Room: $e');
      await _room?.disconnect();
      _room = null;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleAudio() async {
    final participant = _room?.localParticipant;
    if (participant == null) return;

    _isAudioMuted = !_isAudioMuted;
    await participant.setMicrophoneEnabled(!_isAudioMuted);
    notifyListeners();
  }

  Future<void> toggleVideo() async {
    final participant = _room?.localParticipant;
    if (participant == null) return;

    _isVideoMuted = !_isVideoMuted;
    await participant.setCameraEnabled(!_isVideoMuted);
    notifyListeners();
  }

  Future<void> leaveMeeting() async {
    final room = _room;
    if (room == null) return;

    try {
      await room.disconnect();
      debugPrint('Disconnected from LiveKit meeting room safely.');
    } catch (e) {
      debugPrint('Error leaving meeting: $e');
    } finally {
      _room = null;
      _isAudioMuted = false;
      _isVideoMuted = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _room?.disconnect();
    _room = null;
    super.dispose();
  }
}
