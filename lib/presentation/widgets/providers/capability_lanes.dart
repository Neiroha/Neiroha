import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/providers/on_device/on_device_plugin.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/settings/ai_capability_dialogs.dart';
import 'package:neiroha/presentation/widgets/settings/ai_capability_settings.dart';
import 'package:neiroha/providers/app_providers.dart';

import 'provider_hub.dart';

/// [cap]'s connections in its automatic order. Drag a row to change which
/// connection is tried first; open a row to order its models.
class CapabilityLaneList extends ConsumerWidget {
  const CapabilityLaneList({
    super.key,
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
    final ordered = router.ordered(cap);
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: ordered.length,
      onReorderItem: (from, to) {
        final ids = [for (final c in ordered) c.id];
        ids.insert(to, ids.removeAt(from));
        ref.read(databaseProvider).reorderCapabilityConnections(cap.name, ids);
      },
      itemBuilder: (context, i) {
        final c = ordered[i];
        return _Lane(
          key: ValueKey(c.id),
          index: i,
          cap: cap,
          connection: c,
          router: router,
          lane: lanes
              .where((r) => r.connectionId == c.id && r.capability == cap.name)
              .firstOrNull,
          added: [
            for (final m in added)
              if (m.connectionId == c.id && m.capability == cap.name) m,
          ],
        );
      },
    );
  }
}

class _Lane extends ConsumerStatefulWidget {
  const _Lane({
    super.key,
    required this.index,
    required this.cap,
    required this.connection,
    required this.router,
    required this.lane,
    required this.added,
  });
  final int index;
  final AiCapability cap;
  final ProviderConnection connection;
  final CapabilityRouter router;
  final db.ConnectionCapability? lane;
  final List<db.ProviderModel> added;

  @override
  ConsumerState<_Lane> createState() => _LaneState();
}

class _LaneState extends ConsumerState<_Lane> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final database = ref.read(databaseProvider);
    final cap = widget.cap;
    final c = widget.connection;
    final on = widget.router.offers(c, cap);
    final models = widget.router.modelsOf(c, cap);
    final custom = widget.lane != null && laneHasLimits(widget.lane!);
    // The built-in on-device connection has no row to open.
    final openable = c.id != OnDevicePlugin.connectionId;
    final muted = context.fg.withValues(alpha: 0.4);
    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: widget.index,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        size: 18,
                        color: muted,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 22,
                  child: Text(
                    '${widget.index + 1}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: on ? AppTheme.accentColor : muted,
                    ),
                  ),
                ),
                Switch(
                  value: on,
                  onChanged: (v) => database.upsertConnectionCapability(
                    db.ConnectionCapabilitiesCompanion(
                      connectionId: Value(c.id),
                      capability: Value(cap.name),
                      enabled: Value(v),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: openable
                        ? () => openProvider(ref, c.id, cap: cap)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            connectionName(c),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: on ? null : muted),
                          ),
                          if (on && models.isNotEmpty)
                            Text(
                              '${l.capPreferredModel(models.first.label)}'
                              ' · ${l.provModelCount(models.length)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: muted),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: custom ? l.capLimits : l.capInherited,
                  icon: Icon(
                    Icons.speed_rounded,
                    size: 18,
                    color: custom ? AppTheme.accentColor : null,
                  ),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => CapabilityLimitsDialog(
                      title: l.capLimitsTitle(
                        capabilityLabel(l, cap),
                        connectionName(c),
                      ),
                      connectionId: c.id,
                      capability: cap,
                      lane: widget.lane,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l.capAddModel,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  onPressed: () => addCapabilityModel(context, ref, c, cap),
                ),
                IconButton(
                  tooltip: l.capModelOrder,
                  isSelected: _open,
                  icon: const Icon(Icons.expand_more_rounded, size: 20),
                  selectedIcon: const Icon(Icons.expand_less_rounded, size: 20),
                  onPressed: models.length < 2 && widget.added.isEmpty
                      ? null
                      : () => setState(() => _open = !_open),
                ),
              ],
            ),
          ),
          if (_open)
            _ModelOrder(
              connection: c,
              cap: cap,
              models: models,
              added: widget.added,
            ),
        ],
      ),
    );
  }
}

/// One connection's models for a capability, first preferred; drag to
/// reorder, remove the ones added by hand.
class _ModelOrder extends ConsumerWidget {
  const _ModelOrder({
    required this.connection,
    required this.cap,
    required this.models,
    required this.added,
  });
  final ProviderConnection connection;
  final AiCapability cap;
  final List<ModelDescriptor> models;
  final List<db.ProviderModel> added;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final database = ref.read(databaseProvider);
    return Container(
      margin: const EdgeInsets.fromLTRB(58, 0, 8, 8),
      decoration: BoxDecoration(
        color: context.fg.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: models.length,
        onReorderItem: (from, to) {
          final ids = [for (final m in models) m.id];
          ids.insert(to, ids.removeAt(from));
          database.setCapabilityModelOrder(connection.id, cap.name, ids);
        },
        itemBuilder: (context, i) {
          final m = models[i];
          final row = added.where((a) => a.modelId == m.id).firstOrNull;
          return Material(
            key: ValueKey(m.id),
            type: MaterialType.transparency,
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: i,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.drag_handle_rounded,
                        size: 16,
                        color: context.fg.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: m.label,
                      children: [
                        if (m.label != m.id)
                          TextSpan(
                            text: '  ${m.id}',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.fg.withValues(alpha: 0.38),
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                if (i == 0) _Tag(l.capPreferred),
                if (row != null) ...[
                  _Tag(l.capModelAdded, muted: true),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).deleteButtonTooltip,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: () => database.deleteProviderModel(row.id),
                  ),
                ] else
                  const SizedBox(width: 8),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.muted = false});
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 6),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: (muted ? context.fg : AppTheme.accentColor).withValues(
        alpha: muted ? 0.08 : 0.18,
      ),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10.5,
        color: muted
            ? context.fg.withValues(alpha: 0.60)
            : AppTheme.accentColor,
      ),
    ),
  );
}
