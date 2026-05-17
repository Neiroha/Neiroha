import 'dart:convert';

import '../database/app_database.dart';

/// One reusable text-splitting rule. Saved globally (in `AppSettings`) so the
/// user's regex collection is shared across every Phase TTS project.
///
/// Two rule kinds:
/// - `mode = 'newline'` — split paragraphs at blank lines (default).
/// - `mode = 'regex'` — split at every occurrence of [pattern]. The matched
///   delimiter character/sequence is *kept* on the trailing side of the
///   previous segment, mirroring how Chinese/English sentence punctuation is
///   normally read aloud (the period belongs to the sentence it terminates).
///
/// [builtIn] rules are seeded by the app and cannot be deleted or edited;
/// the user can still hide them by toggling [enabled] off in their list.
class SplitRule {
  final String id;
  final String name;
  final String mode; // 'newline' | 'regex'
  final String pattern; // raw regex source; ignored when mode == 'newline'
  final bool builtIn;
  final bool enabled;

  const SplitRule({
    required this.id,
    required this.name,
    required this.mode,
    this.pattern = '',
    this.builtIn = false,
    this.enabled = true,
  });

  bool get isNewline => mode == 'newline';

  SplitRule copyWith({
    String? name,
    String? mode,
    String? pattern,
    bool? enabled,
  }) => SplitRule(
    id: id,
    name: name ?? this.name,
    mode: mode ?? this.mode,
    pattern: pattern ?? this.pattern,
    builtIn: builtIn,
    enabled: enabled ?? this.enabled,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mode': mode,
    'pattern': pattern,
    'builtIn': builtIn,
    'enabled': enabled,
  };

  factory SplitRule.fromJson(Map<String, dynamic> json) => SplitRule(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    mode: json['mode']?.toString() ?? 'regex',
    pattern: json['pattern']?.toString() ?? '',
    builtIn: json['builtIn'] == true,
    enabled: json['enabled'] != false,
  );
}

/// Apply a [SplitRule] to a script. Returns trimmed, non-empty segments in
/// document order. Newline rules split at blank lines; regex rules split at
/// each match while keeping the delimiter character attached to the
/// preceding segment (so `"。"` ends up on the sentence it closes).
List<String> applySplitRule(SplitRule rule, String script) {
  final text = script;
  if (text.trim().isEmpty) return const [];

  if (rule.isNewline) {
    return text
        .split(RegExp(r'\n\s*\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  final pattern = rule.pattern.trim();
  if (pattern.isEmpty) return [text.trim()];

  final RegExp regex;
  try {
    regex = RegExp(pattern, multiLine: true, dotAll: true);
  } on FormatException {
    return [text.trim()];
  }

  final segments = <String>[];
  var cursor = 0;
  for (final match in regex.allMatches(text)) {
    final end = match.end;
    final piece = text.substring(cursor, end).trim();
    if (piece.isNotEmpty) segments.add(piece);
    cursor = end;
  }
  if (cursor < text.length) {
    final tail = text.substring(cursor).trim();
    if (tail.isNotEmpty) segments.add(tail);
  }
  return segments.isEmpty ? [text.trim()] : segments;
}

/// Reader/writer for the user's [SplitRule] collection. Backed by a single
/// JSON blob in `AppSettings` (`split_rules.list`).
class SplitRulesService {
  SplitRulesService(this._db);

  final AppDatabase _db;

  static const String kListKey = 'split_rules.list';
  static const String kSelectedKey = 'split_rules.selectedId';

  /// Built-in rules seeded on first read. The user cannot edit or delete
  /// these but can disable them.
  static const List<SplitRule> builtInRules = [
    SplitRule(
      id: 'builtin.newline',
      name: '按段落 (空行分隔)',
      mode: 'newline',
      builtIn: true,
    ),
    SplitRule(
      id: 'builtin.sentence',
      name: '按句号 (中英文)',
      mode: 'regex',
      // 句末标点：. 。 ! ! ? ? — 任意一种 + 可选闭合引号
      pattern: r'[\.。!！?？][”"’〕\)\]】]?',
      builtIn: true,
    ),
    SplitRule(
      id: 'builtin.quotes',
      name: '按引号 (中英文)',
      mode: 'regex',
      // 引号闭合后断句：" " ' '
      pattern: r'["”’」』]',
      builtIn: true,
    ),
  ];

  Future<List<SplitRule>> load() async {
    final raw = await _db.getSetting(kListKey);
    if (raw == null || raw.trim().isEmpty) {
      // Seed built-ins on first run so the dropdown is never empty.
      return List.of(builtInRules);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return List.of(builtInRules);
      final user = <SplitRule>[];
      for (final entry in decoded) {
        if (entry is Map) {
          user.add(SplitRule.fromJson(entry.cast<String, dynamic>()));
        }
      }
      // Ensure built-ins are always present (re-add any the user lost
      // through a corrupt write) but preserve their `enabled` state.
      final byId = {for (final r in user) r.id: r};
      for (final builtIn in builtInRules) {
        byId.putIfAbsent(builtIn.id, () => builtIn);
      }
      return byId.values.toList();
    } catch (_) {
      return List.of(builtInRules);
    }
  }

  Future<void> save(List<SplitRule> rules) async {
    final encoded = jsonEncode([for (final r in rules) r.toJson()]);
    await _db.setSetting(kListKey, encoded);
  }

  Future<String?> getSelectedId() => _db.getSetting(kSelectedKey);

  Future<void> setSelectedId(String? id) async {
    if (id == null || id.isEmpty) {
      await _db.deleteSetting(kSelectedKey);
    } else {
      await _db.setSetting(kSelectedKey, id);
    }
  }
}
