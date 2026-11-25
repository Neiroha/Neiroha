import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/voice_character_copy.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';

import 'selection.dart';
import 'package:neiroha/presentation/theme/app_colors.dart';

/// Tabs of the character inspector.
enum InspectorTab { basic, voice, chain }

class InspectorTabs extends StatelessWidget {
  const InspectorTabs({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final InspectorTab value;
  final ValueChanged<InspectorTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SegmentedButton<InspectorTab>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: InspectorTab.basic,
          icon: const Icon(Icons.badge_rounded, size: 16),
          label: Text(l.inspectorTabBasic),
        ),
        ButtonSegment(
          value: InspectorTab.voice,
          icon: const Icon(Icons.record_voice_over_rounded, size: 16),
          label: Text(l.inspectorTabVoice),
        ),
        ButtonSegment(
          value: InspectorTab.chain,
          icon: const Icon(Icons.account_tree_rounded, size: 16),
          label: Text(l.chainTitle),
        ),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.single),
    );
  }
}

/// Duplicate / delete buttons under the inspector.
class CharacterActions extends ConsumerWidget {
  const CharacterActions({super.key, required this.asset, this.bankId});
  final db.VoiceAsset asset;
  final String? bankId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final newId = await duplicateVoiceCharacter(
                ref.read(databaseProvider),
                asset,
                bankId: bankId,
              );
              ref.read(selectedCharacterIdProvider.notifier).state = newId;
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: Text(l.uiDuplicate),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _delete(context, ref),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: Text(l.uiDelete),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.danger,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    await ref
        .read(playbackNotifierProvider.notifier)
        .stopIfSourceTag(voiceBankQuickTestPlaybackSource);
    try {
      await ref.read(databaseProvider).deleteVoiceAsset(asset.id);
      ref.read(selectedCharacterIdProvider.notifier).state = null;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).uiFailedToDeleteCharacter(e),
            ),
          ),
        );
      }
    }
  }
}
