import 'dart:convert';

import '../database/app_database.dart';

class NovelDialogueRule {
  final String id;
  final String name;
  final String pattern;
  final bool builtIn;
  final bool enabled;

  const NovelDialogueRule({
    required this.id,
    required this.name,
    required this.pattern,
    this.builtIn = false,
    this.enabled = true,
  });

  NovelDialogueRule copyWith({String? name, String? pattern, bool? enabled}) {
    return NovelDialogueRule(
      id: id,
      name: name ?? this.name,
      pattern: pattern ?? this.pattern,
      builtIn: builtIn,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'pattern': pattern,
    'builtIn': builtIn,
    'enabled': enabled,
  };

  factory NovelDialogueRule.fromJson(Map<String, dynamic> json) {
    return NovelDialogueRule(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      pattern: json['pattern']?.toString() ?? '',
      builtIn: json['builtIn'] == true,
      enabled: json['enabled'] != false,
    );
  }
}

class NovelDialogueRulesService {
  NovelDialogueRulesService(this._db);

  final AppDatabase _db;

  static const String kListKey = 'novel_dialogue_rules.list';

  static const List<NovelDialogueRule> builtInRules = [
    NovelDialogueRule(
      id: 'builtin.cn_double_quote',
      name: '中文双引号',
      pattern: r'“[\s\S]*?”',
      builtIn: true,
    ),
    NovelDialogueRule(
      id: 'builtin.en_double_quote',
      name: '英文双引号',
      pattern: r'"[\s\S]*?"',
      builtIn: true,
    ),
    NovelDialogueRule(
      id: 'builtin.corner_quote',
      name: '直角引号',
      pattern: r'「[\s\S]*?」',
      builtIn: true,
    ),
    NovelDialogueRule(
      id: 'builtin.white_corner_quote',
      name: '白直角引号',
      pattern: r'『[\s\S]*?』',
      builtIn: true,
    ),
    NovelDialogueRule(
      id: 'builtin.book_title_quote',
      name: '书名号',
      pattern: r'《[\s\S]*?》',
      builtIn: true,
      enabled: false,
    ),
  ];

  Future<List<NovelDialogueRule>> load() async {
    final raw = await _db.getSetting(kListKey);
    if (raw == null || raw.trim().isEmpty) return List.of(builtInRules);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return List.of(builtInRules);
      final saved = <NovelDialogueRule>[];
      for (final entry in decoded) {
        if (entry is Map) {
          saved.add(NovelDialogueRule.fromJson(entry.cast<String, dynamic>()));
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

  Future<void> save(List<NovelDialogueRule> rules) async {
    await _db.setSetting(
      kListKey,
      jsonEncode([for (final rule in rules) rule.toJson()]),
    );
  }
}
