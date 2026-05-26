import 'package:flutter/foundation.dart';

class CrashReportingConfig {
  static const String dsn = String.fromEnvironment('GLITCHTIP_DSN');
  static const String environment = String.fromEnvironment(
    'GLITCHTIP_ENVIRONMENT',
    defaultValue: kReleaseMode ? 'production' : 'development',
  );
  static const String release = String.fromEnvironment('GLITCHTIP_RELEASE');
  static const String _tracesSampleRateDefine = String.fromEnvironment(
    'GLITCHTIP_TRACES_SAMPLE_RATE',
    defaultValue: '0',
  );

  static double get tracesSampleRate =>
      double.tryParse(_tracesSampleRateDefine) ?? 0;

  static bool get isEnabled => dsn.trim().isNotEmpty;
}
