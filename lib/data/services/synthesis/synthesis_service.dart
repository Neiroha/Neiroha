import 'package:neiroha/data/ai/registry/tts_adapter_factory.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:neiroha/data/ai/protocols/audio/wav_utils.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/domain/synthesis/streaming_audio_sink.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:neiroha/domain/capabilities/task_profile.dart';
import 'synthesis_routing.dart';

import 'audio_cache_writer.dart';
import 'package:neiroha/data/services/capabilities/capability_repository.dart';

class SynthesisReceipt {
  const SynthesisReceipt({
    required this.audioPath,
    required this.format,
    required this.elapsed,
    required this.firstAudio,
    required this.completion,
  });
  final String audioPath;
  final TtsAudioFormat format;
  final Duration elapsed;
  final Duration? firstAudio;
  final TtsSynthesisCompleted completion;
}

/// Shared queued use case. One upstream request feeds playback and disk;
/// callers publish database paths only after this returns successfully.
class SynthesisService {
  SynthesisService(this.queue, {this.capabilities});
  final TtsQueueService queue;
  final CapabilityRepository? capabilities;

  static const sessionAudioLimit = 32 * 1024 * 1024;

  /// The character's processing chain around [adapter], read when the
  /// task starts (current settings and capabilities).
  ///
  /// Whether a chain applies is decided once the queue admits the task: a
  /// chained task's lease takes only a concurrency slot, and every request
  /// the chain sends (each sentence, or the whole line) is counted in full
  /// right when it goes out, with the text actually sent. Waits end with
  /// the chain's own cancellation.
  Future<TtsAdapter> _chained(
    TtsAdapter adapter,
    TtsRequest request,
    db.TtsProvider provider,
    TtsCancelToken cancellation,
    _ChainDecision decision,
  ) async {
    // Whether to chain was decided at admission: a chain switched on while
    // queued does not wrap an adapter planned without it (a novel's fixed
    // audio sequence) and is not counted twice.
    if (await decision.leaseCounted) return adapter;
    final wrapped =
        await queue.voiceChains?.call(
          adapter,
          request,
          beforeRequest: (next, token) =>
              queue.accountContinuation(provider, next, token),
        ) ??
        adapter;
    // The chain was switched off after queueing: its one request still
    // counts.
    if (identical(wrapped, adapter)) {
      await queue.accountContinuation(provider, request, cancellation);
    }
    return wrapped;
  }

  Future<TtsResult> collectInMemory({
    required db.TtsProvider provider,
    required TtsRequest request,
    required TtsCancelToken cancellation,
    String? modelName,
    TtsAdapter? adapter,
    StreamingAudioSink? sink,
  }) {
    final decision = _ChainDecision(queue, request);
    return queue.enqueue(
      provider: provider,
      source: 'Quick TTS',
      label: request.text,
      estimatedTokens: queue.estimateTokens(request),
      cancelToken: cancellation,
      interactive: true,
      selfAccounting: decision.decide,
      task: () async {
        final transport = await _chained(
          adapter ?? synthesisAdapter(provider, modelName, null),
          request,
          provider,
          cancellation,
          decision,
        );
        final buffer = BytesBuilder(copy: false);
        try {
          final audio = await _readAudio(
            transport,
            request,
            cancellation,
            onStarted: (format) async => await sink?.open(format),
            onChunk: (bytes) async {
              if (buffer.length + bytes.length > sessionAudioLimit - 44) {
                throw const FormatException('Audio exceeded the 32 MiB limit.');
              }
              buffer.add(bytes);
              await sink?.add(bytes);
            },
          );
          await sink?.finish();
          cancellation.throwIfCancelled();
          final bytes = buffer.takeBytes();
          final format = audio.format;
          return TtsResult(
            audioBytes: format.encoding == AudioEncoding.pcmS16le
                ? wrapPcmAsWav(
                    bytes,
                    sampleRate: format.sampleRate!,
                    channels: format.channels!,
                  )
                : bytes,
            contentType: format.contentType,
          );
        } catch (_) {
          await sink?.stop();
          rethrow;
        }
      },
    );
  }

  /// File-oriented callers share event validation, cancellation and the cache
  /// writer. The temporary completed file is owned and removed by this call.
  Future<TtsResult> collect({
    required db.TtsProvider provider,
    required TtsRequest request,
    String? modelName,
    String source = 'TTS',
    String? label,
    TtsCancelToken? cancellation,
  }) async {
    final directory = await Directory.systemTemp.createTemp(
      'neiroha_synthesis_',
    );
    try {
      final result = await generate(
        provider: provider,
        request: request,
        modelName: modelName,
        outputBase: '${directory.path}/audio',
        cancellation: cancellation ?? TtsCancelToken(),
        source: source,
        label: label,
      );
      return TtsResult(
        audioBytes: await File(result.audioPath).readAsBytes(),
        contentType: result.format.contentType,
      );
    } finally {
      await directory.delete(recursive: true);
    }
  }

