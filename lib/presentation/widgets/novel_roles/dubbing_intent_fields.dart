import 'package:flutter/material.dart';
import 'package:neiroha/domain/novel/dubbing_intent.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

class DubbingIntentFields extends StatelessWidget {
  const DubbingIntentFields({
    super.key,
    required this.mode,
    required this.onChanged,
    required this.notes,
    required this.enabled,
    this.notesChanged,
  });
  final DubbingMode mode;
  final ValueChanged<DubbingMode> onChanged;
  final TextEditingController notes;
  final VoidCallback? notesChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final labels = {
      DubbingMode.automatic: l.dubbingModeAutomatic,
      DubbingMode.storyteller: l.dubbingModeStoryteller,
      DubbingMode.dramatized: l.dubbingModeDramatized,
      DubbingMode.script: l.dubbingModeScript,
    };
    final description = switch (mode) {
      DubbingMode.automatic => l.dubbingModeAutomaticHelp,
      DubbingMode.storyteller => l.dubbingModeStorytellerHelp,
      DubbingMode.dramatized => l.dubbingModeDramatizedHelp,
      DubbingMode.script => l.dubbingModeScriptHelp,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.dubbingMode, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final item in labels.entries)
              ChoiceChip(
                label: Text(item.value),
                selected: mode == item.key,
                onSelected: enabled
                    ? (selected) {
                        if (selected) onChanged(item.key);
                      }
                    : null,
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 12),
          child: Text(
            description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        TextField(
          controller: notes,
          enabled: enabled,
          onChanged: (_) => notesChanged?.call(),
          minLines: 1,
          maxLines: 4,
          maxLength: 1800,
          decoration: InputDecoration(
            labelText: l.phaseRoleIntent,
            hintText: l.phaseRoleIntentHint,
          ),
        ),
      ],
    );
  }
}
