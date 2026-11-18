import 'dart:typed_data';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'tts_adapter.dart';
import 'wav_utils.dart';
import 'package:neiroha/domain/capabilities/model_capability.dart';

/// Each request is a distinct utterance; PCM frames form one continuous
/// playback/cache stream. Any rate/channel change fails the entire cache.
class PcmSequenceAdapter extends TtsAdapter {
  PcmSequenceAdapter(this.adapter, this.requests, {this.beforeContinuation});
  final TtsAdapter adapter;
  final List<TtsRequest> requests;
  final Future<void> Function(TtsRequest)? beforeContinuation;
  @override
  bool get supportsStreaming => true;
  @override
  ServiceRoute get serviceRoute => adapter.serviceRoute;
  @override
  Future<bool> healthCheck() => adapter.healthCheck();
  @override
  Stream<TtsEvent> synthesizeStream(
    TtsRequest request, {
    required TtsCancelToken cancellation,
  }) async* {
    TtsAudioFormat? format;
    final usage = <String, Object?>{};
    if (requests.isEmpty) throw ArgumentError('No utterances to synthesize.');
    for (var index = 0; index < requests.length; index++) {
      final part = requests[index];
      if (index > 0) await beforeContinuation?.call(part);
      var started = false;
      var completed = false;
      var partBytes = 0;
      await for (final event in adapter.synthesizeStream(
        part,
        cancellation: cancellation,
      )) {
        cancellation.throwIfCancelled();
        if (completed) {
          throw const FormatException('Audio after utterance completion.');
        }
        switch (event) {
          case TtsAudioStarted(:final format):
            if (started || format.encoding != AudioEncoding.pcmS16le) {
              throw const FormatException(
                'Continuous utterances require declared PCM.',
              );
            }
            started = true;
            format.validate();
          case TtsAudioChunk():
            partBytes += event.bytes.length;
            if (!started) throw const FormatException('Audio before format.');
          case TtsSynthesisCompleted(usage: final partUsage):
            completed = true;
            for (final entry in partUsage.entries) {
              if (entry.value is num) {
                usage[entry.key] =
                    ((usage[entry.key] as num?) ?? 0) + (entry.value as num);
              }
            }
        }
        if (event is TtsAudioStarted) {
          if (format == null) {
            format = event.format;
            yield event;
          } else if (format.sampleRate != event.format.sampleRate ||
              format.channels != event.format.channels) {
            throw const FormatException(
              'Audio format changed between utterances.',
            );
          }
        } else if (event is TtsAudioChunk) {
          yield event;
        }
      }
      if (!started || !completed) {
        throw const FormatException('Incomplete utterance.');
      }
      if (partBytes == 0 || partBytes % (format!.channels! * 2) != 0) {
        throw const FormatException(
          'Incomplete PCM frame at utterance boundary.',
        );
      }
    }
    yield TtsSynthesisCompleted(usage: usage);
  }

  @override
  Future<TtsResult> synthesize(TtsRequest request) async {
    final bytes = BytesBuilder(copy: false);
    TtsAudioFormat? format;
    await for (final e in synthesizeStream(
      request,
      cancellation: TtsCancelToken(),
    )) {
      if (e is TtsAudioStarted) format = e.format;
      if (e is TtsAudioChunk) bytes.add(e.bytes);
    }
    return TtsResult(
      audioBytes: wrapPcmAsWav(
        bytes.takeBytes(),
        sampleRate: format!.sampleRate!,
        channels: format.channels!,
      ),
      contentType: 'audio/wav',
    );
  }
}
