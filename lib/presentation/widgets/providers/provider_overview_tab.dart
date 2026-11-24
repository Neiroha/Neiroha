import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/ai/core/capability_health.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/ai/capability_badges.dart';
import 'package:neiroha/presentation/widgets/layout/form_pair.dart';
import 'package:neiroha/presentation/widgets/settings/ai_capability_settings.dart';
import 'package:neiroha/providers/ai_capability_providers.dart';
import 'package:neiroha/providers/app_providers.dart';

import 'provider_draft.dart';

/// Account fields of one connection, what it can do and whether each
/// capability answers.
class ProviderOverviewTab extends ConsumerStatefulWidget {
  const ProviderOverviewTab({
    super.key,
    required this.provider,
    required this.draft,
    required this.defaultModel,
    required this.onAdapterChanged,
    required this.onSave,
  });
  final db.TtsProvider provider;
  final ProviderDraft draft;
  final String defaultModel;
  final ValueChanged<AdapterType> onAdapterChanged;
  final Future<void> Function() onSave;

  @override
  ConsumerState<ProviderOverviewTab> createState() =>
      _ProviderOverviewTabState();
}

class _ProviderOverviewTabState extends ConsumerState<ProviderOverviewTab> {
  bool _showKey = false;
  bool _checking = false;

  ProviderDraft get _draft => widget.draft;

  /// Checks every capability with the unsaved fields, so they can be tried
  /// before saving.
  Future<void> _check() async {
    setState(() => _checking = true);
    final id = widget.provider.id;
    final timeout = await readHealthCheckTimeout(ref);
    Map<AiCapability, CapabilityHealth> result;
    try {
      final connection = connectionForProvider(
        _draft.connection(widget.provider, widget.defaultModel),
      );
      result = await connection.check().timeout(
        timeout,
        onTimeout: () => {
          for (final c in connection.capabilities)
            c: const CapabilityHealth(HealthState.failed, message: 'timeout'),
        },
      );
    } catch (e) {
      result = {
        for (final c in rowCapabilities(widget.provider))
          c: CapabilityHealth(HealthState.failed, message: '$e'),
      };
    }
    final all = ref.read(providerHealthProvider.notifier);
    all.state = {...all.state, id: result};
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final platform = ref.watch(platformCapabilitiesProvider);
    final supported = platform.supportsTtsAdapter(_draft.adapterType);
    final id = widget.provider.id;
    final health = ref.watch(providerHealthProvider)[id];
    final lanes = ref.watch(connectionCapabilitiesProvider).value ?? const [];
    final added = ref.watch(providerModelsProvider).value ?? const [];
    // Capabilities whose app-wide default model is on this connection.
    final defaultHere = {
      for (final r in ref.watch(capabilityDefaultsProvider).value ?? const [])
        if (r.purpose.isEmpty && r.connectionId == id) r.capability,
    };
    final off = {
      for (final r in lanes)
        if (r.connectionId == id && !r.enabled) r.capability,
    };
    final caps = [
      for (final cap in AiCapability.values)
        if (rowCapabilities(widget.provider).contains(cap)) cap,
    ];
    final catalog = connectionForProvider(widget.provider);
    int modelCount(AiCapability cap) {
      final own = {for (final m in catalog.models(cap)) m.id};
      return own.length +
          added
              .where((m) => m.connectionId == id && m.capability == cap.name)
              .where((m) => !own.contains(m.modelId))
              .length;
    }

    final account = _Section(
      title: l.provConnection,
      children: [
        FormPair(
          first: TextField(
            controller: _draft.name,
            decoration: InputDecoration(labelText: l.uiName),
          ),
          second: DropdownButtonFormField<AdapterType>(
            decoration: InputDecoration(labelText: l.uiAdapterType),
            initialValue: _draft.adapterType,
            isExpanded: true,
            items: [
              for (final t in platform.editableAdapterTypes(_draft.adapterType))
                DropdownMenuItem(
                  value: t,
                  enabled: platform.supportsTtsAdapter(t),
                  child: Text(
                    platform.supportsTtsAdapter(t)
                        ? platform.displayNameForAdapter(t)
                        : '${platform.displayNameForAdapter(t)} '
                              '(${l.uiUnavailableOnThisPlatform})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null) widget.onAdapterChanged(v);
            },
          ),
        ),
        const SizedBox(height: 12),
        FormPair(
          first: TextField(
            controller: _draft.baseUrl,
            decoration: InputDecoration(
              labelText: l.uiBaseURL,
              hintText: baseUrlHint(_draft.adapterType),
              helperText: _draft.adapterType == AdapterType.azureTts
                  ? 'Accepts region name, tts.speech.microsoft.com, or '
                        'api.cognitive.microsoft.com URL'
                  : null,
            ),
          ),
          second: TextField(
            controller: _draft.apiKey,
            obscureText: !_showKey,
            decoration: InputDecoration(
              labelText: l.uiAPIKey,
              suffixIcon: IconButton(
                icon: Icon(
                  _showKey
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 18,
                ),
                onPressed: () => setState(() => _showKey = !_showKey),
              ),
            ),
          ),
        ),
        if (_draft.adapterType.showDefaultModelField) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _draft.model,
            decoration: InputDecoration(
              labelText: l.uiDefaultModelName,
              hintText: widget.defaultModel,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: widget.onSave,
            icon: const Icon(Icons.save_rounded, size: 18),
            label: Text(l.uiSave),
          ),
        ),
      ],
    );
    final capabilities = _Section(
      title: l.provCapabilities,
      action: OutlinedButton.icon(
        onPressed: !supported || _checking ? null : _check,
        icon: _checking
            ? const SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.favorite_rounded, size: 16),
        label: Text(l.provCheckAll),
      ),
      children: [
        for (final (i, cap) in caps.indexed)
          _CapabilityHealthRow(
            cap: cap,
            connectionId: id,
            off: off.contains(cap.name),
            health: health?[cap],
            models: modelCount(cap),
            isDefault: defaultHere.contains(cap.name),
            onOpen: () => DefaultTabController.of(context).animateTo(i + 1),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 920;
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!supported) ...[
                      _Banner(
                        l.uiAdapterUnavailableOnThisPlatform,
                        Colors.redAccent,
                      ),
                      const SizedBox(height: 14),
                    ] else if (!widget.provider.enabled) ...[
                      _Banner(l.provConnectionOff, Colors.amber),
                      const SizedBox(height: 14),
                    ],
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 11, child: account),
                          const SizedBox(width: 16),
                          Expanded(flex: 9, child: capabilities),
                        ],
                      )
                    else ...[
                      account,
                      const SizedBox(height: 16),
                      capabilities,
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A titled card of the overview.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.action});
  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}

