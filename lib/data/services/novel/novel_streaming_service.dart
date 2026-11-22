import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:neiroha/data/ai/protocols/audio/pcm_sequence_adapter.dart';
import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/auto_loudness_service.dart';
import 'package:neiroha/data/services/capabilities/task_profile_repository.dart';
import 'package:neiroha/data/services/synthesis/synthesis_routing.dart';
import 'package:neiroha/data/services/synthesis/synthesis_service.dart';
import 'package:neiroha/data/storage/novel_text_filter_rules_service.dart';
import 'package:neiroha/data/storage/path_service.dart';
import 'package:neiroha/data/storage/storage_service.dart';
import 'package:neiroha/domain/capabilities/model_capability.dart';
import 'package:neiroha/domain/capabilities/task_profile.dart';
import 'package:neiroha/domain/synthesis/streaming_audio_sink.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:uuid/uuid.dart';

import 'character_repository.dart';
import 'novel_audio_fingerprint.dart';
import 'novel_audio_tools.dart';
import 'novel_synthesis_binding.dart';
import 'novel_voice_resolution.dart';

class NovelStreamPlan {
  const NovelStreamPlan(
    this.project,
    this.segment,
    this.binding,
    this.adapter,
    this.cacheKey,
    this.chunks,
  );
  final db.NovelProject project;
  final db.NovelSegment segment;
  final NovelSynthesisBinding binding;
  final TtsAdapter adapter;
  final String cacheKey;
  final List<String> chunks;
  bool get canStream =>
      adapter.supportsStreaming &&
      {
        ServiceRoute.speech,
        ServiceRoute.realtime,
      }.contains(adapter.serviceRoute);
  String? get cachedPath =>
      !segment.missing &&
          segment.audioCacheKey == cacheKey &&
          segment.audioPath != null &&
          File(segment.audioPath!).existsSync()
      ? segment.audioPath
      : null;
}

/// Current sentence streaming and prefetch share one complete cache job.
/// Legacy protocols continue through the existing full-sentence path.
class NovelStreamingService {
  NovelStreamingService(
    this.database,
    this.storage,
    this.synthesis,
    this.loudness,
  );
  final db.AppDatabase database;
  final StorageService storage;
  final SynthesisService synthesis;
  final AutoLoudnessService loudness;
  final _jobs = <String, Future<SynthesisReceipt>>{};

  Future<NovelStreamPlan> prepare(
    db.NovelProject project,
    db.NovelSegment segment,
  ) async {
    final roles = await CharacterRepository(database).load(project.id);
    final members = await database.getBankMembers(project.bankId);
    final direction = resolveNovelSegmentVoice(
      project: project,
      segment: segment,
      roles: roles,
      availableVoiceIds: members.map((m) => m.voiceAssetId),
    );
    var asset = await database.getVoiceAssetById(direction.voiceAssetId ?? '');
    if (asset == null) {
      throw StateError('Select a voice from the novel voice bank.');
    }
    if (direction.instruction != null) {
      asset = asset.copyWith(voiceInstruction: Value(direction.instruction));
    }
    final providers = await database.getAllProviders();
    final provider = providers
        .where((p) => p.id == asset!.providerId)
        .firstOrNull;
    if (provider == null) throw StateError('Voice connection was deleted.');
    final profile = (await TaskProfileRepository(
      database,
    ).load(project.id)).where((p) => p.task == ModelTask.synthesis).firstOrNull;
    final binding = NovelSynthesisBinding.resolve(
      asset,
      provider,
      providers,
      profile,
    );
    final rules = await NovelTextFilterRulesService(database).load();
    final text = NovelTextFilterRulesService.applyFilters(
      segment.segmentText,
      rules,
    );
    if (text.trim().isEmpty) throw StateError('No text remains after filters.');
    final key = NovelAudioFingerprint.build(
      project: project,
      segment: segment,
      asset: binding.asset,
      provider: binding.provider,
      protocolSignature: profile == null ? '' : jsonEncode(profile.toJson()),
      textFilterSignature: NovelTextFilterRulesService.signature(rules),
    );
    return NovelStreamPlan(
      project,
      segment,
      binding,
      synthesisAdapter(binding.provider, binding.asset.modelName, profile),
      key,
      NovelAudioTools.chunks(
        text,
        autoSlice: project.autoSliceLongSegments,
        maxSliceChars: project.maxSliceChars,
        punctuationOnly: project.sliceOnlyAtPunctuation,
      ),
    );
  }

  Future<SynthesisReceipt> generate(
    NovelStreamPlan plan, {
    required TtsCancelToken cancellation,
    StreamingAudioSink? sink,
    void Function()? onFirstAudio,
  }) {
    final key = '${plan.segment.id}:${plan.cacheKey}';
    final existing = _jobs[key];
    if (existing != null) return _join(existing, cancellation, sink);
    final job = _generate(plan, cancellation, sink, onFirstAudio);
    _jobs[key] = job;
    return job.whenComplete(() {
      if (identical(_jobs[key], job)) _jobs.remove(key);
    });
  }

