import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:yaml/yaml.dart';

/// Versioned instructions; runtime permissions and schemas remain in code.
class NovelRoleSkill {
  NovelRoleSkill._(this.name, this.version, this.digest, this._prompts);

  static const requiredStages = [
    'planner',
    'executor',
    'reviewer',
    'caster',
    'director',
  ];
  final String name;
  final String version;
  final String digest;
  final Map<String, String> _prompts;

  String prompt(String stage) =>
      _prompts[stage] ??
      (throw ArgumentError.value(stage, 'stage', 'Unknown role skill stage'));

  Map<String, String> get identity => {
    'name': name,
    'version': version,
    'sha256': digest,
  };

  factory NovelRoleSkill.parse(String document) {
    final normalized = document.replaceAll('\r\n', '\n');
    final header = RegExp(
      r'^---\n([\s\S]*?)\n---(?:\n|$)',
    ).firstMatch(normalized);
    if (header == null) throw const FormatException('Missing skill metadata.');
    final yaml = loadYaml(header.group(1)!);
    if (yaml is! YamlMap ||
        yaml['name'] != 'novel-role-assign' ||
        yaml['description'] is! String ||
        (yaml['description'] as String).trim().isEmpty) {
      throw const FormatException('Invalid novel role skill identity.');
    }
    final metadata = yaml['metadata'];
    if (metadata is! YamlMap ||
        metadata['runtime'] != 'neiroha-role-analysis-v1' ||
        metadata['version'] is! String ||
        !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(metadata['version'] as String)) {
      throw const FormatException('Unsupported role skill runtime or version.');
    }
    final body = normalized.substring(header.end);
    final headings = RegExp(
      r'^## ([a-z][a-z0-9_-]*)\s*$',
      multiLine: true,
    ).allMatches(body).toList();
    final prompts = <String, String>{};
    for (var i = 0; i < headings.length; i++) {
      final stage = headings[i].group(1)!;
      if (!requiredStages.contains(stage)) continue;
      if (prompts.containsKey(stage)) {
        throw FormatException('Duplicate role skill stage: $stage');
      }
      final end = i + 1 < headings.length ? headings[i + 1].start : body.length;
      final text = body.substring(headings[i].end, end).trim();
      if (text.isEmpty || text.length > 16000) {
        throw FormatException('Empty or oversized role skill stage: $stage');
      }
      prompts[stage] = text;
    }
    if (!requiredStages.every(prompts.containsKey)) {
      throw const FormatException('Incomplete novel role skill.');
    }
    return NovelRoleSkill._(
      yaml['name'] as String,
      metadata['version'] as String,
      sha256.convert(utf8.encode(normalized)).toString(),
      Map.unmodifiable(prompts),
    );
  }
}
