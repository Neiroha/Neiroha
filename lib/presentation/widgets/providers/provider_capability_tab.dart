import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/ai/catalog/llm_discovery.dart';
import 'package:neiroha/data/ai/core/capability_health.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/widgets/ai/llm_traits_chips.dart';
import 'package:neiroha/presentation/widgets/settings/ai_capability_dialogs.dart';
import 'package:neiroha/presentation/widgets/settings/ai_capability_settings.dart';
import 'package:neiroha/providers/ai_capability_providers.dart';
import 'package:neiroha/providers/app_providers.dart';

import 'provider_models.dart';

/// One capability of one connection (everything but speech synthesis):
/// its switch, the catalog, fetched and added models, and the default.
/// Language models can also be discovered from the account.
class ProviderCapabilityTab extends ConsumerStatefulWidget {
  const ProviderCapabilityTab({
    super.key,
    required this.provider,
    required this.cap,
  });
  final db.TtsProvider provider;
  final AiCapability cap;

  @override
  ConsumerState<ProviderCapabilityTab> createState() =>
      _ProviderCapabilityTabState();
}

/// A model row before it is drawn.
typedef _Entry = ({
  ModelDescriptor model,
  String source,
  VoidCallback? onDelete,
});

class _ProviderCapabilityTabState extends ConsumerState<ProviderCapabilityTab> {
  final _query = TextEditingController();

  /// Whether the account's model list was asked for (LLM only).
  bool _live = false;

  static const _searchFrom = 12;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  AiCapability get cap => widget.cap;

  List<_Entry> _entries(ProviderConnection c, AppLocalizations l) {
    final database = ref.read(databaseProvider);
    final entries = <_Entry>[];
    void add(ModelDescriptor m, String source, [VoidCallback? onDelete]) {
      if (entries.any((e) => e.model.id == m.id)) return;
      entries.add((model: m, source: source, onDelete: onDelete));
    }

    String source(ModelDescriptor m, LlmInventory? inv) =>
        m.source == DescriptorSource.provider
        ? l.llmSourceAccount
        : inv?.unlisted(m) ?? false
        ? l.llmSourceUnlisted
        : l.llmSourceCatalog;

    if (cap == AiCapability.llm) {
      final live = _live
          ? ref.watch(llmInventoryProvider(widget.provider.id)).value
          : null;
      final catalog = ref.watch(llmTraitsCatalogProvider).value;
      final inventory =
          live ?? (catalog == null ? null : LlmDiscovery(catalog).offline(c));
      for (final m in inventory?.models ?? c.models(cap)) {
        add(m, source(m, inventory));
      }
    } else {
      for (final m in c.models(cap)) {
        add(m, source(m, null));
      }
    }
    final bindings =
        ref.watch(providerBindingsProvider(widget.provider.id)).value ??
        const [];
    final type = AdapterType.values.asNameMap()[widget.provider.adapterType];
    for (final b in bindings) {
      // Voice-only engines list voices, not models.
      if (type == null || !type.hasSeparateModelAndVoice) break;
      if (b.supportedTaskModes == 'voice' || isTtsModelKey(type, b.modelKey)) {
        continue;
      }
      if (bindingCapability(b.modelKey, c) != cap) continue;
      if (c.describe(cap, b.modelKey) case final m?) {
        add(m, l.provSourceFetched, () async {
          await database.deleteBinding(b.id);
          ref.invalidate(providerBindingsProvider(widget.provider.id));
        });
      }
    }
    final added = ref.watch(providerModelsProvider).value ?? const [];
    for (final r in added) {
      if (r.connectionId != c.id || r.capability != cap.name) continue;
      final m = c.describe(cap, r.modelId);
      if (m == null) continue;
      add(
        m.copyWith(
          displayName: r.displayName,
          shutdownAt: r.shutdownAt?.toUtc().toIso8601String(),
        ),
        l.provSourceAdded,
        () => database.deleteProviderModel(r.id),
      );
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = connectionOf(widget.provider);
    if (c == null) return const SizedBox.shrink();
    final database = ref.read(databaseProvider);
    final defaults = ref.watch(capabilityDefaultsProvider).value ?? const [];
    final current = defaults
        .where((r) => r.capability == cap.name && r.purpose.isEmpty)
        .firstOrNull;
    bool isDefault(ModelDescriptor m) =>
        current?.connectionId == c.id && current?.modelId == m.id;
    final all = _entries(c, l);
    final query = _query.text.trim().toLowerCase();
    final shown = [
      for (final e in all)
        if (query.isEmpty ||
            e.model.id.toLowerCase().contains(query) ||
            e.model.label.toLowerCase().contains(query))
          e,
    ];
    final live = cap == AiCapability.llm && _live
        ? ref.watch(llmInventoryProvider(widget.provider.id))
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        if (!widget.provider.enabled)
          Text(
            l.provConnectionOff,
            style: const TextStyle(fontSize: 12, color: Colors.amber),
          ),
        CapabilitySwitch(connectionId: c.id, cap: cap),
        SectionHeader(
          '${capabilityLabel(l, cap)} · ${all.length}',
          actions: [
            if (cap == AiCapability.llm)
              TextButton.icon(
                onPressed: live?.isLoading ?? false
                    ? null
                    : () => _live
                          ? ref.invalidate(
                              llmInventoryProvider(widget.provider.id),
                            )
                          : setState(() => _live = true),
                icon: const Icon(Icons.cloud_download_rounded, size: 16),
                label: Text(l.provDiscoverLlm),
              ),
            TextButton.icon(
              onPressed: () => addCapabilityModel(context, ref, c, cap),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(l.capAddModel),
            ),
          ],
        ),
        if (live != null) _LiveStatus(live),
        if (all.length >= _searchFrom)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: _query,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                hintText: l.llmPickerSearch,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        if (shown.isEmpty)
          Text(
            l.modelNoModels,
            style: const TextStyle(fontSize: 12, color: Colors.white38),
          ),
        for (final e in shown)
          ProviderModelTile(
            key: ValueKey(e.model.id),
            label: e.model.label,
            id: e.model.id,
            source: e.source,
            features: cap == AiCapability.llm
                ? const []
                : [for (final f in e.model.features) featureLabel(l, f)],
            details: cap == AiCapability.llm
                ? LlmTraitsChips(e.model.llm ?? LlmTraits.unknown)
                : null,
            shutdownAt: e.model.shutdownAt,
            isDefault: isDefault(e.model),
            onSetDefault: () =>
                database.setCapabilityDefault(cap.name, (c.id, e.model.id)),
            onDelete: e.onDelete,
          ),
      ],
    );
  }
}

class _LiveStatus extends StatelessWidget {
  const _LiveStatus(this.live);
  final AsyncValue<LlmInventory?> live;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final inventory = live.value;
    final text = live.isLoading
        ? l.llmPickerLoading
        : live.hasError
        ? l.llmPickerDenied('${live.error}')
        : switch (inventory?.state) {
            HealthState.ok => l.llmPickerFound(inventory?.listed?.length ?? 0),
            HealthState.failed => l.llmPickerDenied(inventory?.message ?? ''),
            _ => l.llmPickerOffline,
          };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (live.isLoading) const LinearProgressIndicator(),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
