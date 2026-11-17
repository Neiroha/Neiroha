import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/adapters/openai_tts_adapter.dart';
import 'package:neiroha/data/adapters/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/synthesis/synthesis_service.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/domain/synthesis/streaming_audio_sink.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';

const _format = TtsAudioFormat(
  AudioEncoding.pcmS16le,
  sampleRate: 22050,
  channels: 1,
);
const _request = TtsRequest(text: '测试原文', voice: 'marin');

db.TtsProvider _provider(String id, [String url = 'http://localhost']) =>
    db.TtsProvider(
      id: id,
      name: id,
      adapterType: 'openai',
      baseUrl: url,
      apiKey: '',
      defaultModelName: OpenAiTtsAdapter.defaultModel,
      enabled: true,
      position: 0,
      maxConcurrency: 1,
    );

class _Adapter extends TtsAdapter {
  _Adapter(this.events);
  final Stream<TtsEvent> Function() events;
  @override
  Stream<TtsEvent> synthesizeStream(
    TtsRequest request, {
    required TtsCancelToken cancellation,
  }) => events();
  @override
  Future<bool> healthCheck() async => true;
  @override
  Future<TtsResult> synthesize(TtsRequest request) =>
      throw UnimplementedError();
}

class _Sink implements StreamingAudioSink {
  final bytes = <int>[];
  bool stopped = false;
  bool ended = false;
  @override
  Future<void> open(TtsAudioFormat format) async => format.validate();
  @override
  Future<void> add(Uint8List chunk) async => bytes.addAll(chunk);
  @override
  Future<void> finish() async => ended = true;
  @override
  Future<void> stop() async => stopped = true;
  @override
  Future<void> pause(bool paused) async {}
  @override
  Future<void> get drained => Future.value();
  @override
  Duration get position => Duration.zero;
  @override
  Duration get bufferedUntil => Duration.zero;
  @override
  bool get isBuffering => false;
}

void main() {
  late Directory directory;
  final queue = TtsQueueService.instance;
  final service = SynthesisService(queue);
  setUp(
    () async =>
        directory = await Directory.systemTemp.createTemp('neiroha_stream_'),
  );
  tearDown(() async => directory.delete(recursive: true));

  test(
    'one request feeds sink before completion, slot held, WAV committed at EOF',
    () async {
      final controller = StreamController<TtsEvent>();
      final sink = _Sink();
      final provider = _provider('stream-lifetime');
      final token = TtsCancelToken();
      final result = service.generate(
        provider: provider,
        request: _request,
        outputBase: '${directory.path}/result',
        cancellation: token,
        sink: sink,
        adapter: _Adapter(() => controller.stream),
      );
      controller.add(const TtsAudioStarted(_format));
      controller.add(TtsAudioChunk(Uint8List.fromList([1, 0, 2, 0])));
      var secondStarted = false;
      final next = queue.enqueue(
        provider: provider,
        task: () async {
          secondStarted = true;
        },
      );
      await pumpEventQueue(times: 100);
      expect(sink.bytes, [1, 0, 2, 0]);
      expect(secondStarted, isFalse);
      expect(File('${directory.path}/result.wav').existsSync(), isFalse);
      controller.add(const TtsSynthesisCompleted());
      await controller.close();
      final receipt = await result;
      await next;
      expect(sink.ended, isTrue);
      final bytes = await File(receipt.audioPath).readAsBytes();
      expect(bytes.sublist(44), sink.bytes);
      expect(ByteData.sublistView(bytes).getUint32(24, Endian.little), 22050);
      expect(ByteData.sublistView(bytes).getUint32(40, Endian.little), 4);
      expect(directory.listSync().whereType<File>().length, 1);
    },
  );

  for (final mode in [
    'disconnect',
    'missing-completion',
    'cancel',
    'odd-pcm',
  ]) {
    test('$mode never commits partial audio and releases the queue', () async {
      final token = TtsCancelToken();
      final sink = _Sink();
      final adapter = _Adapter(() async* {
        yield const TtsAudioStarted(_format);
        yield TtsAudioChunk(
          Uint8List.fromList(mode == 'odd-pcm' ? [1] : [1, 0]),
        );
        if (mode == 'disconnect') throw const SocketException('disconnected');
        if (mode == 'cancel') token.cancel();
        if (mode == 'odd-pcm' || mode == 'cancel') {
          yield const TtsSynthesisCompleted();
        }
      });
      await expectLater(
        service.generate(
          provider: _provider(mode),
          request: _request,
          outputBase: '${directory.path}/bad',
          cancellation: token,
          sink: sink,
          adapter: adapter,
        ),
        throwsA(isA<Exception>()),
      );
      expect(directory.listSync(), isEmpty);
      expect(sink.stopped, isTrue);
      expect(
        queue.snapshot.running.where((t) => t.providerId == mode),
        isEmpty,
      );
    });
  }

  test(
    'interactive request overtakes queued prefetch without interrupting active work',
    () async {
      final provider = _provider('priority');
      final gate = Completer<void>();
      final order = <String>[];
      final first = queue.enqueue(provider: provider, task: () => gate.future);
      final background = queue.enqueue(
        provider: provider,
        task: () async => order.add('prefetch'),
      );
      final interactive = queue.enqueue(
        provider: provider,
        interactive: true,
        task: () async => order.add('play'),
      );
      gate.complete();
      await Future.wait([first, background, interactive]);
      expect(order, ['play', 'prefetch']);
    },
  );

  test(
    'Realtime yields first delta while upstream is waiting, cancellation closes socket',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final disconnected = Completer<void>();
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen(
          (message) {
            if (jsonDecode(message as String)['type'] == 'response.create') {
              socket.add(
                jsonEncode({
                  'type': 'response.output_audio.delta',
                  'delta': base64Encode([1, 0, 2, 0]),
                }),
              );
            }
          },
          onDone: () {
            if (!disconnected.isCompleted) disconnected.complete();
          },
        );
      });
      final provider = _provider(
        'realtime-cancel',
        'http://127.0.0.1:${server.port}/v1',
      );
      final adapter = OpenAiTtsAdapter(
        baseUrl: provider.baseUrl,
        apiKey: '',
        realtimeTimeout: const Duration(seconds: 3),
      );
      final token = TtsCancelToken();
      final firstChunk = Completer<void>();
      final events = <TtsEvent>[];
      final done = adapter
          .synthesizeStream(_request, cancellation: token)
          .forEach((event) {
            events.add(event);
            if (event is TtsAudioChunk && !firstChunk.isCompleted) {
              firstChunk.complete();
            }
          });
      final assertion = expectLater(
        done,
        throwsA(isA<TtsCancelledException>()),
      );
      await firstChunk.future.timeout(const Duration(seconds: 2));
      expect(events.whereType<TtsSynthesisCompleted>(), isEmpty);
      token.cancel();
      await assertion;
      await disconnected.future.timeout(const Duration(seconds: 2));
    },
  );

  test('Realtime timeout aborts pending synthesis', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      final ws = await WebSocketTransformer.upgrade(request);
      ws.listen((_) {});
    });
    final adapter = OpenAiTtsAdapter(
      baseUrl: 'http://127.0.0.1:${server.port}/v1',
      apiKey: '',
      realtimeTimeout: const Duration(milliseconds: 100),
    );
    await expectLater(
      adapter
          .synthesizeStream(_request, cancellation: TtsCancelToken())
          .drain<void>(),
      throwsA(isA<TimeoutException>()),
    );
  });
}
