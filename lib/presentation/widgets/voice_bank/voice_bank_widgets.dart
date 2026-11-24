import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/voice_character/components.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

part 'import_from_bank_dialog.dart';

class VoiceBankCharacterTile extends StatelessWidget {
  final db.VoiceAsset asset;
  final bool isSelected;
  final bool? healthOk;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const VoiceBankCharacterTile({
    super.key,
    required this.asset,
    required this.isSelected,
    required this.healthOk,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected
            ? AppTheme.accentColor.withValues(alpha: 0.12)
            : AppTheme.surfaceDim,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                VoiceCharacterAvatar(
                  radius: 16,
                  name: asset.name,
                  avatarPath: asset.avatarPath,
                  selected: isSelected,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _modeLabel(asset.taskMode),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: healthOk == false
                      ? l10n.healthCheckFailedTooltip
                      : asset.enabled
                      ? l10n.uiEnabled
                      : l10n.uiDisabled,
                  child: Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: healthOk == false
                          ? Colors.redAccent
                          : asset.enabled
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context).uiRemoveFromBank,
                  icon: Icon(
                    Icons.remove_circle_outline_rounded,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  onPressed: onRemove,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _modeLabel(String mode) => switch (mode) {
  'cloneWithPrompt' => 'Voice Clone',
  'presetVoice' => 'Preset Voice',
  'voiceDesign' => 'Voice Design',
  _ => mode,
};
