import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/resizable_split_pane.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';

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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (tracks) {
              if (tracks.isEmpty) return _buildEmpty(context, ref);
              final selected =
                  tracks.where((t) => t.id == selectedId).firstOrNull;
              return ResizableSplitPane(
                initialLeftFraction: 0.6,
                left: _TrackList(
                  tracks: tracks,
                  selectedId: selectedId,
                  onSelect: (id) => ref
                      .read(_selectedTrackIdProvider.notifier)
                      .state = id,
                ),
                rightBuilder: (_) => selected != null
                    ? _TrackInspector(track: selected)
                    : Center(
                        child: Text('Select a track',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4)))),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          Text('Voice Assets',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text('Single audio tracks for voice cloning',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => _recordTrack(context),
            icon: const Icon(Icons.mic_rounded, size: 18),
            label: const Text('Record'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _uploadTrack(context, ref),
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: const Text('Upload Audio'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.library_music_outlined,
              size: 64, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Text('No audio tracks yet',
              style: TextStyle(
                  fontSize: 16, color: Colors.white.withValues(alpha: 0.4))),
          const SizedBox(height: 8),
          Text(
            'Upload an audio file or record a new sample to get started.',
            style: TextStyle(
                fontSize: 13, color: Colors.white.withValues(alpha: 0.25)),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => _uploadTrack(context, ref),
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: const Text('Upload Audio'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadTrack(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;
    final src = File(result.files.single.path!);
    if (!await src.exists()) return;

    // Copy into AppSupportDir/voice_assets/
    final dir = await getApplicationSupportDirectory();
    final assetDir = Directory(p.join(dir.path, 'voice_assets'));
    if (!await assetDir.exists()) await assetDir.create(recursive: true);
    final id = const Uuid().v4();
    final ext = p.extension(src.path).isEmpty ? '.wav' : p.extension(src.path);
    final dstPath = p.join(assetDir.path, '$id$ext');
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
    await ref.read(databaseProvider).insertAudioTrack(db.AudioTracksCompanion(
          id: Value(id),
          name: Value(name),
          audioPath: Value(dstPath),
          durationSec: Value(duration),
          sourceType: const Value('upload'),
          createdAt: Value(DateTime.now()),
        ));
    ref.read(_selectedTrackIdProvider.notifier).state = id;
  }

  void _recordTrack(BuildContext context) {
    // Microphone recording opens an editor dialog. Not yet implemented —
    // surfaced as a placeholder so the entry point is discoverable.
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Microphone recording is not implemented yet.')));
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    _Avatar(
                        name: t.name,
                        avatarPath: t.avatarPath,
                        selected: isSelected),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text(
                            _subtitle(t),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.4)),
                          ),
                        ],
                      ),
                    ),
                    if (t.refText != null && t.refText!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(Icons.subtitles_rounded,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.25)),
                      ),
                    Text(
                      _formatDuration(t.durationSec),
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.4),
                          fontFeatures: const [FontFeature.tabularFigures()]),
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

class _TrackInspector extends ConsumerStatefulWidget {
  final db.AudioTrack track;
  const _TrackInspector({required this.track});

  @override
  ConsumerState<_TrackInspector> createState() => _TrackInspectorState();
}

