import 'dart:async';
import 'dart:typed_data';
import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';

class StallingPcm extends TtsAdapter {
  final cancelled = Completer<void>();
  @override
  bool get supportsStreaming => true;
  @override
  Future<bool> healthCheck() async => true;
  @override
  Future<TtsResult> synthesize(TtsRequest request) =>
      throw UnimplementedError();
  @override
  Stream<TtsEvent> synthesizeStream(
    TtsRequest request, {
    required TtsCancelToken cancellation,
  }) async* {
    final remove = cancellation.onCancel(() {
      if (!cancelled.isCompleted) cancelled.complete();
    });
    try {
      yield const TtsAudioStarted(
        TtsAudioFormat(AudioEncoding.pcmS16le, sampleRate: 22050, channels: 1),
      );
      yield TtsAudioChunk(Uint8List.fromList([1, 0, 2, 0]));
      await cancelled.future;
      cancellation.throwIfCancelled();
    } finally {
      remove();
    }
  }
}

class FinitePcm extends StallingPcm {
  FinitePcm({this.fail = false});
  final bool fail;
  @override
  Stream<TtsEvent> synthesizeStream(
    TtsRequest request, {
    required TtsCancelToken cancellation,
  }) async* {
    yield const TtsAudioStarted(
      TtsAudioFormat(AudioEncoding.pcmS16le, sampleRate: 22050, channels: 1),
    );
    yield TtsAudioChunk(Uint8List.fromList([1, 0, 2, 0]));
    if (fail) throw StateError('upstream disconnected');
    yield const TtsSynthesisCompleted();
  }
}
