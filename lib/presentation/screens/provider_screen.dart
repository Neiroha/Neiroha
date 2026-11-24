import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/ai/core/capability_health.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/domain/platform/platform_capabilities.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/ai/capability_badges.dart';
import 'package:neiroha/presentation/widgets/layout/window_drag_area.dart';
import 'package:neiroha/presentation/widgets/providers/add_provider_dialog.dart';
import 'package:neiroha/presentation/widgets/providers/provider_draft.dart';
import 'package:neiroha/presentation/widgets/providers/provider_editor.dart';
import 'package:neiroha/presentation/widgets/resizable_split_pane.dart';
import 'package:neiroha/providers/app_providers.dart';

/// Two-pane provider configuration screen.
///
/// Left:  ordered list of providers (drag to reorder), each with its
///        capabilities, last health check and an activation toggle.
/// Right: the selected provider's editor, one tab per capability.
class ProviderScreen extends ConsumerWidget {
  const ProviderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providersAsync = ref.watch(ttsProvidersStreamProvider);
    final selectedId = ref.watch(selectedProviderIdProvider);

    return providersAsync.when(
      loading: () => Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text(AppLocalizations.of(context).uiError2(e))),
      data: (providers) {
        // Auto-select the first provider if nothing selected and list is not empty.
        final effectiveSelectedId =
            selectedId ?? (providers.isNotEmpty ? providers.first.id : null);
        final selected = providers
            .where((p) => p.id == effectiveSelectedId)
            .firstOrNull;

        return ResizableSplitPane(
          initialLeftFraction: 0.35,
          compactRightIcon: Icons.tune_rounded,
          compactRightLabel: AppLocalizations.of(context).uiDetails,
          left: _ProviderListPane(
            providers: providers,
            selectedId: effectiveSelectedId,
            onSelect: (id) =>
                ref.read(selectedProviderIdProvider.notifier).state = id,
          ),
          rightBuilder: (_) => selected == null
              ? _buildEmpty(context)
              : ProviderEditor(key: ValueKey(selected.id), provider: selected),
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.dns_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).uiSelectOrAddAProvider,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────── Left Pane: List ───────────────────────────────

class _ProviderListPane extends ConsumerWidget {
  final List<db.TtsProvider> providers;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const _ProviderListPane({
    required this.providers,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(providerCapabilityFilterProvider);
    final providers = filter == null
        ? this.providers
        : [
            for (final p in this.providers)
              if (rowCapabilities(p).contains(filter)) p,
          ];
    return Container(
      color: AppTheme.surfaceDim,
      child: Column(
        children: [
          WindowDragArea(
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
              child: Row(
                children: [
                  Text(
                    AppLocalizations.of(context).navProviders,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _showAddDialog(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    tooltip: AppLocalizations.of(context).uiAddProvider,
                  ),
                ],
              ),
            ),
          ),
          CapabilityFilterBar(providers: this.providers),
          const Divider(height: 1),
          Expanded(
            child: providers.isEmpty
                ? Center(
                    child: Text(
                      AppLocalizations.of(context).uiNoProvidersYet,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    buildDefaultDragHandles: false,
                    itemCount: providers.length,
                    onReorderItem: (oldIndex, newIndex) async {
                      // Filtered rows move among themselves; others keep
                      // their slots.
                      final shown = [...providers];
                      shown.insert(newIndex, shown.removeAt(oldIndex));
                      final slots = shown.iterator;
                      final list = [
                        for (final p in this.providers)
                          providers.contains(p)
                              ? (slots..moveNext()).current
                              : p,
                      ];
                      await ref
                          .read(databaseProvider)
                          .reorderProviders(list.map((p) => p.id).toList());
                    },
                    itemBuilder: (ctx, i) {
                      final p = providers[i];
                      return _ProviderRow(
                        key: ValueKey(p.id),
                        provider: p,
                        index: i,
                        isSelected: p.id == selectedId,
                        onTap: () => onSelect(p.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AddProviderDialog(
        onAdd: (companion) async {
          final db_ = ref.read(databaseProvider);
          await db_.insertProvider(companion);
          ref.read(selectedProviderIdProvider.notifier).state =
              companion.id.value;
        },
      ),
    );
  }
}

class _ProviderRow extends ConsumerWidget {
  final db.TtsProvider provider;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProviderRow({
    super.key,
    required this.provider,
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capabilities = ref.watch(platformCapabilitiesProvider);
    final adapterType = _adapterTypeFor(provider.adapterType);
    final supported =
        adapterType != null && capabilities.supportsTtsAdapter(adapterType);
    final l10n = AppLocalizations.of(context);
    final health = ref.watch(providerHealthProvider)[provider.id];
    final dot = healthColor(health);
    final failed = [
      for (final MapEntry(:key, :value) in (health ?? const {}).entries)
        if (value.state == HealthState.failed) key.name,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected
            ? AppTheme.accentColor.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                SizedBox(width: 6),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: provider.enabled && supported
                        ? AppTheme.accentColor.withValues(alpha: 0.2)
                        : AppTheme.surfaceBright,
                  ),
                  child: Icon(
                    !supported
                        ? Icons.block_rounded
                        : provider.enabled
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_off_rounded,
                    size: 16,
                    color: provider.enabled && supported
                        ? AppTheme.accentColor
                        : (!supported ? Colors.redAccent : Colors.grey),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              provider.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (dot != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Tooltip(
                                message: failed.isEmpty
                                    ? l10n.provHealthOk
                                    : l10n.provHealthSome(failed.join(', ')),
                                child: Icon(Icons.circle, size: 8, color: dot),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        _adapterLabel(provider.adapterType, capabilities),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      CapabilityBadges(provider: provider),
                      if (!supported)
                        Text(
                          l10n.uiUnavailableOnThisPlatform,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.redAccent,
                          ),
                        ),
                    ],
                  ),
                ),
                Switch(
                  value: provider.enabled && supported,
                  onChanged: supported
                      ? (v) async {
                          await ref
                              .read(databaseProvider)
                              .updateProvider(provider.copyWith(enabled: v));
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

AdapterType? _adapterTypeFor(String type) {
  for (final t in AdapterType.values) {
    if (t.name == type) return t;
  }
  return null;
}

String _adapterLabel(String type, PlatformCapabilities capabilities) {
  final adapterType = _adapterTypeFor(type);
  if (adapterType == null) return type;
  return capabilities.displayNameForAdapter(adapterType);
}
