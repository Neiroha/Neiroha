import 'dart:typed_data';

import 'package:neiroha/data/ai/protocols/audio/wav_utils.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/synthesis/streaming_audio_sink.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';

import 'package:neiroha/data/services/synthesis/sentence_speech_pipeline.dart';

import 'conversation_engine.dart';

export 'package:neiroha/data/services/synthesis/sentence_speech_pipeline.dart'
    show VoiceConversionStage;

/// Plays one reply. Without VC audio streams straight to the speakers; with
/// VC the reply is collected, then converted audio plays as it streams back
/// (Realtime replies; the companion converts per sentence in its pipeline).
class ReplyPlayer {
  ReplyPlayer(this.io, {this.conversion});
  final ConversationAudioIo io;
  final VoiceConversionStage? conversion;

  StreamingAudioSink? _sink;
  TtsAudioFormat? _format;
  final _collected = BytesBuilder(copy: false);
  TtsCancelToken _cancel = TtsCancelToken();

  bool get active => _format != null;

  Future<void> begin(TtsAudioFormat format) async {
    await stop();
    _cancel = TtsCancelToken();
    _format = format;
    if (conversion == null) {
      _sink = io.newSink();
      await _sink!.open(format);
    }
  }

  Future<void> add(Uint8List bytes) async {
    if (_format == null) return;
    if (conversion != null) {
      _collected.add(bytes);
    } else {
      await _sink?.add(bytes);
    }
  }

  /// Completes when the speakers have drained.
  Future<void> end() async {
    final format = _format;
    if (format == null) return;
    final vc = conversion;
    if (vc != null) {
      final raw = _collected.takeBytes();
      if (raw.isEmpty) return _reset();
      final input = AudioInput(
        format.encoding == AudioEncoding.pcmS16le
            ? wrapPcmAsWav(raw, sampleRate: format.sampleRate!)
            : raw,
        contentType: format.contentType,
        fileName: 'reply${format.extension}',
      );
      await for (final event in convertAsStream(
        vc.converter,
        input,
        targetVoice: vc.targetVoice,
        cancellation: _cancel,
      )) {
        if (_cancel.isCancelled) return;
        switch (event) {
          case TtsAudioStarted(:final format):
            _sink = io.newSink();
            await _sink!.open(format);
          case TtsAudioChunk(:final bytes):
            await _sink?.add(bytes);
          case TtsSynthesisCompleted():
            break;
        }
      }
      if (_cancel.isCancelled) return;
    }
    final sink = _sink;
    _format = null;
    if (sink == null) return;
    await sink.finish();
    await sink.drained;
    if (identical(_sink, sink)) _sink = null;
  }

  /// Barge-in: drop whatever is queued or playing.
  Future<void> stop() async {
    _cancel.cancel();
    final sink = _sink;
    _reset();
    await sink?.stop();
  }

  void _reset() {
    _sink = null;
    _format = null;
    _collected.clear();
  }
}
