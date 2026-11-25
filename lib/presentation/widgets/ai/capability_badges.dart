import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/settings/ai_capability_settings.dart';
import 'package:neiroha/providers/ai_capability_providers.dart';

/// Capabilities a provider row's plugin offers; empty for unknown types.
Set<AiCapability> rowCapabilities(db.TtsProvider row) {
  if (AdapterType.values.asNameMap()[row.adapterType] == null) return {};
  try {
    return connectionForProvider(row).capabilities;
  } catch (_) {
    return {};
  }
}

/// The provider list's capability tab; null shows every connection.
final providerCapabilityFilterProvider = StateProvider<AiCapability?>(
  (_) => null,
);

/// Tabs over the provider list: all, then each capability some row offers.
class CapabilityFilterBar extends ConsumerWidget {
  const CapabilityFilterBar({super.key, required this.providers});
  final List<db.TtsProvider> providers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final selected = ref.watch(providerCapabilityFilterProvider);
    final offered = {for (final p in providers) ...rowCapabilities(p)};
    void pick(AiCapability? cap) =>
        ref.read(providerCapabilityFilterProvider.notifier).state = cap;
    Widget chip(AiCapability? cap) => Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        visualDensity: VisualDensity.compact,
        avatar: cap == null ? null : Icon(capabilityIcon(cap), size: 14),
        label: Text(
          cap == null ? l.capAll : capabilityLabel(l, cap),
          style: const TextStyle(fontSize: 12),
        ),
        selected: selected == cap,
        onSelected: (_) => pick(cap),
      ),
    );
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        children: [
          chip(null),
          for (final cap in AiCapability.values)
            if (offered.contains(cap)) chip(cap),
        ],
      ),
    );
  }
}

/// Small icons for what a connection can do; switched-off ones are dimmed.
class CapabilityBadges extends ConsumerWidget {
  const CapabilityBadges({super.key, required this.provider});
  final db.TtsProvider provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final lanes = ref.watch(connectionCapabilitiesProvider).value ?? const [];
    final off = {
      for (final r in lanes)
        if (r.connectionId == provider.id && !r.enabled) r.capability,
    };
    final caps = rowCapabilities(provider);
    if (caps.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Wrap(
        spacing: 4,
        children: [
          for (final cap in AiCapability.values)
            if (caps.contains(cap))
              Tooltip(
                message: off.contains(cap.name)
                    ? '${capabilityLabel(l, cap)} · ${l.capOff}'
                    : capabilityLabel(l, cap),
                child: Icon(
                  capabilityIcon(cap),
                  size: 12,
                  color: off.contains(cap.name)
                      ? context.fg.withValues(alpha: 0.24)
                      : AppTheme.accentColor.withValues(alpha: 0.8),
                ),
              ),
        ],
      ),
    );
  }
}
