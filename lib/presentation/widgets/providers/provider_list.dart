import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/ai/core/capability_health.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/domain/platform/platform_capabilities.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/ai/capability_badges.dart';
import 'package:neiroha/presentation/widgets/providers/add_provider_dialog.dart';
import 'package:neiroha/presentation/widgets/providers/provider_draft.dart';
import 'package:neiroha/providers/app_providers.dart';

import 'provider_hub.dart';

/// Asks for a new connection and opens it.
void showAddProviderDialog(BuildContext context, WidgetRef ref) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AddProviderDialog(
      onAdd: (companion) async {
        await ref.read(databaseProvider).insertProvider(companion);
        openProvider(ref, companion.id.value);
      },
    ),
  );
}

/// The ordered provider rows under a capability filter: drag to reorder,
/// tap to open, switch to activate.
class ProviderList extends ConsumerWidget {
  const ProviderList({
    super.key,
    required this.providers,
    required this.selectedId,
    this.showChevron = false,
    this.padding = EdgeInsets.zero,
  });
  final List<db.TtsProvider> providers;
  final String? selectedId;

  /// Rows lead into their settings (the providers page).
  final bool showChevron;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(providerCapabilityFilterProvider);
    final shown = filter == null
        ? providers
        : [
            for (final p in providers)
              if (rowCapabilities(p).contains(filter)) p,
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: padding.left, right: padding.right),
          child: CapabilityFilterBar(providers: providers),
        ),
        const Divider(height: 1),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Text(
                    AppLocalizations.of(context).uiNoProvidersYet,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  padding: padding.copyWith(top: 6, bottom: 6),
                  buildDefaultDragHandles: false,
                  itemCount: shown.length,
                  onReorderItem: (oldIndex, newIndex) async {
                    // Filtered rows move among themselves; others keep
                    // their slots.
                    final moved = [...shown];
                    moved.insert(newIndex, moved.removeAt(oldIndex));
                    final slots = moved.iterator;
                    final list = [
                      for (final p in providers)
                        shown.contains(p) ? (slots..moveNext()).current : p,
                    ];
                    await ref
                        .read(databaseProvider)
                        .reorderProviders(list.map((p) => p.id).toList());
                  },
                  itemBuilder: (ctx, i) {
                    final p = shown[i];
                    return _ProviderRow(
                      key: ValueKey(p.id),
                      provider: p,
                      index: i,
                      isSelected: p.id == selectedId,
                      showChevron: showChevron,
                      onTap: () => openProvider(ref, p.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ProviderRow extends ConsumerWidget {
  final db.TtsProvider provider;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showChevron;

  const _ProviderRow({
    super.key,
    required this.provider,
    required this.index,
    required this.isSelected,
    required this.onTap,
    required this.showChevron,
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
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
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
                if (showChevron)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
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
