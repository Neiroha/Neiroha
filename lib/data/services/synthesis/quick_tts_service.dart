import 'package:neiroha/data/ai/registry/tts_adapter_factory.dart';
import 'dart:io';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:drift/drift.dart' show Value;
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/storage/path_service.dart';
import 'package:neiroha/data/storage/storage_service.dart';
import 'package:neiroha/domain/platform/platform_capabilities.dart';
import 'package:neiroha/domain/synthesis/streaming_audio_sink.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

import 'browser_speech_support.dart';
import 'synthesis_service.dart';

bool supportsQuickTtsStreaming(
  db.TtsProvider? provider,
  db.VoiceAsset asset,
  PlatformCapabilities platform,
) {
  if (provider == null || !provider.enabled) return false;
  return platform.isWeb
      ? supportsBrowserSpeechStreaming(provider, asset)
      : ttsAdapterSupportsStreaming(provider, asset.modelName);
}

TtsRequest quickTtsRequest(
  db.VoiceAsset asset,
  db.TtsProvider provider,
  String text, {
  String? responseFormat,
}) => TtsRequest(
  text: text,
  voice: asset.presetVoiceName ?? asset.name,
  speed: asset.speed,
  responseFormat: responseFormat,
  presetVoiceName: asset.presetVoiceName,
  textLang: provider.adapterType == 'gptSovits' ? asset.modelName : null,
  voiceInstruction: asset.voiceInstruction,
  refAudioPath: asset.refAudioPath,
  promptText: asset.promptText,
  promptLang: asset.promptLang,
);

class QuickTtsService {
  const QuickTtsService(this.database, this.storage, this.synthesis);
  final db.AppDatabase database;
  final StorageService storage;
  final SynthesisService synthesis;

  Future<SynthesisReceipt> generate({
    required String entryId,
    required db.VoiceAsset asset,
    required db.TtsProvider provider,
    required String text,
    required TtsCancelToken cancellation,
    StreamingAudioSink? sink,
  }) async {
    try {
      final slug = await storage.ensureVoiceAssetSlug(asset.id);
      final directory = await PathService.instance.quickTtsDir(slug);
      cancellation.throwIfCancelled();
      final result = await synthesis.generate(
        provider: provider,
        modelName: asset.modelName,
        source: 'Quick TTS',
        label: '${asset.name}: $text',
        outputBase:
            '${directory.path}/${PathService.formatTimestamp()}_$entryId',
        cancellation: cancellation,
        interactive: true,
        sink: sink,
        request: quickTtsRequest(
          asset,
          provider,
          text,
          responseFormat: sink == null ? null : 'pcm',
        ),
      );
      final duration = result.format.encoding == AudioEncoding.pcmS16le
          ? ((await File(result.audioPath).length()) - 44) /
                (result.format.sampleRate! * result.format.channels! * 2)
          : null;
      // A complete file can be saved even when the user stops after EOF.
      await database.insertQuickTtsHistory(
        db.QuickTtsHistoriesCompanion(
          id: Value(entryId),
          voiceAssetId: Value(asset.id),
          voiceName: Value(asset.name),
          inputText: Value(text),
          audioPath: Value(result.audioPath),
          audioDuration: Value(duration),
          createdAt: Value(DateTime.now()),
        ),
      );
      return result;
    } on TtsCancelledException {
      rethrow;
    } catch (error) {
      await database.insertQuickTtsHistory(
        db.QuickTtsHistoriesCompanion(
          id: Value(entryId),
          voiceAssetId: Value(asset.id),
          voiceName: Value(asset.name),
          inputText: Value(text),
          error: Value(error.toString()),
          createdAt: Value(DateTime.now()),
        ),
      );
      rethrow;
    }
  }
}
