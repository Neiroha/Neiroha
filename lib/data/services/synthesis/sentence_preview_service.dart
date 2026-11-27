import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/auto_loudness_service.dart';
import 'package:neiroha/data/services/phase_segment_settings_file.dart';
import 'package:neiroha/data/storage/path_service.dart';
import 'package:neiroha/data/storage/storage_service.dart';
import 'package:neiroha/domain/synthesis/streaming_audio_sink.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:neiroha/domain/voice_capabilities.dart';
import 'package:uuid/uuid.dart';
import 'synthesis_service.dart';

enum SentenceProjectKind { dialog, phase, video }

class _Sentence {
  const _Sentence(
    this.text,
    this.voiceId,
    this.bankId,
    this.normalize,
    this.directory,
    this.table,
    this.textColumn,
    this.slug,
  );
  final String text;
  final String? voiceId;
  final String bankId;
  final bool normalize;
  final Directory directory;
  final TableInfo table;
  final String textColumn;
  final String slug;
}

/// A live preview produces the same complete project clip used by exports.
/// Only audio fields are published, with compare-and-set on text and voice.
class SentencePreviewService {
  const SentencePreviewService(
    this.database,
    this.storage,
    this.synthesis,
    this.loudness,
  );
  final db.AppDatabase database;
  final StorageService storage;
  final SynthesisService synthesis;
  final AutoLoudnessService loudness;

  Future<SynthesisReceipt> generate({
    required SentenceProjectKind kind,
    required String projectId,
    required String id,
    required TtsCancelToken cancellation,
    required StreamingAudioSink sink,
  }) async {
    final source = await _load(kind, projectId, id);
    final asset = await database.getVoiceAssetById(source.voiceId ?? '');
    if (asset == null ||
        !(await database.getBankMembers(
          source.bankId,
        )).any((m) => m.voiceAssetId == asset.id)) {
      throw StateError('Select a voice from this project’s bank.');
    }
    final provider = (await database.getAllProviders())
        .where((p) => p.id == asset.providerId)
        .firstOrNull;
    if (provider == null) throw StateError('Voice provider was deleted.');
    final settings = kind == SentenceProjectKind.phase
        ? (await PhaseSegmentSettingsFileService().load(
            source.slug,
          )).bySegmentId[id]
        : null;
    final instruction = settings?.voiceInstruction?.trim();
    cancellation.throwIfCancelled();
    final result = await synthesis.generate(
      provider: provider,
      modelName: asset.modelName,
      source: '${kind.name} live preview',
      label: source.text,
      outputBase: '${source.directory.path}/preview_${const Uuid().v4()}',
      cancellation: cancellation,
      sink: sink,
      interactive: true,
      request: TtsRequest(
        text: source.text,
        voice: asset.presetVoiceName ?? asset.name,
        seed: asset.seed,
        voiceAssetId: asset.id,
        presetVoiceName: asset.presetVoiceName,
        speed: asset.speed,
        responseFormat: provider.adapterType == 'openaiTts' ? 'pcm' : null,
        textLang: TtsRequest.legacyTextLanguage(
          provider.adapterType,
          asset.modelName,
        ),
        voiceInstruction:
            VoiceCapabilities.supportsVoiceInstruction(asset, provider)
            ? instruction?.isNotEmpty == true
                  ? instruction
                  : asset.voiceInstruction
            : null,
        audioTagPrefix: VoiceCapabilities.supportsAudioTags(asset, provider)
            ? settings?.audioTagPrefix
            : null,
        refAudioPath: asset.refAudioPath,
        promptText: asset.promptText,
        promptLang: asset.promptLang,
      ),
    );
    cancellation.throwIfCancelled();
    final duration = result.format.encoding == AudioEncoding.pcmS16le
        ? ((await File(result.audioPath).length()) - 44) /
              (result.format.sampleRate! * result.format.channels! * 2)
        : null;
    if (await _publish(source, projectId, id, result.audioPath, duration) ==
        0) {
      throw const TtsCancelledException();
    }
    unawaited(
      _normalize(
        source,
        projectId,
        id,
        result.audioPath,
        duration,
        sink,
        cancellation,
      ),
    );
    return result;
  }

