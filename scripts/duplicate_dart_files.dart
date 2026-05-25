import 'dart:io';

void main(List<String> args) {
  final targets = args.isEmpty
      ? ['lib']
      : args.where((arg) => arg.trim().isNotEmpty).toList();

  final byName = <String, List<String>>{};
  final missingTargets = <String>[];

  for (final target in targets) {
    final root = Directory(target);

    if (!root.existsSync()) {
      missingTargets.add(target);
      continue;
    }

    for (final entity in root.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final name = entity.uri.pathSegments.last;
      byName.putIfAbsent(name, () => []).add(entity.path);
    }
  }

  final duplicates = byName.entries
      .where((entry) => entry.value.length > 1)
      .toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  if (duplicates.isEmpty) {
    stdout.writeln(
      'No duplicate Dart filenames found under ${targets.join(', ')}.',
    );
    if (missingTargets.isNotEmpty) {
      stdout
          .writeln('Skipped missing directories: ${missingTargets.join(', ')}');
    }
    return;
  }

  for (final entry in duplicates) {
    stdout.writeln('${entry.key} (${entry.value.length})');
    for (final path in entry.value..sort()) {
      stdout.writeln('  - $path');
    }
  }

  if (missingTargets.isNotEmpty) {
    stdout.writeln('Skipped missing directories: ${missingTargets.join(', ')}');
  }

  exitCode = 1;
}
