import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/services/capabilities/model_retirement.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/presentation/theme/app_colors.dart';

/// Small red "Retires yyyy-MM-dd" tag for model rows.
class RetirementChip extends StatelessWidget {
  const RetirementChip({super.key, required this.shutdownAt});
  final String shutdownAt;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.danger;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          AppLocalizations.of(context).retireBadge(shutdownAt),
          style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.9)),
        ),
      ),
    );
  }
}

/// The advice line under a model field: when it stops and what to use.
String retirementAdvice(
  AppLocalizations l10n,
  ModelDescriptor retiring,
  RetirementMove? move,
) => move == null
    ? l10n.retireHintNoReplacement(retiring.id, retiring.shutdownAt!)
    : l10n.retireHint(retiring.id, retiring.shutdownAt!, move.model);

/// App-wide strip shown while any enabled character speaks with a model
/// that has a shutdown date. Offers a one-click move to the replacements;
/// "Later" hides it until the next launch.
class RetirementBanner extends ConsumerStatefulWidget {
  const RetirementBanner({super.key, this.now});

  /// Fixed clock for tests.
  final DateTime? now;

  @override
  ConsumerState<RetirementBanner> createState() => _RetirementBannerState();
}

class _RetirementBannerState extends ConsumerState<RetirementBanner> {
  bool _hidden = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    final providers = ref.watch(ttsProvidersStreamProvider).value;
    final assets = ref.watch(voiceAssetsStreamProvider).value;
    if (providers == null || assets == null) return const SizedBox.shrink();
    final uses = findRetiringUses(providers, assets);
    if (uses.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final date = uses.first.model.shutdownAt!;
    final days = daysUntil(date, widget.now ?? DateTime.now());
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: context.colors.danger.withValues(alpha: 0.14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 18,
              color: context.colors.danger,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.retireBanner(uses.length, date, days < 0 ? 0 : days),
                style: TextStyle(fontSize: 13, color: scheme.onSurface),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _hidden = true),
              child: Text(l10n.retireLater),
            ),
            const SizedBox(width: 4),
            FilledButton.tonal(
              onPressed: _busy ? null : () => _migrate(uses),
              child: Text(l10n.retireMigrate),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _migrate(List<RetiringUse> uses) async {
    final platform = aiPlatformOf(ref.read(platformCapabilitiesProvider));
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => RetirementMigrationDialog(uses: uses, platform: platform),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final moved = await migrateRetiring(
        ref.read(databaseProvider),
        uses,
        platform: platform,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).retireMigrated(moved)),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Lists what each character moves to; characters without a replacement on
/// this platform are listed separately for a manual change.
class RetirementMigrationDialog extends StatelessWidget {
  const RetirementMigrationDialog({
    super.key,
    required this.uses,
    required this.platform,
  });
  final List<RetiringUse> uses;
  final AiPlatform platform;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final movable = [
      for (final u in uses)
        if (u.move(platform) case final move?) (use: u, move: move),
    ];
    final manual = [
      for (final u in uses)
        if (u.move(platform) == null) u,
    ];
    String target(RetirementMove m) =>
        m.voice == null ? m.model : '${m.model} · ${m.voice}';
    return AlertDialog(
      title: Text(l10n.retireMigrateTitle),
      content: SizedBox(
        width: 460,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final r in movable)
              ListTile(
                dense: true,
                title: Text(r.use.asset.name),
                subtitle: Text('${r.use.model.id} → ${target(r.move)}'),
              ),
            if (manual.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(l10n.retireMigrateManual),
              ),
              for (final u in manual)
                ListTile(
                  dense: true,
                  title: Text(u.asset.name),
                  subtitle: Text('${u.provider.name} · ${u.model.id}'),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.uiCancel),
        ),
        FilledButton(
          onPressed: movable.isEmpty
              ? null
              : () => Navigator.pop(context, true),
          child: Text(l10n.retireMigrate),
        ),
      ],
    );
  }
}
