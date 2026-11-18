import 'package:flutter_test/flutter_test.dart';
import '../tools/run_live_tests.dart' as launcher;

void main() {
  test(
    'dotenv parsing preserves quoted credentials and never evaluates code',
    () {
      final values = launcher.parseEnvFile('''
# local configuration
export OPENAI_KEY="test-key=with=padding"
OPENAI_API_KEY='test-secondary'
EMPTY=
IGNORED
COMMAND=\$(touch /tmp/should-not-exist)
''');
      expect(values['OPENAI_KEY'], 'test-key=with=padding');
      expect(values['OPENAI_API_KEY'], 'test-secondary');
      expect(values['EMPTY'], isEmpty);
      expect(values['COMMAND'], r'$(touch /tmp/should-not-exist)');
      expect(values, isNot(contains('IGNORED')));
    },
  );

  test('redacts exact secrets and token-shaped values from process output', () {
    expect(
      launcher.redactCredentials(
        'failure: local-secret and sk-fake_token123',
        'local-secret',
      ),
      'failure: [REDACTED] and [REDACTED]',
    );
    expect(launcher.redactCredentials('sk-fake_token123', ''), '[REDACTED]');
  });
}
