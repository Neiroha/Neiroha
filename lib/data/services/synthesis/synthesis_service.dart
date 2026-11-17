import 'dart:io';
import 'package:neiroha/data/adapters/tts_adapter.dart';
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
  }) => queue.enqueue(
    provider: provider,
    source: source,
    label: label ?? request.text,
    estimatedTokens: queue.estimateTokens(request),
    cancelToken: cancellation,
    interactive: interactive,
    task: () async {
      final transport =
          adapter ?? synthesisAdapter(provider, modelName, profile);
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
          profile?.model ?? modelName ?? provider.defaultModelName,
          transport.serviceRoute,
          ['speech', if (transport.supportsStreaming) 'streaming'],
        );
      } catch (_) {
        /* Optional capability metadata cannot invalidate audio. */
      }
      return receipt;
    },
  );

  Future<SynthesisReceipt> _consume(
    TtsAdapter adapter,
    TtsRequest request,
    String outputBase,
    TtsCancelToken cancellation,
    StreamingAudioSink? sink,
    void Function()? onFirstAudio,
  ) async {
    final clock = Stopwatch()..start();
    Duration? firstAudio;
    AudioCacheWriter? writer;
    TtsAudioFormat? format;
    TtsSynthesisCompleted? completed;
    try {
      await for (final event in adapter.synthesizeStream(
        request,
        cancellation: cancellation,
      )) {
        cancellation.throwIfCancelled();
        if (completed != null) {
          throw const FormatException('Audio after completion.');
        }
        switch (event) {
          case TtsAudioStarted(:final format):
            if (writer != null) {
              throw const FormatException('Duplicate audio start.');
            }
            format.validate();
            writer = AudioCacheWriter('$outputBase${format.extension}', format);
            await writer.open();
            await sink?.open(format);
          case TtsAudioChunk(:final bytes):
            if (writer == null) {
              throw const FormatException('Audio before format.');
            }
            if (bytes.isEmpty) continue;
            if (firstAudio == null) {
              firstAudio = clock.elapsed;
              onFirstAudio?.call();
            }
            await writer.add(bytes);
            await sink?.add(bytes);
          case TtsSynthesisCompleted():
            if (writer == null) {
              throw const FormatException('Completion before format.');
            }
            completed = event;
        }
        if (event is TtsAudioStarted) format = event.format;
      }
      cancellation.throwIfCancelled();
      if (writer == null || format == null || completed == null) {
        throw const FormatException(
          'Synthesis ended without a complete result.',
        );
      }
      await sink?.finish();
      cancellation.throwIfCancelled();
      final path = await writer.commit();
      return SynthesisReceipt(
        audioPath: path,
        format: format,
        elapsed: clock.elapsed,
        firstAudio: firstAudio,
        completion: completed,
      );
    } catch (_) {
      await sink?.stop();
      rethrow;
    } finally {
      await writer?.abort();
    }
  }
}
