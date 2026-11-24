import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/ai/core/capability_health.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/widgets/ai/capability_badges.dart';
import 'package:neiroha/presentation/widgets/layout/form_pair.dart';
import 'package:neiroha/presentation/widgets/settings/ai_capability_settings.dart';
import 'package:neiroha/providers/ai_capability_providers.dart';
import 'package:neiroha/providers/app_providers.dart';

import 'provider_draft.dart';
import 'provider_models.dart';

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
    final health = ref.watch(providerHealthProvider)[widget.provider.id];
    final lanes = ref.watch(connectionCapabilitiesProvider).value ?? const [];
    final off = {
      for (final r in lanes)
        if (r.connectionId == widget.provider.id && !r.enabled) r.capability,
    };
    final caps = rowCapabilities(widget.provider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        if (!supported) ...[
          _Banner(l.uiAdapterUnavailableOnThisPlatform, Colors.redAccent),
          const SizedBox(height: 14),
        ] else if (!widget.provider.enabled) ...[
          _Banner(l.provConnectionOff, Colors.amber),
          const SizedBox(height: 14),
        ],
        FormPair(
          first: TextField(
            controller: _draft.name,
            decoration: InputDecoration(labelText: l.uiName),
          ),
          second: DropdownButtonFormField<AdapterType>(
            decoration: InputDecoration(labelText: l.uiAdapterType),
            initialValue: _draft.adapterType,
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
        SectionHeader(
          l.provCapabilities,
          actions: [
            OutlinedButton.icon(
              onPressed: !supported || _checking ? null : _check,
              icon: _checking
                  ? const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.favorite_rounded, size: 16),
              label: Text(l.provCheckAll),
            ),
          ],
        ),
        for (final cap in AiCapability.values)
          if (caps.contains(cap))
            _CapabilityHealthRow(
              cap: cap,
              off: off.contains(cap.name),
              health: health?[cap],
            ),
        const SizedBox(height: 20),
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
  }
}

class _CapabilityHealthRow extends StatelessWidget {
  const _CapabilityHealthRow({
    required this.cap,
    required this.off,
    required this.health,
  });
  final AiCapability cap;
  final bool off;
  final CapabilityHealth? health;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (text, color) = switch (health?.state) {
      null => (l.provHealthNotChecked, Colors.white38),
      HealthState.ok => (l.provHealthOk, Colors.greenAccent),
      HealthState.failed => (l.provHealthFailed, Colors.redAccent),
      HealthState.unavailable => (l.provHealthUnavailable, Colors.amber),
      HealthState.unknown => (l.provHealthUnknown, Colors.white54),
    };
    final message = health?.message;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            capabilityIcon(cap),
            size: 16,
            color: off ? Colors.white24 : null,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(
              off
                  ? '${capabilityLabel(l, cap)} · ${l.capOff}'
                  : capabilityLabel(l, cap),
              style: TextStyle(color: off ? Colors.white38 : null),
            ),
          ),
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Tooltip(
              message: message ?? '',
              child: Text(
                message == null ? text : '$text · $message',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
