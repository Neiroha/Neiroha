import 'package:neiroha/data/services/synthesis/browser_speech_support.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

String browserSpeechMessage(AppLocalizations l10n, BrowserSpeechBlock block) =>
    switch (block) {
      BrowserSpeechBlock.providerDisabled => l10n.webSpeechProviderDisabled,
      BrowserSpeechBlock.adapterUnavailable => l10n.webSpeechAdapterUnavailable,
      BrowserSpeechBlock.invalidEndpoint => l10n.webSpeechEndpointInvalid,
      BrowserSpeechBlock.realtime => l10n.webRealtimeUnavailable,
      BrowserSpeechBlock.geminiLive => l10n.webGeminiLiveUnavailable,
      BrowserSpeechBlock.openAiRealtimeWrongAdapter =>
        l10n.webOpenAiRealtimeWrongAdapter,
      BrowserSpeechBlock.retiredMiMo => l10n.webMiMoModelRetired,
      BrowserSpeechBlock.localReference => l10n.webSpeechLocalReference,
      BrowserSpeechBlock.missingVoice => l10n.webSpeechPresetRequired,
      BrowserSpeechBlock.incompatibleVoice => l10n.webSpeechIncompatibleVoice,
    };
