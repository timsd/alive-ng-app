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

  // Push is native-only, so there is no browser service worker to configure.
  // Previously this block substituted Firebase *Web app* values into
  // web/firebase-messaging-sw.js; that worker never worked (no Web app, no VAPID
  // key) and has been removed. The FIREBASE_WEB_* dart-defines are gone with it.

  // Always sync app version from pubspec.yaml (single source of truth) into
  // lib/constants/app_constants.dart and web/index.html before building web.
  final pubspecFile = File('pubspec.yaml');
  if (await pubspecFile.exists()) {
    final pubspecText = await pubspecFile.readAsString();
    final versionMatch =
        RegExp(r'^version:\s*([^\s#]+)', multiLine: true).firstMatch(pubspecText);
    final pubspecVersion = versionMatch?.group(1)?.trim();
    if (pubspecVersion != null && pubspecVersion.isNotEmpty) {
      final constantsFile = File('lib/constants/app_constants.dart');
      if (await constantsFile.exists()) {
        final orig = await constantsFile.readAsString();
        final updated = orig.replaceFirstMapped(
          RegExp(
            r"(static const String appVersion = String\.fromEnvironment\([\s\S]*?defaultValue:\s*')[^']+(')",
          ),
          (m) => '${m.group(1)}$pubspecVersion${m.group(2)}',
        );
        if (updated != orig) {
          await constantsFile.writeAsString(updated);
          stdout.writeln('Synced app_constants.dart version -> $pubspecVersion');
        }
      }

      final indexFile = File('web/index.html');
      if (await indexFile.exists()) {
        final orig = await indexFile.readAsString();
        final updated = orig.replaceFirst(
          RegExp(r'<meta name="version" content="[^"]*">'),
          '<meta name="version" content="$pubspecVersion">',
        );
        if (updated != orig) {
          await indexFile.writeAsString(updated);
          stdout.writeln('Synced web/index.html version -> $pubspecVersion');
        }
      }
    }
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
