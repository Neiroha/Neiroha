import 'dart:async';

import 'package:neiroha/data/ai/protocols/realtime/openai_translation_session.dart';
import 'package:neiroha/data/ai/providers/openai/openai_endpoint.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/ai/models/capability_model.dart';
import 'package:neiroha/domain/ai/models/speech_translator.dart';

class OpenAiSpeechTranslator implements SpeechTranslator {
  OpenAiSpeechTranslator(this.descriptor, this.endpoint);
  @override
  final ModelDescriptor descriptor;
  final OpenAiEndpoint endpoint;

  @override
  Future<AudioStreamSession> open({required String targetLanguage}) =>
      OpenAiTranslationSession.connect(
        baseUrl: endpoint.baseUrl,
        apiKey: endpoint.apiKey,
        model: descriptor.id,
        targetLanguage: targetLanguage,
      );
}
