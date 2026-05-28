import 'dart:convert';

import '../database/app_database.dart';

class NovelTextFilterRule {
  final String id;
  final String name;
  final String pattern;
  final String replacement;
  final bool builtIn;
  final bool enabled;

  const NovelTextFilterRule({
    required this.id,
    required this.name,
    required this.pattern,
    this.replacement = '',
    this.builtIn = false,
    this.enabled = true,
  });

  NovelTextFilterRule copyWith({
    String? name,
    String? pattern,
    String? replacement,
    bool? enabled,
  }) {
    return NovelTextFilterRule(
      id: id,
      name: name ?? this.name,
      pattern: pattern ?? this.pattern,
      replacement: replacement ?? this.replacement,
      builtIn: builtIn,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'pattern': pattern,
    'replacement': replacement,
    'builtIn': builtIn,
    'enabled': enabled,
  };

  factory NovelTextFilterRule.fromJson(Map<String, dynamic> json) {
    return NovelTextFilterRule(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      pattern: json['pattern']?.toString() ?? '',
      replacement: json['replacement']?.toString() ?? '',
      builtIn: json['builtIn'] == true,
      enabled: json['enabled'] != false,
    );
  }
}

class NovelTextFilterRulesService {
  NovelTextFilterRulesService(this._db);

  final AppDatabase _db;

  static const String kListKey = 'novel_text_filter_rules.list';

  static const List<NovelTextFilterRule> builtInRules = [
    NovelTextFilterRule(
      id: 'builtin.emoji_symbols',
      name: 'Emoji and pictographs',
      pattern:
          r'[\u{1F1E6}-\u{1F1FF}\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}]+',
      builtIn: true,
    ),
  ];

  Future<List<NovelTextFilterRule>> load() async {
    final raw = await _db.getSetting(kListKey);
    if (raw == null || raw.trim().isEmpty) return List.of(builtInRules);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return List.of(builtInRules);
      final saved = <NovelTextFilterRule>[];
      for (final entry in decoded) {
        if (entry is Map) {
          saved.add(
            NovelTextFilterRule.fromJson(entry.cast<String, dynamic>()),
          );
        }
      }
      final byId = {for (final rule in saved) rule.id: rule};
      for (final builtIn in builtInRules) {
        byId.putIfAbsent(builtIn.id, () => builtIn);
      }
      return byId.values.toList();
    } catch (_) {
      return List.of(builtInRules);
    }
  }

  Future<void> save(List<NovelTextFilterRule> rules) async {
    await _db.setSetting(
      kListKey,
      jsonEncode([for (final rule in rules) rule.toJson()]),
    );
  }

  static String applyFilters(String input, List<NovelTextFilterRule> rules) {
    var text = input;
    for (final rule in rules) {
      if (!rule.enabled || rule.pattern.trim().isEmpty) continue;
      try {
        text = text.replaceAll(
          RegExp(rule.pattern, multiLine: true, dotAll: true, unicode: true),
          rule.replacement,
        );
      } on FormatException {
        // Invalid saved custom rules are ignored at synthesis time so one
        // malformed pattern cannot block the whole novel.
      }
    }
    return text;
  }

  static String signature(List<NovelTextFilterRule> rules) {
    return [
      for (final rule in rules)
        if (rule.enabled)
          [rule.id, rule.pattern, rule.replacement].join('\u001E'),
    ].join('\u001F');
  }
}
