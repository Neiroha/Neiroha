// Live: does LLM discovery find the account's models and their traits?
//   set -a; source .env; set +a
//   flutter test scripts/tests/ai_llm_discovery_live_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/catalog/llm_discovery.dart';
import 'package:neiroha/data/ai/catalog/llm_traits_catalog.dart';
import 'package:neiroha/data/ai/core/capability_health.dart';
import 'package:neiroha/data/ai/core/connection_config.dart';
import 'package:neiroha/data/ai/providers/openai/openai_plugin.dart';
import 'package:neiroha/domain/ai/ai.dart';

void main() {
  final env = Platform.environment;
  final key = env['OPENAI_TEST_API_KEY'] ?? env['OPENAI_KEY'] ?? '';
  final skip = key.isEmpty ? 'OPENAI_TEST_API_KEY / OPENAI_KEY not set' : null;

  test('OpenAI: lists LLMs only, with snapshot traits', () async {
    final catalog = LlmTraitsCatalog.fromSnapshot(
      jsonDecode(File(LlmTraitsCatalog.asset).readAsStringSync())
          as Map<String, dynamic>,
    );
    final connection = const OpenAiPlugin().connect(
      ConnectionConfig(id: 'live', baseUrl: '', apiKey: key),
    );
    final inventory = await LlmDiscovery(catalog).discover(connection);
    expect(inventory.state, HealthState.ok, reason: inventory.message);

    String fmt(ModelDescriptor m) {
      final t = m.llm ?? LlmTraits.unknown;
      final r = t.reasoning;
      return '${m.id.padRight(28)} ${m.source.name.padRight(8)} '
          'tools=${t.tools} schema=${t.structuredOutput} '
          'in=${t.inputs?.map((e) => e.name).join('+')} '
          'think=${r == null
              ? '?'
              : !r.supported
              ? 'no'
              : r.levels.isEmpty
              ? 'yes'
              : r.levels.map((e) => e.name).join('/')}'
          '${r?.modes.isNotEmpty == true ? ' modes=${r!.modes.join('/')}' : ''} '
          'ctx=${t.contextWindow}';
    }

    // ignore: avoid_print
    print(inventory.models.map(fmt).join('\n'));

    final ids = inventory.models.map((m) => m.id).toSet();
    for (final notLlm in const [
      'tts-1',
      'whisper-1',
      'gpt-transcribe',
      'text-embedding-3-small',
      'gpt-realtime-2.1',
    ]) {
      expect(ids, isNot(contains(notLlm)));
    }
    final luna = inventory.find('gpt-6-luna')!;
    expect(luna.llm!.tools, isTrue);
    expect(luna.llm!.accepts(Modality.image), isTrue);
    expect(luna.llm!.reasoning!.canDisable, isTrue);
    expect(luna.llm!.reasoning!.levels.last, ReasoningEffort.max);
    expect(
      inventory.models.where((m) => m.source == DescriptorSource.provider),
      isNotEmpty,
      reason: 'account models outside the plugin catalog are discovered',
    );
  }, skip: skip);
}