  Future<SynthesisReceipt> _join(
    Future<SynthesisReceipt> job,
    TtsCancelToken cancellation,
    StreamingAudioSink? sink,
  ) async {
    final cancelled = Completer<SynthesisReceipt>();
    final remove = cancellation.onCancel(
      () => cancelled.completeError(const TtsCancelledException()),
    );
    try {
      final result = await Future.any([job, cancelled.future]);
      cancellation.throwIfCancelled();
      if (sink != null) {
        await sink.open(const TtsAudioFormat(AudioEncoding.wav));
        await sink.add(await File(result.audioPath).readAsBytes());
        await sink.finish();
      }
      return result;
    } finally {
      remove();
    }
  }

  Future<SynthesisReceipt> _generate(
    NovelStreamPlan plan,
    TtsCancelToken cancellation,
    StreamingAudioSink? sink,
    void Function()? onFirstAudio,
  ) async {
    if (!plan.canStream) {
      throw StateError('This protocol generates full sentence files.');
    }
    final asset = plan.binding.asset;
    final requests = [
      for (final text in plan.chunks)
        TtsRequest(
          text: text,
          voice: asset.presetVoiceName ?? asset.name,
          presetVoiceName: asset.presetVoiceName,
          speed: asset.speed,
          voiceInstruction: asset.voiceInstruction,
          responseFormat: 'pcm',
          refAudioPath: asset.refAudioPath,
          promptText: asset.promptText,
          promptLang: asset.promptLang,
        ),
    ];
    final slug = await storage.ensureNovelProjectSlug(plan.project.id);
    final directory = await PathService.instance.novelReaderAudioDir(slug);
    try {
      final result = await synthesis.generate(
        provider: plan.binding.provider,
        modelName: asset.modelName,
        request: requests.first,
        outputBase:
            '${directory.path}/seg_${plan.segment.globalIndex}_${const Uuid().v4()}',
        cancellation: cancellation,
        interactive: sink != null,
        sink: sink,
        source: 'Novel Reader',
        label: plan.segment.segmentText,
        adapter: PcmSequenceAdapter(
          plan.adapter,
          requests,
          beforeContinuation: (request) => synthesis.queue.accountContinuation(
            plan.binding.provider,
            request,
            cancellation,
          ),
        ),
        onFirstAudio: onFirstAudio,
      );
      cancellation.throwIfCancelled();
      final latest = await prepare(plan.project, plan.segment);
      if (latest.cacheKey != plan.cacheKey) throw const TtsCancelledException();
      final duration =
          ((await File(result.audioPath).length()) - 44) /
          (result.format.sampleRate! * result.format.channels! * 2);
      if (sink == null) {
        await loudness.normalizeGenerated(
          enabled: plan.project.autoNormalizeLoudness,
          path: result.audioPath,
          bankId: plan.project.bankId,
          voiceAssetId: asset.id,
        );
      }
      final applied = await database.completeNovelAudio(
        plan.segment,
        path: result.audioPath,
        cacheKey: plan.cacheKey,
        duration: duration,
      );
      if (applied == 0) throw const TtsCancelledException();
      if (sink != null && plan.project.autoNormalizeLoudness) {
        unawaited(
          _normalizeAfterPlayback(plan, result.audioPath, sink, cancellation),
        );
      }
      return result;
    } on TtsCancelledException {
      rethrow;
    } catch (error) {
      await database.recordNovelAudioError(plan.segment, '$error');
      rethrow;
    }
  }

  Future<void> _normalizeAfterPlayback(
    NovelStreamPlan plan,
    String raw,
    StreamingAudioSink sink,
    TtsCancelToken cancellation,
  ) async {
    try {
      await sink.drained;
      if (cancellation.isCancelled) return;
      final copy = '$raw.normalized.wav';
      await File(raw).copy(copy);
      final outcome = await loudness.normalizeGenerated(
        enabled: true,
        path: copy,
        bankId: plan.project.bankId,
        voiceAssetId: plan.binding.asset.id,
      );
      if (outcome == null) {
        await File(copy).delete();
        return;
      }
      await (database.update(database.novelSegments)..where(
            (t) =>
                t.id.equals(plan.segment.id) &
                t.segmentText.equals(plan.segment.segmentText) &
                t.audioPath.equals(raw) &
                t.audioCacheKey.equals(plan.cacheKey),
          ))
          .write(db.NovelSegmentsCompanion(audioPath: Value(copy)));
    } catch (_) {
      /* Retain the complete raw cache on best-effort failure. */
    }
  }
}
