// The video dub timeline lays out every track, and taps reach the caller.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/widgets/video_dub/timeline.dart';
import 'package:neiroha/presentation/widgets/video_dub/tracks.dart';

db.SubtitleCue _cue(String id, int start, int end) => db.SubtitleCue(
  id: id,
  projectId: 'p',
  orderIndex: 0,
  startMs: start,
  endMs: end,
  cueText: 'line $id',
  missing: false,
);

db.TimelineClip _clip(String id, int lane, String type, int start) =>
    db.TimelineClip(
      id: id,
      projectId: 'videodub:p',
      projectType: 'videodub',
      laneIndex: lane,
      startTimeMs: start,
      durationSec: 4,
      audioPath: '/media/$id',
      sourceType: type,
      label: 'clip $id',
      missing: false,
    );

void main() {
  testWidgets('shows cues and clips; tapping a cue reports it', (
    tester,
  ) async {
    final tapped = <String>[];
    await tester.binding.setSurfaceSize(const Size(1200, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VideoDubTimeline(
            cues: [_cue('a', 0, 3000), _cue('b', 4000, 8000)],
            clips: [
              _clip('v', DubLanes.v1, 'video', 0),
              _clip('o', DubLanes.a1, 'audio', 0),
              _clip('m', DubLanes.a3, 'audio', 2000),
            ],
            assetMap: const {},
            position: const Duration(seconds: 2),
            duration: const Duration(seconds: 10),
            selectedCueId: 'b',
            selectedClipId: null,
            onSeek: (_) {},
            onTapCue: (c) => tapped.add(c.id),
            onTapClip: (_) {},
            onDeleteClip: (_) {},
            onImport: (_) {},
            waveformPeaks: const [0.1, 0.5, 0.9, 0.4],
            ffmpegSupported: true,
            ffmpegAvailable: true,
            onConfigureFfmpeg: () {},
            v1Occupied: true,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('V1 · Video'), findsOneWidget);
    expect(find.text('A3 · Audio'), findsOneWidget);
    await tester.tap(find.textContaining('line a').first);
    expect(tapped, ['a']);
  });
}
