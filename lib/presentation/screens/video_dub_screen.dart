import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/project_card_grid.dart';
import 'package:neiroha/presentation/widgets/resizable_split_pane.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:uuid/uuid.dart';

/// Video Dub — dub video with TTS generated from subtitle cues.
///
/// List mode: grid of project cards (searchable, sorted by most recent edit).
/// Editor mode: video surface (media_kit), timeline placeholder, subtitle
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
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _durationSub;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  String? _currentVideoPath;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);

    _positionSub = _player.stream.position.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _playingSub = _player.stream.playing.listen((p) {
      if (mounted) setState(() => _playing = p);
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

    return Column(
      children: [
        _buildBar(project),
        const Divider(height: 1),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: VerticalResizableSplitPane(
                  initialTopFraction: 0.72,
                  minPaneHeight: 120,
                  top: Column(
                    children: [
                      Expanded(child: _buildVideoSurface(project)),
                      const Divider(height: 1),
                      SizedBox(height: 64, child: _buildTransport(project)),
                    ],
                  ),
                  bottom: _buildTimelinePlaceholder(),
                ),
              ),
              const VerticalDivider(width: 1),
              SizedBox(
                width: 320,
                child: _buildSubtitlePanel(project, cuesAsync),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBar(db.VideoDubProject project) {
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
                ? () => _player.seek(Duration.zero)
                : null,
            icon: const Icon(Icons.skip_previous_rounded),
          ),
          IconButton(
            onPressed: canPlay
                ? () => _player.playOrPause()
                : null,
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
                    ? (v) =>
                        _player.seek(Duration(milliseconds: v.round()))
                    : null,
              ),
            ),
          ),
          Text(_formatDuration(_duration),
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTimelinePlaceholder() {
    return Container(
      color: AppTheme.surfaceDim,
      child: Center(
        child: Text('Timeline',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 13,
            )),
      ),
    );
  }

  Widget _buildSubtitlePanel(
    db.VideoDubProject project,
    AsyncValue<List<db.SubtitleCue>> cuesAsync,
  ) {
    return Container(
      color: AppTheme.surfaceDim,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                const Text('Subtitles',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  tooltip: 'Import SRT/LRC',
                  onPressed: null,
                  icon: const Icon(Icons.file_upload_outlined, size: 18),
                ),
                IconButton(
                  tooltip: 'Add cue',
                  onPressed: null,
                  icon: const Icon(Icons.add, size: 18),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: cuesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (cues) {
                if (cues.isEmpty) {
                  return Center(
                    child: Text('No cues',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 13,
                        )),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  itemCount: cues.length,
                  itemBuilder: (_, i) => _CueCard(cue: cues[i], index: i),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Generate All'),
            ),
          ),
        ],
      ),
    );
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

  void _close(db.VideoDubProject project) {
    // Video path + cue edits persist live, so Save here just bumps updatedAt
    // (so the card list sorts the edited project to the top) and returns.
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
}

class _CueCard extends StatelessWidget {
  final db.SubtitleCue cue;
  final int index;
  const _CueCard({required this.cue, required this.index});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('#${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                    )),
                const SizedBox(width: 8),
                Text(
                  '${_ms(cue.startMs)} → ${_ms(cue.endMs)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(cue.cueText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
          ],
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
