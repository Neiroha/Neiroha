import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:neiroha/presentation/widgets/layout/page_header.dart';
import 'package:neiroha/presentation/actions/file_dialogs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;
import 'package:neiroha/data/storage/path_service.dart';
import 'package:uuid/uuid.dart';

import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/resizable_split_pane.dart';
import 'package:neiroha/presentation/widgets/voice_asset/record_dialog.dart';
import 'package:neiroha/presentation/widgets/voice_asset/reference_text_field.dart';
import 'package:neiroha/presentation/widgets/voice_asset/trim_dialog.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

part '../widgets/voice_asset/track_inspector.dart';

/// Voice Asset library — a collection of single audio tracks that the user
/// has uploaded, recorded, or imported from generated TTS output. These can
/// be referenced by voice cloning models that need a sample audio file.
final _selectedTrackIdProvider = StateProvider<String?>((ref) => null);

class VoiceAssetScreen extends ConsumerWidget {
  const VoiceAssetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(audioTracksStreamProvider);
    final selectedId = ref.watch(_selectedTrackIdProvider);

    return Column(
      children: [
        _buildHeader(context, ref),
        const Divider(height: 1),
        Expanded(
          child: tracksAsync.when(
            loading: () => Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text(AppLocalizations.of(context).uiError2(e))),
            data: (tracks) {
              if (tracks.isEmpty) return _buildEmpty(context, ref);
              final selected = tracks
                  .where((t) => t.id == selectedId)
                  .firstOrNull;
              return ResizableSplitPane(
                initialLeftFraction: 0.6,
                compactRightIcon: Icons.tune_rounded,
                compactRightLabel: AppLocalizations.of(context).uiDetails,
                left: _TrackList(
                  tracks: tracks,
                  selectedId: selectedId,
                  onSelect: (id) =>
                      ref.read(_selectedTrackIdProvider.notifier).state = id,
                ),
                rightBuilder: (_) => selected != null
                    ? _TrackInspector(track: selected)
                    : Center(
                        child: Text(
                          AppLocalizations.of(context).uiSelectATrack,
                          style: TextStyle(
                            color: context.fg.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 460;
        return PageHeader(
          icon: Icons.library_music_rounded,
          title: l10n.navVoiceAssets,
          subtitle: compact ? null : l10n.uiSingleAudioTracksForVoiceCloning,
          actions: compact
              ? [
                  IconButton.outlined(
                    tooltip: l10n.uiRecord,
                    onPressed: () => _recordTrack(context, ref),
                    icon: const Icon(Icons.mic_rounded, size: 18),
                  ),
                  IconButton.filled(
                    tooltip: l10n.uiUploadAudio,
                    onPressed: () => _uploadTrack(context, ref),
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                  ),
                ]
              : [
                  OutlinedButton.icon(
                    onPressed: () => _recordTrack(context, ref),
                    icon: const Icon(Icons.mic_rounded, size: 18),
                    label: Text(l10n.uiRecord),
                  ),
                  FilledButton.icon(
                    onPressed: () => _uploadTrack(context, ref),
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: Text(l10n.uiUploadAudio),
                  ),
                ],
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.library_music_rounded,
            size: 64,
            color: context.fg.withValues(alpha: 0.1),
          ),
          SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).uiNoAudioTracksYet,
            style: TextStyle(
              fontSize: 16,
              color: context.fg.withValues(alpha: 0.4),
            ),
          ),
          SizedBox(height: 8),
          Text(
            AppLocalizations.of(
              context,
            ).uiUploadAnAudioFileOrRecordANewSampleToGetStarted,
            style: TextStyle(
              fontSize: 13,
              color: context.fg.withValues(alpha: 0.25),
            ),
          ),
          SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => _uploadTrack(context, ref),
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: Text(AppLocalizations.of(context).uiUploadAudio),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadTrack(BuildContext context, WidgetRef ref) async {
    final result = await pickFiles(type: FileType.audio, allowMultiple: false);
    if (result == null || result.files.single.path == null) return;
    final src = File(result.files.single.path!);
    if (!await src.exists()) return;

    // Copy into the managed voice_character_ref/ folder so the library is
    // always discoverable under the user's configured voice-asset root.
    final assetDir = await PathService.instance.voiceCharacterRefDir();
    final id = const Uuid().v4();
    final ext = p.extension(src.path).isEmpty ? '.wav' : p.extension(src.path);
    final base = p.basenameWithoutExtension(src.path);
    final dstPath = PathService.dedupeFilename(
      assetDir,
      '${PathService.sanitizeSegment(base, fallback: 'track')}_${PathService.formatTimestamp()}',
      ext,
    );
    await src.copy(dstPath);

    // Detect duration
    double? duration;
    try {
      final probe = AudioPlayer();
      await probe.setSourceDeviceFile(dstPath);
      final d = await probe.getDuration();
      if (d != null) duration = d.inMilliseconds / 1000.0;
      await probe.dispose();
    } catch (_) {}

    final name = p.basenameWithoutExtension(src.path);
    await ref
        .read(databaseProvider)
        .insertAudioTrack(
          db.AudioTracksCompanion(
            id: Value(id),
            name: Value(name),
            audioPath: Value(dstPath),
            durationSec: Value(duration),
            sourceType: const Value('upload'),
            createdAt: Value(DateTime.now()),
          ),
        );
    ref.read(_selectedTrackIdProvider.notifier).state = id;
  }

  Future<void> _recordTrack(BuildContext context, WidgetRef ref) async {
    final recordedPath = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const RecordDialog(),
    );
    if (recordedPath == null) return;
    final src = File(recordedPath);
    if (!await src.exists()) return;

    // Recordings already land inside voice_character_ref/ via the dialog —
    // we just need to detect duration and insert the row.
    double? duration;
    try {
      final probe = AudioPlayer();
      await probe.setSourceDeviceFile(recordedPath);
      final d = await probe.getDuration();
      if (d != null) duration = d.inMilliseconds / 1000.0;
      await probe.dispose();
    } catch (_) {}

    final id = const Uuid().v4();
    final name = 'Recording ${PathService.formatTimestamp()}';
    await ref
        .read(databaseProvider)
        .insertAudioTrack(
          db.AudioTracksCompanion(
            id: Value(id),
            name: Value(name),
            audioPath: Value(recordedPath),
            durationSec: Value(duration),
            sourceType: const Value('record'),
            createdAt: Value(DateTime.now()),
          ),
        );
    ref.read(_selectedTrackIdProvider.notifier).state = id;
  }
}

// ─────────────────────────── Track List ────────────────────────────────

class _TrackList extends StatelessWidget {
  final List<db.AudioTrack> tracks;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const _TrackList({
    required this.tracks,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final t = tracks[index];
        final isSelected = t.id == selectedId;
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Material(
            color: isSelected
                ? AppTheme.accentColor.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onSelect(t.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    _Avatar(
                      name: t.name,
                      avatarPath: t.avatarPath,
                      selected: isSelected,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            _subtitle(t),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.fg.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (t.refText != null && t.refText!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.subtitles_rounded,
                          size: 14,
                          color: context.fg.withValues(alpha: 0.25),
                        ),
                      ),
                    Text(
                      _formatDuration(t.durationSec),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.fg.withValues(alpha: 0.4),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _subtitle(db.AudioTrack t) {
    final src = switch (t.sourceType) {
      'upload' => 'Uploaded',
      'record' => 'Recorded',
      'quickTts' => 'From Quick TTS',
      'phaseTts' => 'From Phase TTS',
      'dialogTts' => 'From Dialog TTS',
      _ => t.sourceType,
    };
    return src;
  }
}

String _formatDuration(double? sec) {
  if (sec == null) return '--:--';
  final s = sec.round();
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

// ─────────────────────────── Inspector Panel ────────────────────────────
