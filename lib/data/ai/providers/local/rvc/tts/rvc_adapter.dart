import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/data/ai/providers/local/rvc/rvc_client.dart';

/// Lets the provider editor health-check RVC and list its checkpoints and
/// voices through the shared adapter path. RVC never synthesizes text: it is
/// used as a VC step in a character's processing chain or live settings.
class RvcAdapter extends TtsAdapter {
  RvcAdapter({required String baseUrl, String apiKey = ''})
    : client = RvcClient(baseUrl: baseUrl, apiKey: apiKey);
  final RvcClient client;

  @override
  Future<bool> healthCheck() => client.health();

  @override
  Future<List<ModelInfo>> getModels() async => [
    for (final m in (await client.catalog()).models)
      if (m.available) ModelInfo(id: m.id, name: m.name),
  ];

  @override
  Future<List<String>> getSpeakers() async => [
    for (final v in (await client.catalog()).voices) voiceLabel(v.name, v.id),
  ];

  @override
  Future<TtsResult> synthesize(TtsRequest request) => throw UnsupportedError(
    'RVC converts audio and cannot speak text. Add it as a voice-conversion '
    'step in the character processing chain.',
  );
}
