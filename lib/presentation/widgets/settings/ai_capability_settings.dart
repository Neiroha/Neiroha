import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/providers/ai_capability_providers.dart';
import 'package:neiroha/providers/app_providers.dart';

import 'ai_capability_dialogs.dart';
import 'settings_shared.dart';

String capabilityLabel(AppLocalizations l, AiCapability cap) => switch (cap) {
  AiCapability.llm => l.capLlm,
  AiCapability.tts => l.capTts,
  AiCapability.stt => l.capStt,
  AiCapability.realtime => l.capRealtime,
  AiCapability.translate => l.capTranslate,
  AiCapability.vc => l.capVc,
  AiCapability.vad => l.capVad,
  AiCapability.music => l.capMusic,
};

IconData capabilityIcon(AiCapability cap) => switch (cap) {
  AiCapability.llm => Icons.psychology_rounded,
  AiCapability.tts => Icons.record_voice_over_rounded,
  AiCapability.stt => Icons.hearing_rounded,
  AiCapability.realtime => Icons.forum_rounded,
  AiCapability.translate => Icons.translate_rounded,
  AiCapability.vc => Icons.transform_rounded,
  AiCapability.vad => Icons.graphic_eq_rounded,
  AiCapability.music => Icons.music_note_rounded,
};

String connectionName(ProviderConnection c) =>
    c.config.name.isEmpty ? c.plugin.displayName : c.config.name;

/// 「设置 → AI 能力」: per capability, the default model, and per connection
/// an on/off switch, its own limits and models added beyond the catalog.
class AiCapabilitySettingsCard extends ConsumerWidget {
  const AiCapabilitySettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(aiCapabilityRouterProvider).value;
    final lanes = ref.watch(connectionCapabilitiesProvider).value ?? const [];
    final added = ref.watch(providerModelsProvider).value ?? const [];
    if (router == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final cap in AiCapability.values)
          if (router.connections.any((c) => c.capabilities.contains(cap)))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CapabilityCard(
                cap: cap,
                router: router,
                lanes: lanes,
                added: added,
              ),
            ),
      ],
    );
  }
}

class _CapabilityCard extends ConsumerWidget {
  const _CapabilityCard({
    required this.cap,
    required this.router,
    required this.lanes,
    required this.added,
  });
  final AiCapability cap;
  final CapabilityRouter router;
  final List<db.ConnectionCapability> lanes;
  final List<db.ProviderModel> added;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final database = ref.read(databaseProvider);
    final choices = [
      for (final c in router.serving(cap))
        for (final m in router.modelsOf(c, cap)) (c, m),
    ];
    final current = router.defaults[cap];
    final picked = choices.any((e) => (e.$1.id, e.$2.id) == current)
        ? current
        : null;
    final offering = [
      for (final c in router.connections)
        if (c.capabilities.contains(cap)) c,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsRow(
              icon: capabilityIcon(cap),
              title: capabilityLabel(l, cap),
              subtitle: l.capDefaultModel,
              trailing: SizedBox(
                width: 320,
                child: DropdownButtonFormField<(String, String)?>(
                  initialValue: picked,
                  isExpanded: true,
                  decoration: const InputDecoration(isDense: true),
                  items: [
                    DropdownMenuItem(value: null, child: Text(l.capAutomatic)),
                    for (final (c, m) in choices)
                      DropdownMenuItem(
                        value: (c.id, m.id),
                        child: Text(
                          '${connectionName(c)} · ${m.label}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => database.setCapabilityDefault(cap.name, v),
                ),
              ),
            ),
            const Divider(),
            if (offering.isEmpty)
              Text(
                l.capNoConnections,
                style: const TextStyle(color: Colors.white54),
              ),
            for (final c in offering)
              _ConnectionLane(
                cap: cap,
                connection: c,
                router: router,
                lane: lanes
                    .where((r) => r.connectionId == c.id)
                    .where((r) => r.capability == cap.name)
                    .firstOrNull,
                added: [
                  for (final m in added)
                    if (m.connectionId == c.id && m.capability == cap.name) m,
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionLane extends ConsumerWidget {
  const _ConnectionLane({
    required this.cap,
    required this.connection,
    required this.router,
    required this.lane,
    required this.added,
  });
  final AiCapability cap;
  final ProviderConnection connection;
  final CapabilityRouter router;
  final db.ConnectionCapability? lane;
  final List<db.ProviderModel> added;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final database = ref.read(databaseProvider);
    final on = router.offers(connection, cap);
    final custom = lane != null && laneHasLimits(lane!);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Switch(
                value: on,
                onChanged: (v) => database.upsertConnectionCapability(
                  db.ConnectionCapabilitiesCompanion(
                    connectionId: Value(connection.id),
                    capability: Value(cap.name),
                    enabled: Value(v),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  connectionName(connection),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: on ? null : Colors.white38),
                ),
              ),
              TextButton.icon(
                icon: Icon(
                  Icons.speed_rounded,
                  size: 16,
                  color: custom ? AppTheme.accentColor : null,
                ),
                label: Text(custom ? l.capLimits : l.capInherited),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => CapabilityLimitsDialog(
                    title: l.capLimitsTitle(
                      capabilityLabel(l, cap),
                      connectionName(connection),
                    ),
                    connectionId: connection.id,
                    capability: cap,
                    lane: lane,
                  ),
                ),
              ),
              IconButton(
                tooltip: l.capAddModel,
                icon: const Icon(Icons.add_rounded, size: 18),
                onPressed: () =>
                    addCapabilityModel(context, ref, connection, cap),
              ),
            ],
          ),
          if (added.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 56, bottom: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final m in added)
                    InputChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        m.displayName?.isNotEmpty == true
                            ? '${m.displayName} (${m.modelId})'
                            : m.modelId,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onDeleted: () => database.deleteProviderModel(m.id),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
