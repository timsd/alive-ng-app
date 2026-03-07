// Conditionally export the platform implementation or the web stub.
export 'jitsi_meet_service_impl.dart' if (dart.library.html) 'jitsi_meet_service_web_stub.dart';