import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/data/services/synthesis/synthesis_service.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/domain/synthesis/tts_request.dart';

import 'support/pcm_test_adapters.dart';
import 'support/memory_audio_sink.dart';

void main() {
  const connection = TtsProvider(
    id: 'session-synthesis',
    name: 'Session synthesis',
    adapterType: 'openaiCompatible',
    baseUrl: 'http://127.0.0.1',
    apiKey: '',
    defaultModelName: 'demo',
    enabled: true,
    position: 0,
    maxConcurrency: 1,
  );
  late SynthesisService service;
  setUp(() {
    service = SynthesisService(TtsQueueService.instance);
  });

  test('session synthesis wraps complete PCM in a WAV in memory', () async {
    final sink = MemoryAudioSink();
    final result = await service.collectInMemory(
      provider: connection,
      request: const TtsRequest(text: '试听', voice: 'demo'),
      cancellation: TtsCancelToken(),
      adapter: FinitePcm(),
      sink: sink,
    );
    expect(result.contentType, 'audio/wav');
    expect(ascii.decode(result.audioBytes.take(4).toList()), 'RIFF');
    final header = ByteData.sublistView(result.audioBytes);
    expect(header.getUint32(24, Endian.little), 22050);
    expect(header.getUint16(22, Endian.little), 1);
    expect(result.audioBytes.sublist(44), [1, 0, 2, 0]);
    expect(sink.finished, isTrue);
    expect(sink.playbackEnded.isCompleted, isFalse);
  });

  test(
    'session synthesis rejects truncated streams without returning bytes',
    () {
      return expectLater(
        service.collectInMemory(
          provider: connection,
          request: const TtsRequest(text: '试听', voice: 'demo'),
          cancellation: TtsCancelToken(),
          adapter: FinitePcm(fail: true),
        ),
        throwsStateError,
      );
    },
  );

  test(
    'session synthesis plays incrementally and discards cancelled audio',
    () async {
      final token = TtsCancelToken();
      final adapter = StallingPcm();
      final sink = MemoryAudioSink();
      final result = service.collectInMemory(
        provider: connection,
        request: const TtsRequest(text: '试听', voice: 'demo'),
        cancellation: token,
        adapter: adapter,
        sink: sink,
      );
      final check = expectLater(result, throwsA(isA<TtsCancelledException>()));
      await sink.firstChunk.future.timeout(const Duration(seconds: 1));
      expect(sink.bytes.length, greaterThan(0));
      expect(sink.finished, isFalse);
      token.cancel();
      await check;
      expect(adapter.cancelled.isCompleted, isTrue);
      expect(sink.stopped, isTrue);
    },
  );
}
