import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:neiroha/data/ai/core/capability_health.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';

/// The provider row the provider screen shows; null picks the first one.
final selectedProviderIdProvider = StateProvider<String?>((ref) => null);

/// Last capability check per provider row, for the list's health dot.
final providerHealthProvider =
    StateProvider<Map<String, Map<AiCapability, CapabilityHealth>>>(
      (_) => const {},
    );

/// Unsaved edits of one provider row, shared by the editor's tabs.
class ProviderDraft {
  ProviderDraft(db.TtsProvider p)
    : name = TextEditingController(text: p.name),
      baseUrl = TextEditingController(text: p.baseUrl),
      apiKey = TextEditingController(text: p.apiKey),
      model = TextEditingController(text: p.defaultModelName),
      concurrency = TextEditingController(text: '${p.maxConcurrency}'),
      rpm = _limit(p.requestsPerMinute),
      rpd = _limit(p.requestsPerDay),
      tpm = _limit(p.tokensPerMinute),
      tpd = _limit(p.tokensPerDay),
      adapterType = AdapterType.values.firstWhere(
        (t) => t.name == p.adapterType,
        orElse: () => AdapterType.openaiCompatible,
      );

  final TextEditingController name;
  final TextEditingController baseUrl;
  final TextEditingController apiKey;
  final TextEditingController model;
  final TextEditingController concurrency;
  final TextEditingController rpm;
  final TextEditingController rpd;
  final TextEditingController tpm;
  final TextEditingController tpd;
  AdapterType adapterType;

  static TextEditingController _limit(int? v) =>
      TextEditingController(text: v?.toString() ?? '');

  static int? _optional(TextEditingController c) {
    final n = int.tryParse(c.text.trim());
    return n == null || n <= 0 ? null : n;
  }

  /// The connection fields applied to [base], to test before saving.
  db.TtsProvider connection(db.TtsProvider base, String defaultModel) =>
      base.copyWith(
        adapterType: adapterType.name,
        baseUrl: baseUrl.text.trim(),
        apiKey: apiKey.text,
        defaultModelName: model.text.trim().isEmpty
            ? defaultModel
            : model.text.trim(),
      );

  /// Every field applied to [base], to save.
  db.TtsProvider row(db.TtsProvider base, String defaultModel) =>
      connection(base, defaultModel).copyWith(
        name: name.text.trim(),
        maxConcurrency: (int.tryParse(concurrency.text.trim()) ?? 1)
            .clamp(1, 64)
            .toInt(),
        requestsPerMinute: Value(_optional(rpm)),
        requestsPerDay: Value(_optional(rpd)),
        tokensPerMinute: Value(_optional(tpm)),
        tokensPerDay: Value(_optional(tpd)),
      );

  void dispose() {
    for (final c in [
      name,
      baseUrl,
      apiKey,
      model,
      concurrency,
      rpm,
      rpd,
      tpm,
      tpd,
    ]) {
      c.dispose();
    }
  }
}

String baseUrlHint(AdapterType type) => switch (type) {
  AdapterType.azureTts =>
    'https://eastasia.tts.speech.microsoft.com  (or region name)',
  AdapterType.systemTts => '(not required)',
  AdapterType.gptSovits => 'http://127.0.0.1:9880',
  AdapterType.cosyvoice => 'http://127.0.0.1:9880',
  AdapterType.voxcpm2Native => 'http://127.0.0.1:8000',
  AdapterType.openaiTts => 'https://api.openai.com/v1',
  AdapterType.geminiTts => 'https://generativelanguage.googleapis.com',
  AdapterType.elevenLabs => 'https://api.elevenlabs.io',
  AdapterType.minimaxTts =>
    'https://api.minimax.io  (China: https://api.minimaxi.com)',
  AdapterType.indexTts => 'http://127.0.0.1:7860  (IndexTTS WebUI)',
  AdapterType.irodori => 'http://127.0.0.1:19000',
  AdapterType.rvc => 'http://127.0.0.1:19001  (Neiroha-RVC, voice conversion)',
  _ => 'https://api.openai.com/v1',
};

/// Green when every checked capability works, amber when some fail, red
/// when all fail; null before any check.
Color? healthColor(Map<AiCapability, CapabilityHealth>? health) {
  if (health == null || health.isEmpty) return null;
  final failed = health.values.where((h) => h.state == HealthState.failed);
  if (failed.isEmpty) return Colors.greenAccent;
  return failed.length == health.length ? Colors.redAccent : Colors.amber;
}
