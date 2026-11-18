import 'dart:convert';
import 'dart:io';

/// Cross-platform opt-in launcher. Parse .env as data, never execute it.
Map<String, String> parseEnvFile(String text) {
  final values = <String, String>{};
  for (final raw in const LineSplitter().convert(text)) {
    final line = raw.trim().replaceFirst(RegExp(r'^export\s+'), '');
    if (line.isEmpty || line.startsWith('#')) continue;
    final separator = line.indexOf('=');
    if (separator < 1) continue;
    final name = line.substring(0, separator).trim();
    var value = line.substring(separator + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    values[name] = value;
  }
  return values;
}

String redactCredentials(String text, String key) =>
    (key.isEmpty ? text : text.replaceAll(key, '[REDACTED]')).replaceAll(
      RegExp(r'sk-[A-Za-z0-9_-]+'),
      '[REDACTED]',
    );

Future<void> main(List<String> args) async {
  const suites = {
    'streaming': 'scripts/tests/openai_streaming_live_test.dart',
    'speech': 'scripts/tests/openai_tts_live_test.dart',
    'roles': 'scripts/tests/novel_role_live_test.dart',
    'review': 'scripts/tests/role_review_live_test.dart',
    'text-roles': 'scripts/tests/text_role_live_test.dart',
  };
  const usage =
      'Usage: dart scripts/tools/run_live_tests.dart '
      '<streaming|speech|roles|review|text-roles> [--env-file .env] [--output directory] '
      '[--model gpt-6-luna] [--cases id1,id2] [--fixtures directory] [--replay]';
  if (args.length == 1 && args.first == '--help') {
    stdout.writeln(usage);
    return;
  }
  if (args.isEmpty || !suites.containsKey(args.first)) {
    stderr.writeln(usage);
    exitCode = 64;
    return;
  }
  final suite = args.first;
  final options = <String, String>{};
  var replay = false;
  for (var i = 1; i < args.length; i++) {
    final option = args[i];
    if (option == '--fixtures' && suite != 'roles') {
      stderr.writeln(usage);
      exitCode = 64;
      return;
    }
    if (suite != 'roles' &&
        suite != 'review' &&
        suite != 'text-roles' &&
        ['--model', '--cases', '--fixtures'].contains(option)) {
      stderr.writeln(usage);
      exitCode = 64;
      return;
    }
    if (option == '--replay' && suite == 'roles') {
      replay = true;
    } else if ([
          '--env-file',
          '--output',
          '--model',
          '--cases',
          '--fixtures',
        ].contains(option) &&
        i + 1 < args.length &&
        !args[i + 1].startsWith('--')) {
      options[option] = args[++i];
    } else {
      stderr.writeln(usage);
      exitCode = 64;
      return;
    }
  }
  if (suite == 'review' &&
      (options['--cases'] ?? '')
          .split(',')
          .where((s) => s.isNotEmpty)
          .any((s) => !['identity', 'chat', 'merge'].contains(s))) {
    stderr.writeln('Review cases: identity, chat, merge.');
    exitCode = 64;
    return;
  }
  if (suite == 'text-roles' &&
      options['--model'] != null &&
      options['--model'] != 'gpt-6-luna') {
    stderr.writeln('The shared-budget text intent suite uses gpt-6-luna only.');
    exitCode = 64;
    return;
  }
  final output =
      options['--output'] ??
      '.dart_tool/live-${suite == 'roles' ? 'novel-roles' : suite}';
  var key = '';
  if (!replay) {
    final file = File(options['--env-file'] ?? '.env');
    if (!file.existsSync()) {
      stderr.writeln('Local .env file not found.');
      exitCode = 66;
      return;
    }
    final values = parseEnvFile(file.readAsStringSync());
    key = [
      values['OPENAI_TEST_API_KEY'],
      values['OPENAI_API_KEY'],
      values['OPENAI_KEY'],
    ].whereType<String>().firstWhere((v) => v.isNotEmpty, orElse: () => '');
    if (key.isEmpty) {
      stderr.writeln('No supported API key variable found in the local .env.');
      exitCode = 78;
      return;
    }
  }
  final environment = {
    'OPENAI_TEST_API_KEY': key,
    'NEIROHA_LIVE_STREAMING': suite == 'streaming' ? '1' : '0',
    'NEIROHA_LIVE_ROLES': suite == 'roles' && !replay ? '1' : '0',
    'NEIROHA_LIVE_REVIEW': suite == 'review' ? '1' : '0',
    'NEIROHA_TEXT_ROLE_LIVE': suite == 'text-roles' ? '1' : '0',
    'NEIROHA_ROLE_REPLAY': replay ? '1' : '0',
    'OPENAI_TEST_OUT_DIR': output,
    'OPENAI_ROLE_OUT_DIR': output,
    'OPENAI_ROLE_MODEL': options['--model'] ?? 'gpt-6-luna',
    'OPENAI_ROLE_CASES': options['--cases'] ?? '',
    'NEIROHA_ROLE_FIXTURES':
        options['--fixtures'] ?? 'scripts/tests/fixtures/role_assign',
  };
  stdout.writeln(
    replay
        ? 'Replaying captured roles offline; no inference requests.'
        : 'Running $suite against api.openai.com on '
              '${Platform.operatingSystem}; '
              '${suite == 'review'
                  ? 'limit: 6 calls / 40000 budgeted tokens, no retries'
                  : suite == 'roles'
                  ? 'limit: 72 structured calls'
                  : suite == 'text-roles'
                  ? 'shared USD 50 ledger required; no audio synthesis'
                  : 'native audio may play'}.',
  );
  try {
    final process = await Process.start(
      Platform.isWindows ? 'flutter.bat' : 'flutter',
      ['test', suites[suite]!, '--no-pub', '--reporter', 'expanded'],
      environment: environment,
      runInShell: Platform.isWindows,
    );
    Future<void> forward(Stream<List<int>> stream, IOSink sink) => stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) => sink.writeln(redactCredentials(line, key)));
    await Future.wait([
      forward(process.stdout, stdout),
      forward(process.stderr, stderr),
    ]);
    exitCode = await process.exitCode;
  } on ProcessException catch (error) {
    stderr.writeln(redactCredentials(error.message, key));
    exitCode = 69;
  }
}
