import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:neiroha/data/ai/protocols/audio/pcm_resample.dart';
import 'package:neiroha/data/ai/protocols/audio/wav_utils.dart';
import 'package:neiroha/domain/ai/media/audio_input.dart';
import 'package:neiroha/domain/ai/models/voice_converter.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';

import 'clip_stages.dart';

export 'clip_stages.dart';

/// Unpacks an encoded clip (MP3, Ogg…) to 16-bit PCM, e.g. with FFmpeg.
typedef AudioDecoder =
    Future<WavPcm> Function(Uint8List bytes, TtsAudioFormat format);

/// Audio the pipeline cannot turn into PCM (no [AudioDecoder] available).
class UndecodableAudioException extends FormatException {
  const UndecodableAudioException(super.message);
}

/// Whether [stages] can run per sentence: each converter streams PCM, or
/// encoded output can be decoded. Otherwise convert the whole reply once.
bool canConvertPerSentence(List<ClipStage> stages, AudioDecoder? decode) =>
    decode != null ||
    stages.whereType<VoiceConversionStage>().every(
      (s) => s.converter is StreamingVoiceConverter,
    );

/// Speaks one sentence with the character's own voice.
typedef SentenceSpeaker =
    Stream<TtsEvent> Function(String sentence, TtsCancelToken cancellation);

/// Turns a stream of sentences into one continuous PCM stream:
///
///   sentence ─▶ TTS ─▶ [VC …] ─▶ PCM ─┐
///   sentence ─▶ TTS ─▶ [VC …] ─▶ PCM ─┼─▶ in order ─▶ speakers / file
///   …                                 ┘
///
/// Sentence *n* plays while up to [lookahead] later sentences are already
/// being synthesized and converted. At most [ttsConcurrency] sentences are
/// in TTS at once: a local engine on one GPU answers the first sentence
/// fastest when it is not also working on the second, so by default TTS of
/// sentence *n+1* overlaps VC and playback of sentence *n*, not its TTS. The first sentence's sample rate and
/// channel count fix the output; later sentences are resampled to it.
/// TTS audio must be PCM or WAV; VC receives each sentence as one WAV clip
/// (padded to [minClip], since converters reject very short input) and its
/// streamed PCM is forwarded as it arrives.
class SentenceSpeechPipeline {
  SentenceSpeechPipeline({
    required this.speak,
    this.conversions = const [],
    this.lookahead = 1,
    this.ttsConcurrency = 1,
    this.minClip = const Duration(milliseconds: 250),
    this.onSentence,
    this.decode,
  });

  final SentenceSpeaker speak;

  /// Audio stages for every sentence, in order (VC, trim, ASR check).
  final List<ClipStage> conversions;
  final int lookahead;
  final int ttsConcurrency;
  final Duration minClip;

  /// Called when a sentence starts playing (for captions).
  final void Function(String sentence)? onSentence;

  /// Decoder for encoded TTS / VC output; without one only PCM and WAV work.
  final AudioDecoder? decode;

