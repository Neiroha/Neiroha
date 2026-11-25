import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/subtitles/subtitle_pipeline.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/widgets/ai/capability_model_picker.dart';
import 'package:neiroha/presentation/widgets/layout/page_header.dart';
import 'package:neiroha/presentation/widgets/settings/ai_capability_settings.dart';
import 'package:neiroha/presentation/widgets/settings/settings_shared.dart';
import 'package:neiroha/providers/ai_capability_providers.dart';
import 'package:neiroha/providers/app_providers.dart';

import 'capability_lanes.dart';
import 'package:neiroha/presentation/theme/app_colors.dart';

/// 「AI 服务 → 默认模型」: what each capability runs on, which connections
/// serve it, and the models features picked for themselves.
class CapabilityDefaultsView extends StatelessWidget {
  const CapabilityDefaultsView({super.key, this.onBack});
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          icon: Icons.hub_rounded,
          title: l.provHubDefaults,
          subtitle: l.provHubDefaultsHint,
          onBack: onBack,
        ),
        const Divider(height: 1),
        const Expanded(
          child: HubPageBody(
            children: [_PurposeOverrides(), CapabilityDefaultsList()],
          ),
        ),
      ],
    );
  }
}

/// A scrolling column capped to a readable width, centered in wide panes.
class HubPageBody extends StatelessWidget {
  const HubPageBody({super.key, required this.children});
  final List<Widget> children;

  static const maxWidth = 960.0;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(vertical: 16),
    children: [
      for (final child in children)
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: child,
            ),
          ),
        ),
    ],
  );
}

/// One card per capability some connection offers.
class CapabilityDefaultsList extends ConsumerWidget {
  const CapabilityDefaultsList({super.key});

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

/// Models a feature chose for itself (`capability_defaults.purpose`),
/// shown so they are not a hidden override; hidden when there are none.
class _PurposeOverrides extends ConsumerWidget {
  const _PurposeOverrides();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final rows = [
      for (final r in ref.watch(capabilityDefaultsProvider).value ?? const [])
        if (r.purpose.isNotEmpty) r,
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    final router = ref.watch(aiCapabilityRouterProvider).value;
    String purposeLabel(String purpose) =>
        purpose == subtitlePurpose ? l.navSubtitles : purpose;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.provHubFeatureModels,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                l.provHubFeatureModelsHint,
                style: TextStyle(
                  fontSize: 12,
                  color: context.fg.withValues(alpha: 0.54),
                ),
              ),
              const SizedBox(height: 6),
              for (final r in rows)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${purposeLabel(r.purpose)} · '
                        '${_capLabel(l, r.capability)}',
                      ),
                    ),
                    Flexible(
                      child: Text(
                        '${_connectionLabel(router, r.connectionId)} · '
                        '${r.modelId}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.fg.withValues(alpha: 0.70),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l.provHubResetFeatureModel,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () => ref
                          .read(databaseProvider)
                          .setCapabilityDefault(
                            r.capability,
                            null,
                            purpose: r.purpose,
                          ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _capLabel(AppLocalizations l, String name) =>
      switch (AiCapability.values.asNameMap()[name]) {
        final cap? => capabilityLabel(l, cap),
        null => name,
      };

  static String _connectionLabel(CapabilityRouter? router, String id) {
    for (final c in router?.connections ?? const <ProviderConnection>[]) {
      if (c.id == id) return connectionName(c);
    }
    return id;
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
    final auto = router.automatic(cap);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsRow(
              icon: capabilityIcon(cap),
              title: capabilityLabel(l, cap),
              subtitle: l.capDefaultModel,
              trailing: SizedBox(
                width: 340,
                child: CapabilityModelPicker(
                  cap: cap,
                  router: router,
                  value: router.defaults[cap],
                  automaticLabel: auto == null
                      ? l.capAutomatic
                      : l.capAutomaticInOrder(routedLabel(auto)),
                  onChanged: (v) => database.setCapabilityDefault(cap.name, v),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(
                l.capAutoOrderHint,
                style: TextStyle(
                  fontSize: 12,
                  color: context.fg.withValues(alpha: 0.38),
                ),
              ),
            ),
            if (router.ordered(cap).isEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  l.capNoConnections,
                  style: TextStyle(color: context.fg.withValues(alpha: 0.54)),
                ),
              )
            else
              CapabilityLaneList(
                cap: cap,
                router: router,
                lanes: lanes,
                added: added,
              ),
          ],
        ),
      ),
    );
  }
}
