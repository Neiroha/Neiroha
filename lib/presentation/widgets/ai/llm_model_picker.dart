import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/ai/catalog/llm_discovery.dart';
import 'package:neiroha/data/ai/core/capability_health.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/providers/ai_capability_providers.dart';
import 'package:neiroha/providers/app_providers.dart';

import 'llm_traits_chips.dart';

/// Picks a language model of one provider. Shows the built-in catalog at
/// once, then what the account's `GET models` adds, each with its traits.
Future<ModelDescriptor?> showLlmModelPicker(
  BuildContext context, {
  required String providerId,
  String? current,
  bool requireTools = false,
}) => showDialog<ModelDescriptor>(
  context: context,
  builder: (_) => _LlmModelPicker(providerId, current, requireTools),
);

class _LlmModelPicker extends ConsumerStatefulWidget {
  const _LlmModelPicker(this.providerId, this.current, this.requireTools);
  final String providerId;
  final String? current;
  final bool requireTools;

  @override
  ConsumerState<_LlmModelPicker> createState() => _LlmModelPickerState();
}

class _LlmModelPickerState extends ConsumerState<_LlmModelPicker> {
  final _query = TextEditingController();
  late bool _toolsOnly = widget.requireTools;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  LlmInventory? _offline() {
    final row = (ref.watch(ttsProvidersStreamProvider).value ?? const [])
        .where((r) => r.id == widget.providerId)
        .firstOrNull;
    final catalog = ref.watch(llmTraitsCatalogProvider).value;
    if (row == null || catalog == null || !providerOffersLlm(row)) return null;
    return LlmDiscovery(catalog).offline(connectionForProvider(row));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final live = ref.watch(llmInventoryProvider(widget.providerId));
    final inventory = live.value ?? _offline();
    final query = _query.text.trim().toLowerCase();
    final models = [
      for (final m in inventory?.models ?? const <ModelDescriptor>[])
        if ((!_toolsOnly || m.llm?.tools != false) &&
            (query.isEmpty ||
                m.id.toLowerCase().contains(query) ||
                m.label.toLowerCase().contains(query)))
          m,
    ];
    final typed = _query.text.trim();
    final exact = inventory?.find(typed);
    final listed = live.value?.listed?.length;
    String source(ModelDescriptor m) => m.source == DescriptorSource.provider
        ? l.llmSourceAccount
        : inventory!.unlisted(m)
        ? l.llmSourceUnlisted
        : l.llmSourceCatalog;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              l.llmPickerTitle(inventory?.connection.config.name ?? ''),
            ),
          ),
          IconButton(
            tooltip: l.modelRefresh,
            onPressed: live.isLoading
                ? null
                : () => ref.invalidate(llmInventoryProvider(widget.providerId)),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      content: SizedBox(
        width: 640,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l.llmPickerSearch,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilterChip(
                  label: Text(l.llmPickerToolsOnly),
                  selected: _toolsOnly,
                  onSelected: (v) => setState(() => _toolsOnly = v),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    live.isLoading
                        ? l.llmPickerLoading
                        : switch (live.value?.state) {
                            HealthState.ok => l.llmPickerFound(listed ?? 0),
                            HealthState.failed => l.llmPickerDenied(
                              live.value?.message ?? '',
                            ),
                            _ => l.llmPickerOffline,
                          },
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (live.isLoading) const LinearProgressIndicator(),
            const SizedBox(height: 4),
            Expanded(
              child: models.isEmpty
                  ? Center(child: Text(l.modelNoModels))
                  : ListView.separated(
                      itemCount: models.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final m = models[i];
                        final traits = m.llm ?? LlmTraits.unknown;
                        final blocked =
                            widget.requireTools && traits.tools == false;
                        return ListTile(
                          selected: m.id == widget.current,
                          selectedTileColor: AppTheme.accentColor.withAlpha(30),
                          enabled: !blocked,
                          onTap: () => Navigator.pop(context, m),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  m.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (m.isDefault) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: AppTheme.accentColor,
                                ),
                              ],
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${m.label == m.id ? '' : '${m.id} · '}'
                                '${source(m)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              const SizedBox(height: 4),
                              LlmTraitsChips(traits),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.uiCancel),
        ),
        if (typed.isNotEmpty && exact == null && inventory != null)
          FilledButton(
            onPressed: () {
              final manual = inventory.connection.describe(
                AiCapability.llm,
                typed,
              );
              if (manual != null) Navigator.pop(context, manual);
            },
            child: Text(l.llmPickerUse(typed)),
          ),
      ],
    );
  }
}
