import 'dart:io';

void main(List<String> args) {
  final target = args.isEmpty ? 'lib' : args.first;
  final root = Directory(target);

  if (!root.existsSync()) {
    stderr.writeln('Directory not found: $target');
    exitCode = 1;
    return;
  }

  final byName = <String, List<String>>{};
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final name = entity.uri.pathSegments.last;
    byName.putIfAbsent(name, () => []).add(entity.path);
  }

  final duplicates = byName.entries
      .where((entry) => entry.value.length > 1)
      .toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  if (duplicates.isEmpty) {
    stdout.writeln('No duplicate Dart filenames found under $target.');
    return;
  }

  for (final entry in duplicates) {
    stdout.writeln('${entry.key} (${entry.value.length})');
    for (final path in entry.value..sort()) {
      stdout.writeln('  - $path');
    }
  }
}
