import 'dart:async';
import 'dart:io';

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
import 'package:neiroha/presentation/screens/app_shell.dart'
    show selectedTabProvider;
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/actions/video_dub/exporter.dart';
import 'package:neiroha/presentation/widgets/project_card_grid.dart';
import 'package:neiroha/presentation/widgets/resizable_split_pane.dart';
import 'package:neiroha/presentation/widgets/video_dub/cue_card.dart';
import 'package:neiroha/presentation/widgets/video_dub/cue_dialogs.dart';
import 'package:neiroha/presentation/widgets/video_dub/timeline.dart';
import 'package:neiroha/presentation/widgets/video_dub/tracks.dart';
import 'package:neiroha/providers/app_providers.dart';
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
          Text(
            'Video Dub',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Dub video with TTS from subtitle cues',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
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
          const SnackBar(content: Text('Create a Voice Bank first')),
        );
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
                    .map(
                      (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
                    )
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
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, (nameCtrl.text, selectedBankId)),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result.$1.trim().isNotEmpty) {
      final id = const Uuid().v4();
      final now = DateTime.now();
      await ref
          .read(databaseProvider)
          .insertVideoDubProject(
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
  late final Player _cuePlayer;
  late final Player _previewPlayer;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _previewCompletedSub;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier(
    Duration.zero,
  );
  final ValueNotifier<Duration> _durationNotifier = ValueNotifier(
    Duration.zero,
  );
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

  // Export-in-progress guard for the toolbar button.
  bool _exporting = false;
  bool _exportingSubtitles = false;
  bool _syncingCueLengths = false;

  // Sticky import preferences: remembered across imports in the same
  // editor session so the user doesn't have to re-toggle each time.
  bool _autoTtsAfterImport = false;
  bool _autoSyncAfterImport = false;

  // True after the user makes any change that hasn't been confirmed via
  // the Save button. All edits also persist to the database immediately,
  // but Save is what bumps `updatedAt` (project list ordering) and what
  // the user expects to do before walking away.
  bool _dirty = false;

  /// Mark the editor as having unsaved work. Cheap to call repeatedly
  /// — only triggers a rebuild on the false → true transition (so the
  /// title bar's dirty dot appears).
  void _markDirty() {
    if (_dirty || !mounted) return;
    setState(() => _dirty = true);
  }

  // One-flight guard — the position stream fires ~30×/s and the tick body
  // is async (stop → play → seek). Overlapping ticks caused a seek from
  // tick N+1 to land on tick N's old play call, replaying cues from zero.
  bool _ticking = false;

  // Waveform cache — keyed by the video path we extracted it from, so
  // changing videos invalidates the old peaks.
  String? _waveformPath;
  List<double>? _waveformPeaks;
  bool _extractingWaveform = false;

  late final Listenable _playbackTimelineListenable = Listenable.merge([
    _positionNotifier,
    _durationNotifier,
  ]);

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _cuePlayer = Player();
    _previewPlayer = Player();

    _positionSub = _player.stream.position.listen((p) {
      if (!mounted) return;
      _position = p;
      _positionNotifier.value = p;
      if (_syncDub) _onVideoTick(p);
    });
    _playingSub = _player.stream.playing.listen((p) async {
      if (!mounted) return;
      setState(() => _playing = p);
      if (_syncDub) {
        if (p) {
          // Video resumed — resume whatever cue is currently active.
          await _cuePlayer.play();
        } else {
          await _cuePlayer.pause();
        }
      }
    });
    _durationSub = _player.stream.duration.listen((d) {
      if (!mounted) return;
      _duration = d;
      _durationNotifier.value = d;
    });
    _previewCompletedSub = _previewPlayer.stream.completed.listen((done) {
      if (!mounted || !done) return;
      setState(() => _previewCueId = null);
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _playingSub?.cancel();
    _durationSub?.cancel();
    _previewCompletedSub?.cancel();
    _positionNotifier.dispose();
    _durationNotifier.dispose();
    _player.dispose();
    _cuePlayer.dispose();
    _previewPlayer.dispose();
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
    final peaks = await svc.extractWaveformPeaks(videoPath, bucketCount: 800);
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

  // Last A1-coverage state, so we only push a setVolume when it flips.
  bool? _a1Covers;

  /// Mute / unmute the video player based on whether any A1 clip covers
  /// [ms]. The `_muteVideoAudio` toggle is an additional override —
  /// if the user muted the video, it stays muted regardless of A1.
  void _applyA1Gating(int ms) {
    final clips = ref
        .read(timelineClipsStreamProvider('videodub:${widget.projectId}'))
        .valueOrNull;
    bool covered = false;
    if (clips != null) {
      for (final c in clips) {
        if (c.laneIndex != DubLanes.a1) continue;
        final end = c.startTimeMs + ((c.durationSec ?? 0) * 1000).round();
        if (ms >= c.startTimeMs && ms < end) {
          covered = true;
          break;
        }
      }
    }
    if (covered == _a1Covers) return;
    _a1Covers = covered;
    final target = (_muteVideoAudio || !covered) ? 0.0 : 100.0;
    _player.setVolume(target);
  }

  /// Called every video position tick. Two concerns:
  ///   1. Cue-synced dub audio (A2): if the active TTS cue changed, stop
  ///      the current dub audio and start the new cue at the right offset.
  ///   2. A1-gated video audio: V1's own audio only plays when an A1
  ///      clip covers the current ms. Deleting an A1 clip silences V1's
  ///      audio in that window; splitting an A1 clip later will create
  ///      gaps naturally.
  Future<void> _onVideoTick(Duration pos) async {
    if (_ticking) return;
    _ticking = true;
    try {
      final ms = pos.inMilliseconds;
      _applyA1Gating(ms);

      final cues = ref
          .read(subtitleCuesStreamProvider(widget.projectId))
          .valueOrNull;
      if (cues == null || cues.isEmpty) return;

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
        await _cuePlayer.open(Media(active.audioPath!), play: false);
        if (offsetMs > 50) {
          await _cuePlayer.seek(Duration(milliseconds: offsetMs));
        }
        await _cuePlayer.play();
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
    final bankMembers =
        membersAsync.valueOrNull ?? const <db.VoiceBankMember>[];
    final bankAssets = bankMembers
        .map((m) => assetMap[m.voiceAssetId])
        .whereType<db.VoiceAsset>()
        .toList();

    final cues = cuesAsync.valueOrNull ?? const <db.SubtitleCue>[];
    final clipsAsync = ref.watch(
      timelineClipsStreamProvider('videodub:${widget.projectId}'),
    );
    final clips = clipsAsync.valueOrNull ?? const <db.TimelineClip>[];
    final ffmpegAvailable = ref
        .watch(ffmpegAvailabilityProvider)
        .maybeWhen(data: (v) => v, orElse: () => false);

    return Column(
      children: [
        _buildBar(project, bankAssets.length),
        const Divider(height: 1),
        Expanded(
          child: HorizontalResizableSplitPane(
            initialLeftFraction: 0.74,
            minPaneWidth: 280,
            left: VerticalResizableSplitPane(
              initialTopFraction: 0.7,
              minPaneHeight: 160,
              top: Column(
                children: [
                  Expanded(child: _buildVideoSurface(project)),
                  const Divider(height: 1),
                  SizedBox(
                    height: 64,
                    child: AnimatedBuilder(
                      animation: _playbackTimelineListenable,
                      builder: (context, _) => _buildTransport(project),
                    ),
                  ),
                ],
              ),
              bottom: AnimatedBuilder(
                animation: _playbackTimelineListenable,
                builder: (context, _) => VideoDubTimeline(
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
                    await _player.seek(Duration(milliseconds: cue.startMs));
                  },
                  onTapClip: (clip) async {
                    setState(() {
                      _selectedClipId = clip.id;
                      _selectedCueId = null;
                    });
                    await _player.seek(
                      Duration(milliseconds: clip.startTimeMs),
                    );
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
                    _markDirty();
                  },
                  onImport: (kind) => _importMedia(project, kind, clips),
                  onMoveCue: (cue, newStartMs) => _moveCueTo(cue, newStartMs),
                  v1Occupied: clips.any((c) => c.laneIndex == DubLanes.v1),
                  a1Muted: _muteVideoAudio,
                  onToggleA1Mute: () async {
                    setState(() => _muteVideoAudio = !_muteVideoAudio);
                    _a1Covers = null;
                    _applyA1Gating(_position.inMilliseconds);
                  },
                ),
              ),
            ),
            right: _buildSubtitlePanel(project, cues, bankAssets, assetMap),
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
            onPressed: () => _back(project),
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.movie_filter_rounded,
            color: AppTheme.accentColor,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _dirty ? '• ${project.name}' : project.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDim,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$voiceCount voices',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _exporting ? null : () => _exportAudio(project),
            icon: _exporting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.audiotrack_rounded, size: 16),
            label: const Text('Export Audio'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: project.videoPath == null || _exporting
                ? null
                : () => _exportVideo(project),
            icon: _exporting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download_outlined, size: 16),
            label: Text(_exporting ? 'Exporting…' : 'Export Video'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _save(project),
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
              Icon(
                Icons.movie_outlined,
                size: 56,
                color: Colors.white.withValues(alpha: 0.25),
              ),
              const SizedBox(height: 12),
              Text(
                'No video loaded',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Import a video onto the V1 track from the timeline.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      color: Colors.black,
      child: ExcludeSemantics(
        child: Video(controller: _controller, controls: NoVideoControls),
      ),
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
    return ExcludeSemantics(
      child: Container(
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
              icon: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatDuration(_position),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
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
            Text(
              _formatDuration(_duration),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
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
                  // Invalidate the A1-gating latch so the next tick (or an
                  // immediate re-apply while paused) picks up the new state.
                  _a1Covers = null;
                  _applyA1Gating(_position.inMilliseconds);
                },
              ),
            ),
            Tooltip(
              message: _syncDub ? 'Dub playback synced' : 'Dub playback off',
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
          // Header: cue-bar actions, ordered (left → right):
          //   • Add cue (one-off)
          //   • Add Subtitles (bulk SRT/LRC import)
          //   • Export Subtitles (per-cue TTS audio + SRT folder)
          //   • Clear (destructive, last by convention)
          // Top bar carries only the project-wide Export Audio / Export
          // Video / Save buttons.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                const Text(
                  'Subtitles',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Add cue',
                  onPressed: () => _addCueDialog(project, cues),
                  icon: const Icon(Icons.add, size: 18),
                ),
                IconButton(
                  tooltip: 'Add subtitles (import SRT/LRC)',
                  onPressed: () => _importSubtitles(project, cues),
                  icon: const Icon(Icons.subtitles_outlined, size: 18),
                ),
                if (cues.isNotEmpty)
                  IconButton(
                    tooltip: 'Export subtitles + Single TTS audio',
                    onPressed: _exportingSubtitles
                        ? null
                        : () => _exportSubtitlesAndTts(project, cues),
                    icon: _exportingSubtitles
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.queue_music_rounded, size: 18),
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
                          Icon(
                            Icons.subtitles_off_outlined,
                            size: 42,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
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
                      horizontal: 8,
                      vertical: 6,
                    ),
                    itemCount: cues.length,
                    itemBuilder: (_, i) {
                      final cue = cues[i];
                      return CueCard(
                        key: ValueKey(cue.id),
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
                            Duration(milliseconds: cue.startMs),
                          );
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
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: cues.isEmpty || _syncingCueLengths
                      ? null
                      : () => _syncCueLengthsToAudio(cues),
                  icon: _syncingCueLengths
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_alt_rounded, size: 16),
                  label: const Text('Sync cue lengths to TTS'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed:
                      cues.isEmpty || _generatingAll || bankAssets.isEmpty
                      ? null
                      : () => _generateAll(project, cues, bankAssets),
                  icon: _generatingAll
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Generate All'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────── Actions ─────────────────

  Future<double?> _probeMediaDuration(String path) async {
    final ffmpeg = ref.read(ffmpegServiceProvider);
    final viaFfmpeg = await ffmpeg.probeDurationSeconds(path);
    if (viaFfmpeg != null && viaFfmpeg > 0) return viaFfmpeg;

    final probe = Player();
    try {
      await probe.open(Media(path), play: false);
      final duration = await probe.stream.duration
          .firstWhere((d) => d > Duration.zero)
          .timeout(const Duration(seconds: 2), onTimeout: () => Duration.zero);
      return duration > Duration.zero ? duration.inMilliseconds / 1000.0 : null;
    } catch (_) {
      return null;
    } finally {
      await probe.dispose();
    }
  }

  /// Import video, image, or audio onto the multi-track timeline.
  /// Files are copied into `{voiceAssetRoot}/video_dub/{slug}/assets/`
  /// and registered as TimelineClips under `projectType='videodub'`.
  /// Start time = end of the last clip on the same lane (stacked append).
  /// Duration is probed via ffprobe first, then media_kit as a local fallback;
  /// image clips default to 3 s so they have something visible until stretched.
  /// Premiere-style import: references the source file in place (no
  /// copy into the project folder). The DB row stores the absolute path;
  /// a missing source later lights up as a red "missing" clip.
  ///
  /// A `video` import inserts **two** linked rows — V1 (video) + A1
  /// (video-audio) — sharing a `linkGroupId` so subsequent drag/trim
  /// work can move them in lock-step.
  Future<void> _importMedia(
    db.VideoDubProject project,
    DubImportKind kind,
    List<db.TimelineClip> existing,
  ) async {
    // Single-video constraint: refuse a second V1 import. The toolbar
    // disables the button too, but guard here in case it's invoked
    // programmatically.
    if (kind == DubImportKind.video &&
        existing.any((c) => c.laneIndex == DubLanes.v1)) {
      _snack('Delete the V1 clip first — only one source video is allowed');
      return;
    }

    final typeForPicker = switch (kind) {
      DubImportKind.video => FileType.video,
      DubImportKind.audio => FileType.audio,
    };
    final picked = await FilePicker.platform.pickFiles(
      type: typeForPicker,
      allowMultiple: false,
    );
    final src = picked?.files.single.path;
    if (src == null) return;
    if (!await File(src).exists()) return;

    final base = p.basenameWithoutExtension(src);
    double? duration;
    switch (kind) {
      case DubImportKind.video:
        duration = await _probeMediaDuration(src);
        break;
      case DubImportKind.audio:
        duration = await _probeMediaDuration(src);
        break;
    }

    final assignment = laneAndSourceForImport(kind);

    // Stack append on the target lane: start at the end of the last clip
    // already on it, so successive imports don't stack on top of each other.
    var startMs = 0;
    for (final c in existing) {
      if (c.laneIndex != assignment.lane) continue;
      final end = c.startTimeMs + ((c.durationSec ?? 0) * 1000).round();
      if (end > startMs) startMs = end;
    }

    final database = ref.read(databaseProvider);
    final uuid = const Uuid();
    _markDirty();

    if (kind == DubImportKind.video) {
      final linkId = uuid.v4();
      await database.insertTimelineClip(
        makeDubClipCompanion(
          id: uuid.v4(),
          projectId: project.id,
          lane: DubLanes.v1,
          startTimeMs: startMs,
          sourceType: 'video',
          audioPath: src,
          label: base,
          durationSec: duration,
          linkGroupId: linkId,
        ),
      );
      await database.insertTimelineClip(
        makeDubClipCompanion(
          id: uuid.v4(),
          projectId: project.id,
          lane: DubLanes.a1,
          startTimeMs: startMs,
          sourceType: 'video-audio',
          audioPath: src,
          label: base,
          durationSec: duration,
          linkGroupId: linkId,
        ),
      );
      // Promote the imported clip to the active video for the central
      // surface. Without this the clip lands on V1 but the player has
      // nothing to render, so the timeline appears wired up to nothing.
      await database.updateVideoDubProject(
        project.copyWith(videoPath: Value(src), updatedAt: DateTime.now()),
      );
    } else {
      await database.insertTimelineClip(
        makeDubClipCompanion(
          id: uuid.v4(),
          projectId: project.id,
          lane: assignment.lane,
          startTimeMs: startMs,
          sourceType: assignment.sourceType,
          audioPath: src,
          label: base,
          durationSec: duration,
        ),
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Imported "$base"')));
    }
  }

  Future<void> _exportVideo(db.VideoDubProject project) async {
    final cues =
        ref.read(subtitleCuesStreamProvider(widget.projectId)).valueOrNull ??
        const <db.SubtitleCue>[];
    final clips =
        ref
            .read(timelineClipsStreamProvider('videodub:${widget.projectId}'))
            .valueOrNull ??
        const <db.TimelineClip>[];
    setState(() => _exporting = true);
    try {
      await exportVideoDubVideo(
        context: context,
        ref: ref,
        project: project,
        cues: cues,
        clips: clips,
        muteVideoAudio: _muteVideoAudio,
        playerDuration: _duration,
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportAudio(db.VideoDubProject project) async {
    final cues =
        ref.read(subtitleCuesStreamProvider(widget.projectId)).valueOrNull ??
        const <db.SubtitleCue>[];
    final clips =
        ref
            .read(timelineClipsStreamProvider('videodub:${widget.projectId}'))
            .valueOrNull ??
        const <db.TimelineClip>[];
    setState(() => _exporting = true);
    try {
      await exportVideoDubAudio(
        context: context,
        ref: ref,
        project: project,
        cues: cues,
        clips: clips,
        muteVideoAudio: _muteVideoAudio,
        playerDuration: _duration,
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportSubtitlesAndTts(
    db.VideoDubProject project,
    List<db.SubtitleCue> cues,
  ) async {
    setState(() => _exportingSubtitles = true);
    try {
      await exportVideoDubSubtitlesAndTts(
        context: context,
        project: project,
        cues: cues,
      );
    } finally {
      if (mounted) setState(() => _exportingSubtitles = false);
    }
  }

  /// Re-fit each cue's `endMs` so the on-screen subtitle length matches
  /// its generated TTS audio length. Skips cues that haven't been
  /// generated yet (no `audioPath` / `audioDuration`). Preserves
  /// `startMs` — only the end edge moves. The user can fix overlap with
  /// a follow-up drag if needed.
  Future<void> _syncCueLengthsToAudio(List<db.SubtitleCue> cues) async {
    setState(() => _syncingCueLengths = true);
    final db_ = ref.read(databaseProvider);
    var adjusted = 0;
    var skipped = 0;
    try {
      for (final cue in cues) {
        final dur = cue.audioDuration;
        if (dur == null || dur <= 0) {
          skipped++;
          continue;
        }
        final newEnd = cue.startMs + (dur * 1000).round();
        if (newEnd == cue.endMs) continue;
        await db_.updateSubtitleCue(cue.copyWith(endMs: newEnd));
        adjusted++;
      }
      if (adjusted > 0) _markDirty();
      if (mounted) {
        _snack(
          'Synced $adjusted cue(s) to audio length'
          '${skipped > 0 ? ' ($skipped without audio skipped)' : ''}',
        );
      }
    } finally {
      if (mounted) setState(() => _syncingCueLengths = false);
    }
  }

  /// Persist a cue-block drag from the timeline. Duration is preserved;
  /// only the start (and matching end) shift.
  Future<void> _moveCueTo(db.SubtitleCue cue, int newStartMs) async {
    final clamped = newStartMs < 0 ? 0 : newStartMs;
    final dur = cue.endMs - cue.startMs;
    await ref
        .read(databaseProvider)
        .updateSubtitleCue(
          cue.copyWith(startMs: clamped, endMs: clamped + dur),
        );
    _markDirty();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Parse failed: $e')));
      }
      return;
    }
    if (parsed.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No cues found in file')));
      }
      return;
    }

    if (!mounted) return;
    final choice = await showImportSubtitlesDialog(
      context: context,
      cueCount: parsed.length,
      existingCount: existing.length,
      initialAutoTts: _autoTtsAfterImport,
      initialAutoSync: _autoSyncAfterImport,
    );
    if (choice == null) return;

    // Persist switch state across imports in this session.
    _autoTtsAfterImport = choice.autoTts;
    _autoSyncAfterImport = choice.autoSync;

    final database = ref.read(databaseProvider);
    _markDirty();
    int nextOrder = 0;
    if (choice.replace) {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Imported ${parsed.length} cues')));
    }

    // Auto-flow: re-read cues from the database (the freshly-inserted
    // rows aren't in `existing`), then optionally generate then sync.
    if (!choice.autoTts && !choice.autoSync) return;
    final fresh = await database.getSubtitleCues(project.id);
    if (choice.autoTts) {
      final bankAssets = await _resolveBankAssets(project.bankId);
      if (bankAssets.isEmpty) {
        if (mounted) {
          _snack('Auto-TTS skipped — bank has no voices');
        }
      } else {
        await _runGenerateAll(project, fresh, bankAssets, forceRegen: false);
      }
    }
    if (choice.autoSync) {
      // Re-read again post-generation so audioDuration is populated.
      final afterGen = await database.getSubtitleCues(project.id);
      await _syncCueLengthsToAudio(afterGen);
    }
  }

  /// Resolve the [bankId]'s voice assets the same way the editor build
  /// does — needed for the auto-TTS path because that fires from inside
  /// `_importSubtitles`, not from the build closure.
  Future<List<db.VoiceAsset>> _resolveBankAssets(String bankId) async {
    final db_ = ref.read(databaseProvider);
    final members = await db_.getBankMembers(bankId);
    final allAssets = await db_.getAllVoiceAssets();
    final assetMap = {for (final a in allAssets) a.id: a};
    return members
        .map((m) => assetMap[m.voiceAssetId])
        .whereType<db.VoiceAsset>()
        .toList();
  }

  Future<void> _addCueDialog(
    db.VideoDubProject project,
    List<db.SubtitleCue> existing,
  ) async {
    // Resolve the bank's voices straight from the DB — works even on
    // first build before the stream provider has had a chance to warm.
    final bankAssets = await _resolveBankAssets(project.bankId);
    // Default to the first voice if there is one, mirroring what the
    // SRT-import path does.
    final initialVoiceId = bankAssets.isEmpty ? null : bankAssets.first.id;

    if (!mounted) return;
    final result = await showCueEditDialog(
      context: context,
      initialStartMs: _position.inMilliseconds,
      initialEndMs: _position.inMilliseconds + 3000,
      initialText: '',
      title: 'Add cue',
      showAutoSwitches: true,
      initialAutoTts: _autoTtsAfterImport,
      initialAutoSync: _autoSyncAfterImport,
      voiceAssets: bankAssets,
      initialVoiceId: initialVoiceId,
    );
    if (result == null) return;

    // Persist the user's choice for next time.
    _autoTtsAfterImport = result.autoTts;
    _autoSyncAfterImport = result.autoSync;

    final nextOrder = existing.isEmpty
        ? 0
        : (existing.map((c) => c.orderIndex).reduce((a, b) => a > b ? a : b) +
              1);
    // Prefer the dropdown choice; fall back to the first bank voice if
    // somehow nothing came back.
    final voiceForCue = result.voiceAssetId ?? initialVoiceId;
    final cueId = const Uuid().v4();
    final database = ref.read(databaseProvider);
    await database.insertSubtitleCue(
      db.SubtitleCuesCompanion(
        id: Value(cueId),
        projectId: Value(project.id),
        orderIndex: Value(nextOrder),
        startMs: Value(result.startMs),
        endMs: Value(result.endMs),
        cueText: Value(result.text),
        voiceAssetId: Value(voiceForCue),
      ),
    );
    _markDirty();

    if (!result.autoTts && !result.autoSync) return;

    // Re-read the row from the DB so we have a real `SubtitleCue` (not
    // a companion) to feed `_generateOne`. Same pattern the bulk-import
    // auto-flow uses.
    final allCues = await database.getSubtitleCues(project.id);
    final fresh = allCues.where((c) => c.id == cueId).firstOrNull;
    if (fresh == null) return;

    if (result.autoTts) {
      if (fresh.voiceAssetId == null || bankAssets.isEmpty) {
        if (mounted) _snack('Auto-TTS skipped — bank has no voices');
      } else {
        // Reuse the bank list we resolved before opening the dialog —
        // no second round-trip to the DB.
        await _generateOne(project, fresh, bankAssets);
      }
    }

    if (result.autoSync) {
      // _generateOne writes audioDuration on success — re-read so we
      // pick that up before snapping endMs.
      final afterGen = await database.getSubtitleCues(project.id);
      final updated = afterGen.where((c) => c.id == cueId).firstOrNull;
      if (updated != null && updated.audioDuration != null) {
        final newEnd =
            updated.startMs + (updated.audioDuration! * 1000).round();
        if (newEnd != updated.endMs) {
          await database.updateSubtitleCue(updated.copyWith(endMs: newEnd));
        }
      }
    }
  }

  Future<void> _editCueDialog(db.SubtitleCue cue) async {
    final result = await showCueEditDialog(
      context: context,
      initialStartMs: cue.startMs,
      initialEndMs: cue.endMs,
      initialText: cue.cueText,
      title: 'Edit cue',
    );
    if (result == null) return;
    _markDirty();
    await ref
        .read(databaseProvider)
        .updateSubtitleCue(
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

  Future<void> _confirmClearCues(db.VideoDubProject project) async {
    final confirmed = await showClearCuesConfirmDialog(context);
    if (confirmed) {
      await ref.read(databaseProvider).clearSubtitleCues(project.id);
      _markDirty();
    }
  }

  Future<void> _deleteCue(db.SubtitleCue cue) async {
    if (_selectedCueId == cue.id) {
      setState(() => _selectedCueId = null);
    }
    await ref.read(databaseProvider).deleteSubtitleCue(cue.id);
    _markDirty();
  }

  void _updateCueVoice(db.SubtitleCue cue, String? voiceId) {
    ref
        .read(databaseProvider)
        .updateSubtitleCue(cue.copyWith(voiceAssetId: Value(voiceId)));
    _markDirty();
  }

  Future<void> _previewCue(db.SubtitleCue cue) async {
    if (cue.audioPath == null) return;
    if (_previewCueId == cue.id) {
      await _previewPlayer.stop();
      setState(() => _previewCueId = null);
      return;
    }
    setState(() => _previewCueId = cue.id);
    await _previewPlayer.open(Media(cue.audioPath!), play: true);
  }

  /// Generate TTS for every cue. By default skips cues that already
  /// have audio; if any do, prompts the user with a Skip / Regenerate
  /// All / Cancel choice so the same button works for both first-pass
  /// generation and after-edit refresh.
  Future<void> _generateAll(
    db.VideoDubProject project,
    List<db.SubtitleCue> cues,
    List<db.VoiceAsset> bankAssets,
  ) async {
    final pending = cues
        .where((c) => c.voiceAssetId != null && c.audioPath == null)
        .length;
    final alreadyDone = cues
        .where((c) => c.voiceAssetId != null && c.audioPath != null)
        .length;
    final missingVoice = cues.where((c) => c.voiceAssetId == null).length;

    bool forceRegen = false;
    if (alreadyDone > 0) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Generate all cues'),
          content: Text(
            '$alreadyDone cue(s) already have audio. '
            '$pending pending. '
            '${missingVoice > 0 ? '$missingVoice without a voice will be skipped. ' : ''}'
            'Regenerate the existing ones too, or only fill in the gaps?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'skip'),
              child: const Text('Only pending'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'regen'),
              child: const Text('Regenerate all'),
            ),
          ],
        ),
      );
      if (choice == null || choice == 'cancel') return;
      forceRegen = choice == 'regen';
    } else if (pending == 0) {
      _snack('No cues to generate — assign a voice first');
      return;
    }

    await _runGenerateAll(project, cues, bankAssets, forceRegen: forceRegen);
  }

  /// Generation loop without the confirm dialog. Used by both the
  /// "Generate All" button (after its confirm) and the auto-TTS path
  /// after import. Reports a snackbar with done/failed counts.
  Future<void> _runGenerateAll(
    db.VideoDubProject project,
    List<db.SubtitleCue> cues,
    List<db.VoiceAsset> bankAssets, {
    required bool forceRegen,
  }) async {
    setState(() => _generatingAll = true);
    var done = 0;
    var failed = 0;
    try {
      for (final cue in cues) {
        if (cue.voiceAssetId == null) continue;
        if (!forceRegen && cue.audioPath != null) continue;
        try {
          await _generateOne(project, cue, bankAssets);
          done++;
        } catch (_) {
          failed++;
        }
      }
    } finally {
      if (mounted) setState(() => _generatingAll = false);
    }
    if (done > 0) _markDirty();
    if (mounted) {
      _snack(
        'Generated $done cue(s)'
        '${failed > 0 ? ', $failed failed' : ''}',
      );
    }
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
    // ttsProvidersStreamProvider isn't watched in this screen, so the
    // first read from valueOrNull is `null` until the stream warms up
    // — which is what made the auto-TTS path appear to "only work after
    // a manual generate". Read straight from the DB instead.
    final database = ref.read(databaseProvider);
    final providers = await database.getAllProviders();
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

    setState(() => _generatingCueIds.add(cue.id));
    try {
      final adapter = createAdapter(provider, modelName: asset.modelName);
      final result = await adapter.synthesize(
        TtsRequest(
          text: cue.cueText,
          voice: asset.presetVoiceName ?? asset.name,
          speed: asset.speed,
          textLang: provider.adapterType == 'gptSovits'
              ? asset.modelName
              : null,
          presetVoiceName: asset.presetVoiceName,
          voiceInstruction: asset.voiceInstruction,
          refAudioPath: asset.refAudioPath,
          promptText: asset.promptText,
          promptLang: asset.promptLang,
        ),
      );
      final ext = result.contentType.contains('wav') ? '.wav' : '.mp3';
      final filePath = PathService.dedupeFilename(
        outDir,
        'cue_${cue.orderIndex}_${PathService.formatTimestamp()}',
        ext,
      );
      await File(filePath).writeAsBytes(result.audioBytes);
      final durationSec = await _probeMediaDuration(filePath);
      await database.updateSubtitleCue(
        cue.copyWith(
          audioPath: Value(filePath),
          audioDuration: Value(durationSec),
          error: const Value(null),
        ),
      );
      _markDirty();
    } catch (e) {
      await database.updateSubtitleCue(
        cue.copyWith(error: Value(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _generatingCueIds.remove(cue.id));
    }
  }

  /// Save bumps `updatedAt` so the project sorts to the top of the
  /// list, clears the dirty flag, and shows a confirmation snackbar.
  /// Stays in the editor — leaving is a separate action via the back
  /// arrow.
  Future<void> _save(db.VideoDubProject project) async {
    await ref
        .read(databaseProvider)
        .updateVideoDubProject(project.copyWith(updatedAt: DateTime.now()));
    if (!mounted) return;
    setState(() => _dirty = false);
    _snack('Saved');
  }

  /// Handle the back arrow. If there's unsaved work, prompt with
  /// Save & Exit / Discard / Cancel before leaving — otherwise just
  /// close. ("Discard" is a slight misnomer since edits are written to
  /// the DB immediately; it really just means "don't bump updatedAt".)
  Future<void> _back(db.VideoDubProject project) async {
    if (!_dirty) {
      widget.onClose();
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text(
          'You have unsaved changes in this project. Save before leaving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text("Don't save"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Save & Exit'),
          ),
        ],
      ),
    );
    if (choice == 'save') {
      await _save(project);
      if (mounted) widget.onClose();
    } else if (choice == 'discard') {
      if (mounted) widget.onClose();
    }
    // 'cancel' / null: stay in the editor.
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}
