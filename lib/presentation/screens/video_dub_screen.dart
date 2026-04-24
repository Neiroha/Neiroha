import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:neiroha/data/adapters/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/storage/path_service.dart';
import 'package:neiroha/data/storage/subtitle_parser.dart';
import 'package:neiroha/presentation/navigation/app_navigation.dart';
import 'package:neiroha/presentation/screens/app_shell.dart' show selectedTabProvider;
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/project_card_grid.dart';
import 'package:neiroha/presentation/widgets/resizable_split_pane.dart';
import 'package:neiroha/presentation/widgets/video_dub_timeline.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Video Dub — dub video with TTS generated from subtitle cues.
///
/// List mode: grid of project cards (searchable, sorted by most recent edit).
/// Editor mode: video surface (media_kit), cue-synced timeline, subtitle
/// panel. Save returns to the list.
class VideoDubScreen extends ConsumerStatefulWidget {
  const VideoDubScreen({super.key});

  @override
  ConsumerState<VideoDubScreen> createState() => _VideoDubScreenState();
}

class _VideoDubScreenState extends ConsumerState<VideoDubScreen> {
  String? _selectedProjectId;

  @override
  Widget build(BuildContext context) {
    if (_selectedProjectId == null) {
      return _buildProjectListScreen();
    }
    return _VideoDubEditor(
      key: ValueKey(_selectedProjectId),
      projectId: _selectedProjectId!,
      onClose: () => setState(() => _selectedProjectId = null),
    );
  }

  // ───────────────── List mode ─────────────────

