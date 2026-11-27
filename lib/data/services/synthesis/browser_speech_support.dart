import 'package:neiroha/data/ai/registry/tts_adapter_factory.dart';
import 'package:neiroha/data/ai/providers/azure_speech/tts/azure_tts_adapter.dart';
import 'package:neiroha/data/ai/providers/mimo/tts/chat_completions_tts_adapter.dart';
import 'package:neiroha/data/ai/providers/gemini/tts/gemini_tts_adapter.dart';
import 'package:neiroha/data/ai/providers/openai/tts/openai_tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/domain/platform/platform_capabilities.dart';

enum BrowserSpeechBlock {
  providerDisabled,
  adapterUnavailable,
  invalidEndpoint,
  realtime,
  geminiLive,
  openAiRealtimeWrongAdapter,
  retiredMiMo,
  localReference,
  missingVoice,
  incompatibleVoice,
}

const browserDefaultOpenAiSpeechModel = 'gpt-4o-mini-tts';

String defaultSpeechModelForPlatform(
  AdapterType adapter,
  PlatformCapabilities platform,
) => platform.isWeb && adapter == AdapterType.openaiTts
    ? browserDefaultOpenAiSpeechModel
    : adapter.defaultModel;

/// Only inherited defaults fall back. An explicit Realtime choice must be
/// visible and actionable instead of silently sending it to a different model.
String? browserSpeechModel(db.TtsProvider provider, String? requestedModel) {
  final requested = requestedModel?.trim() ?? '';
  if (provider.adapterType == 'chatCompletionsTts') {
    return ttsAdapterModel(provider, requested);
  }
  if (provider.adapterType != 'openaiTts') {
    return requested.isEmpty ? null : requested;
  }
  if (requested.isNotEmpty && requested != 'default') return requested;
  final configured = provider.defaultModelName.trim();
  return configured.isEmpty ||
          configured == 'default' ||
          OpenAiTtsAdapter.usesRealtime(configured)
      ? browserDefaultOpenAiSpeechModel
      : configured;
}

BrowserSpeechBlock? browserSpeechModelBlock(
  String adapter,
  String model, {
  String baseUrl = '',
}) {
  if (adapter == 'openaiTts' && OpenAiTtsAdapter.usesRealtime(model)) {
    return BrowserSpeechBlock.realtime;
  }
  if (adapter == 'openaiCompatible' &&
      OpenAiTtsAdapter.isOfficialApiEndpoint(baseUrl) &&
      OpenAiTtsAdapter.usesRealtime(model)) {
    return BrowserSpeechBlock.openAiRealtimeWrongAdapter;
  }
  if (adapter == 'geminiTts' && GeminiTtsAdapter.usesLiveModel(model)) {
    return BrowserSpeechBlock.geminiLive;
  }
  if (adapter == 'chatCompletionsTts' &&
      model.trim() == 'mimo-v2-tts' &&
      ChatCompletionsTtsAdapter.isOfficialMiMo(baseUrl)) {
    return BrowserSpeechBlock.retiredMiMo;
  }
  if (adapter == 'chatCompletionsTts' &&
      model.toLowerCase().contains('voiceclone')) {
    return BrowserSpeechBlock.localReference;
  }
  return null;
}

List<String> browserSpeechModels(
  db.TtsProvider provider,
  Iterable<String> ids,
) {
  final adapter = provider.adapterType;
  final models = ids
      .where(
        (id) =>
            id.trim().isNotEmpty &&
            (adapter != 'openaiTts' || id.trim() != 'default') &&
            browserSpeechModelBlock(adapter, id, baseUrl: provider.baseUrl) ==
                null,
      )
      .toSet();
  if (adapter == 'openaiTts') {
    if (models.isEmpty) {
      models.addAll(
        OpenAiTtsAdapter.kModels
            .map((model) => model.id)
            .where((id) => browserSpeechModelBlock(adapter, id) == null),
      );
    }
    models.add(browserSpeechModel(provider, null)!);
  }
  if (adapter == 'chatCompletionsTts' &&
      ChatCompletionsTtsAdapter.isOfficialMiMo(provider.baseUrl)) {
    models.add(AdapterType.chatCompletionsTts.defaultModel);
  }
  if (adapter == 'geminiTts' && models.isEmpty) {
    models.addAll(GeminiTtsAdapter.kModels.map((model) => model.id));
  }
  return models.toList()..sort();
}

String? browserOpenAiVoiceId(String? presetVoice, String? legacyName) {
  final preset = voiceIdFromLabel(presetVoice ?? '');
  if (preset.isNotEmpty) return preset;
  final legacy = voiceIdFromLabel(legacyName ?? '');
  return OpenAiTtsAdapter.kSpeechVoices.contains(legacy) ||
          legacy.startsWith('voice_')
      ? legacy
      : null;
}

List<String> browserOpenAiVoiceOptions(String model, Iterable<String> cached) {
  final builtIn = OpenAiTtsAdapter.voicesForModel(model);
  return {
    ...builtIn,
    ...cached.where((label) {
      final id = voiceIdFromLabel(label);
      return id.isNotEmpty && !OpenAiTtsAdapter.kSpeechVoices.contains(id);
    }),
  }.toList();
}

BrowserSpeechBlock? browserSpeechBlockForVoice(
  db.TtsProvider provider,
  db.VoiceAsset voice,
) => browserSpeechBlock(
  provider: provider,
  modelName: voice.modelName,
  refAudioPath: voice.refAudioPath,
  presetVoice: voice.presetVoiceName,
  legacyName: voice.name,
);

BrowserSpeechBlock? browserSpeechBlock({
  required db.TtsProvider provider,
  String? modelName,
  String? refAudioPath,
  String? presetVoice,
  String? legacyName,
}) {
  const browser = PlatformCapabilities(NeirohaPlatform.web);
  if (!provider.enabled) return BrowserSpeechBlock.providerDisabled;
  if (!browser.supportsAdapterName(provider.adapterType)) {
    return BrowserSpeechBlock.adapterUnavailable;
  }
  final isAzure = provider.adapterType == 'azureTts';
  final url = isAzure
      ? AzureTtsAdapter.normalizeTtsUrl(provider.baseUrl)
      : provider.baseUrl.trim();
  if (isAzure && url.isEmpty) return BrowserSpeechBlock.invalidEndpoint;
  if (url.isNotEmpty) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return BrowserSpeechBlock.invalidEndpoint;
    }
  }
  final model =
      browserSpeechModel(provider, modelName) ?? provider.defaultModelName;
  final modelBlock = browserSpeechModelBlock(
    provider.adapterType,
    model,
    baseUrl: provider.baseUrl,
  );
  if (modelBlock != null) return modelBlock;
  if (refAudioPath?.trim().isNotEmpty == true) {
    return BrowserSpeechBlock.localReference;
  }
  if (provider.adapterType == 'openaiTts') {
    final voice = browserOpenAiVoiceId(presetVoice, legacyName);
    if (voice == null) return BrowserSpeechBlock.missingVoice;
    if (OpenAiTtsAdapter.kSpeechVoices.contains(voice) &&
        !OpenAiTtsAdapter.voicesForModel(model).contains(voice)) {
      return BrowserSpeechBlock.incompatibleVoice;
    }
  }
  return null;
}

bool supportsBrowserSpeechStreaming(
  db.TtsProvider provider,
  db.VoiceAsset voice,
) =>
    browserSpeechBlockForVoice(provider, voice) == null &&
    ttsAdapterSupportsStreaming(
      provider,
      browserSpeechModel(provider, voice.modelName),
    );
