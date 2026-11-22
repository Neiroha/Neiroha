import 'dart:async';

import 'package:neiroha/data/ai/protocols/realtime/openai_conversation_session.dart';
import 'package:neiroha/data/ai/providers/openai/openai_endpoint.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/ai/models/realtime_model.dart';

class OpenAiRealtimeModel implements RealtimeModel {
  OpenAiRealtimeModel(this.descriptor, this.endpoint);
  @override
  final ModelDescriptor descriptor;
  final OpenAiEndpoint endpoint;

  @override
  Future<RealtimeSession> connect(RealtimeConfig config) =>
      OpenAiConversationSession.connect(
        baseUrl: endpoint.baseUrl,
        apiKey: endpoint.apiKey,
        model: descriptor.id,
        config: config,
      );
}
