import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/presentation/widgets/voice_character/create_character_dialog.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

export 'package:neiroha/presentation/widgets/voice_character/character_inspector.dart';
export 'package:neiroha/presentation/widgets/voice_character/create_character_dialog.dart';
export 'package:neiroha/presentation/widgets/voice_character/selection.dart';

/// Opens the "Create Character" dialog. Caller can hook [onCreated] to
/// receive the new asset id - used by Voice Bank to auto-add the new
/// character as a member of the currently-selected bank.
void openCreateCharacterDialog(
  BuildContext context,
  WidgetRef ref, {
  void Function(String assetId)? onCreated,
}) {
  final allProviders =
      ref.read(ttsProvidersStreamProvider).valueOrNull ?? const [];
  final enabledProviders = allProviders.where((p) => p.enabled).toList();
  if (enabledProviders.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(
            context,
          ).uiEnableAtLeastOneProviderFirstProvidersTab,
        ),
      ),
    );
    return;
  }
  final audioTracks = ref.read(audioTracksStreamProvider).valueOrNull ?? [];
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => CreateCharacterDialog(
      providers: enabledProviders,
      audioTracks: audioTracks,
      database: ref.read(databaseProvider),
      onSave: (companion) async {
        await ref.read(databaseProvider).insertVoiceAsset(companion);
        onCreated?.call(companion.id.value);
      },
      onSaveAudioTrack: (track) async {
        await ref.read(databaseProvider).insertAudioTrack(track);
      },
    ),
  );
}
