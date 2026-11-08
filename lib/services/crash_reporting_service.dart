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

      // Filter out pure network dropouts / offline connectivity disconnects
      // to avoid retry loops when the device's internet flickers or disconnects.
      options.beforeSend = (event, hint) {
        final throwableStr = event.throwable?.toString().toLowerCase() ?? '';
        final messageStr = event.message?.formatted.toLowerCase() ?? '';
        if (throwableStr.contains('err_internet_disconnected') ||
            throwableStr.contains('socketexception') ||
            throwableStr.contains('clientexception') ||
            throwableStr.contains('failed host lookup') ||
            throwableStr.contains('connection refused') ||
            messageStr.contains('err_internet_disconnected')) {
          return null; // Do not report offline connectivity losses
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
