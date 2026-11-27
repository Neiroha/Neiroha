// Gemini text models calling the character's tools against the real API.
// Skipped unless a key is set (from .env):
//   set -a; source .env; set +a
//   flutter test scripts/tests/gemini_tool_chat_live_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/providers/gemini/gemini_catalog.dart';
import 'package:neiroha/data/ai/providers/gemini/gemini_endpoint.dart';
import 'package:neiroha/data/ai/providers/gemini/llm/gemini_language_model.dart';
import 'package:neiroha/data/services/conversation/character_brain.dart';
import 'package:neiroha/data/services/conversation/character_tools.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/llm/tool_chat.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

void main() {
  final env = Platform.environment;
  final key = env['GEMINI_API_KEY'] ?? env['GEMINI_KEY'] ?? '';
  final skip = key.isEmpty ? 'GEMINI_API_KEY / GEMINI_KEY not set' : null;
  final modelId = env['GEMINI_LLM'] ?? 'gemini-3.8-flash';

  test(
    '$modelId remembers a fact through a tool, then replies in character',
    () async {
      final memory = ChatMemory();
      final uses = <ToolUse>[];
      final model = GeminiLanguageModel(
        ModelDescriptor(
          id: modelId,
          capability: AiCapability.llm,
          protocol: AiProtocol.native,
        ),
        GeminiEndpoint('', key),
        thinkingLevel: geminiReasoningDefaults[modelId],
      );
      final reply = await CharacterBrain(model, tools: characterTools(memory))
          .answer(
            const [
              ToolChatMessage.system(
                'You are Nagato, a calm and dignified companion. Whenever the '
                'user tells you something about themselves, save it with '
                'remember_fact before you answer.',
              ),
              ToolChatMessage.user(
                'Please remember that my favourite tea is '
                'jasmine.',
              ),
            ],
            cancellation: TtsCancelToken(),
            onTool: uses.add,
          );
      // ignore: avoid_print
      print('tools: ${uses.map((u) => '${u.name}(${u.arguments})')}');
      // ignore: avoid_print
      print('reply: ${reply.say} [${reply.emotion}; ${reply.style}]');
      expect(uses.map((u) => u.name), contains('remember_fact'));
      expect(memory.facts.join(' ').toLowerCase(), contains('jasmine'));
      expect(reply.say, isNotEmpty);
      expect(reply.say, isNot(startsWith('{')));
      expect(CharacterReply.emotions, contains(reply.emotion));
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