  Future<int> _publish(
    _Sentence source,
    String projectId,
    String id,
    String path,
    double? duration, {
    String? expectedPath,
  }) => database.customUpdate(
    'UPDATE ${source.table.actualTableName} SET audio_path = ?, audio_duration = ?, error = NULL, missing = 0 '
    'WHERE id = ? AND project_id = ? AND ${source.textColumn} = ? AND voice_asset_id = ?'
    '${expectedPath == null ? '' : ' AND audio_path = ?'}',
    variables: [
      Variable(path),
      Variable(duration),
      Variable(id),
      Variable(projectId),
      Variable(source.text),
      Variable(source.voiceId),
      if (expectedPath != null) Variable(expectedPath),
    ],
    updates: {source.table},
  );

  Future<void> _normalize(
    _Sentence source,
    String projectId,
    String id,
    String raw,
    double? duration,
    StreamingAudioSink sink,
    TtsCancelToken cancellation,
  ) async {
    try {
      await sink.drained;
      if (cancellation.isCancelled) return;
      duration ??= sink.bufferedUntil > Duration.zero
          ? sink.bufferedUntil.inMicroseconds / 1000000
          : null;
      if (!source.normalize) {
        await _publish(source, projectId, id, raw, duration, expectedPath: raw);
        return;
      }
      final copy =
          '$raw.normalized${File(raw).path.endsWith('.wav') ? '.wav' : '.mp3'}';
      await File(raw).copy(copy);
      final outcome = await loudness.normalizeGenerated(
        enabled: true,
        path: copy,
        bankId: source.bankId,
        voiceAssetId: source.voiceId,
      );
      if (outcome != null) {
        await _publish(
          source,
          projectId,
          id,
          copy,
          duration,
          expectedPath: raw,
        );
      }
    } catch (_) {
      /* The complete raw take remains usable. */
    }
  }

  Future<_Sentence> _load(
    SentenceProjectKind kind,
    String projectId,
    String id,
  ) async {
    switch (kind) {
      case SentenceProjectKind.dialog:
        final project = await database.getDialogTtsProjectById(projectId);
        final row = (await database.getDialogTtsLines(
          projectId,
        )).where((s) => s.id == id).firstOrNull;
        if (project == null || row == null) {
          throw StateError('Dialog line was deleted.');
        }
        final slug = await storage.ensureDialogProjectSlug(projectId);
        return _Sentence(
          row.lineText,
          row.voiceAssetId,
          project.bankId,
          project.autoNormalizeLoudness,
          await PathService.instance.dialogTtsDir(slug),
          database.dialogTtsLines,
          'line_text',
          slug,
        );
      case SentenceProjectKind.phase:
        final project = await database.getPhaseTtsProjectById(projectId);
        final row = (await database.getPhaseTtsSegments(
          projectId,
        )).where((s) => s.id == id).firstOrNull;
        if (project == null || row == null) {
          throw StateError('Phase segment was deleted.');
        }
        final slug = await storage.ensurePhaseProjectSlug(projectId);
        return _Sentence(
          row.segmentText,
          row.voiceAssetId,
          project.bankId,
          project.autoNormalizeLoudness,
          await PathService.instance.phaseTtsDir(slug),
          database.phaseTtsSegments,
          'segment_text',
          slug,
        );
      case SentenceProjectKind.video:
        final project = await database.getVideoDubProjectById(projectId);
        final row = (await database.getSubtitleCues(
          projectId,
        )).where((s) => s.id == id).firstOrNull;
        if (project == null || row == null) {
          throw StateError('Video cue was deleted.');
        }
        final slug = await storage.ensureVideoDubProjectSlug(projectId);
        return _Sentence(
          row.cueText,
          row.voiceAssetId,
          project.bankId,
          project.autoNormalizeLoudness,
          await PathService.instance.videoDubDir(slug),
          database.subtitleCues,
          'cue_text',
          slug,
        );
    }
  }
}
