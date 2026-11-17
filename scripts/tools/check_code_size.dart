import 'dart:convert';
import 'dart:io';

/// Run from the repository root. Generated sources are intentionally excluded.
/// Baseline limits are upper bounds: do not increase them to silence failures.
void main() {
  final baselineFile = File('scripts/tools/code_size_baseline.json');
  final baseline = Map<String, dynamic>.from(
    jsonDecode(baselineFile.readAsStringSync()) as Map,
  );
  var failures = 0;
  var legacy = 0;
  var files = 0;
  for (final root in ['lib', 'scripts', 'macos/Runner']) {
    if (!Directory(root).existsSync()) continue;
    for (final entry in Directory(root).listSync(recursive: true)) {
      if (entry is! File) continue;
      final path = entry.path.replaceAll('\\', '/');
      if (!RegExp(r'\.(dart|swift|ps1|sh|py)$').hasMatch(path) ||
          path.endsWith('.g.dart') ||
          path.endsWith('.freezed.dart') ||
          path.startsWith('lib/l10n/generated/')) {
        continue;
      }
      files++;
      final count = entry.readAsLinesSync().length;
      final limit = (baseline[path] as int?) ?? 500;
      if (count > limit) {
        stderr.writeln('$path: $count lines (limit $limit)');
        failures++;
      } else if (count > 500) {
        legacy++;
      }
    }
  }
  stdout.writeln(
    '$files files checked; $legacy legacy files over 500 lines; '
    '$failures violations.',
  );
  if (failures != 0) exitCode = 1;
}
