import 'package:neiroha/data/ai/protocols/openai/openai_tool_chat.dart'
    show toolArguments;
import 'package:neiroha/domain/llm/tool_chat.dart';

/// What the character was asked to remember in this chat; [onChanged]
/// persists it.
class ChatMemory {
  ChatMemory([Iterable<String> facts = const [], this.onChanged])
    : _facts = [...facts];
  final List<String> _facts;
  final void Function(List<String> facts)? onChanged;

  static const maxFacts = 50;

  List<String> get facts => List.unmodifiable(_facts);

  bool add(String fact) {
    final f = fact.trim();
    if (f.isEmpty || _facts.contains(f)) return false;
    _facts.add(f);
    if (_facts.length > maxFacts) _facts.removeAt(0);
    onChanged?.call(facts);
    return true;
  }

  bool remove(String fact) {
    final removed = _facts.remove(fact.trim());
    if (removed) onChanged?.call(facts);
    return removed;
  }

  /// The facts, for the character's instructions.
  String get prompt => _facts.isEmpty
      ? ''
      : 'What you remember about the user:\n'
            '${_facts.map((f) => '- $f').join('\n')}';
}

/// A function the character can call during a chat, run on this device.
class CharacterTool {
  const CharacterTool(this.spec, this.run);
  final LlmTool spec;
  final Future<String> Function(Map<String, Object?> arguments) run;

  String get name => spec.name;
}

/// The tools every character has: the time, and a memory for the chat.
List<CharacterTool> characterTools(
  ChatMemory memory, {
  DateTime Function() now = DateTime.now,
}) => [
  CharacterTool(
    const LlmTool(
      name: 'get_current_time',
      description:
          'The local date, weekday and time. Use it before talking about '
          'today, tonight, the date or how late it is.',
    ),
    (_) async {
      final t = now();
      const days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      String two(int n) => n.toString().padLeft(2, '0');
      final offset = t.timeZoneOffset;
      final sign = offset.isNegative ? '-' : '+';
      return '${t.year}-${two(t.month)}-${two(t.day)} ${days[t.weekday - 1]} '
          '${two(t.hour)}:${two(t.minute)} (UTC$sign'
          '${two(offset.inHours.abs())}:${two(offset.inMinutes.abs() % 60)})';
    },
  ),
  CharacterTool(
    const LlmTool(
      name: 'remember_fact',
      description:
          'Remember one short fact about the user for the rest of this chat '
          '(their name, what they like, plans they mentioned).',
      parameters: {
        'type': 'object',
        'properties': {
          'fact': {
            'type': 'string',
            'description': 'The fact, in one short sentence.',
          },
        },
        'required': ['fact'],
        'additionalProperties': false,
      },
    ),
    (args) async =>
        memory.add('${args['fact'] ?? ''}') ? 'Remembered.' : 'Already known.',
  ),
  CharacterTool(
    const LlmTool(
      name: 'forget_fact',
      description: 'Forget a fact the user asked you not to keep.',
      parameters: {
        'type': 'object',
        'properties': {
          'fact': {
            'type': 'string',
            'description': 'The fact exactly as remembered.',
          },
        },
        'required': ['fact'],
        'additionalProperties': false,
      },
    ),
    (args) async =>
        memory.remove('${args['fact'] ?? ''}') ? 'Forgotten.' : 'Not found.',
  ),
];

/// Runs [call] with the matching tool; unknown tools and failures become
/// a message the model can read.
Future<String> runCharacterTool(
  List<CharacterTool> tools,
  String name,
  String arguments,
) async {
  final tool = tools.where((t) => t.name == name).firstOrNull;
  if (tool == null) return 'Unknown tool "$name".';
  try {
    return await tool.run(toolArguments(arguments));
  } catch (error) {
    return 'The tool failed: $error';
  }
}
