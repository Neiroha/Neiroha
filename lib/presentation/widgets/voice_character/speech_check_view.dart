import 'package:flutter/material.dart';
import 'package:neiroha/data/services/synthesis/speech_check_log.dart';
import 'package:neiroha/domain/synthesis/speech_check.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_colors.dart';

/// The character's latest ASR read-back results, newest first.
class SpeechCheckView extends StatelessWidget {
  const SpeechCheckView({super.key, required this.voiceAssetId, this.show = 3});
  final String voiceAssetId;
  final int show;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return StreamBuilder<List<SpeechCheck>>(
      stream: SpeechCheckLog.instance.watch(voiceAssetId),
      builder: (context, snap) {
        final checks = (snap.data ?? const <SpeechCheck>[]).reversed
            .take(show)
            .toList();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (checks.isEmpty)
                Text(
                  l.chainCheckNone,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: context.fg.withValues(alpha: 0.38),
                  ),
                ),
              for (final c in checks) _CheckLine(c),
            ],
          ),
        );
      },
    );
  }
}

class _CheckLine extends StatelessWidget {
  const _CheckLine(this.check);
  final SpeechCheck check;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final score = (check.score * 100).round();
    final (icon, color, text) = switch (check) {
      SpeechCheck(:final error?) => (
        Icons.error_outline_rounded,
        context.colors.warning,
        l.chainCheckFailed('$error'),
      ),
      SpeechCheck(clean: true) => (
        Icons.check_circle_outline_rounded,
        context.colors.success,
        l.chainCheckClean('$score'),
      ),
      SpeechCheck(missing: []) => (
        Icons.warning_amber_rounded,
        context.colors.warning,
        '$score% · ${l.chainCheckExtra(check.extra.join(' / '))}',
      ),
      _ => (
        Icons.warning_amber_rounded,
        context.colors.warning,
        [
          l.chainCheckMissing('$score', check.missing.join(' / ')),
          if (check.extra.isNotEmpty)
            l.chainCheckExtra(check.extra.join(' / ')),
        ].join(' · '),
      ),
    };
    return Tooltip(
      message: '${check.expected}\n→ ${check.heard}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
