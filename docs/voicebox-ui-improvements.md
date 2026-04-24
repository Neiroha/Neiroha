# Voicebox UI Improvements — Implementation Plan

**Date:** 2026-04-16  
**Reference:** [temp/voicebox](../temp/voicebox) — React/TypeScript/Zustand desktop TTS app  
**Goal:** Two features inspired by Voicebox:
1. Persistent bottom audio player bar (global, visible across all screens)
2. PR-like story editor (Dialog TTS upgraded with drag reorder + bottom track timeline)

---

## Context: What Was Analyzed

Voicebox (cloned to `temp/voicebox/`) is a React + Zustand + WaveSurfer.js TTS workstation.  
Two features stand out as missing in Q-Vox-Lab:

| Feature | Voicebox | Q-Vox-Lab (current) |
|---|---|---|
| Global bottom audio player | Fixed bottom bar, waveform viz | Per-screen, no persistent UI |
| Story editor (PR-like) | Chat list + visual timeline editor | Dialog TTS — rigid list, no timeline |
| Waveform display | WaveSurfer.js per clip | None |
| Drag reorder | dnd-kit | `orderIndex` in DB but no reorder UI |

---

## Feature 1: Global Bottom Audio Player

### Architecture Change Required

Current: each screen subscribes to the shared `audioPlayerProvider` and manages its own UI state.  
Target: single `PlaybackNotifier` (Riverpod) + `PersistentAudioBar` widget in app shell.

### Step 1 — New provider: `lib/providers/playback_provider.dart`

```dart
import 'package:audioplayers/audioplayers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'playback_provider.g.dart';

class PlaybackState {
  final String? audioPath;
  final String? title;
  final String? subtitle;   // voice character name
  final bool isPlaying;
  final Duration position;
  final Duration duration;

  const PlaybackState({
    this.audioPath,
    this.title,
    this.subtitle,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  PlaybackState copyWith({...}) => PlaybackState(...);
}

@riverpod
class PlaybackNotifier extends _$PlaybackNotifier {
  late AudioPlayer _player;

  @override
  PlaybackState build() {
    _player = ref.read(audioPlayerProvider);
    _player.onPlayerComplete.listen((_) {
      state = state.copyWith(isPlaying: false, position: Duration.zero);
    });
    _player.onPositionChanged.listen((pos) {
      state = state.copyWith(position: pos);
    });
    _player.onDurationChanged.listen((dur) {
      state = state.copyWith(duration: dur);
    });
    return const PlaybackState();
  }

  Future<void> load(String audioPath, String title, {String? subtitle}) async {
    state = state.copyWith(audioPath: audioPath, title: title, subtitle: subtitle);
    await _player.play(DeviceFileSource(audioPath));
    state = state.copyWith(isPlaying: true);
  }

  Future<void> togglePlay() async {
    if (state.isPlaying) {
      await _player.pause();
      state = state.copyWith(isPlaying: false);
    } else {
      await _player.resume();
      state = state.copyWith(isPlaying: true);
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
    state = state.copyWith(position: position);
  }

  /// Play a sequence of audio files (for Dialog TTS "play from here")
  Future<void> playSequenceFrom(
    List<({String audioPath, String title, String? subtitle})> items,
    {int startIndex = 0}
  ) async {
    // Iterate items[startIndex..] sequentially
    for (int i = startIndex; i < items.length; i++) {
      final item = items[i];
      if (!mounted) return;
      await load(item.audioPath, item.title, subtitle: item.subtitle);
      // Wait for completion before advancing
      await _player.onPlayerComplete.first;
    }
  }
}
```

### Step 2 — New widget: `lib/presentation/widgets/persistent_audio_bar.dart`

```dart
import 'package:audio_waveforms/audio_waveforms.dart';

class PersistentAudioBar extends ConsumerStatefulWidget {
  const PersistentAudioBar({super.key});
  @override
  ConsumerState<PersistentAudioBar> createState() => _PersistentAudioBarState();
}

class _PersistentAudioBarState extends ConsumerState<PersistentAudioBar> {
  late PlayerController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = PlayerController();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playbackNotifierProvider);
    if (state.audioPath == null) return const SizedBox.shrink();

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: const Border(top: BorderSide(color: Colors.white12)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        // Voice avatar (CircleAvatar with first letter of subtitle)
        CircleAvatar(radius: 16, child: Text(state.subtitle?[0] ?? '?')),
        const SizedBox(width: 12),
        // Title + subtitle
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(state.title ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
              if (state.subtitle != null)
                Text(state.subtitle!, style: const TextStyle(fontSize: 11, color: Colors.white54)),
            ],
          ),
        ),
        // Waveform visualization
        Expanded(
          flex: 3,
          child: AudioFileWaveforms(
            playerController: _waveController,
            size: const Size(double.infinity, 40),
            waveformType: WaveformType.fitWidth,
            playerWaveStyle: const PlayerWaveStyle(
              fixedWaveColor: Colors.white24,
              liveWaveColor: Colors.amber,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Time display
        Text(
          '${_fmt(state.position)} / ${_fmt(state.duration)}',
          style: const TextStyle(fontSize: 11, color: Colors.white54),
        ),
        const SizedBox(width: 8),
        // Play/pause
        IconButton(
          icon: Icon(state.isPlaying ? Icons.pause_circle : Icons.play_circle),
          iconSize: 32,
          onPressed: () => ref.read(playbackNotifierProvider.notifier).togglePlay(),
        ),
      ]),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
```

