import 'dart:io';

void main() async {
  // Define the keys we need to replace
  final keys = [
    'FIREBASE_API_KEY',
    'FIREBASE_AUTH_DOMAIN',
    'FIREBASE_PROJECT_ID',
    'FIREBASE_STORAGE_BUCKET',
    'FIREBASE_MESSAGING_SENDER_ID',
    'FIREBASE_APP_ID',
    'FIREBASE_MEASUREMENT_ID',
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
    // Support both FIREBASE_* and FIREBASE_WEB_* env naming
    String? value = Platform.environment[key] ?? envMap[key];
    if (value == null || value.isEmpty) {
      final webKey = key.startsWith('FIREBASE_')
          ? 'FIREBASE_WEB_${key.substring('FIREBASE_'.length)}'
          : null;
      if (webKey != null) {
        value = Platform.environment[webKey] ?? envMap[webKey];
      }
    }
    if (value == null || value.isEmpty) {
      stderr.writeln('Warning: Environment variable $key (or WEB variant) is not set.');
      missingKeys = true;
    } else {
      replacements['{{$key}}'] = value;
    }
  }

  if (missingKeys) {
    stderr.writeln('Some environment variables are missing. Please set them before running this script.');
    // We don't exit here to allow partial updates if intended, but usually this is fatal for a correct build.
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
