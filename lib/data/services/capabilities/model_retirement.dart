import 'package:drift/drift.dart' show Value;
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/registry/built_in_voices.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/domain/platform/platform_capabilities.dart';

/// The model platform this build runs on.
AiPlatform aiPlatformOf(PlatformCapabilities capabilities) =>
    switch (capabilities.platform) {
      NeirohaPlatform.web => AiPlatform.web,
      NeirohaPlatform.android || NeirohaPlatform.ios => AiPlatform.android,
      _ => AiPlatform.desktop,
    };

/// The catalog entry of [modelId] on [connection] when the vendor has
/// announced a shutdown date for it, under any capability.
ModelDescriptor? retiringDescriptor(
  ProviderConnection? connection,
  String modelId,
) {
  final id = modelId.trim();
  if (connection == null || id.isEmpty) return null;
  for (final cap in connection.capabilities) {
    for (final m in connection.models(cap)) {
      if (m.id == id && m.shutdownAt != null) return m;
    }
  }
  return null;
}

/// The TTS model a character speaks with: its own override, else the
/// provider default.
String effectiveTtsModel(db.VoiceAsset asset, db.TtsProvider provider) {
  final own = asset.modelName?.trim() ?? '';
  return own.isNotEmpty ? own : provider.defaultModelName.trim();
}

/// Whole days from [now] until [shutdownAt] (negative once past).
int daysUntil(String shutdownAt, DateTime now) {
  final day = DateTime.parse(shutdownAt);
  final today = DateTime(now.year, now.month, now.day);
  return DateTime(day.year, day.month, day.day).difference(today).inDays;
}

/// Where a retiring model can move: the vendor's replacement and, when the
/// current preset voice does not exist there, the replacement's first voice.
class RetirementMove {
  const RetirementMove(this.model, {this.voice});
  final String model;

  /// Voice to switch to; null keeps the current voice.
  final String? voice;
}

/// The vendor's replacement for [retiring] when it runs on [platform] and
/// the provider mounts it; null when the user has to pick another provider
/// (for example on the web, where Realtime models need a native socket).
RetirementMove? replacementFor(
  db.TtsProvider provider,
  ModelDescriptor retiring, {
  required AiPlatform platform,
  String? currentVoice,
}) {
  final target = retiring.replacement;
  if (target == null) return null;
  final mounted = connectionForProvider(
    provider,
  ).models(retiring.capability).where((m) => m.id == target).firstOrNull;
  if (mounted == null || !mounted.platforms.contains(platform)) return null;
  final type = AdapterType.values.asNameMap()[provider.adapterType];
  final voices = type == null
      ? const <String>[]
      : builtInVoicesFor(type, target);
  final voice = currentVoice?.trim() ?? '';
  // Custom voices (`voice_…`) and unknown lists are kept as they are.
  final keep =
      voices.isEmpty ||
      voice.isEmpty ||
      voice.startsWith('voice_') ||
      voices.contains(voice);
  return RetirementMove(target, voice: keep ? null : voices.first);
}

/// A character whose TTS model is going away.
class RetiringUse {
  const RetiringUse(this.asset, this.provider, this.model);
  final db.VoiceAsset asset;
  final db.TtsProvider provider;
  final ModelDescriptor model;

  RetirementMove? move(AiPlatform platform) => replacementFor(
    provider,
    model,
    platform: platform,
    currentVoice: asset.presetVoiceName,
  );
}

/// Every enabled character speaking with a model that has a shutdown date,
/// soonest first.
List<RetiringUse> findRetiringUses(
  List<db.TtsProvider> providers,
  List<db.VoiceAsset> assets,
) {
  final byId = {for (final p in providers) p.id: p};
  final connections = <String, ProviderConnection>{};
  final uses = <RetiringUse>[];
  for (final asset in assets) {
    final provider = byId[asset.providerId];
    if (provider == null || !asset.enabled) continue;
    final connection = connections[provider.id] ??= connectionForProvider(
      provider,
    );
    final model = retiringDescriptor(
      connection,
      effectiveTtsModel(asset, provider),
    );
    if (model != null && model.capability == AiCapability.tts) {
      uses.add(RetiringUse(asset, provider, model));
    }
  }
  uses.sort((a, b) => a.model.shutdownAt!.compareTo(b.model.shutdownAt!));
  return uses;
}

/// Moves every use that has a replacement on [platform]; provider defaults
/// pointing at a retiring model move too. Returns the characters moved.
Future<int> migrateRetiring(
  db.AppDatabase database,
  List<RetiringUse> uses, {
  required AiPlatform platform,
}) async {
  var moved = 0;
  await database.transaction(() async {
    final providers = <String, db.TtsProvider>{};
    for (final use in uses) {
      final move = use.move(platform);
      if (move == null) continue;
      await database.updateVoiceAsset(
        use.asset.copyWith(
          modelName: Value(move.model),
          presetVoiceName: move.voice == null
              ? Value(use.asset.presetVoiceName)
              : Value(move.voice),
        ),
      );
      moved++;
      providers[use.provider.id] = use.provider;
    }
    for (final provider in providers.values) {
      final retiring = retiringDescriptor(
        connectionForProvider(provider),
        provider.defaultModelName,
      );
      if (retiring == null) continue;
      final move = replacementFor(provider, retiring, platform: platform);
      if (move != null) {
        await database.updateProvider(
          provider.copyWith(defaultModelName: move.model),
        );
      }
    }
  });
  return moved;
}
