import 'dart:async';
import 'package:flutter/foundation.dart';
import '../config/meeting_links_config.dart';
import '../utils/logger.dart';

/// Web stub for JitsiMeetService. Provides the same API but no-ops or throws.
class JitsiMeetService {
  static final JitsiMeetService _instance = JitsiMeetService._internal();
  static final Logger _logger = Logger('JitsiMeetService');
  factory JitsiMeetService() => _instance;
  JitsiMeetService._internal();

  Future<void> initialize() async {
    if (kDebugMode) {
      _logger.debug('JitsiMeetService (web stub) initialized');
    }
  }

  Future<void> joinMeeting({
    required String roomName,
    required String displayName,
    String? email,
    String? avatarUrl,
    bool isModerator = false,
    Map<String, dynamic>? customFeatureFlags,
    Map<String, dynamic>? customConfig,
  }) async {
    throw UnsupportedError('JitsiMeet not supported on web in this build');
  }

  Future<void> joinPredefinedMeeting({
    required MeetingType meetingType,
    required String displayName,
    String? email,
    String? avatarUrl,
    bool isModerator = false,
    Map<String, dynamic>? customFeatureFlags,
  }) async {
    throw UnsupportedError('JitsiMeet not supported on web in this build');
  }

  Future<void> leaveMeeting() async {}
  Future<void> setAudioMuted(bool muted) async {}
  Future<void> setVideoMuted(bool muted) async {}
  Future<void> sendChatMessage(String message) async {}

  void dispose() {}
}

// MeetingType is imported from meeting_links_config.dart