  Stream<TtsEvent> run(
    Stream<String> sentences, {
    required TtsCancelToken cancellation,
  }) async* {
    // Local token: an error or an abandoned listener stops every sentence.
    final local = TtsCancelToken();
    final unbind = cancellation.onCancel(local.cancel);
    final jobs = StreamController<_Sentence>();
    final slots = _Slots(lookahead + 1);
    final tts = _Slots(ttsConcurrency);
    unawaited(() async {
      try {
        await for (final text in sentences) {
          local.throwIfCancelled();
          if (text.trim().isEmpty) continue;
          await slots.acquire();
          if (local.isCancelled) break;
          final job = _Sentence(text.trim());
          jobs.add(job);
          // The slot frees once the sentence has been read out below, so a
          // listener that stops reading also stops new sentences.
          unawaited(job.run(this, tts, local));
        }
      } catch (error, stack) {
        if (!jobs.isClosed) jobs.addError(error, stack);
      } finally {
        await jobs.close();
      }
    }());

    TtsAudioFormat? format;
    var spoken = 0;
    try {
      await for (final job in jobs.stream) {
        local.throwIfCancelled();
        onSentence?.call(job.text);
        await for (final pcm in job.audio.stream) {
          local.throwIfCancelled();
          if (format == null) {
            format = TtsAudioFormat(
              AudioEncoding.pcmS16le,
              sampleRate: pcm.rate,
              channels: pcm.channels,
            );
            yield TtsAudioStarted(format);
          }
          final out = conformPcm(
            pcm.bytes,
            fromRate: pcm.rate,
            fromChannels: pcm.channels,
            toRate: format.sampleRate!,
            toChannels: format.channels!,
          );
          if (out.isEmpty) continue;
          spoken += out.length;
          yield TtsAudioChunk(out);
        }
        slots.release();
      }
      local.throwIfCancelled();
      if (spoken == 0) throw const FormatException('Nothing to speak.');
      yield const TtsSynthesisCompleted();
    } finally {
      local.cancel();
      unbind();
      slots.dispose();
      tts.dispose();
    }
  }

  /// One sentence's audio as PCM pieces. The TTS slot is held only while
  /// the engine is speaking this sentence.
  Stream<_Pcm> _sentence(
    String text,
    _Slots tts,
    TtsCancelToken cancellation,
  ) async* {
    await tts.acquire();
    var held = true;
    void release() {
      if (held) tts.release();
      held = false;
    }

    _Pcm clip;
    try {
      cancellation.throwIfCancelled();
      final spoken = speak(text, cancellation);
      if (conversions.isEmpty) {
        yield* _decode(spoken);
        return;
      }
      // VC needs the whole sentence as one clip.
      clip = await _wholeClip(spoken);
    } finally {
      release();
    }
    for (var i = 0; i < conversions.length; i++) {
      cancellation.throwIfCancelled();
      switch (conversions[i]) {
        case SilenceTrimStage trim:
          clip = _Pcm(
            trim.apply(clip.bytes, clip.rate, clip.channels),
            clip.rate,
            clip.channels,
          );
        case SpeechCheckStage check:
          // Beside playback: the sentence plays while it is transcribed. Not
          // tied to the line's token, which is cancelled once playback ends.
          unawaited(check.checkPcm(text, clip.bytes, clip.rate, clip.channels));
        case VoiceConversionStage stage:
          final converted = convertAsStream(
            stage.converter,
            AudioInput(
              _padded(clip),
              fileName: 'sentence.wav',
              contentType: 'audio/wav',
            ),
            targetVoice: stage.targetVoice,
            cancellation: cancellation,
          );
          if (i == conversions.length - 1) {
            yield* _decode(converted);
            return;
          }
          clip = await _wholeClip(converted);
      }
    }
    yield clip;
  }

  Future<_Pcm> _wholeClip(Stream<TtsEvent> events) async {
    final builder = BytesBuilder(copy: false);
    int? rate;
    int? channels;
    await for (final pcm in _decode(events)) {
      if (rate != null && (pcm.rate != rate || pcm.channels != channels)) {
        throw const FormatException('Audio layout changed mid-sentence.');
      }
      rate = pcm.rate;
      channels = pcm.channels;
      builder.add(pcm.bytes);
    }
    if (rate == null) throw const FormatException('Sentence had no audio.');
    return _Pcm(builder.takeBytes(), rate, channels!);
  }

  Uint8List _padded(_Pcm clip) {
    final minBytes =
        clip.rate * clip.channels * 2 * minClip.inMilliseconds ~/ 1000;
    final bytes = clip.bytes.length >= minBytes
        ? clip.bytes
        : (Uint8List(minBytes)..setRange(0, clip.bytes.length, clip.bytes));
    return wrapPcmAsWav(bytes, sampleRate: clip.rate, channels: clip.channels);
  }

