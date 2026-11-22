import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/quick_tts_preferences.dart';

class QuickTtsPlaybackSetting extends ConsumerWidget {
  const QuickTtsPlaybackSetting({super.key, required this.voiceId});

  final String voiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final preference = ref.watch(quickTtsStreamingProvider(voiceId));
    final stream = preference.value ?? true;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: PopupMenuButton<bool>(
        tooltip: l10n.quickTtsPlaybackMode,
        enabled: preference.hasValue,
        initialValue: stream,
        onSelected: (enabled) async {
          try {
            await ref
                .read(databaseProvider)
                .setQuickTtsStreaming(voiceId, enabled);
          } catch (error) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.uiFailedToSave(error))));
          }
        },
        itemBuilder: (_) => [
          CheckedPopupMenuItem(
            value: true,
            checked: stream,
            child: Text(l10n.quickTtsStreamPlayback),
          ),
          CheckedPopupMenuItem(
            value: false,
            checked: !stream,
            child: Text(l10n.quickTtsFullPlayback),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.graphic_eq, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stream
                      ? l10n.quickTtsStreamPlayback
                      : l10n.quickTtsFullPlayback,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const Icon(Icons.expand_more, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
