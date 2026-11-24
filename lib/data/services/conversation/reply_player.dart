import 'dart:async';
import 'dart:typed_data';

import 'package:neiroha/data/ai/protocols/audio/wav_utils.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/synthesis/pcm_segmenter.dart';
import 'package:neiroha/domain/synthesis/streaming_audio_sink.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';

import 'package:neiroha/data/services/synthesis/sentence_speech_pipeline.dart';

import 'conversation_engine.dart';

export 'package:neiroha/data/services/synthesis/sentence_speech_pipeline.dart'
    show VoiceConversionStage;

/// Plays one reply.
///
/// - Without VC, audio streams straight to the speakers.
/// - With VC on a PCM reply, the audio is cut at short pauses and each
///   phrase is converted while the next one arrives (Realtime replies), so
///   converted speech starts after the first phrase, not the whole reply.
/// - With a converter that only returns encoded files and no decoder, the
///   reply is collected and converted once.
class ReplyPlayer {
  ReplyPlayer(this.io, {this.conversion, this.decode});
  final ConversationAudioIo io;
  final VoiceConversionStage? conversion;
  final AudioDecoder? decode;

  StreamingAudioSink? _sink;
  TtsAudioFormat? _format;
  final _collected = BytesBuilder(copy: false);
  TtsCancelToken _cancel = TtsCancelToken();

  // Phrase-by-phrase conversion state.
  PcmSegmenter? _segmenter;
  StreamController<String>? _phrases;
  final _clips = <String, Uint8List>{};
  var _next = 0;
  Future<void>? _converting;
  Object? _failure;
  StackTrace? _failureTrace;

  bool get active => _format != null;

  /// True when [end] still has to convert the whole collected reply.
  bool get convertsWholeReply => conversion != null && _segmenter == null;

  Future<void> begin(TtsAudioFormat format) async {
    await stop();
    _cancel = TtsCancelToken();
    _format = format;
    final vc = conversion;
    if (vc == null) {
      _sink = io.newSink();
      await _sink!.open(format);
    } else if (format.encoding == AudioEncoding.pcmS16le &&
        format.sampleRate != null &&
        canConvertPerSentence([vc], decode)) {
      _startPhrases(vc, format);
    }
  }

  void _startPhrases(VoiceConversionStage vc, TtsAudioFormat format) {
    _segmenter = PcmSegmenter(sampleRate: format.sampleRate!);
    final phrases = _phrases = StreamController<String>();
    final pipeline = SentenceSpeechPipeline(
      // Each "sentence" is a key into the clips cut so far.
      speak: (key, _) => Stream.fromIterable([
        TtsAudioStarted(format),
        TtsAudioChunk(_clips.remove(key)!),
        const TtsSynthesisCompleted(),
      ]),
      conversions: [vc],
      decode: decode,
    );
    final cancel = _cancel;
    // Errors are kept for [end]; a barge-in cancellation is not an error.
    _converting =
        () async {
          await for (final event in pipeline.run(
            phrases.stream,
            cancellation: cancel,
          )) {
            if (cancel.isCancelled) return;
            await _play(event);
          }
        }().catchError((Object error, StackTrace trace) {
          if (error is TtsCancelledException || cancel.isCancelled) return;
          _failure = error;
          _failureTrace = trace;
        });
  }

  void _queue(Uint8List clip) {
    final key = '${_next++}';
    _clips[key] = clip;
    _phrases?.add(key);
  }

  Future<void> _play(TtsEvent event) async {
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

  Future<void> add(Uint8List bytes) async {
    if (_format == null) return;
    final segmenter = _segmenter;
    if (segmenter != null) {
      segmenter.add(bytes).forEach(_queue);
    } else if (conversion != null) {
      _collected.add(bytes);
    } else {
      await _sink?.add(bytes);
    }
  }

  /// Completes when the speakers have drained.
  Future<void> end() async {
    final format = _format;
    if (format == null) return;
    if (_segmenter case final segmenter?) {
      if (segmenter.flush() case final rest?) _queue(rest);
      final queued = _next > 0;
      await _phrases?.close();
      await _converting;
      if (_cancel.isCancelled) return;
      final failure = _failure;
      // A reply with no audio at all has nothing to play.
      if (failure != null && (queued || failure is! FormatException)) {
        _reset();
        Error.throwWithStackTrace(failure, _failureTrace!);
      }
    } else if (conversion case final vc?) {
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
        await _play(event);
      }
      if (_cancel.isCancelled) return;
    }
    final sink = _sink;
    _format = null;
    _segmenter = null;
    if (sink == null) return;
    await sink.finish();
    await sink.drained;
    if (identical(_sink, sink)) _sink = null;
  }

  /// Barge-in: drop whatever is queued or playing.
  Future<void> stop() async {
    _cancel.cancel();
    final sink = _sink;
    final phrases = _phrases;
    _reset();
    if (phrases != null && !phrases.isClosed) unawaited(phrases.close());
    await sink?.stop();
  }

  void _reset() {
    _sink = null;
    _format = null;
    _collected.clear();
    _segmenter = null;
    _phrases = null;
    _clips.clear();
    _converting = null;
    _failure = null;
    _failureTrace = null;
    _next = 0;
  }
}
