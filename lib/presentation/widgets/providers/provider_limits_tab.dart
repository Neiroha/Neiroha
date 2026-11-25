import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/ai/capability_badges.dart';
import 'package:neiroha/presentation/widgets/settings/ai_capability_dialogs.dart';
import 'package:neiroha/presentation/widgets/settings/ai_capability_settings.dart';
import 'package:neiroha/providers/ai_capability_providers.dart';

import 'provider_draft.dart';
import 'provider_models.dart';

/// Queue limits of the whole connection, then each capability's own lane
/// (empty fields inherit the connection's).
class ProviderLimitsTab extends ConsumerWidget {
  const ProviderLimitsTab({
    super.key,
    required this.provider,
    required this.draft,
    required this.onSave,
  });
  final db.TtsProvider provider;
  final ProviderDraft draft;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final lanes = ref.watch(connectionCapabilitiesProvider).value ?? const [];
    final caps = rowCapabilities(provider);
    final name = provider.name;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        SectionHeader(l.provLimitsConnection),
        Text(
          l.uiConcurrency1IsSafestForLocalGPUTTSLeaveRateFieldsBlank,
          style: TextStyle(
            fontSize: 12,
            color: context.fg.withValues(alpha: 0.38),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _LimitField(draft.concurrency, l.uiConcurrency, '1-64', 110),
            _LimitField(draft.rpm, 'RPM', l.uiRequestsMin),
            _LimitField(draft.rpd, 'RPD', l.uiRequestsDay),
            _LimitField(draft.tpm, 'TPM', l.uiApproxTokensMin),
            _LimitField(draft.tpd, 'TPD', l.uiApproxTokensDay),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.save_rounded, size: 18),
            label: Text(l.uiSave),
          ),
        ),
        if (caps.isNotEmpty) ...[
          SectionHeader(l.provLimitsPerCapability),
          Text(
            l.capLimitsHint,
            style: TextStyle(
              fontSize: 12,
              color: context.fg.withValues(alpha: 0.38),
            ),
          ),
          const SizedBox(height: 6),
          for (final cap in AiCapability.values)
            if (caps.contains(cap))
              _LaneRow(
                cap: cap,
                connectionId: provider.id,
                connectionName: name,
                lane: lanes
                    .where((r) => r.connectionId == provider.id)
                    .where((r) => r.capability == cap.name)
                    .firstOrNull,
              ),
        ],
      ],
    );
  }
}

class _LaneRow extends StatelessWidget {
  const _LaneRow({
    required this.cap,
    required this.connectionId,
    required this.connectionName,
    required this.lane,
  });
  final AiCapability cap;
  final String connectionId;
  final String connectionName;
  final db.ConnectionCapability? lane;

  String _summary(AppLocalizations l, db.ConnectionCapability lane) => [
    if (lane.maxConcurrency case final v?) '${l.capConcurrency} $v',
    if (lane.requestsPerMinute case final v?) 'RPM $v',
    if (lane.requestsPerDay case final v?) 'RPD $v',
    if (lane.tokensPerMinute case final v?) 'TPM $v',
    if (lane.tokensPerDay case final v?) 'TPD $v',
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final custom = lane != null && laneHasLimits(lane!);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(capabilityIcon(cap), size: 18),
      title: Text(capabilityLabel(l, cap)),
      subtitle: Text(custom ? _summary(l, lane!) : l.capInherited),
      trailing: IconButton(
        tooltip: l.capLimits,
        icon: Icon(
          Icons.speed_rounded,
          color: custom ? AppTheme.accentColor : null,
        ),
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => CapabilityLimitsDialog(
            title: l.capLimitsTitle(capabilityLabel(l, cap), connectionName),
            connectionId: connectionId,
            capability: cap,
            lane: lane,
          ),
        ),
      ),
    );
  }
}

class _LimitField extends StatelessWidget {
  const _LimitField(
    this.controller,
    this.label,
    this.helper, [
    this.width = 140,
  ]);
  final TextEditingController controller;
  final String label;
  final String helper;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, helperText: helper),
    ),
  );
}
