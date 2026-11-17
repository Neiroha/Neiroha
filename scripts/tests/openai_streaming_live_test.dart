// Opt-in only. Use scripts/tools/test_openai_streaming.ps1 to load the local .env.
// API credentials are never included in audio or measurement artifacts.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/adapters/openai_tts_adapter.dart';
import 'package:neiroha/data/adapters/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/synthesis/soloud_audio_sink.dart';
import 'package:neiroha/data/services/synthesis/synthesis_service.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'support/test_capabilities.dart';

void main() {
  final key = Platform.environment['OPENAI_TEST_API_KEY'] ?? '';
  final enabled =
      Platform.environment['NEIROHA_LIVE_STREAMING'] == '1' && key.isNotEmpty;
  final unavailable = TestCapabilities.current().nativeAudioUnavailableReason;
  final skip = !enabled
      ? 'Explicit live streaming opt-in and API key required'
      : unavailable ?? false;
  final output = Directory(
    Platform.environment['OPENAI_TEST_OUT_DIR'] ?? '.dart_tool/live-streaming',
  );
  if (enabled && unavailable == null) {
    // Native audio needs a binding; retain the real HTTP implementation for
    // these explicitly enabled live tests instead of the widget-test mock.
    final http = HttpOverrides.current;
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = http;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => Directory.systemTemp.path,
        );
  }
  const text = '指挥官，这是 Neiroha 的流式语音测试。音频应当边生成边播放。现在稍作停顿，然后继续朗读，直到本段完整结束。';
  db.TtsProvider provider(String model) => db.TtsProvider(
    id: 'live-$model',
    name: 'Live test',
    adapterType: 'openaiTts',
    baseUrl: OpenAiTtsAdapter.defaultBaseUrl,
    apiKey: key,
    defaultModelName: model,
    enabled: true,
    position: 0,
    maxConcurrency: 1,
  );

  for (final model in ['gpt-4o-mini-tts', 'gpt-realtime-2.1-mini']) {
    test(
      'live streamed playback and complete cache: $model',
      () async {
        await output.create(recursive: true);
        final sink = SoloudAudioSink();
        addTearDown(sink.stop);
        final cancellation = TtsCancelToken();
        final started = Stopwatch()..start();
        final audible = Completer<int>();
        final polling = Timer.periodic(const Duration(milliseconds: 10), (_) {
          if (!audible.isCompleted && sink.position > Duration.zero) {
            audible.complete(started.elapsedMilliseconds);
          }
        });
        addTearDown(polling.cancel);
        final job = SynthesisService(TtsQueueService.instance).generate(
          provider: provider(model),
          modelName: model,
          request: const TtsRequest(
            text: text,
            voice: 'marin',
            presetVoiceName: 'marin',
            responseFormat: 'pcm',
          ),
          outputBase: '${output.path}/$model',
          cancellation: cancellation,
          sink: sink,
          adapter: OpenAiTtsAdapter(
            baseUrl: OpenAiTtsAdapter.defaultBaseUrl,
            apiKey: key,
            modelName: model,
            realtimeTimeout: const Duration(seconds: 50),
          ),
        );
        // Attach an error handler immediately while waiting for audible playback.
        final receiptOrError = job.then<Object>(
          (r) => r,
          onError: (Object e) => e,
        );
        final first = await Future.any<Object>([
          audible.future,
          receiptOrError,
        ]);
        if (first is! int && first is! SynthesisReceipt) {
          throw first;
        }
        final receiptValue = await receiptOrError;
        if (receiptValue is! SynthesisReceipt) throw receiptValue;
        final receipt = receiptValue;
        final firstPlayback = audible.isCompleted
            ? await audible.future
            : await audible.future.timeout(const Duration(seconds: 10));
        expect(receipt.firstAudio, isNotNull);
        expect(receipt.firstAudio!, lessThan(receipt.elapsed));
        expect(
          firstPlayback,
          lessThan(receipt.elapsed.inMilliseconds),
          reason: 'Native audio should start before upstream EOF.',
        );
        await sink.pause(true);
        final paused = sink.position;
        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect((sink.position - paused).inMilliseconds.abs(), lessThan(70));
        await sink.pause(false);
        await sink.drained.timeout(const Duration(seconds: 35));
        final bytes = await File(receipt.audioPath).readAsBytes();
        expect(ascii.decode(bytes.sublist(0, 4)), 'RIFF');
        expect(bytes.length, greaterThan(44 + 24000));
        expect(receipt.format.encoding, AudioEncoding.pcmS16le);
        final metrics = {
          'model': model,
          'firstChunkMs': receipt.firstAudio!.inMilliseconds,
          'firstPlaybackMs': firstPlayback,
          'generationMs': receipt.elapsed.inMilliseconds,
          'playbackEndMs': started.elapsedMilliseconds,
          'sampleRate': receipt.format.sampleRate,
          'channels': receipt.format.channels,
          'bytes': bytes.length,
          'usage': receipt.completion.usage,
        };
        await File(
          '${output.path}/$model.metrics.json',
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(metrics));
        // Only public model names and measurements; never print connection data.
        // ignore: avoid_print
        print(jsonEncode(metrics));
      },
      skip: skip,
      timeout: const Timeout(Duration(seconds: 100)),
    );
  }

  test(
    'live cancellation stops native audio and discards incomplete cache',
    () async {
      await output.create(recursive: true);
      final directory = await output.createTemp('cancel_');
      final sink = SoloudAudioSink();
      addTearDown(sink.stop);
      final cancellation = TtsCancelToken();
      final first = Completer<void>();
      const model = 'gpt-realtime-2.1-mini';
      final task = SynthesisService(TtsQueueService.instance).generate(
        provider: provider(model),
        request: TtsRequest(
          text: List.filled(6, text).join(),
          voice: 'marin',
          presetVoiceName: 'marin',
        ),
        outputBase: '${directory.path}/incomplete',
        cancellation: cancellation,
        sink: sink,
        onFirstAudio: () {
          if (!first.isCompleted) first.complete();
        },
        adapter: OpenAiTtsAdapter(
          baseUrl: OpenAiTtsAdapter.defaultBaseUrl,
          apiKey: key,
          modelName: model,
          realtimeTimeout: const Duration(seconds: 50),
        ),
      );
      final outcome = task.then<Object>((r) => r, onError: (Object e) => e);
      final firstOrError = await Future.any<Object>([
        first.future.then<Object>((_) => true),
        outcome,
      ]);
      if (firstOrError is! bool) throw firstOrError;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final timer = Stopwatch()..start();
      cancellation.cancel();
      expect(
        await outcome.timeout(const Duration(seconds: 3)),
        isA<TtsCancelledException>(),
      );
      await sink.drained.timeout(const Duration(seconds: 1));
      expect(directory.listSync(), isEmpty);
      await File('${output.path}/cancellation.metrics.json').writeAsString(
        jsonEncode({
          'model': model,
          'cancelMs': timer.elapsedMilliseconds,
          'incompleteCacheFiles': 0,
        }),
      );
      await directory.delete();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 70)),
  );
}
