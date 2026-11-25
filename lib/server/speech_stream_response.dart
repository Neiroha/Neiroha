import 'package:neiroha/data/ai/registry/tts_adapter_factory.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:shelf/shelf.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/synthesis/synthesis_service.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/domain/synthesis/streaming_audio_sink.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'tracked_http_server.dart';

/// The API advertises PCM explicitly. Disconnect cancels this request only;
/// completed export/file requests keep their existing response contract.
Future<Response> streamSpeechResponse({
  required db.TtsProvider provider,
  required TtsRequest request,
  String? modelName,
  SynthesisService? service,
  TtsAdapter? adapter,
  Future<void>? clientClosed,
}) async {
  final transport = adapter ?? createAdapter(provider, modelName: modelName);
  if (!transport.supportsStreaming) {
    return Response(
      400,
      body: jsonEncode({
        'error': 'This provider does not support incremental PCM.',
      }),
      headers: {'content-type': 'application/json'},
    );
  }
  final cancellation = TtsCancelToken();
  final output = _HttpAudioSink(cancellation);
  if (clientClosed != null) {
    unawaited(
      clientClosed.then((_) {
        if (!output._finished) cancellation.cancel();
      }),
    );
  }
  final directory = await Directory.systemTemp.createTemp(
    'neiroha_api_stream_',
  );
  unawaited(() async {
    try {
      await (service ?? SynthesisService(TtsQueueService.instance)).generate(
        provider: provider,
        modelName: modelName,
        request: request,
        outputBase: '${directory.path}/audio',
        cancellation: cancellation,
        source: 'Local API',
        sink: output,
        adapter: transport,
        interactive: true,
      );
    } catch (error, stack) {
      output.fail(error, stack);
    } finally {
      await directory.delete(recursive: true);
    }
  }());
  final format = await output.format.future;
  return Response.ok(
    output.controller.stream,
    context: {
      'shelf.io.buffer_output': false,
      streamingResponseContextKey: true,
    },
    headers: {
      'content-type': 'audio/pcm',
      'cache-control': 'no-store',
      'x-audio-encoding': 'pcm_s16le',
      'x-audio-sample-rate': '${format.sampleRate}',
      'x-audio-channels': '${format.channels}',
      'access-control-expose-headers':
          'x-audio-encoding,x-audio-sample-rate,x-audio-channels',
    },
  );
}

class _HttpAudioSink implements StreamingAudioSink {
  _HttpAudioSink(this.cancellation) {
    controller = StreamController<List<int>>(
      onPause: () => _resume = Completer<void>(),
      onResume: () {
        _resume?.complete();
        _resume = null;
      },
      onCancel: () {
        if (!_finished) cancellation.cancel();
        _unblock();
      },
    );
  }
  final TtsCancelToken cancellation;
  late final StreamController<List<int>> controller;
  final format = Completer<TtsAudioFormat>();
  final _drained = Completer<void>();
  Completer<void>? _resume;
  bool _finished = false;
  @override
  Future<void> open(TtsAudioFormat value) async {
    if (value.encoding != AudioEncoding.pcmS16le) {
      throw const FormatException('Streaming endpoint requires PCM audio.');
    }
    format.complete(value);
  }

  @override
  Future<void> add(Uint8List bytes) async {
    while (_resume != null) {
      final cancelled = Completer<void>();
      final remove = cancellation.onCancel(() => cancelled.complete());
      try {
        await Future.any([_resume!.future, cancelled.future]);
      } finally {
        remove();
      }
      cancellation.throwIfCancelled();
    }
    cancellation.throwIfCancelled();
    controller.add(bytes);
  }

  @override
  Future<void> finish() async {
    _finished = true;
    await controller.close();
    _unblock();
  }

  @override
  Future<void> stop() async {
    _unblock();
    // The outer use case calls fail with the original error. Closing normally
    // here would turn truncated synthesis into a successful HTTP EOF.
  }

  void fail(Object error, StackTrace stack) {
    if (!format.isCompleted) {
      format.completeError(error, stack);
    } else if (!controller.isClosed && !cancellation.isCancelled) {
      // A disconnected consumer has no error listener left. Cancellation is
      // normal cleanup; only upstream failures should become body errors.
      controller.addError(error, stack);
    }
    if (!controller.isClosed) unawaited(controller.close());
    _unblock();
  }

  void _unblock() {
    if (_resume?.isCompleted == false) _resume!.complete();
    _resume = null;
    if (!_drained.isCompleted) _drained.complete();
  }

  @override
  Future<void> get drained => _drained.future;
  @override
  Duration get position => Duration.zero;
  @override
  Duration get bufferedUntil => Duration.zero;
  @override
  bool get isBuffering => false;
  @override
  Future<void> pause(bool paused) async {}
}
