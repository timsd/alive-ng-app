import 'dart:io';

void main() async {
  // Define the keys we need to replace
  final keys = [
    'RECAPTCHA_SITE_KEY',
  ];

  // Try to load .env file if it exists
  final envMap = <String, String>{};
  final envFile = File('.env');
  if (await envFile.exists()) {
    final lines = await envFile.readAsLines();
    for (final line in lines) {
      if (line.trim().isEmpty || line.trim().startsWith('#')) continue;
      final parts = line.split('=');
      if (parts.length >= 2) {
        envMap[parts[0].trim()] = parts.sublist(1).join('=').trim();
      }
    }
    stdout.writeln('Loaded variables from .env file.');
  }

  // Map of placeholders to environment variable names
  final replacements = <String, String>{};
  bool missingKeys = false;

  for (final key in keys) {
    String? value = Platform.environment[key] ?? envMap[key];
    if (value == null || value.isEmpty) {
      stderr.writeln('Warning: Environment variable $key (or WEB variant) is not set.');
      missingKeys = true;
    } else {
      replacements['{{$key}}'] = value;
    }
  }

  // HTML receives public configuration only; server keys are never substituted.

  if (missingKeys) {
    stderr.writeln('Some environment variables are missing. Please set them before running this script.');
    // We don't exit here to allow partial updates if intended, but usually this is fatal for a correct build.
  }

  // The Firebase service worker ships with placeholders rather than real config,
  // so nothing secret is committed. Substituting them here means the deployed
  // bundle is built from the same --dart-define values the Dart side reads,
  // and the two cannot drift.
  //
  // A browser cannot register an FCM token without a real Firebase *Web app*
  // and a VAPID key. When either is missing the placeholders are left in place
  // and the app falls back to in-app notifications, which is a clear "not
  // configured" rather than a runtime error inside Firebase.
  const swKeys = [
    'FIREBASE_WEB_API_KEY',
    'FIREBASE_WEB_AUTH_DOMAIN',
    'FIREBASE_WEB_PROJECT_ID',
    'FIREBASE_WEB_STORAGE_BUCKET',
    'FIREBASE_WEB_MESSAGING_SENDER_ID',
    'FIREBASE_WEB_APP_ID',
  ];

  final swValues = <String, String>{};
  var swConfigured = true;
  for (final key in swKeys) {
    final value = Platform.environment[key] ?? envMap[key];
    if (value == null || value.isEmpty) {
      swConfigured = false;
    } else {
      swValues[key] = value;
    }
  }

  final swFile = File('web/firebase-messaging-sw.js');
  if (await swFile.exists()) {
    if (swConfigured) {
      var sw = await swFile.readAsString();
      swValues.forEach((key, value) {
        // The placeholder is a literal __NAME__, not an interpolated string:
        // writing '__$key__' would ask Dart to interpolate `key` and match
        // 'key__'.
        final placeholder = '__${key}__';
        sw = sw.replaceAll(placeholder, value);
      });
      await swFile.writeAsString(sw);
      stdout.writeln('Injected Firebase web config into firebase-messaging-sw.js');
    } else {
      final missing = swKeys
          .where((k) => (Platform.environment[k] ?? envMap[k] ?? '').isEmpty)
          .toList();
      stderr.writeln(
        'Web push stays disabled: missing ${missing.join(', ')}.\n'
        '  A Firebase Web app must be registered in the project, and its VAPID '
        'key is passed separately as FIREBASE_WEB_VAPID_KEY.\n'
        '  See web/README-push.md. The app still works; it just uses in-app '
        'notifications in the browser.',
      );
    }
  } else {
    stderr.writeln('File not found: web/firebase-messaging-sw.js');
  }

  // Files to update
  final files = [
    'web/index.html',
    'web/donation.html',
  ];

  for (final filePath in files) {
    final file = File(filePath);
    if (!await file.exists()) {
      stderr.writeln('File not found: $filePath');
      continue;
    }

    String content = await file.readAsString();
    bool modified = false;

    replacements.forEach((placeholder, value) {
      if (content.contains(placeholder)) {
        content = content.replaceAll(placeholder, value);
        modified = true;
      }
    });

    if (modified) {
      await file.writeAsString(content);
      stdout.writeln('Updated $filePath');
    } else {
      stdout.writeln('No placeholders found in $filePath (or already updated).');
    }
  }
}
