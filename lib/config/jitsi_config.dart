/// Configuration class for Jitsi Meet feature flags and customization
class JitsiConfig {
  /// Feature flags for controlling Jitsi Meet UI and functionality
  static const Map<String, dynamic> featureFlags = {
    'chat.enabled': true,
    'invite.enabled': false,
    'live-streaming.enabled': false,
    'recording.enabled': false,
    'tile-view.enabled': true,
    'toolbox.alwaysVisible': false,
    'add-people.enabled': false,
    'raise-hand.enabled': true,
    'help.enabled': false,
    'meeting-name.enabled': true,
    'prejoinpage.enabled': false,
    'kick-out.enabled': false, // Set to true for moderator only if implementing token security
  };

  /// Default user configuration
  static const Map<String, dynamic> defaultUserConfig = {
    'startWithAudioMuted': false,
    'startWithVideoMuted': false,
    'enableWelcomePage': false,
    'enableClosePage': false,
  };

  /// Server configuration
  static const String serverUrl = 'https://meet.jit.si';

  /// Get feature flags for a specific user role
  static Map<String, dynamic> getFeatureFlagsForRole({bool isModerator = false}) {
    final flags = Map<String, dynamic>.from(featureFlags);
    
    // Enable kick-out for moderators only
    if (isModerator) {
      flags['kick-out.enabled'] = true;
      flags['live-streaming.enabled'] = true;
      flags['recording.enabled'] = true;
    }
    
    return flags;
  }

  /// Get user info configuration
  static Map<String, dynamic> getUserInfo({
    required String displayName,
    String? email,
    String? avatarUrl,
  }) {
    return {
      'displayName': displayName,
      if (email != null) 'email': email,
      if (avatarUrl != null) 'avatarURL': avatarUrl,
    };
  }

  /// Get complete Jitsi configuration
  static Map<String, dynamic> getJitsiConfiguration({
    required String roomName,
    required String displayName,
    String? email,
    String? avatarUrl,
    bool isModerator = false,
    Map<String, dynamic>? customFeatureFlags,
  }) {
    final config = {
      'serverURL': serverUrl,
      'room': roomName,
      'userInfo': getUserInfo(
        displayName: displayName,
        email: email,
        avatarUrl: avatarUrl,
      ),
      'featureFlags': customFeatureFlags ?? getFeatureFlagsForRole(isModerator: isModerator),
      'configOverrides': {
        ...defaultUserConfig,
        'subject': roomName,
      },
    };

    return config;
  }
}