### Step 3 — Wire into `lib/presentation/screens/app_shell.dart`

Find the `Scaffold` in `app_shell.dart` and add `bottomNavigationBar`:

```dart
Scaffold(
  body: Row(children: [
    _buildNavRail(context, ref),
    Expanded(child: _buildScreen(selectedTab)),
  ]),
  bottomNavigationBar: const PersistentAudioBar(),  // ADD THIS
)
```

### Step 4 — Migrate all screens

Replace all per-screen `_player.play(...)` calls with:
```dart
ref.read(playbackNotifierProvider.notifier).load(audioPath, title, subtitle: characterName);
```

Remove per-screen `_completeSub` and `_positionSub` subscriptions — the global notifier handles all of this now.

### Package to add

```yaml
# pubspec.yaml
dependencies:
  audio_waveforms: ^1.0.5   # Waveform viz + PlayerController
```

---

## Feature 2: PR-like Story Editor (Dialog TTS Upgrade)

The Dialog TTS screen (`lib/presentation/screens/dialog_tts_screen.dart`) already has:
- Project list (left panel)
- Chat-like line items with voice assignment (right panel)
- Per-line generation and playback

### What to add:

#### A. Drag-to-reorder the chat list

The DB already has `orderIndex` on `DialogTtsLine`. Just wrap the `ListView` in a `ReorderableListView`:

```dart
ReorderableListView.builder(
  onReorder: (oldIndex, newIndex) async {
    // Adjust for ReorderableListView's off-by-one on downward moves
    if (newIndex > oldIndex) newIndex--;
    final db = ref.read(databaseProvider);
    await db.reorderDialogLine(projectId, oldIndex, newIndex);
  },
  itemCount: lines.length,
  itemBuilder: (ctx, i) => DialogLineCard(
    key: ValueKey(lines[i].id),
    line: lines[i],
  ),
)
```

Add `reorderDialogLine` to the database DAO — swap `orderIndex` values for affected rows.

#### B. "Play from here" button on each line

In `DialogLineCard` (or wherever lines are rendered), add:

```dart
IconButton(
  icon: const Icon(Icons.play_circle_outline, size: 18),
  tooltip: 'Play from here',
  onPressed: line.audioPath == null ? null : () {
    final items = lines
      .skip(lineIndex)
      .where((l) => l.audioPath != null)
      .map((l) => (
        audioPath: l.audioPath!,
        title: l.lineText,
        subtitle: l.voiceCharacterName,
      ))
      .toList();
    ref.read(playbackNotifierProvider.notifier).playSequenceFrom(items);
  },
)
```

#### C. DB schema change: add `startTimeMs` to `DialogTtsLine`

In `lib/data/database/tables.dart`, add to `DialogTtsLines`:

```dart
IntColumn get startTimeMs => integer().nullable()();
```

Bump schema version and compute `startTimeMs` when audio is generated:
```dart
// After generating line audio, sum durations of all prior lines
final priorDuration = lines
  .where((l) => l.orderIndex < currentLine.orderIndex)
  .fold(0.0, (sum, l) => sum + (l.audioDuration ?? 0));
await db.updateDialogLine(currentLine.copyWith(startTimeMs: (priorDuration * 1000).round()));
```

#### D. Bottom track timeline widget

Create `lib/presentation/widgets/story_track_editor.dart`:

