// Song page: style tags, library search and lyrics that follow playback.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/services/music/song_library.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/widgets/music/song_list.dart';
import 'package:neiroha/presentation/widgets/music/song_now_playing.dart';
import 'package:neiroha/presentation/widgets/music/style_presets.dart';
import 'package:neiroha/providers/playback_provider.dart';

class _Playing extends PlaybackNotifier {
  final seeks = <Duration>[];

  @override
  PlaybackState build() => const PlaybackState(
    audioPath: '/songs/b.wav',
    sourceTag: songStudioPlaybackSource,
    isPlaying: true,
    position: Duration(seconds: 12),
    duration: Duration(seconds: 60),
  );

  @override
  Future<void> seek(Duration position) async => seeks.add(position);
}

SongRecord _song(String name, String prompt, List<LyricLine> lyrics) =>
    SongRecord(
      audioPath: '/songs/$name.wav',
      title: 'Song $name',
      prompt: prompt,
      lyrics: lyrics,
      model: 'lyria-3',
      provider: 'Gemini',
      created: DateTime(2026, 11, 24),
    );

void main() {
  test('style tags toggle as comma parts of the prompt', () {
    expect(togglePromptWords('', 'pop'), 'pop');
    expect(togglePromptWords('dreamy, piano', 'pop'), 'dreamy, piano, pop');
    expect(togglePromptWords('Dreamy，pop、piano', 'pop'), 'Dreamy, piano');
    expect(promptHas('slow tempo, Piano', 'piano'), isTrue);
    expect(promptHas('pianos', 'piano'), isFalse);
  });

  testWidgets('search filters the library; the playing line lights up', (
    tester,
  ) async {
    final playback = _Playing();
    final songs = [
      _song('a', 'rock, drums', const [LyricLine('loud')]),
      _song('b', 'dreamy, piano', const [
        LyricLine('first', start: Duration.zero, section: 'Verse'),
        LyricLine('second', start: Duration(seconds: 10)),
        LyricLine('third', start: Duration(seconds: 20)),
      ]),
    ];
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [playbackNotifierProvider.overrideWith(() => playback)],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SongList(
              songs: songs,
              selected: songs[1],
              playingPath: songs[1].audioPath,
              onSelect: (_) {},
              onPlay: (_) {},
              onAction: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('共 2 首'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'piano');
    await tester.pump();
    expect(find.text('Song a'), findsNothing);
    expect(find.text('Song b'), findsWidgets);

    TextStyle styleOf(String line) => tester
        .widget<AnimatedDefaultTextStyle>(
          find
              .ancestor(
                of: find.text(line),
                matching: find.byType(AnimatedDefaultTextStyle),
              )
              .first,
        )
        .style;
    expect(styleOf('second').fontWeight, FontWeight.w700);
    expect(styleOf('first').fontWeight, FontWeight.w400);
    expect(find.text('正在播放'), findsOneWidget);

    await tester.tap(find.text('third'));
    expect(playback.seeks, [const Duration(seconds: 20)]);
  });
}