/// One capability: on/off, whether it answered, how many models, and
/// whether it is the app-wide default; tapping opens its tab.
class _CapabilityHealthRow extends ConsumerWidget {
  const _CapabilityHealthRow({
    required this.cap,
    required this.connectionId,
    required this.off,
    required this.health,
    required this.models,
    required this.isDefault,
    required this.onOpen,
  });
  final AiCapability cap;
  final String connectionId;
  final bool off;
  final CapabilityHealth? health;
  final int models;
  final bool isDefault;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final (text, color) = switch (health?.state) {
      null => (l.provHealthNotChecked, Colors.white38),
      HealthState.ok => (l.provHealthOk, Colors.greenAccent),
      HealthState.failed => (l.provHealthFailed, Colors.redAccent),
      HealthState.unavailable => (l.provHealthUnavailable, Colors.amber),
      HealthState.unknown => (l.provHealthUnknown, Colors.white54),
    };
    final message = health?.message;
    final dim = off ? Colors.white38 : null;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 0, 6),
        child: Row(
          children: [
            Icon(capabilityIcon(cap), size: 18, color: dim),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          capabilityLabel(l, cap),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: dim,
                          ),
                        ),
                      ),
                      if (isDefault && !off) ...[
                        const SizedBox(width: 6),
                        _Pill(l.provIsDefault),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Tooltip(
                    message: message ?? '',
                    child: Row(
                      children: [
                        Icon(Icons.circle, size: 7, color: off ? dim : color),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            [
                              off ? l.capOff : text,
                              if (!off && message != null) message,
                              l.provModelCount(models),
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: off ? dim : color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: !off,
              onChanged: (v) => ref
                  .read(databaseProvider)
                  .upsertConnectionCapability(
                    db.ConnectionCapabilitiesCompanion(
                      connectionId: Value(connectionId),
                      capability: Value(cap.name),
                      enabled: Value(v),
                    ),
                  ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Colors.white38,
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: AppTheme.accentColor.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 10.5, color: AppTheme.accentColor),
    ),
  );
}

class _Banner extends StatelessWidget {
  const _Banner(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.30)),
    ),
    child: Row(
      children: [
        Icon(Icons.info_outline_rounded, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 12, color: color)),
        ),
      ],
    ),
  );
}
