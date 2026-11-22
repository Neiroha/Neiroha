import 'package:neiroha/domain/ai/ai.dart';

enum GeminiLiveMode { conversation, transcription, translation }

/// The first Live message (`{"setup": …}`) for each mode.
Map<String, Object?> geminiLiveSetup({
  required String model,
  required GeminiLiveMode mode,
  RealtimeConfig config = const RealtimeConfig(),
  String? targetLanguage,
  TranscribeOptions transcribe = const TranscribeOptions(),
}) {
  final talk = mode == GeminiLiveMode.conversation;
  final audioOut =
      mode == GeminiLiveMode.translation || (talk && config.audioOutput);
  return {
    'setup': {
      'model': model.startsWith('models/') ? model : 'models/$model',
      'generationConfig': {
        'responseModalities': [audioOut ? 'AUDIO' : 'TEXT'],
        if (talk && config.voice != null)
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {'voiceName': config.voice},
            },
          },
        if (mode == GeminiLiveMode.translation)
          'translationConfig': {'targetLanguageCode': targetLanguage ?? 'en'},
      },
      if (talk && config.instructions.trim().isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': config.instructions},
          ],
        },
      if (mode != GeminiLiveMode.translation)
        'realtimeInputConfig': {
          'automaticActivityDetection': {
            'disabled': !talk || !config.serverVad,
          },
        },
      if (!talk || config.transcribeInput)
        'inputAudioTranscription': {
          if (transcribe.languages.isNotEmpty)
            'languageCodes': transcribe.languages,
          if (transcribe.keywords.isNotEmpty)
            'customVocabulary': transcribe.keywords,
        },
      if (audioOut) 'outputAudioTranscription': <String, Object?>{},
    },
  };
}
