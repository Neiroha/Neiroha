import 'dart:async';

import 'package:neiroha/domain/capabilities/model_capability.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:neiroha/domain/synthesis/tts_request.dart';

export 'package:neiroha/domain/synthesis/tts_request.dart';

/// Describes a model available from a provider.
class ModelInfo {
  final String id;
  final String name;

  const ModelInfo({required this.id, this.name = ''});

  @override
  String toString() => name.isNotEmpty ? '$name ($id)' : id;
}

/// Base class for all TTS provider adapters.
abstract class TtsAdapter {
  ServiceRoute get serviceRoute => ServiceRoute.native;

  /// True only when audio is delivered before the upstream result completes.
  bool get supportsStreaming => false;

  bool streamsAudioFor(TtsRequest request) =>
      supportsStreaming && request.responseFormat == 'pcm';

  /// Compatibility path for file-only adapters. It deliberately retains the
  /// queue slot until the non-cancellable legacy request actually completes.
  Stream<TtsEvent> synthesizeStream(
    TtsRequest request, {
    required TtsCancelToken cancellation,
  }) async* {
    cancellation.throwIfCancelled();
    final result = await synthesize(request);
    cancellation.throwIfCancelled();
    yield TtsAudioStarted(
      TtsAudioFormat.fromFileBytes(result.audioBytes, result.contentType),
    );
    yield TtsAudioChunk(result.audioBytes);
    yield const TtsSynthesisCompleted();
  }

  Future<TtsResult> synthesize(TtsRequest request);
  Future<bool> healthCheck();

  /// Fetch available speaker/voice names from the provider.
  /// Returns empty list if not supported.
  Future<List<String>> getSpeakers() async => [];

  /// Fetch available models from the provider.
  /// Returns empty list if not supported.
  Future<List<ModelInfo>> getModels() async => [];
}

/// Adapters whose upstream service can register a reusable cloned voice from
/// a reference recording (ElevenLabs instant voice clone, MiniMax
/// voice_clone). The returned label is stored as the character's
/// `presetVoiceName`; later synthesis treats it like any preset voice.
abstract interface class VoiceCloneCapable {
  Future<String> cloneVoice({
    required String name,
    required String audioPath,
    String? promptText,
    String? description,
  });
}

/// Voice pickers show cloud voices as `Display Name [voice_id]` so users see
/// a readable name while the adapter still sends the opaque id. Plain ids
/// (no brackets) pass through unchanged.
String voiceIdFromLabel(String label) {
  final match = RegExp(r'\[([^\[\]]+)\]\s*$').firstMatch(label.trim());
  return match != null ? match.group(1)!.trim() : label.trim();
}

/// Builds the `Display Name [voice_id]` label used by [voiceIdFromLabel].
String voiceLabel(String name, String id) {
  final n = name.trim();
  if (n.isEmpty || n == id) return id;
  return '$n [$id]';
}
