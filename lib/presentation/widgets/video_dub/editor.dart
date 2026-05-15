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
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/actions/video_dub/exporter.dart';
import 'package:neiroha/presentation/navigation/app_navigation.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/resizable_split_pane.dart';
import 'package:neiroha/presentation/widgets/video_dub/cue_card.dart';
import 'package:neiroha/presentation/widgets/video_dub/cue_dialogs.dart';
import 'package:neiroha/presentation/widgets/video_dub/timeline.dart';
import 'package:neiroha/presentation/widgets/video_dub/tracks.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

part 'generation_actions.dart';
part 'media_actions.dart';
part 'subtitle_actions.dart';
part 'layout.dart';

class VideoDubEditor extends ConsumerStatefulWidget {
  final String projectId;
  final bool active;
  final VoidCallback onClose;

  const VideoDubEditor({
    super.key,
    required this.projectId,
    required this.active,
    required this.onClose,
  });

  @override
  ConsumerState<VideoDubEditor> createState() => _VideoDubEditorState();
}

class _VideoDubEditorState extends ConsumerState<VideoDubEditor> {
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

  void _updateState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
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

  @override
  void didUpdateWidget(covariant VideoDubEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active) {
      unawaited(_pauseForBackground());
    }
  }

  Future<void> _pauseForBackground() async {
    await _player.pause();
    await _cuePlayer.pause();
    await _previewPlayer.pause();
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
                    ref.read(settingsSectionProvider.notifier).state =
                        SettingsSection.media;
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
}
