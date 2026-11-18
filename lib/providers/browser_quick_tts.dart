import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/synthesis/browser_pcm_sink.dart';
import 'package:neiroha/data/services/synthesis/quick_tts_service.dart';
import 'package:neiroha/domain/synthesis/streaming_audio_sink.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

import 'app_providers.dart';
import 'playback_provider.dart';
import 'session_audio_provider.dart';

Future<void> generateBrowserQuickTts(
  WidgetRef ref, {
  required String entryId,
  required db.TtsProvider provider,
  required db.VoiceAsset voice,
  required String text,
  required TtsCancelToken cancellation,
  required bool stream,
}) async {
  final synthesis = ref.read(synthesisServiceProvider);
  final history = ref.read(sessionAudioProvider.notifier);
  Future<String> generate([StreamingAudioSink? sink]) async {
    final audio = await synthesis.collectInMemory(
      provider: provider,
      request: quickTtsRequest(
        voice,
        provider,
        text,
        responseFormat: stream ? 'pcm' : null,
      ),
      modelName: voice.modelName,
      cancellation: cancellation,
      sink: sink,
    );
    cancellation.throwIfCancelled();
    return history.add(entryId, voice, text, audio);
  }

  if (!stream) {
    await generate();
    return;
  }
  final player = ref.read(playbackNotifierProvider.notifier);
  final sink = createBrowserPcmSink();
  try {
    await player.playSessionSynthesis(
      generate: generate,
      cancellation: cancellation,
      title: text,
      subtitle: voice.name,
      sourceTag: voiceBankQuickTestPlaybackSource,
      sink: sink,
    );
  } catch (_) {
    await sink.stop();
    rethrow;
  }
}
