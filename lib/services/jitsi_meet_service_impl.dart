import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import '../config/jitsi_config.dart';
import '../config/meeting_links_config.dart';
import '../utils/logger.dart';

/// Enhanced Jitsi Meet service with full customization and feature flags
class JitsiMeetService {
  static final JitsiMeetService _instance = JitsiMeetService._internal();
  factory JitsiMeetService() => _instance;
  JitsiMeetService._internal();

  final JitsiMeet _jitsiMeet = JitsiMeet();
  final Logger _logger = Logger('JitsiMeetService');
  // Event stream is not exposed by the SDK; events are provided via listener on join.

  /// Initialize Jitsi Meet service
  Future<void> initialize() async {
    try {
      // SDK initialization hook (kept for symmetry and future expansion)
      if (kDebugMode) {
        _logger.debug('JitsiMeetService initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        _logger.error('Error initializing JitsiMeetService', e);
      }
      rethrow;
    }
  }

  /// Join a meeting with full customization
  Future<void> joinMeeting({
    required String roomName,
    required String displayName,
    String? email,
    String? avatarUrl,
    bool isModerator = false,
    Map<String, dynamic>? customFeatureFlags,
    Map<String, dynamic>? customConfig,
  }) async {
    try {
      // Get Jitsi configuration
      final config = JitsiConfig.getJitsiConfiguration(
        roomName: roomName,
        displayName: displayName,
        email: email,
        avatarUrl: avatarUrl,
        isModerator: isModerator,
        customFeatureFlags: customFeatureFlags,
      );

      // Merge with any custom configuration
      if (customConfig != null) {
        config.addAll(customConfig);
      }

      // Create meeting options aligned with SDK
      final options = JitsiMeetConferenceOptions(
        serverURL: config['serverURL'],
        room: config['room'],
        userInfo: JitsiMeetUserInfo(
          displayName: displayName,
          email: email,
          // In SDK v10+, use 'avatar' instead of 'avatarURL'
          avatar: avatarUrl,
        ),
        // Feature flags should be provided as a Map
        featureFlags: config['featureFlags'],
        // Additional config overrides as a Map
        configOverrides: config['configOverrides'],
      );

      // Wire up Jitsi event listener and join
      final listener = JitsiMeetEventListener(
        conferenceJoined: (url) => _onConferenceJoined(url),
        conferenceTerminated: (url, error) => _onConferenceLeft(url, error),
        conferenceWillJoin: (url) => _onConferenceWillJoin(url),
        participantJoined: (email, name, role, participantId) =>
            _onParticipantJoined(email, name, role, participantId),
        participantLeft: (participantId) => _onParticipantLeft(participantId),
        audioMutedChanged: (muted) => _onAudioMutedChanged(muted),
        videoMutedChanged: (muted) => _onVideoMutedChanged(muted),
        endpointTextMessageReceived: (senderId, message) =>
            _onEndpointTextMessageReceived(senderId, message),
        screenShareToggled: (participantId, enabled) =>
            _onScreenShareToggled(enabled),
        chatMessageReceived: (senderId, message, isPrivate, messageId) =>
            _onChatMessageReceived(senderId, message, isPrivate),
        chatToggled: (enabled) => _onChatToggled(enabled),
        participantsInfoRetrieved: (participantsInfo) =>
            _onParticipantsInfoRetrieved(participantsInfo),
        readyToClose: () => _onReadyToClose(),
      );

      await _jitsiMeet.join(options, listener);

      if (kDebugMode) {
        _logger.debug('Joined Jitsi meeting: $roomName');
      }
    } catch (e) {
      if (kDebugMode) {
        _logger.error('Error joining Jitsi meeting', e);
      }
      rethrow;
    }
  }

  /// Join a predefined meeting by type
  Future<void> joinPredefinedMeeting({
    required MeetingType meetingType,
    required String displayName,
    String? email,
    String? avatarUrl,
    bool isModerator = false,
    Map<String, dynamic>? customFeatureFlags,
  }) async {
    final roomName =
        _extractRoomNameFromUrl(MeetingLinksConfig.getMeetingUrl(meetingType));

    await joinMeeting(
      roomName: roomName,
      displayName: displayName,
      email: email,
      avatarUrl: avatarUrl,
      isModerator: isModerator,
      customFeatureFlags: customFeatureFlags,
    );
  }

  /// Leave the current meeting
  Future<void> leaveMeeting() async {
    try {
      await _jitsiMeet.hangUp();

      if (kDebugMode) {
        _logger.debug('Left Jitsi meeting');
      }
    } catch (e) {
      if (kDebugMode) {
        _logger.error('Error leaving Jitsi meeting', e);
      }
      rethrow;
    }
  }

  /// Set audio muted state
  Future<void> setAudioMuted(bool muted) async {
    try {
      await _jitsiMeet.setAudioMuted(muted);
    } catch (e) {
      if (kDebugMode) {
        _logger.error('Error setting audio muted', e);
      }
      rethrow;
    }
  }

  /// Set video muted state
  Future<void> setVideoMuted(bool muted) async {
    try {
      await _jitsiMeet.setVideoMuted(muted);
    } catch (e) {
      if (kDebugMode) {
        _logger.error('Error setting video muted', e);
      }
      rethrow;
    }
  }

  /// Send a chat message
  Future<void> sendChatMessage(String message) async {
    try {
      await _jitsiMeet.sendChatMessage(message: message);
    } catch (e) {
      if (kDebugMode) {
        _logger.error('Error sending chat message', e);
      }
      rethrow;
    }
  }

  // Event handling now occurs via the listener passed to join()

  /// Event handlers
  void _onConferenceJoined(String url) {
    if (kDebugMode) {
      _logger.debug('Conference joined successfully: $url');
    }
  }

  void _onConferenceLeft(String url, dynamic error) {
    if (kDebugMode) {
      _logger.debug('Conference terminated: url=$url error=$error');
    }
  }

  void _onConferenceWillJoin(String url) {
    if (kDebugMode) {
      _logger.debug('Conference will join: $url');
    }
  }

  void _onParticipantJoined(
      String? email, String? name, String? role, String? participantId) {
    if (kDebugMode) {
      _logger.debug(
          'Participant joined: id=$participantId name=$name email=$email role=$role');
    }
  }

  void _onParticipantLeft(String? participantId) {
    if (kDebugMode) {
      _logger.debug('Participant left: id=$participantId');
    }
  }

  void _onAudioMutedChanged(bool muted) {
    if (kDebugMode) {
      _logger.debug('Audio muted state changed: $muted');
    }
  }

  void _onVideoMutedChanged(bool muted) {
    if (kDebugMode) {
      _logger.debug('Video muted state changed: $muted');
    }
  }

  void _onChatMessageReceived(String senderId, String message, bool isPrivate) {
    if (kDebugMode) {
      _logger.debug(
          'Chat message received: from=$senderId private=$isPrivate message=$message');
    }
  }

  void _onScreenShareToggled(bool enabled) {
    if (kDebugMode) {
      _logger.debug('Screen share toggled: $enabled');
    }
  }

  void _onChatToggled(bool enabled) {
    if (kDebugMode) {
      _logger.debug('Chat toggled: $enabled');
    }
  }

  void _onParticipantsInfoRetrieved(dynamic participantsInfo) {
    if (kDebugMode) {
      _logger.debug('Participants info retrieved: $participantsInfo');
    }
  }

  void _onEndpointTextMessageReceived(String senderId, String message) {
    if (kDebugMode) {
      _logger.debug(
          'Endpoint text message received: from=$senderId message=$message');
    }
  }

  void _onReadyToClose() {
    if (kDebugMode) {
      _logger.debug('Ready to close');
    }
  }

  /// Extract room name from Jitsi Meet URL
  String _extractRoomNameFromUrl(String url) {
    final uri = Uri.parse(url);
    return uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'default-room';
  }

  /// Dispose resources
  void dispose() {
    // No-op for now; add cleanup as needed
  }
}
