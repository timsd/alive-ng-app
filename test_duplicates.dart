import 'dart:io';

void main() {
  final dir = Directory('lib');
  var files = dir.listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path.split(Platform.pathSeparator).last)
      .toList();
      
  var counts = <String, int>{};
  for (var f in files) {
    counts[f] = (counts[f] ?? 0) + 1;
  }
  
  var dups = counts.entries.where((e) => e.value > 1).toList();
  print(dups);
}
