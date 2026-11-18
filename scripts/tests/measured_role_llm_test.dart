import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'support/measured_role_llm.dart';

void main() {
  const entry = {
    'stage': 'test',
    'output': {'ok': true},
    'finishReason': 'stop',
    'format': 'json_schema',
    'usage': {'total_tokens': 100},
  };
  test(
    'pure offline replay never falls back to another inference request',
    () async {
      var before = 0;
      final records = <Map<String, Object?>>[];
      final client = MeasuredRoleLlm(
        '',
        'gpt-6-luna',
        records.add,
        () => before++,
        replay: [entry],
      );
      final result = await client.structured(
        messages: [],
        schemaName: 'test',
        schema: {},
        cancellation: TtsCancelToken(),
      );
      expect(result.object, {'ok': true});
      client.verifyReplayComplete();
      await expectLater(
        client.structured(
          messages: [],
          schemaName: 'test',
          schema: {},
          cancellation: TtsCancelToken(),
        ),
        throwsStateError,
      );
      expect(before, 0);
      expect(records.single['replayed'], isTrue);
    },
  );
  test(
    'paid continuation reconstructs saved stages before asking permission from the shared call gate',
    () async {
      var calls = 0;
      final client = MeasuredRoleLlm('', 'gpt-6-luna', (_) {}, () {
        calls++;
        throw StateError('No network in this unit test.');
      }, paidPrefix: [entry]);
      await client.structured(
        messages: [],
        schemaName: 'test',
        schema: {},
        cancellation: TtsCancelToken(),
      );
      expect(calls, 0);
      client.verifyReplayComplete();
      await expectLater(
        client.structured(
          messages: [],
          schemaName: 'next',
          schema: {},
          cancellation: TtsCancelToken(),
        ),
        throwsStateError,
      );
      expect(calls, 1);
    },
  );
  test('stage mismatches refuse replay before any network gate', () async {
    var calls = 0;
    final client = MeasuredRoleLlm(
      '',
      'gpt-6-luna',
      (_) {},
      () => calls++,
      paidPrefix: [entry],
    );
    await expectLater(
      client.structured(
        messages: [],
        schemaName: 'different',
        schema: {},
        cancellation: TtsCancelToken(),
      ),
      throwsStateError,
    );
    expect(calls, 0);
  });
}
