import 'dart:convert';

import 'package:neiroha/domain/llm/llm_contract.dart';
import 'package:neiroha/domain/llm/tool_chat.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

import 'character_tools.dart';

/// How a character replies: the words to speak, how to say them, and the
/// feeling behind them.
class CharacterReply {
  const CharacterReply({
    required this.say,
    this.style = '',
    this.emotion = 'neutral',
  });
  final String say;

  /// A short delivery note for the voice ("softly, amused").
  final String style;
  final String emotion;

  static const emotions = [
    'neutral',
    'happy',
    'sad',
    'angry',
    'surprised',
    'shy',
    'serious',
    'playful',
  ];

  static const schema = <String, Object?>{
    'type': 'object',
    'properties': {
      'say': {
        'type': 'string',
        'description':
            'The words to speak aloud: plain spoken sentences, no markdown, '
            'lists or stage directions.',
      },
      'style': {
        'type': 'string',
        'description':
            'How to deliver the line, a few words for the voice actor '
            '(tone, pace, volume). Empty for a neutral delivery.',
      },
      'emotion': {'type': 'string', 'enum': emotions},
    },
    'required': ['say', 'style', 'emotion'],
    'additionalProperties': false,
  };

  /// Reads the model's JSON; plain text (a model that ignored the schema)
  /// is spoken as it is.
  factory CharacterReply.parse(String raw) {
    final text = raw
        .trim()
        .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '');
    try {
      final o = jsonDecode(text);
      if (o is Map && o['say'] is String) {
        final emotion = '${o['emotion'] ?? 'neutral'}';
        return CharacterReply(
          say: (o['say'] as String).trim(),
          style: '${o['style'] ?? ''}'.trim(),
          emotion: emotions.contains(emotion) ? emotion : 'neutral',
        );
      }
    } on FormatException {
      // Not JSON: speak the text.
    }
    return CharacterReply(say: text);
  }
}

/// A tool the character called while answering.
typedef ToolUse = ({String name, String arguments, String result});

/// Runs one turn: the model may call [tools] (each run here and handed
/// back) for up to [maxRounds] rounds, then answers as a [CharacterReply].
class CharacterBrain {
  CharacterBrain(this.llm, {this.tools = const [], this.maxRounds = 4});
  final ToolCallingLanguageModel llm;
  final List<CharacterTool> tools;
  final int maxRounds;

  static const replyRules =
      'Answer in character, as spoken dialogue: one to three short '
      'sentences in the language the user speaks. Use the tools when they '
      'help. Reply with the JSON object the schema describes.';

  Future<CharacterReply> answer(
    List<ToolChatMessage> conversation, {
    required TtsCancelToken cancellation,
    void Function(ToolUse use)? onTool,
  }) async {
    final messages = [...conversation];
    for (var round = 0; ; round++) {
      cancellation.throwIfCancelled();
      // The last round gets no tools, so the model has to answer.
      final turn = await llm.chatWithTools(
        messages,
        tools: round < maxRounds ? [for (final t in tools) t.spec] : const [],
        schemaName: 'character_reply',
        replySchema: CharacterReply.schema,
        cancellation: cancellation,
      );
      if (turn.toolCalls.isEmpty || round >= maxRounds) {
        final reply = CharacterReply.parse(turn.content);
        if (reply.say.isEmpty) {
          throw const LlmChatException('The character gave no answer.');
        }
        return reply;
      }
      messages.add(
        ToolChatMessage.assistant(turn.content, toolCalls: turn.toolCalls),
      );
      for (final call in turn.toolCalls) {
        final result = await runCharacterTool(tools, call.name, call.arguments);
        onTool?.call((
          name: call.name,
          arguments: call.arguments,
          result: result,
        ));
        messages.add(ToolChatMessage.toolResult(call.id, result));
      }
    }
  }
}
