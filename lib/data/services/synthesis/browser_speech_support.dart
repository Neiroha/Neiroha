import 'package:neiroha/data/adapters/openai_tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/platform/platform_capabilities.dart';

bool supportsBrowserSpeechStreaming(
  db.TtsProvider provider,
  db.VoiceAsset voice,
) =>
    provider.adapterType == 'openaiTts' &&
    supportsBrowserSpeech(
      provider: provider,
      modelName: voice.modelName,
      refAudioPath: voice.refAudioPath,
    );

bool supportsBrowserSpeech({
  required db.TtsProvider provider,
  String? modelName,
  String? refAudioPath,
}) {
  const browser = PlatformCapabilities(NeirohaPlatform.web);
  if (!provider.enabled ||
      !browser.supportsAdapterName(provider.adapterType) ||
      refAudioPath?.isNotEmpty == true) {
    return false;
  }
  final url = provider.baseUrl.trim();
  if (url.isNotEmpty) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return false;
    }
  }
  if (provider.adapterType != 'openaiTts') return true;
  final model = (modelName ?? provider.defaultModelName).trim();
  return !OpenAiTtsAdapter.usesRealtime(
    model.isEmpty || model == 'default' ? OpenAiTtsAdapter.defaultModel : model,
  );
}