  /// PCM events pass through; whole WAV files are unpacked.
  Stream<_Pcm> _decode(Stream<TtsEvent> events) async* {
    TtsAudioFormat? format;
    final file = BytesBuilder(copy: false);
    await for (final event in events) {
      switch (event) {
        case TtsAudioStarted():
          format = event.format..validate();
        case TtsAudioChunk():
          final f = format;
          if (f == null) throw const FormatException('Audio before format.');
          if (f.encoding == AudioEncoding.pcmS16le) {
            yield _Pcm(event.bytes, f.sampleRate!, f.channels!);
          } else {
            file.add(event.bytes);
          }
        case TtsSynthesisCompleted():
          break;
      }
    }
    if (format == null) throw const FormatException('Sentence had no audio.');
    if (format.encoding == AudioEncoding.pcmS16le) return;
    final bytes = file.takeBytes();
    final WavPcm wav;
    if (format.encoding == AudioEncoding.wav || isRiffWav(bytes)) {
      wav = parsePcmWav(bytes);
    } else if (decode case final decoder?) {
      wav = await decoder(bytes, format);
    } else {
      throw UndecodableAudioException(
        'Sentence streaming needs PCM or WAV audio, got '
        '${format.encoding.name}.',
      );
    }
    yield _Pcm(wav.pcm, wav.sampleRate, wav.channels);
  }
}

/// Converts PCM16 between layouts: stereo is averaged to mono, mono is
/// duplicated to stereo, then the rate is resampled.
Uint8List conformPcm(
  Uint8List pcm, {
  required int fromRate,
  required int fromChannels,
  required int toRate,
  required int toChannels,
}) {
  if (fromRate == toRate && fromChannels == toChannels) return pcm;
  Int16List samples(Uint8List bytes) {
    final aligned = bytes.offsetInBytes.isEven
        ? bytes
        : Uint8List.fromList(bytes);
    return Int16List.sublistView(aligned, 0, aligned.length & ~1);
  }

  var mono = pcm;
  if (fromChannels == 2) {
    final input = samples(pcm);
    final out = Int16List(input.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = (input[2 * i] + input[2 * i + 1]) ~/ 2;
    }
    mono = out.buffer.asUint8List();
  }
  final resampled = resamplePcm16(mono, fromRate, toRate);
  if (toChannels == 1) return resampled;
  final input = samples(resampled);
  final out = Int16List(input.length * 2);
  for (var i = 0; i < input.length; i++) {
    out[2 * i] = input[i];
    out[2 * i + 1] = input[i];
  }
  return out.buffer.asUint8List();
}

class _Pcm {
  const _Pcm(this.bytes, this.rate, this.channels);
  final Uint8List bytes;
  final int rate;
  final int channels;
}

/// One sentence in flight. Generation runs eagerly; [audio] buffers what is
/// produced until the player reaches this sentence.
class _Sentence {
  _Sentence(this.text);
  final String text;
  final audio = StreamController<_Pcm>();

  Future<void> run(
    SentenceSpeechPipeline p,
    _Slots tts,
    TtsCancelToken cancellation,
  ) async {
    try {
      await for (final pcm in p._sentence(text, tts, cancellation)) {
        audio.add(pcm);
      }
    } catch (error, stack) {
      audio.addError(error, stack);
    } finally {
      // Not awaited: `close` completes only once the player drains it.
      unawaited(audio.close());
    }
  }
}

/// A counting semaphore bounding sentences in flight.
class _Slots {
  _Slots(this._free);
  int _free;
  final _waiting = Queue<Completer<void>>();

  Future<void> acquire() {
    if (_free > 0) {
      _free--;
      return Future.value();
    }
    final waiter = Completer<void>();
    _waiting.add(waiter);
    return waiter.future;
  }

  void release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
    } else {
      _free++;
    }
  }

  /// Wakes producers waiting on a finished pipeline.
  void dispose() {
    while (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
    }
  }
}
