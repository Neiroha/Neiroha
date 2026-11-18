import 'role_analysis_protocol.dart';

/// Application-dispatched action protocol, shared by Chat Completions/Responses.
/// Nested anyOf follows https://developers.openai.com/api/docs/guides/structured-outputs
class RoleReviewProtocol {
  static const version = 'local-review-v1';
  static Map<String, Object?> text([int limit = 300]) => {
    'type': 'string',
    'maxLength': limit,
  };
  static Map<String, Object?> action(String name, Map<String, Object?> args) =>
      RoleAnalysisProtocol.object({
        'action': {
          'type': 'string',
          'enum': [name],
        },
        ...args,
      });
  static Map<String, Object?> get evidence => {
    'type': 'array',
    'minItems': 1,
    'maxItems': 3,
    'items': RoleAnalysisProtocol.object({
      'segmentId': text(100),
      'quote': text(160),
    }),
  };
  static Map<String, Object?> get schema => RoleAnalysisProtocol.object({
    'actions': {
      'type': 'array',
      'minItems': 1,
      'maxItems': 4,
      'items': {
        'anyOf': [
          action('read_context', {
            'segmentId': text(100),
            'radius': {'type': 'integer', 'minimum': 0, 'maximum': 2},
          }),
          action('search_text', {'query': text(80)}),
          action('inspect_character', {'query': text(100)}),
          action('propose_patch', {
            'key': text(40),
            'segmentId': text(100),
            'characterRef': {
              'type': ['string', 'null'],
            },
            'kind': {
              'type': 'string',
              'enum': ['narrator', 'dialogue', 'thought', 'system'],
            },
            'reason': text(),
            'evidence': evidence,
          }),
          action('propose_character', {
            'key': text(40),
            'name': text(80),
            'aliases': {'type': 'array', 'maxItems': 8, 'items': text(80)},
            'description': text(500),
            'identityKind': {
              'type': 'string',
              'enum': ['named', 'anonymous', 'group'],
            },
            'reason': text(),
            'evidence': evidence,
          }),
          action('propose_merge', {
            'key': text(40),
            'fromId': text(100),
            'intoId': text(100),
            'reason': text(),
            'evidence': evidence,
          }),
          action('finish', {'reason': text()}),
        ],
      },
    },
  });
  static List<Map<String, dynamic>> parse(Map<String, dynamic> output) {
    final actions = output['actions'];
    if (output.length != 1 ||
        actions is! List ||
        actions.isEmpty ||
        actions.length > 4 ||
        actions.any((a) => a is! Map)) {
      throw const FormatException('Invalid local review action batch.');
    }
    return actions.map((a) => Map<String, dynamic>.from(a as Map)).toList();
  }
}
