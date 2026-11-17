import 'dart:convert';
import 'dart:io';
import 'run_live_tests.dart' show parseEnvFile, redactCredentials;

/// Explicit paid matrix, with one shared USD 50 ledger for all variants/runs.
Future<void> main(List<String> args) async {
  final options = <String, String>{};
  const allowed = [
    '--variant',
    '--skill-file',
    '--runs',
    '--output',
    '--env-file',
  ];
  for (var i = 0; i < args.length; i++) {
    if (!allowed.contains(args[i]) || i + 1 >= args.length) {
      stderr.writeln(
        'Usage: dart scripts/tools/run_role_quality.dart --variant baseline|candidate --skill-file path [--runs 3] [--output directory]',
      );
      exitCode = 64;
      return;
    }
    final name = args[i];
    options[name] = args[++i];
  }
  final variant = options['--variant'] ?? '';
  final runs = int.tryParse(options['--runs'] ?? '3') ?? 0;
  final source = File(
    options['--skill-file'] ?? 'assets/skills/novel-role-assign/SKILL.md',
  );
  if (!RegExp(r'^[a-zA-Z0-9_-]{1,40}$').hasMatch(variant) ||
      runs < 1 ||
      runs > 3 ||
      !source.existsSync()) {
    stderr.writeln('Choose a variant, existing skill and 1–3 runs.');
    exitCode = 64;
    return;
  }
  final root = Directory(
    options['--output'] ?? '.dart_tool/role-quality-2026-11-17',
  )..createSync(recursive: true);
  final frozen = File('${root.path}/$variant-SKILL.md');
  if (frozen.existsSync() &&
      frozen.readAsStringSync() != source.readAsStringSync()) {
    throw StateError('Variant skill already frozen; choose a new variant.');
  }
  if (!frozen.existsSync()) source.copySync(frozen.path);
  final fixtures = Directory('${root.path}/fixtures')
    ..createSync(recursive: true);
  for (final dir in ['role_assign', 'role_holdout', 'role_quality']) {
    for (final file in Directory(
      'scripts/tests/fixtures/$dir',
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.json'))) {
      final target = File('${fixtures.path}/${file.uri.pathSegments.last}');
      if (target.existsSync() &&
          target.readAsStringSync() != file.readAsStringSync()) {
        throw StateError('Frozen fixture changed: ${file.path}');
      }
      if (!target.existsSync()) file.copySync(target.path);
    }
  }
  final env = parseEnvFile(
    File(options['--env-file'] ?? '.env').readAsStringSync(),
  );
  final key = [
    env['OPENAI_TEST_API_KEY'],
    env['OPENAI_API_KEY'],
    env['OPENAI_KEY'],
  ].whereType<String>().where((s) => s.isNotEmpty).firstOrNull;
  if (key == null) throw StateError('No supported key in local .env.');
  var failed = false;
  Future<void> runOne(int run) async {
    final ledger = File('${root.path}/budget.json');
    if (ledger.existsSync() &&
        (jsonDecode(ledger.readAsStringSync()) as Map)['blockedReason'] !=
            null) {
      return;
    }
    final out = Directory('${root.path}/$variant/run-$run')
      ..createSync(recursive: true);
    for (final file in out.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.metrics.json'),
    )) {
      final id = file.uri.pathSegments.last.replaceFirst('.metrics.json', '');
      if (!File('${out.path}/$id.json').existsSync()) {
        final archive = Directory('${root.path}/failed-attempts')
          ..createSync(recursive: true);
        file.copySync(
          '${archive.path}/$variant-run-$run-$id-${DateTime.now().microsecondsSinceEpoch}.json',
        );
      }
    }
    final log = File('${out.path}/run.log').openWrite(mode: FileMode.append);
    stdout.writeln(
      '$variant run $run/$runs: gpt-6-luna, ${fixtures.listSync().length} texts; shared USD 50 guard.',
    );
    final process = await Process.start(
      Platform.isWindows ? 'flutter.bat' : 'flutter',
      [
        'test',
        'scripts/tests/novel_role_live_test.dart',
        '--no-pub',
        '--no-test-assets',
        '--reporter',
        'expanded',
      ],
      runInShell: Platform.isWindows,
      environment: {
        if (Platform.environment['NEIROHA_EVAL_PROXY'] != null)
          'NEIROHA_EVAL_PROXY': Platform.environment['NEIROHA_EVAL_PROXY']!,
        'NEIROHA_LIVE_ROLES': '1',
        'NEIROHA_ROLE_REPLAY': '0',
        'OPENAI_TEST_API_KEY': key,
        'OPENAI_ROLE_MODEL': 'gpt-6-luna',
        'OPENAI_ROLE_OUT_DIR': out.path,
        'OPENAI_ROLE_CASES': '',
        'NEIROHA_ROLE_FIXTURES': fixtures.path,
        'NEIROHA_ROLE_SKILL_FILE': frozen.path,
        'NEIROHA_EVAL_BUDGET_FILE': '${root.path}/budget.json',
        'NEIROHA_EVAL_MAX_CALLS': '250',
        'NEIROHA_EVAL_CASE_CALLS': '48',
        'NEIROHA_EVAL_RESUME': '1',
      },
    );
    Future<void> forward(Stream<List<int>> stream) => stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) {
          final redacted = redactCredentials(line, key);
          log.writeln(redacted);
          stdout.writeln('$variant/$run: $redacted');
        });
    await Future.wait([forward(process.stdout), forward(process.stderr)]);
    final code = await process.exitCode;
    await log.close();
    failed = failed || code != 0;
  }

  await Future.wait([for (var run = 1; run <= runs; run++) runOne(run)]);
  exitCode = failed ? 1 : 0;
}