```dart
class StoryTrackEditor extends ConsumerStatefulWidget {
  final List<DialogTtsLine> lines;
  const StoryTrackEditor({super.key, required this.lines});
}

class _StoryTrackEditorState extends ConsumerState<StoryTrackEditor> {
  double pixelsPerSecond = 50.0;
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackNotifierProvider);

    return Column(children: [
      // Toolbar
      Row(children: [
        const Text('Timeline', style: TextStyle(fontSize: 12, color: Colors.white54)),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.zoom_out, size: 16),
          onPressed: () => setState(() => pixelsPerSecond = (pixelsPerSecond / 1.5).clamp(10, 200)),
        ),
        IconButton(
          icon: const Icon(Icons.zoom_in, size: 16),
          onPressed: () => setState(() => pixelsPerSecond = (pixelsPerSecond * 1.5).clamp(10, 200)),
        ),
      ]),
      // Track area
      SizedBox(
        height: 100,
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: _totalWidth(),
            child: Stack(children: [
              // Time ruler (CustomPaint)
              Positioned.fill(
                child: CustomPaint(painter: _TimeRulerPainter(pixelsPerSecond: pixelsPerSecond)),
              ),
              // Clip tiles
              ...widget.lines
                .where((l) => l.audioPath != null && l.startTimeMs != null)
                .map((l) => Positioned(
                  top: 24,
                  left: l.startTimeMs! / 1000 * pixelsPerSecond,
                  width: (l.audioDuration ?? 1) * pixelsPerSecond,
                  height: 52,
                  child: _ClipTile(line: l),
                )),
              // Playhead
              Positioned(
                top: 0,
                left: playback.position.inMilliseconds / 1000 * pixelsPerSecond,
                child: Container(width: 2, height: 100, color: Colors.amber),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }

  double _totalWidth() {
    if (widget.lines.isEmpty) return 400;
    final lastLine = widget.lines
      .where((l) => l.startTimeMs != null && l.audioDuration != null)
      .fold<double>(0, (max, l) =>
        ((l.startTimeMs! / 1000) + l.audioDuration!).clamp(0, double.infinity) > max
          ? (l.startTimeMs! / 1000) + l.audioDuration!
          : max);
    return (lastLine * pixelsPerSecond) + 100;
  }
}

class _ClipTile extends ConsumerWidget {
  final DialogTtsLine line;
  const _ClipTile({required this.line});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackNotifierProvider);
    final isActive = playback.audioPath == line.audioPath;

    return GestureDetector(
      onTap: () => ref.read(playbackNotifierProvider.notifier)
        .load(line.audioPath!, line.lineText, subtitle: line.voiceCharacterName),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isActive ? Colors.amber.withOpacity(0.3) : Colors.white12,
          borderRadius: BorderRadius.circular(4),
          border: isActive ? Border.all(color: Colors.amber, width: 1.5) : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          line.lineText,
          style: const TextStyle(fontSize: 10),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ),
    );
  }
}

class _TimeRulerPainter extends CustomPainter {
  final double pixelsPerSecond;
  _TimeRulerPainter({required this.pixelsPerSecond});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white24..strokeWidth = 1;
    final textStyle = const TextStyle(color: Colors.white38, fontSize: 10);
    int seconds = 0;
    while (seconds * pixelsPerSecond < size.width) {
      final x = seconds * pixelsPerSecond;
      canvas.drawLine(Offset(x, 0), Offset(x, 12), paint);
      if (seconds % 5 == 0) {
        final tp = TextPainter(
          text: TextSpan(text: '${seconds}s', style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + 2, 2));
      }
      seconds++;
    }
  }

  @override
  bool shouldRepaint(_TimeRulerPainter old) => old.pixelsPerSecond != pixelsPerSecond;
}
```

#### E. Add track editor to Dialog TTS screen

At the bottom of the right panel in `dialog_tts_screen.dart`, add:

```dart
// Replace fixed-height bottom area with:
Column(children: [
  Expanded(child: /* existing chat list */),
  const Divider(height: 1),
  StoryTrackEditor(lines: projectLines),
])
```

---

## Recommended Package Additions

```yaml
# pubspec.yaml
dependencies:
  audio_waveforms: ^1.0.5    # Bottom player waveform visualization
  just_audio: ^0.9.40        # Optional: replace audioplayers for gapless queue playback
```

`just_audio`'s `ConcatenatingAudioSource` makes sequential multi-line playback trivial and removes the manual "wait for complete → play next" loop in `playSequenceFrom`.

---

## Implementation Order

1. **`PlaybackNotifier` + `PersistentAudioBar`** — refactor audio state first, everything else builds on it
2. **Migrate all screens** to call `playbackNotifierProvider.notifier.load(...)` 
3. **Drag reorder** in Dialog TTS (1-day effort, DB already supports it)
4. **"Play from here"** button + `playSequenceFrom` method
5. **`startTimeMs` DB migration** + auto-compute on generation
6. **`StoryTrackEditor` widget** — add to bottom of Dialog TTS screen

---

## Key Reference Files

| File | Purpose |
|---|---|
| `lib/presentation/screens/app_shell.dart` | Add `bottomNavigationBar: PersistentAudioBar()` |
| `lib/presentation/screens/dialog_tts_screen.dart` | Add reorder + StoryTrackEditor |
| `lib/providers/app_providers.dart` | Existing `audioPlayerProvider` to keep as-is |
| `lib/data/database/tables.dart` | Add `startTimeMs` to `DialogTtsLines` |
| `temp/voicebox/app/src/components/AudioPlayer/AudioPlayer.tsx` | Reference: bottom player implementation |
| `temp/voicebox/app/src/components/StoriesTab/StoryTrackEditor.tsx` | Reference: timeline editor (700 lines) |
| `temp/voicebox/app/src/lib/hooks/useStoryPlayback.ts` | Reference: sequential playback logic |
