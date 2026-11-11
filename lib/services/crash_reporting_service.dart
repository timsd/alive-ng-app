import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/crash_reporting_config.dart';

class CrashReportingService {
  CrashReportingService._();

  static final CrashReportingService instance = CrashReportingService._();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || !CrashReportingConfig.isEnabled) return;

    await SentryFlutter.init((options) {
      options.dsn = CrashReportingConfig.dsn;
      options.environment = CrashReportingConfig.environment;
      options.release = CrashReportingConfig.release.isEmpty
          ? null
          : CrashReportingConfig.release;
      options.tracesSampleRate = CrashReportingConfig.tracesSampleRate;
      options.sendDefaultPii = false;
      options.attachScreenshot = false;
      options.diagnosticLevel =
          kReleaseMode ? SentryLevel.warning : SentryLevel.info;

      // Filter out pure network dropouts, transient WebSocket closures,
      // and benign browser-sandbox environment notices.
      options.beforeSend = (event, hint) {
        final throwableStr = event.throwable?.toString().toLowerCase() ?? '';
        final messageStr = event.message?.formatted.toLowerCase() ?? '';
        final fullStr = '$throwableStr $messageStr';

        // 1. Filter out pure network dropouts / offline connectivity disconnects
        if (fullStr.contains('err_internet_disconnected') ||
            fullStr.contains('socketexception') ||
            fullStr.contains('clientexception') ||
            fullStr.contains('failed host lookup') ||
            fullStr.contains('connection refused') ||
            fullStr.contains('connection reset') ||
            fullStr.contains('network is unreachable')) {
          return null;
        }

        // 2. Filter out transient WebSocket connection drops and Appwrite 1008 policy closes
        if (fullStr.contains('websocketchannelexception') ||
            fullStr.contains('websocket connection failed') ||
            fullStr.contains('server error (1008)') ||
            fullStr.contains('error: server error (1008)')) {
          return null;
        }

        // 3. Filter out 404 missing avatars / static storage assets
        if (fullStr.contains('networkimageloadexception') && fullStr.contains('404')) {
          return null;
        }

        // 4. Filter out browser sandbox storage denials (e.g. strict privacy / third-party iframe)
        if (fullStr.contains('localstorage') && fullStr.contains('access is denied') ||
            fullStr.contains('sessionstorage') && fullStr.contains('access is denied') ||
            fullStr.contains('access is denied for this document')) {
          return null;
        }

        // 5. Filter out missing NOTICES license asset
        if (fullStr.contains('unable to load asset: "notices"') ||
            fullStr.contains('unable to load asset: \'notices\'')) {
          return null;
        }

        // 6. Filter out Web SpeechRecognition background tab cancellation
        if (fullStr.contains('speechrecognition') && fullStr.contains('invalidstateerror')) {
          return null;
        }

        // 7. Filter out LiveKit non-fatal signal permissions & timeouts
        if (fullStr.contains('signal request failed: not_allowed') ||
            (fullStr.contains('livekit exception') && fullStr.contains('timeout'))) {
          return null;
        }

        return event;
      };
    });

    _initialized = true;
    debugPrint('GlitchTip crash reporting initialized.');
  }

  Future<void> captureFlutterError(FlutterErrorDetails details) async {
    if (!_initialized) return;
    await Sentry.captureException(
      details.exception,
      stackTrace: details.stack,
      hint: Hint.withMap({
        'library': details.library,
        'context': details.context?.toDescription(),
      }),
    );
  }

  Future<void> captureError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
  }) async {
    if (!_initialized) return;
    await Sentry.captureException(
      error,
      stackTrace: stack,
      hint: Hint.withMap({'fatal': fatal}),
    );
  }

  Future<void> setUserId(String? userId) async {
    if (!_initialized) return;
    await Sentry.configureScope((scope) {
      scope.setUser(userId == null || userId.isEmpty
          ? null
          : SentryUser(id: userId));
    });
  }
}
