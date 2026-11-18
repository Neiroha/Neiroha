import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/capabilities/model_capability.dart';

extension RoleAiConnection on db.TtsProvider {
  bool get supportsRoleAi => switch (adapterType) {
    'openaiTts' ||
    'openaiCompatible' ||
    'chatCompletionsTts' ||
    'geminiTts' ||
    'minimaxTts' => true,
    _ => false,
  };

  bool get isOfficialOpenAi {
    final endpoint = Uri.tryParse(baseUrl);
    return endpoint?.scheme == 'https' && endpoint?.host == 'api.openai.com';
  }

  /// Gemini and MiniMax expose their text APIs on a different path from TTS.
  /// Keep custom gateways and credentials on the user's configured origin.
  String get roleAiBaseUrl {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.scheme != 'https') return baseUrl;
    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    if (adapterType == 'geminiTts' &&
        uri.host == 'generativelanguage.googleapis.com' &&
        const ['', '/v1beta'].contains(path)) {
      return uri.replace(path: '/v1beta/openai/').toString();
    }
    if (adapterType == 'minimaxTts' &&
        const [
          'api.minimax.io',
          'api.minimaxi.com',
          'api.minimax.cn',
        ].contains(uri.host) &&
        path.isEmpty) {
      return uri.replace(path: '/v1/').toString();
    }
    return baseUrl;
  }

  String get roleAiKeyHeader =>
      adapterType == 'chatCompletionsTts' ? 'api-key' : 'Authorization';
}

bool isRoleAiRoute(ServiceRoute route) =>
    route == ServiceRoute.chatCompletions || route == ServiceRoute.responses;

const defaultRoleAiModel = 'gpt-6-luna';
const roleAiToolCapability = 'functionCalling';