  Future<SynthesisReceipt> generate({
    required db.TtsProvider provider,
    required TtsRequest request,
    required String outputBase,
    required TtsCancelToken cancellation,
    String? modelName,
    String source = 'TTS',
    String? label,
    bool interactive = false,
    StreamingAudioSink? sink,
    TtsAdapter? adapter,
    TaskProfile? profile,
    void Function()? onFirstAudio,
  }) {
    final decision = _ChainDecision(queue, request);
    return queue.enqueue(
      provider: provider,
      source: source,
      label: label ?? request.text,
      estimatedTokens: queue.estimateTokens(request),
      cancelToken: cancellation,
      interactive: interactive,
      selfAccounting: decision.decide,
      task: () async {
        final transport = await _chained(
          adapter ?? synthesisAdapter(provider, modelName, profile),
          request,
          provider,
          cancellation,
          decision,
        );
        final receipt = await _consume(
          transport,
          request,
          outputBase,
          cancellation,
          sink,
          onFirstAudio,
        );
        try {
          await capabilities?.markSuccess(
            provider,
            profile?.model ?? ttsAdapterModel(provider, modelName),
            transport.serviceRoute,
            ['speech', if (transport.streamsAudioFor(request)) 'streaming'],
          );
        } catch (_) {
          /* Optional capability metadata cannot invalidate audio. */
        }
        return receipt;
      },
    );
  }

  Future<SynthesisReceipt> _consume(
    TtsAdapter adapter,
    TtsRequest request,
    String outputBase,
    TtsCancelToken cancellation,
    StreamingAudioSink? sink,
    void Function()? onFirstAudio,
  ) async {
    AudioCacheWriter? writer;
    try {
      final audio = await _readAudio(
        adapter,
        request,
        cancellation,
        onStarted: (format) async {
          final output = AudioCacheWriter(
            '$outputBase${format.extension}',
            format,
          );
          writer = output;
          await output.open();
          await sink?.open(format);
        },
        onChunk: (bytes) async {
          await writer!.add(bytes);
          await sink?.add(bytes);
        },
        onFirstAudio: onFirstAudio,
      );
      await sink?.finish();
      cancellation.throwIfCancelled();
      final path = await writer!.commit();
      return SynthesisReceipt(
        audioPath: path,
        format: audio.format,
        elapsed: audio.clock.elapsed,
        firstAudio: audio.firstAudio,
        completion: audio.completion,
      );
    } catch (_) {
      await sink?.stop();
      rethrow;
    } finally {
      await writer?.abort();
    }
  }

  Future<
    ({
      TtsAudioFormat format,
      Stopwatch clock,
      Duration? firstAudio,
      TtsSynthesisCompleted completion,
    })
  >
  _readAudio(
    TtsAdapter adapter,
    TtsRequest request,
    TtsCancelToken cancellation, {
    required Future<void> Function(TtsAudioFormat) onStarted,
    required Future<void> Function(Uint8List) onChunk,
    void Function()? onFirstAudio,
  }) async {
    final clock = Stopwatch()..start();
    Duration? firstAudio;
    TtsAudioFormat? format;
    TtsSynthesisCompleted? completed;
    var length = 0;
    await for (final event in adapter.synthesizeStream(
      request,
      cancellation: cancellation,
    )) {
      cancellation.throwIfCancelled();
      if (completed != null) {
        throw const FormatException('Audio after completion.');
      }
      switch (event) {
        case TtsAudioStarted(format: final next):
          if (format != null) {
            throw const FormatException('Duplicate audio start.');
          }
          next.validate();
          format = next;
          await onStarted(next);
        case TtsAudioChunk(:final bytes):
          if (format == null) {
            throw const FormatException('Audio before format.');
          }
          if (bytes.isEmpty) continue;
          if (firstAudio == null) {
            firstAudio = clock.elapsed;
            onFirstAudio?.call();
          }
          length += bytes.length;
          await onChunk(bytes);
        case TtsSynthesisCompleted():
          if (format == null) {
            throw const FormatException('Completion before format.');
          }
          completed = event;
      }
    }
    cancellation.throwIfCancelled();
    if (format == null || completed == null) {
      throw const FormatException('Synthesis ended without a complete result.');
    }
    if (length == 0) throw const FormatException('Empty synthesis audio.');
    if (format.encoding == AudioEncoding.pcmS16le &&
        length % (2 * format.channels!) != 0) {
      throw const FormatException('Incomplete PCM sample frame.');
    }
    return (
      format: format,
      clock: clock,
      firstAudio: firstAudio,
      completion: completed,
    );
  }
}

/// Whether a task's requests are counted by its processing chain, asked by
/// the queue only after it accepts the task.
class _ChainDecision {
  _ChainDecision(this.queue, this.request);
  final TtsQueueService queue;
  final TtsRequest request;
  Future<bool>? _chained;

  /// Without a cheap check, any installed chain hook decides (it counts a
  /// single request itself when it does not wrap).
  Future<bool> decide() => _chained =
      queue.hasVoiceChain?.call(request) ??
      Future.value(queue.voiceChains != null);

  /// True when the lease counted the task's request (no chain, or the
  /// check failed): the task then runs without a chain.
  Future<bool> get leaseCounted async {
    try {
      return !await (_chained ?? Future.value(false));
    } catch (_) {
      return true;
    }
  }
}
