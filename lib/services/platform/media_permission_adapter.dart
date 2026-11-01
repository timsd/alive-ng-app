import 'media_permission_io.dart'
    if (dart.library.html) 'media_permission_web.dart' as platform;

/// Cross-platform media permission and hardware auto-activation helper.
/// Prompts the user for microphone and camera access on web and native devices
/// upfront, following Google Meet / Zoom connection flows.
class MediaPermissionService {
  static Future<bool> requestMediaPermissions() =>
      platform.requestMediaPermissions();
}
