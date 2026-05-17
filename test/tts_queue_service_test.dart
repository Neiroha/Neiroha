import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/adapters/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/tts_queue_service.dart';

void main() {
  db.TtsProvider provider({
    required String id,
    int maxConcurrency = 1,
    int? requestsPerMinute,
    int? tokensPerMinute,
  }) {
    return db.TtsProvider(
      id: id,
      name: id,
      adapterType: 'openaiCompatible',
      baseUrl: 'http://localhost',
      apiKey: '',
      defaultModelName: 'tts-1',
      enabled: true,
      position: 0,
      maxConcurrency: maxConcurrency,
      requestsPerMinute: requestsPerMinute,
      tokensPerMinute: tokensPerMinute,
    );
  }

  test('estimateTokens combines request text and style fields', () {
    final service = TtsQueueService.instance;

    final plain = service.estimateTokens(
      const TtsRequest(text: 'hello world', voice: 'voice'),
    );
    final styled = service.estimateTokens(
      const TtsRequest(
        text: 'hello world',
        voice: 'voice',
        audioTagPrefix: '(excited)',
        voiceInstruction: 'speak warmly',
        promptText: 'reference style',
      ),
    );

    expect(plain, greaterThan(1));
    expect(styled, greaterThan(plain));
  });

  test('enqueue respects provider maxConcurrency', () async {
    final service = TtsQueueService.instance;
    final testProvider = provider(
      id: 'queue-concurrency-${DateTime.now().microsecondsSinceEpoch}',
      maxConcurrency: 1,
    );
    final started = <String>[];
    final firstGate = Completer<String>();
    final secondGate = Completer<String>();

    final first = service.enqueue<String>(
      provider: testProvider,
      label: 'first guarded task',
      task: () {
        started.add('first');
        return firstGate.future;
      },
    );
    final second = service.enqueue<String>(
      provider: testProvider,
      label: 'second guarded task',
      task: () {
        started.add('second');
        return secondGate.future;
      },
    );

    await pumpEventQueue();
    expect(started, ['first']);
    expect(
      service.snapshot.running.where(
        (task) => task.providerId == testProvider.id,
      ),
      hasLength(1),
    );
    expect(
      service.snapshot.queued.where(
        (task) => task.providerId == testProvider.id,
      ),
      hasLength(1),
    );

    firstGate.complete('first done');
    expect(await first, 'first done');
    await pumpEventQueue();
    expect(started, ['first', 'second']);
    expect(
      service.snapshot.running.where(
        (task) => task.providerId == testProvider.id,
      ),
      hasLength(1),
    );
    expect(
      service.snapshot.queued.where(
        (task) => task.providerId == testProvider.id,
      ),
      isEmpty,
    );

    secondGate.complete('second done');
    expect(await second, 'second done');
    await pumpEventQueue();
    expect(
      service.snapshot.running.where(
        (task) => task.providerId == testProvider.id,
      ),
      isEmpty,
    );
  });

  test('failed tasks are recorded in recent snapshot with an error', () async {
    final service = TtsQueueService.instance;
    final testProvider = provider(
      id: 'queue-failure-${DateTime.now().microsecondsSinceEpoch}',
    );

    final failed = service.enqueue<void>(
      provider: testProvider,
      label: 'expected failure task',
      task: () async => throw StateError('planned failure'),
    );

    await expectLater(failed, throwsA(isA<StateError>()));
    await pumpEventQueue();

    final recent = service.snapshot.recent.firstWhere(
      (task) =>
          task.providerId == testProvider.id &&
          task.label == 'expected failure task',
    );
    expect(recent.status, TtsQueueTaskStatus.failed);
    expect(recent.errorMessage, contains('planned failure'));
  });
}