  Widget _buildProjectListScreen() {
    final projectsAsync = ref.watch(videoDubProjectsStreamProvider);
    return Column(
      children: [
        _buildListHeader(),
        const Divider(height: 1),
        Expanded(
          child: projectsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (projects) => ProjectCardGrid(
              emptyLabel: 'No video dub projects yet',
              projects: [
                for (final p in projects)
                  ProjectCardData(
                    id: p.id,
                    name: p.name,
                    updatedAt: p.updatedAt,
                    icon: Icons.movie_filter_rounded,
                    subtitle: p.videoPath == null
                        ? 'No video loaded'
                        : _fileBaseName(p.videoPath!),
                  ),
              ],
              onOpen: (id) => setState(() => _selectedProjectId = id),
              onDelete: (id) {
                ref.read(databaseProvider).deleteVideoDubProject(id);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          Text('Video Dub',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text('Dub video with TTS from subtitle cues',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
          const Spacer(),
          FilledButton.icon(
            onPressed: _createProject,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New Project'),
          ),
        ],
      ),
    );
  }

  Future<void> _createProject() async {
    final banks = ref.read(voiceBanksStreamProvider).valueOrNull ?? [];
    if (banks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Create a Voice Bank first')));
      }
      return;
    }

    final nameCtrl = TextEditingController();
    var selectedBankId = banks.first.id;

    final result = await showDialog<(String, String)?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Video Dub Project'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Project name'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Voice Bank'),
                isExpanded: true,
                initialValue: selectedBankId,
                items: banks
                    .map((b) => DropdownMenuItem(
                        value: b.id, child: Text(b.name)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setDialogState(() => selectedBankId = v);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () =>
                    Navigator.pop(ctx, (nameCtrl.text, selectedBankId)),
                child: const Text('Create')),
          ],
        ),
      ),
    );

    if (result != null && result.$1.trim().isNotEmpty) {
      final id = const Uuid().v4();
      final now = DateTime.now();
      await ref.read(databaseProvider).insertVideoDubProject(
            db.VideoDubProjectsCompanion(
              id: Value(id),
              name: Value(result.$1.trim()),
              bankId: Value(result.$2),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      setState(() => _selectedProjectId = id);
    }
  }

  String _fileBaseName(String path) {
    final sep = path.contains('\\') ? '\\' : '/';
    final parts = path.split(sep);
    return parts.isEmpty ? path : parts.last;
  }
}

// ───────────────── Editor mode ─────────────────

class _VideoDubEditor extends ConsumerStatefulWidget {
  final String projectId;
  final VoidCallback onClose;

  const _VideoDubEditor({
    super.key,
    required this.projectId,
    required this.onClose,
  });

  @override
  ConsumerState<_VideoDubEditor> createState() => _VideoDubEditorState();
}

class _VideoDubEditorState extends ConsumerState<_VideoDubEditor> {
  late final Player _player;
  late final VideoController _controller;
  late final ap.AudioPlayer _cuePlayer;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _durationSub;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  String? _currentVideoPath;

  // Dub sync state
  bool _muteVideoAudio = true;
  bool _syncDub = true;
  String? _activeCueId;
  String? _selectedCueId;
  final Set<String> _generatingCueIds = <String>{};
  bool _generatingAll = false;

  // Cue preview (manual click on a cue card). Independent from dub sync.
  String? _previewCueId;

  // Selected timeline clip (for delete-on-selected affordance).
  String? _selectedClipId;

  // One-flight guard — the position stream fires ~30×/s and the tick body
  // is async (stop → play → seek). Overlapping ticks caused a seek from
  // tick N+1 to land on tick N's old play call, replaying cues from zero.
  bool _ticking = false;

  // Waveform cache — keyed by the video path we extracted it from, so
  // changing videos invalidates the old peaks.
  String? _waveformPath;
  List<double>? _waveformPeaks;
  bool _extractingWaveform = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _cuePlayer = ap.AudioPlayer();

    _positionSub = _player.stream.position.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
      if (_syncDub) _onVideoTick(p);
    });
    _playingSub = _player.stream.playing.listen((p) async {
      if (!mounted) return;
      setState(() => _playing = p);
      if (_syncDub) {
        if (p) {
          // Video resumed — resume whatever cue is currently active.
          await _cuePlayer.resume();
        } else {
          await _cuePlayer.pause();
        }
      }
    });
    _durationSub = _player.stream.duration.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _playingSub?.cancel();
    _durationSub?.cancel();
    _player.dispose();
    _cuePlayer.dispose();
    super.dispose();
  }

  Future<void> _syncVideo(db.VideoDubProject project) async {
    final path = project.videoPath;
    if (path == _currentVideoPath) return;
    _currentVideoPath = path;
    if (path == null) {
      await _player.stop();
      return;
    }
    await _player.open(Media(path), play: false);
    await _player.setVolume(_muteVideoAudio ? 0 : 100);
    unawaited(_refreshWaveform(path));
  }

  /// Extract waveform peaks via the FFmpeg service. Cached per video path
  /// so switching back and forth doesn't reprobe. Silent on failure — the
  /// UI renders the banner when ffmpeg is unavailable, and a missing peak
  /// list just falls back to the unadorned track.
  Future<void> _refreshWaveform(String videoPath) async {
    if (_waveformPath == videoPath && _waveformPeaks != null) return;
    if (_extractingWaveform) return;
    _extractingWaveform = true;
    final svc = ref.read(ffmpegServiceProvider);
    if (!await svc.isAvailable()) {
      _extractingWaveform = false;
      if (mounted) {
        setState(() {
          _waveformPath = videoPath;
          _waveformPeaks = null;
        });
      }
      return;
    }
    final peaks =
        await svc.extractWaveformPeaks(videoPath, bucketCount: 800);
    if (!mounted) {
      _extractingWaveform = false;
      return;
    }
    setState(() {
      _waveformPath = videoPath;
      _waveformPeaks = peaks;
      _extractingWaveform = false;
    });
  }

  /// Called every video position tick. If the active cue changed, stop the
  /// current dub audio and start the new cue's audio at the right offset.
  Future<void> _onVideoTick(Duration pos) async {
    if (_ticking) return;
    _ticking = true;
    try {
      final cues =
          ref.read(subtitleCuesStreamProvider(widget.projectId)).valueOrNull;
      if (cues == null || cues.isEmpty) return;
      final ms = pos.inMilliseconds;

      // Find cue whose window contains current ms.
      db.SubtitleCue? active;
      for (final c in cues) {
        if (ms >= c.startMs && ms < c.endMs) {
          active = c;
          break;
        }
      }

      if (active?.id == _activeCueId) return;

      // Cue boundary crossed — stop whatever was playing.
      await _cuePlayer.stop();
      _activeCueId = active?.id;
      if (active == null) {
        if (mounted) setState(() {});
        return;
      }
      if (active.audioPath == null) {
        if (mounted) setState(() {});
        return;
      }
      final file = File(active.audioPath!);
      if (!file.existsSync()) {
        if (mounted) setState(() {});
        return;
      }
      // Offset into the cue audio = how far past cue.startMs the video is.
      final offsetMs = ms - active.startMs;
      try {
        await _cuePlayer.play(ap.DeviceFileSource(active.audioPath!));
        if (offsetMs > 50) {
          // Give audioplayers a beat to resolve duration before seeking.
          await Future.delayed(const Duration(milliseconds: 40));
          await _cuePlayer.seek(Duration(milliseconds: offsetMs));
        }
      } catch (_) {}
      if (mounted) setState(() {});
    } finally {
      _ticking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(videoDubProjectsStreamProvider);
    final project = projectsAsync.valueOrNull
        ?.where((p) => p.id == widget.projectId)
        .firstOrNull;

    if (project == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Reload the player whenever the persisted path changes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncVideo(project);
    });

    final cuesAsync = ref.watch(subtitleCuesStreamProvider(widget.projectId));
    final assetsAsync = ref.watch(voiceAssetsStreamProvider);
    final membersAsync = ref.watch(bankMembersStreamProvider(project.bankId));
    final allAssets = assetsAsync.valueOrNull ?? const <db.VoiceAsset>[];
    final assetMap = {for (final a in allAssets) a.id: a};
    final bankMembers = membersAsync.valueOrNull ?? const <db.VoiceBankMember>[];
    final bankAssets = bankMembers
        .map((m) => assetMap[m.voiceAssetId])
        .whereType<db.VoiceAsset>()
        .toList();

    final cues = cuesAsync.valueOrNull ?? const <db.SubtitleCue>[];
    final clipsAsync = ref.watch(
        timelineClipsStreamProvider('videodub:${widget.projectId}'));
    final clips = clipsAsync.valueOrNull ?? const <db.TimelineClip>[];
    final ffmpegAvailable = ref
            .watch(ffmpegAvailabilityProvider)
            .maybeWhen(data: (v) => v, orElse: () => false);

    return Column(
      children: [
        _buildBar(project, bankAssets.length),
        const Divider(height: 1),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: VerticalResizableSplitPane(
                  initialTopFraction: 0.58,
                  minPaneHeight: 160,
                  top: Column(
                    children: [
                      Expanded(child: _buildVideoSurface(project)),
                      const Divider(height: 1),
                      SizedBox(height: 64, child: _buildTransport(project)),
                    ],
                  ),
                  bottom: VideoDubTimeline(
                    cues: cues,
                    clips: clips,
                    assetMap: assetMap,
                    position: _position,
                    duration: _duration,
                    selectedCueId: _selectedCueId,
                    selectedClipId: _selectedClipId,
                    waveformPeaks: _waveformPeaks,
                    ffmpegAvailable: ffmpegAvailable,
                    onConfigureFfmpeg: () {
                      ref.read(selectedTabProvider.notifier).state =
                          NavTab.settings;
                    },
                    onSeek: (d) async {
                      await _cuePlayer.stop();
                      _activeCueId = null;
                      await _player.seek(d);
                    },
                    onTapCue: (cue) async {
                      setState(() {
                        _selectedCueId = cue.id;
                        _selectedClipId = null;
                      });
                      await _cuePlayer.stop();
                      _activeCueId = null;
                      await _player
                          .seek(Duration(milliseconds: cue.startMs));
                    },
                    onTapClip: (clip) async {
                      setState(() {
                        _selectedClipId = clip.id;
                        _selectedCueId = null;
                      });
                      await _player
                          .seek(Duration(milliseconds: clip.startTimeMs));
                    },
                    onDeleteClip: (clip) async {
                      if (_selectedClipId == clip.id) {
                        setState(() => _selectedClipId = null);
                      }
                      // NOTE: intentionally does NOT delete the file on
                      // disk. The startup storage scan flags orphans;
                      // the same media may be referenced by other rows
                      // (re-imported or cue-generated).
                      await ref
                          .read(databaseProvider)
                          .deleteTimelineClip(clip.id);
                    },
                    onImport: (kind) => _importMedia(project, kind, clips),
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              SizedBox(
                width: 360,
                child: _buildSubtitlePanel(project, cues, bankAssets, assetMap),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBar(db.VideoDubProject project, int voiceCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 20, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to projects',
            onPressed: () => _close(project),
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
          ),
          const SizedBox(width: 4),
          Icon(Icons.movie_filter_rounded,
              color: AppTheme.accentColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(project.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDim,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('$voiceCount voices',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.5))),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () => _pickVideo(project),
            icon: const Icon(Icons.video_file_outlined, size: 16),
            label: Text(project.videoPath == null ? 'Open Video' : 'Change Video'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _close(project),
            icon: const Icon(Icons.save_rounded, size: 16),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSurface(db.VideoDubProject project) {
    if (project.videoPath == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.movie_outlined,
                  size: 56, color: Colors.white.withValues(alpha: 0.25)),
              const SizedBox(height: 12),
              Text('No video loaded',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 14)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _pickVideo(project),
                icon: const Icon(Icons.video_file_outlined, size: 18),
                label: const Text('Open Video'),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      color: Colors.black,
      child: Video(controller: _controller),
    );
  }

  Widget _buildTransport(db.VideoDubProject project) {
    final canPlay = project.videoPath != null;
    final durationMs = _duration.inMilliseconds.toDouble();
    final sliderMaxMs = durationMs.clamp(0.0, double.infinity).toDouble();
    final sliderValueMs = _position.inMilliseconds
        .toDouble()
        .clamp(0.0, sliderMaxMs)
        .toDouble();
    return Container(
      color: AppTheme.surfaceDim,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: canPlay
                ? () async {
                    await _cuePlayer.stop();
                    _activeCueId = null;
                    await _player.seek(Duration.zero);
                  }
                : null,
            icon: const Icon(Icons.skip_previous_rounded),
          ),
          IconButton(
            onPressed: canPlay ? () => _player.playOrPause() : null,
            icon: Icon(_playing
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded),
          ),
          const SizedBox(width: 8),
          Text(_formatDuration(_position),
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 12)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Slider(
                min: 0,
                max: sliderMaxMs,
                value: sliderValueMs,
                onChanged: canPlay && _duration.inMilliseconds > 0
                    ? (v) async {
                        await _cuePlayer.stop();
                        _activeCueId = null;
                        await _player.seek(Duration(milliseconds: v.round()));
                      }
                    : null,
              ),
            ),
          ),
          Text(_formatDuration(_duration),
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 12)),
          const SizedBox(width: 12),
          // Mute original video audio (default on — dubbing use case).
          Tooltip(
            message: _muteVideoAudio
                ? 'Original audio muted'
                : 'Original audio on',
            child: IconButton(
              icon: Icon(
                _muteVideoAudio
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                size: 18,
              ),
              onPressed: () async {
                setState(() => _muteVideoAudio = !_muteVideoAudio);
                await _player.setVolume(_muteVideoAudio ? 0 : 100);
              },
            ),
          ),
          Tooltip(
            message: _syncDub
                ? 'Dub playback synced'
                : 'Dub playback off',
            child: IconButton(
              icon: Icon(
                _syncDub
                    ? Icons.record_voice_over_rounded
                    : Icons.voice_over_off_rounded,
                size: 18,
                color: _syncDub
                    ? AppTheme.accentColor
                    : Colors.white.withValues(alpha: 0.4),
              ),
              onPressed: () async {
                setState(() => _syncDub = !_syncDub);
                if (!_syncDub) {
                  await _cuePlayer.stop();
                  _activeCueId = null;
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitlePanel(
    db.VideoDubProject project,
    List<db.SubtitleCue> cues,
    List<db.VoiceAsset> bankAssets,
    Map<String, db.VoiceAsset> assetMap,
  ) {
    return Container(
      color: AppTheme.surfaceDim,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Row(
              children: [
                const Text('Subtitles',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  tooltip: 'Import SRT/LRC',
                  onPressed: () => _importSubtitles(project, cues),
                  icon: const Icon(Icons.file_upload_outlined, size: 18),
                ),
                IconButton(
                  tooltip: 'Add cue',
                  onPressed: () => _addCueDialog(project, cues),
                  icon: const Icon(Icons.add, size: 18),
                ),
                if (cues.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear all cues',
                    onPressed: () => _confirmClearCues(project),
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: cues.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.subtitles_off_outlined,
                              size: 42,
                              color: Colors.white.withValues(alpha: 0.2)),
                          const SizedBox(height: 10),
                          Text(
                            'No cues yet.\nImport an SRT/LRC file or add one manually.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    itemCount: cues.length,
                    itemBuilder: (_, i) {
                      final cue = cues[i];
                      return _CueCard(
                        cue: cue,
                        index: i,
                        bankAssets: bankAssets,
                        isSelected: cue.id == _selectedCueId,
                        isGenerating: _generatingCueIds.contains(cue.id),
                        isPreviewing: _previewCueId == cue.id,
                        onTap: () async {
                          setState(() => _selectedCueId = cue.id);
                          await _cuePlayer.stop();
                          _activeCueId = null;
                          await _player.seek(
                              Duration(milliseconds: cue.startMs));
                        },
                        onVoiceChanged: (voiceId) =>
                            _updateCueVoice(cue, voiceId),
                        onGenerate: _generatingCueIds.contains(cue.id)
                            ? null
                            : () => _generateOne(project, cue, bankAssets),
                        onEdit: () => _editCueDialog(cue),
                        onDelete: () => _deleteCue(cue),
                        onPreview: () => _previewCue(cue),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              onPressed: cues.isEmpty || _generatingAll || bankAssets.isEmpty
                  ? null
                  : () => _generateAll(project, cues, bankAssets),
              icon: _generatingAll
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Generate All'),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────── Actions ─────────────────

  /// Import video, image, or audio onto the multi-track timeline.
  /// Files are copied into `{voiceAssetRoot}/video_dub/{slug}/assets/`
  /// and registered as TimelineClips under `projectType='videodub'`.
  /// Start time = end of the last clip on the same lane (stacked append).
  /// Duration is probed via audioplayers where applicable; image clips
  /// default to 3 s so they have something visible until the user stretches.
  Future<void> _importMedia(
    db.VideoDubProject project,
    DubImportKind kind,
    List<db.TimelineClip> existing,
  ) async {
    final typeForPicker = switch (kind) {
      DubImportKind.video => FileType.video,
      DubImportKind.image => FileType.image,
      DubImportKind.audio => FileType.audio,
    };
    final picked = await FilePicker.platform.pickFiles(
      type: typeForPicker,
      allowMultiple: false,
    );
    final src = picked?.files.single.path;
    if (src == null) return;
    if (!await File(src).exists()) return;

    final slug = await ref
        .read(storageServiceProvider)
        .ensureVideoDubProjectSlug(project.id);
    final assetsDir = await _ensureAssetsDir(slug);
    final ext = p.extension(src);
    final base = p.basenameWithoutExtension(src);
    final destPath = PathService.dedupeFilename(
      assetsDir,
      '${base}_${PathService.formatTimestamp()}',
      ext,
    );
    try {
      await File(src).copy(destPath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Copy failed: $e')),
        );
      }
      return;
    }

    final assignment = laneAndSourceForImport(kind);
    double? duration;
    if (kind == DubImportKind.audio) {
      duration = await measureAudioDuration(destPath);
    } else if (kind == DubImportKind.image) {
      duration = 3.0;
    }
    // For video, leave duration null — a probe via ffmpeg would be ideal
    // but for now the user trims manually and the block shows at a
    // minimum width until probing is wired in.

    // Stack append on this lane: start at the end of the last clip there.
    var startMs = 0;
    for (final c in existing) {
      if (c.laneIndex != assignment.lane) continue;
      final end =
          c.startTimeMs + ((c.durationSec ?? 0) * 1000).round();
      if (end > startMs) startMs = end;
    }

    await ref.read(databaseProvider).insertTimelineClip(
          makeDubClipCompanion(
            id: const Uuid().v4(),
            projectId: project.id,
            lane: assignment.lane,
            startTimeMs: startMs,
            sourceType: assignment.sourceType,
            audioPath: destPath,
            label: base,
            durationSec: duration,
          ),
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported "$base"')),
      );
    }
  }

  Future<Directory> _ensureAssetsDir(String slug) async {
    final base = await PathService.instance.videoDubDir(slug);
    final dir = Directory(p.join(base.path, 'assets'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _pickVideo(db.VideoDubProject project) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    if (!await File(path).exists()) return;

    await ref.read(databaseProvider).updateVideoDubProject(
          project.copyWith(
            videoPath: Value(path),
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<void> _importSubtitles(
    db.VideoDubProject project,
    List<db.SubtitleCue> existing,
  ) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['srt', 'lrc', 'vtt', 'txt'],
      allowMultiple: false,
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) return;

    List<ParsedCue> parsed;
    try {
      parsed = await SubtitleParser.parseFile(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Parse failed: $e')),
        );
      }
      return;
    }
    if (parsed.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No cues found in file')),
        );
      }
      return;
    }

    if (!mounted) return;
    final replace = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Import ${parsed.length} cues?'),
        content: existing.isEmpty
            ? const Text('Cues will be added to this project.')
            : Text(
                'This project already has ${existing.length} cues. '
                'Replace them, or append the new cues after?',
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          if (existing.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Append'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(existing.isEmpty ? 'Import' : 'Replace'),
          ),
        ],
      ),
    );
    if (replace == null) return;

    final database = ref.read(databaseProvider);
    int nextOrder = 0;
    if (replace) {
      await database.clearSubtitleCues(project.id);
    } else {
      nextOrder = existing.isEmpty
          ? 0
          : (existing.map((c) => c.orderIndex).reduce((a, b) => a > b ? a : b) +
              1);
    }
    final banks = ref.read(voiceBanksStreamProvider).valueOrNull ?? const [];
    final members =
        ref.read(bankMembersStreamProvider(project.bankId)).valueOrNull ??
            const <db.VoiceBankMember>[];
    // Default voice = first voice in this project's bank.
    String? defaultVoiceId;
    if (members.isNotEmpty && banks.isNotEmpty) {
      defaultVoiceId = members.first.voiceAssetId;
    }

    for (var i = 0; i < parsed.length; i++) {
      final c = parsed[i];
      await database.insertSubtitleCue(
        db.SubtitleCuesCompanion(
          id: Value(const Uuid().v4()),
          projectId: Value(project.id),
          orderIndex: Value(nextOrder + i),
          startMs: Value(c.startMs),
          endMs: Value(c.endMs),
          cueText: Value(c.text),
          voiceAssetId: Value(defaultVoiceId),
        ),
      );
    }
    await database.updateVideoDubProject(
      project.copyWith(updatedAt: DateTime.now()),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${parsed.length} cues')),
      );
    }
  }

  Future<void> _addCueDialog(
    db.VideoDubProject project,
    List<db.SubtitleCue> existing,
  ) async {
    final result = await _showCueEditDialog(
      initialStartMs: _position.inMilliseconds,
      initialEndMs: _position.inMilliseconds + 3000,
      initialText: '',
      title: 'Add cue',
    );
    if (result == null) return;
    final nextOrder = existing.isEmpty
        ? 0
        : (existing.map((c) => c.orderIndex).reduce((a, b) => a > b ? a : b) +
            1);
    final defaultVoiceId =
        ref.read(bankMembersStreamProvider(project.bankId)).valueOrNull?.firstOrNull
            ?.voiceAssetId;
    await ref.read(databaseProvider).insertSubtitleCue(
          db.SubtitleCuesCompanion(
            id: Value(const Uuid().v4()),
            projectId: Value(project.id),
            orderIndex: Value(nextOrder),
            startMs: Value(result.startMs),
            endMs: Value(result.endMs),
            cueText: Value(result.text),
            voiceAssetId: Value(defaultVoiceId),
          ),
        );
  }

  Future<void> _editCueDialog(db.SubtitleCue cue) async {
    final result = await _showCueEditDialog(
      initialStartMs: cue.startMs,
      initialEndMs: cue.endMs,
      initialText: cue.cueText,
      title: 'Edit cue',
    );
    if (result == null) return;
    await ref.read(databaseProvider).updateSubtitleCue(
          cue.copyWith(
            startMs: result.startMs,
            endMs: result.endMs,
            cueText: result.text,
            // Edits invalidate the old audio.
            audioPath: const Value(null),
            audioDuration: const Value(null),
            error: const Value(null),
          ),
        );
  }

  Future<_CueEdit?> _showCueEditDialog({
    required int initialStartMs,
    required int initialEndMs,
    required String initialText,
    required String title,
  }) async {
    final startCtrl =
        TextEditingController(text: _msToStamp(initialStartMs));
    final endCtrl = TextEditingController(text: _msToStamp(initialEndMs));
    final textCtrl = TextEditingController(text: initialText);
    String? errorMsg;

    return showDialog<_CueEdit>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Start (mm:ss.ms)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: endCtrl,
                        decoration: const InputDecoration(
                          labelText: 'End (mm:ss.ms)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: textCtrl,
                  autofocus: true,
                  maxLines: 4,
                  minLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Subtitle text',
                  ),
                ),
                if (errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(errorMsg!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 12)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final startMs = _parseStamp(startCtrl.text);
                final endMs = _parseStamp(endCtrl.text);
                if (startMs == null || endMs == null) {
                  setDialogState(() =>
                      errorMsg = 'Use format mm:ss.ms or HH:mm:ss.ms');
                  return;
                }
                if (endMs <= startMs) {
                  setDialogState(() =>
                      errorMsg = 'End must be greater than start');
                  return;
                }
                if (textCtrl.text.trim().isEmpty) {
                  setDialogState(() => errorMsg = 'Text is required');
                  return;
                }
                Navigator.pop(
                  ctx,
                  _CueEdit(
                    startMs: startMs,
                    endMs: endMs,
                    text: textCtrl.text.trim(),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearCues(db.VideoDubProject project) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all cues?'),
        content: const Text(
            'Cues will be removed. Generated audio files on disk are kept '
            'but the references will be gone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(databaseProvider).clearSubtitleCues(project.id);
    }
  }

  Future<void> _deleteCue(db.SubtitleCue cue) async {
    if (_selectedCueId == cue.id) {
      setState(() => _selectedCueId = null);
    }
    await ref.read(databaseProvider).deleteSubtitleCue(cue.id);
  }

  void _updateCueVoice(db.SubtitleCue cue, String? voiceId) {
    ref.read(databaseProvider).updateSubtitleCue(
          cue.copyWith(voiceAssetId: Value(voiceId)),
        );
  }

  Future<void> _previewCue(db.SubtitleCue cue) async {
    if (cue.audioPath == null) return;
    final playback = ref.read(playbackNotifierProvider);
    final notifier = ref.read(playbackNotifierProvider.notifier);
    if (_previewCueId == cue.id && playback.isPlaying) {
      await notifier.stop();
      setState(() => _previewCueId = null);
      return;
    }
    setState(() => _previewCueId = cue.id);
    await notifier.load(
      cue.audioPath!,
      cue.cueText,
      subtitle: 'Cue preview',
    );
  }

  Future<void> _generateAll(
    db.VideoDubProject project,
    List<db.SubtitleCue> cues,
    List<db.VoiceAsset> bankAssets,
  ) async {
    setState(() => _generatingAll = true);
    for (final cue in cues) {
      if (cue.audioPath != null) continue;
      if (cue.voiceAssetId == null) continue;
      await _generateOne(project, cue, bankAssets);
    }
    if (mounted) setState(() => _generatingAll = false);
  }

  Future<void> _generateOne(
    db.VideoDubProject project,
    db.SubtitleCue cue,
    List<db.VoiceAsset> bankAssets,
  ) async {
    if (cue.voiceAssetId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assign a voice to this cue first')),
        );
      }
      return;
    }
    final providers = ref.read(ttsProvidersStreamProvider).valueOrNull ?? [];
    final assetMap = {for (final a in bankAssets) a.id: a};
    final providerMap = {for (final p in providers) p.id: p};
    final asset = assetMap[cue.voiceAssetId];
    if (asset == null) return;
    final provider = providerMap[asset.providerId];
    if (provider == null) return;

    final slug = await ref
        .read(storageServiceProvider)
        .ensureVideoDubProjectSlug(project.id);
    final outDir = await PathService.instance.videoDubDir(slug);
    final database = ref.read(databaseProvider);

    setState(() => _generatingCueIds.add(cue.id));
    try {
      final adapter = createAdapter(provider, modelName: asset.modelName);
      final result = await adapter.synthesize(TtsRequest(
        text: cue.cueText,
        voice: asset.presetVoiceName ?? asset.name,
        speed: asset.speed,
        textLang: provider.adapterType == 'gptSovits' ? asset.modelName : null,
        presetVoiceName: asset.presetVoiceName,
        voiceInstruction: asset.voiceInstruction,
        refAudioPath: asset.refAudioPath,
        promptText: asset.promptText,
        promptLang: asset.promptLang,
      ));
      final ext = result.contentType.contains('wav') ? '.wav' : '.mp3';
      final filePath = PathService.dedupeFilename(
        outDir,
        'cue_${cue.orderIndex}_${PathService.formatTimestamp()}',
        ext,
      );
      await File(filePath).writeAsBytes(result.audioBytes);
      final durationSec = await measureAudioDuration(filePath);
      await database.updateSubtitleCue(
        cue.copyWith(
          audioPath: Value(filePath),
          audioDuration: Value(durationSec),
          error: const Value(null),
        ),
      );
    } catch (e) {
      await database.updateSubtitleCue(
        cue.copyWith(error: Value(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _generatingCueIds.remove(cue.id));
    }
  }

  void _close(db.VideoDubProject project) {
    ref.read(databaseProvider).updateVideoDubProject(
          project.copyWith(updatedAt: DateTime.now()),
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved'),
          duration: Duration(seconds: 1),
        ),
      );
      widget.onClose();
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  static String _msToStamp(int ms) {
    final d = Duration(milliseconds: ms);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final msR = d.inMilliseconds.remainder(1000);
    String two(int n) => n.toString().padLeft(2, '0');
    final tail = '${two(m)}:${two(s)}.${msR.toString().padLeft(3, '0')}';
    return h > 0 ? '${two(h)}:$tail' : tail;
  }

  /// Accepts `mm:ss`, `mm:ss.ms`, `HH:mm:ss`, `HH:mm:ss.ms`.
  static int? _parseStamp(String input) {
    final s = input.trim();
    if (s.isEmpty) return null;
    final m = RegExp(
      r'^(?:(\d{1,2}):)?(\d{1,2}):(\d{1,2})(?:[.,](\d{1,3}))?$',
    ).firstMatch(s);
    if (m == null) return null;
    final hours = m.group(1) == null ? 0 : int.parse(m.group(1)!);
    final minutes = int.parse(m.group(2)!);
    final seconds = int.parse(m.group(3)!);
    final msGroup = m.group(4);
    final ms = msGroup == null ? 0 : int.parse(msGroup.padRight(3, '0'));
    return ((hours * 3600) + (minutes * 60) + seconds) * 1000 + ms;
  }
}

class _CueEdit {
  final int startMs;
  final int endMs;
  final String text;
  const _CueEdit({
    required this.startMs,
    required this.endMs,
    required this.text,
  });
}

// ───────────────── Cue Card ─────────────────

class _CueCard extends StatelessWidget {
  final db.SubtitleCue cue;
  final int index;
  final List<db.VoiceAsset> bankAssets;
  final bool isSelected;
  final bool isGenerating;
  final bool isPreviewing;
  final VoidCallback onTap;
  final ValueChanged<String?> onVoiceChanged;
  final VoidCallback? onGenerate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPreview;

  const _CueCard({
    required this.cue,
    required this.index,
    required this.bankAssets,
    required this.isSelected,
    required this.isGenerating,
    required this.isPreviewing,
    required this.onTap,
    required this.onVoiceChanged,
    required this.onGenerate,
    required this.onEdit,
    required this.onDelete,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final bankHasVoice = bankAssets.any((a) => a.id == cue.voiceAssetId);
    final canGenerate =
        cue.voiceAssetId != null && bankHasVoice && !isGenerating;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: isSelected
          ? AppTheme.accentColor.withValues(alpha: 0.16)
          : null,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isSelected
              ? Colors.amber.withValues(alpha: 0.6)
              : Colors.transparent,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('#${index + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.55),
                      )),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_ms(cue.startMs)} → ${_ms(cue.endMs)}',
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                  if (isGenerating)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (cue.error != null)
                    Tooltip(
                      message: cue.error!,
                      child: const Icon(Icons.error_rounded,
                          size: 16, color: Colors.redAccent),
                    )
                  else if (cue.audioPath != null)
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints.tightFor(width: 24, height: 24),
                      icon: Icon(
                        isPreviewing
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                        size: 16,
                      ),
                      tooltip: 'Preview',
                      onPressed: onPreview,
                    )
                  else
                    Icon(Icons.pending_rounded,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.22)),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 24, height: 24),
                    icon: Icon(
                      cue.audioPath != null
                          ? Icons.refresh_rounded
                          : Icons.auto_awesome_rounded,
                      size: 14,
                      color: canGenerate
                          ? AppTheme.accentColor
                          : Colors.white.withValues(alpha: 0.18),
                    ),
                    tooltip:
                        cue.audioPath != null ? 'Regenerate' : 'Generate',
                    onPressed: canGenerate ? onGenerate : null,
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 24, height: 24),
                    icon: Icon(Icons.edit_outlined,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.4)),
                    tooltip: 'Edit',
                    onPressed: onEdit,
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 24, height: 24),
                    icon: Icon(Icons.close_rounded,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.35)),
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(cue.cueText,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 6),
              SizedBox(
                height: 30,
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    hintText: 'Voice',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  isExpanded: true,
                  initialValue: bankHasVoice ? cue.voiceAssetId : null,
                  items: bankAssets
                      .map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(a.name,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: onVoiceChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _ms(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    final msR = d.inMilliseconds.remainder(1000);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(m)}:${two(s)}.${msR.toString().padLeft(3, '0')}';
  }
}
