import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:neiroha/data/storage/path_service.dart';
import 'package:uuid/uuid.dart';

import 'package:neiroha/data/adapters/cosyvoice_adapter.dart';
import 'package:neiroha/data/adapters/voxcpm2_native_adapter.dart';
import 'package:neiroha/data/adapters/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/domain/enums/task_mode.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';

part '../widgets/voice_character/character_inspector.dart';
part '../widgets/voice_character/create_character_dialog.dart';
part '../widgets/voice_character/components.dart';

/// Currently-selected character id. Shared between the merged Voice Bank
/// screen (bank-filtered character list) and [CharacterInspector] so the
/// inspector can clear the selection after delete/duplicate.
final selectedCharacterIdProvider = StateProvider<String?>((ref) => null);

/// Opens the "Create Character" dialog. Caller can hook [onCreated] to
/// receive the new asset id — used by Voice Bank to auto-add the new
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
      const SnackBar(
        content: Text('Enable at least one Provider first (Providers tab)'),
      ),
    );
    return;
  }
  final existingAssets = ref.read(voiceAssetsStreamProvider).valueOrNull ?? [];
  final audioTracks = ref.read(audioTracksStreamProvider).valueOrNull ?? [];
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => CreateCharacterDialog(
      providers: enabledProviders,
      existingAssets: existingAssets,
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