class _TrackInspectorState extends ConsumerState<_TrackInspector> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _refTextCtrl;
  late final TextEditingController _refLangCtrl;
  String? _loadedTrackId;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.track.name);
    _descCtrl = TextEditingController(text: widget.track.description ?? '');
    _refTextCtrl = TextEditingController(text: widget.track.refText ?? '');
    _refLangCtrl = TextEditingController(text: widget.track.refLang ?? '');
    _loadedTrackId = widget.track.id;
  }

  @override
  void didUpdateWidget(covariant _TrackInspector old) {
    super.didUpdateWidget(old);
    if (old.track.id != widget.track.id) {
      _nameCtrl.text = widget.track.name;
      _descCtrl.text = widget.track.description ?? '';
      _refTextCtrl.text = widget.track.refText ?? '';
      _refLangCtrl.text = widget.track.refLang ?? '';
      _loadedTrackId = widget.track.id;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _refTextCtrl.dispose();
    _refLangCtrl.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final playback = ref.read(playbackNotifierProvider);
    final notifier = ref.read(playbackNotifierProvider.notifier);
    if (playback.audioPath == widget.track.audioPath && playback.isPlaying) {
      await notifier.stop();
      return;
    }
    if (!await File(widget.track.audioPath).exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audio file missing on disk')));
      }
      return;
    }
    await notifier.load(
      widget.track.audioPath,
      widget.track.name,
      subtitle: widget.track.description,
    );
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;
    final src = File(result.files.single.path!);
    final dir = await getApplicationSupportDirectory();
    final avatarDir = Directory(p.join(dir.path, 'avatars'));
    if (!await avatarDir.exists()) await avatarDir.create(recursive: true);
    final ext = p.extension(src.path).isEmpty ? '.png' : p.extension(src.path);
    final dst = p.join(avatarDir.path, '${widget.track.id}$ext');
    await src.copy(dst);
    await ref.read(databaseProvider).updateAudioTrack(
        widget.track.copyWith(avatarPath: Value(dst)));
  }

  Future<void> _save() async {
    await ref.read(databaseProvider).updateAudioTrack(widget.track.copyWith(
          name: _nameCtrl.text.trim().isEmpty
              ? widget.track.name
              : _nameCtrl.text.trim(),
          description: Value(
              _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim()),
          refText: Value(_refTextCtrl.text.trim().isEmpty
              ? null
              : _refTextCtrl.text.trim()),
          refLang: Value(_refLangCtrl.text.trim().isEmpty
              ? null
              : _refLangCtrl.text.trim()),
        ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved'), duration: Duration(seconds: 1)));
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete audio track?'),
        content: Text('"${widget.track.name}" will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(databaseProvider).deleteAudioTrack(widget.track.id);
    // Best-effort: remove the audio file from disk
    try {
      final f = File(widget.track.audioPath);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    if (mounted) {
      ref.read(_selectedTrackIdProvider.notifier).state = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Suppress "unused" lint when track refreshes mid-edit.
    assert(_loadedTrackId == widget.track.id);
    final playback = ref.watch(playbackNotifierProvider);
    final isPlayingThis = playback.audioPath == widget.track.audioPath &&
        playback.isPlaying;
    return Container(
      color: AppTheme.surfaceDim,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                children: [
                  _Avatar(
                      name: widget.track.name,
                      avatarPath: widget.track.avatarPath,
                      selected: true,
                      size: 84),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppTheme.surfaceDim, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Player row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceBright,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _togglePlay,
                  icon: Icon(isPlayingThis
                      ? Icons.stop_circle_rounded
                      : Icons.play_circle_rounded),
                  color: AppTheme.accentColor,
                  iconSize: 32,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.basename(widget.track.audioPath),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, fontFamily: 'monospace'),
                      ),
                      Text(
                        _formatDuration(widget.track.durationSec),
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.4)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _refTextCtrl,
            decoration: const InputDecoration(
              labelText: 'Reference Text',
              helperText:
                  'Transcript of the audio (used by voice cloning models that need it)',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _refLangCtrl,
            decoration: const InputDecoration(
              labelText: 'Reference Language',
              hintText: 'e.g. zh, en, ja',
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline_rounded),
                color: Colors.redAccent,
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Avatar Helper ─────────────────────────────

class _Avatar extends StatelessWidget {
  final String name;
  final String? avatarPath;
  final bool selected;
  final double size;

  const _Avatar({
    required this.name,
    required this.avatarPath,
    required this.selected,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final hasAvatar = avatarPath != null && File(avatarPath!).existsSync();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected
            ? AppTheme.accentColor.withValues(alpha: 0.2)
            : AppTheme.surfaceBright,
        border: Border.all(
          color: selected
              ? AppTheme.accentColor.withValues(alpha: 0.5)
              : Colors.transparent,
          width: 1,
        ),
        image: hasAvatar
            ? DecorationImage(
                image: FileImage(File(avatarPath!)), fit: BoxFit.cover)
            : null,
      ),
      child: hasAvatar
          ? null
          : Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? AppTheme.accentColor
                      : Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ),
    );
  }
}
