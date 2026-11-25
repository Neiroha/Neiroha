part of '../../screens/voice_asset_screen.dart';

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
          SnackBar(
            content: Text(
              AppLocalizations.of(context).uiAudioFileMissingOnDisk,
            ),
          ),
        );
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
    final result = await pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;
    final src = File(result.files.single.path!);
    final avatarDir = await PathService.instance.avatarsDir();
    final ext = p.extension(src.path).isEmpty ? '.png' : p.extension(src.path);
    final dst = p.join(avatarDir.path, '${widget.track.id}$ext');
    await src.copy(dst);
    await ref
        .read(databaseProvider)
        .updateAudioTrack(widget.track.copyWith(avatarPath: Value(dst)));
  }

  Future<void> _save() async {
    await ref
        .read(databaseProvider)
        .updateAudioTrack(
          widget.track.copyWith(
            name: _nameCtrl.text.trim().isEmpty
                ? widget.track.name
                : _nameCtrl.text.trim(),
            description: Value(
              _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
            ),
            refText: Value(
              _refTextCtrl.text.trim().isEmpty
                  ? null
                  : _refTextCtrl.text.trim(),
            ),
            refLang: Value(
              _refLangCtrl.text.trim().isEmpty
                  ? null
                  : _refLangCtrl.text.trim(),
            ),
          ),
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).uiSaved),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _trim() async {
    final track = widget.track;
    final duration = track.durationSec;
    if (duration == null || duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).uiAudioDurationUnknownCannotTrim,
          ),
        ),
      );
      return;
    }
    if (!await File(track.audioPath).exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).uiAudioFileMissingOnDisk),
        ),
      );
      return;
    }
    // Stop any inline preview so the trim dialog's player has exclusive
    // access to the file.
    await ref.read(playbackNotifierProvider.notifier).stop();
    if (!mounted) return;

    await applyTrim(
      context: context,
      ref: ref,
      audioPath: track.audioPath,
      currentDurationSec: duration,
      onSaved:
          ({
            required String trimmedPath,
            required double newDurationSec,
            required bool replaceOriginal,
          }) async {
            final database = ref.read(databaseProvider);
            if (replaceOriginal) {
              await database.updateAudioTrack(
                track.copyWith(
                  audioPath: trimmedPath,
                  durationSec: Value(newDurationSec),
                ),
              );
            } else {
              final id = const Uuid().v4();
              await database.insertAudioTrack(
                db.AudioTracksCompanion(
                  id: Value(id),
                  name: Value('${track.name} (trim)'),
                  audioPath: Value(trimmedPath),
                  durationSec: Value(newDurationSec),
                  sourceType: Value(track.sourceType),
                  description: Value(track.description),
                  refText: Value(track.refText),
                  refLang: Value(track.refLang),
                  createdAt: Value(DateTime.now()),
                ),
              );
              ref.read(_selectedTrackIdProvider.notifier).state = id;
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context).uiTrimApplied),
                  duration: Duration(seconds: 1),
                ),
              );
            }
          },
    );
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).uiDeleteAudioTrack),
        content: Text(
          AppLocalizations.of(context).uiWillBeRemoved(widget.track.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).uiCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context).uiDelete),
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
    final playback = ref.watch(
      playbackNotifierProvider.select(
        (state) => (audioPath: state.audioPath, isPlaying: state.isPlaying),
      ),
    );
    final isPlayingThis =
        playback.audioPath == widget.track.audioPath && playback.isPlaying;
    return Container(
      color: context.colors.panel,
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
                    size: 84,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.colors.panel,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          // Player row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: context.colors.raised,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _togglePlay,
                  icon: Icon(
                    isPlayingThis
                        ? Icons.stop_circle_rounded
                        : Icons.play_circle_rounded,
                  ),
                  color: AppTheme.accentColor,
                  iconSize: 32,
                ),
                SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.basename(widget.track.audioPath),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        _formatDuration(widget.track.durationSec),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.fg.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).uiName,
            ),
          ),
          SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).uiDescription,
            ),
            maxLines: 2,
          ),
          SizedBox(height: 12),
          ReferenceTextField(
            controller: _refTextCtrl,
            languageController: _refLangCtrl,
            audioPath: widget.track.audioPath,
          ),
          SizedBox(height: 12),
          TextField(
            controller: _refLangCtrl,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).uiReferenceLanguage,
              hintText: AppLocalizations.of(context).uiEGZhEnJa,
            ),
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: Text(AppLocalizations.of(context).uiSave),
                ),
              ),
              SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _trim,
                icon: const Icon(Icons.content_cut_rounded, size: 18),
                label: Text(AppLocalizations.of(context).uiTrim),
              ),
              SizedBox(width: 8),
              IconButton(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline_rounded),
                color: Colors.redAccent,
                tooltip: AppLocalizations.of(context).uiDelete,
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
            : context.colors.raised,
        border: Border.all(
          color: selected
              ? AppTheme.accentColor.withValues(alpha: 0.5)
              : Colors.transparent,
          width: 1,
        ),
        image: hasAvatar
            ? DecorationImage(
                image: FileImage(File(avatarPath!)),
                fit: BoxFit.cover,
              )
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
                      : context.fg.withValues(alpha: 0.6),
                ),
              ),
            ),
    );
  }
}
