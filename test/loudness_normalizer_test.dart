import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/services/loudness_normalizer.dart';
import 'package:path/path.dart' as p;

bool _ffmpegOnPath() {
  try {
    return Process.runSync('ffmpeg', const ['-version']).exitCode == 0;
  } catch (_) {
    return false;
  }
}

void main() {
  group('parseLoudnormJson', () {
    test('reads integrated loudness and true peak', () {
      const stderr = '''
Input #0, wav, from 'a.wav':
[Parsed_loudnorm_0 @ 000002b45110b680]
{
	"input_i" : "-47.95",
	"input_tp" : "-44.07",
	"input_lra" : "0.00",
	"input_thresh" : "-57.95",
	"output_i" : "-17.95",
	"output_tp" : "-14.12",
	"output_lra" : "0.00",
	"output_thresh" : "-27.95",
	"normalization_type" : "linear",
	"target_offset" : "-0.05"
}
[out#0/null @ 000002b4510e8100] video:0KiB audio:600KiB
''';
      final m = LoudnessNormalizer.parseLoudnormJson(stderr)!;
      expect(m.integratedLufs, closeTo(-47.95, 1e-9));
      expect(m.truePeakDb, closeTo(-44.07, 1e-9));
      expect(m.isSilent, isFalse);
    });

    test('treats -inf as silence', () {
      const stderr = '''
[Parsed_loudnorm_0 @ 0001]
{
	"input_i" : "-inf",
	"input_tp" : "-inf",
	"input_lra" : "0.00"
}
''';
      final m = LoudnessNormalizer.parseLoudnormJson(stderr)!;
      expect(m.integratedLufs, double.negativeInfinity);
      expect(m.isSilent, isTrue);
    });

    test('returns null without a report', () {
      expect(LoudnessNormalizer.parseLoudnormJson('no json here'), isNull);
    });
  });

  test('buildGainFilter adds the limiter only when asked', () {
    expect(
      LoudnessNormalizer.buildGainFilter(6, -1.5, limiter: false),
      'volume=6.00dB',
    );
    expect(
      LoudnessNormalizer.buildGainFilter(12.345, -1.5, limiter: true),
      'volume=12.35dB,alimiter=limit=0.8414:attack=5:release=50:level=disabled',
    );
    expect(
      LoudnessNormalizer.buildGainFilter(
        3,
        -1.5,
        limiter: true,
        limiterLevelFlag: false,
      ),
      'volume=3.00dB,alimiter=limit=0.8414:attack=5:release=50',
    );
  });

  test('encoderArgsFor keeps the container codec', () {
    expect(LoudnessNormalizer.encoderArgsFor('.wav'), ['-c:a', 'pcm_s16le']);
    expect(LoudnessNormalizer.encoderArgsFor('.mp3').take(2), [
      '-c:a',
      'libmp3lame',
    ]);
  });

  group('with ffmpeg', () {
    late Directory dir;
    final normalizer = LoudnessNormalizer(resolveFfmpeg: () async => 'ffmpeg');

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('neiroha_loudness_');
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    Future<String> tone(String name, String lavfi) async {
      final out = p.join(dir.path, name);
      final r = await Process.run('ffmpeg', [
        '-v',
        'error',
        '-y',
        '-f',
        'lavfi',
        '-i',
        lavfi,
        '-t',
        '2',
        '-ac',
        '1',
        out,
      ]);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      return out;
    }

    test(
      'quiet and loud clips converge on the target and keep a backup',
      () async {
        const target = LoudnessTarget(lufs: -18);
        final quiet = await tone(
          'quiet.wav',
          'anoisesrc=d=2:c=pink:r=24000:a=0.03',
        );
        final loud = await tone(
          'loud.wav',
          'anoisesrc=d=2:c=pink:r=24000:a=0.5',
        );

        for (final path in [quiet, loud]) {
          final outcome = await normalizer.normalizeFile(path, target);
          expect(outcome.kind, LoudnessOutcomeKind.adjusted);
          final after = await normalizer.measure(path);
          expect(after.integratedLufs, closeTo(-18, 1.0));
          expect(
            File(LoudnessNormalizer.backupPathFor(path)).existsSync(),
            true,
          );
        }

        // Re-targeting starts from the pristine backup.
        expect(LoudnessNormalizer.sourcePathFor(quiet), isNot(quiet));
        await normalizer.normalizeFile(quiet, const LoudnessTarget(lufs: -24));
        final retargeted = await normalizer.measure(quiet);
        expect(retargeted.integratedLufs, closeTo(-24, 1.0));
      },
      skip: _ffmpegOnPath() ? false : 'ffmpeg not on PATH',
    );

    test(
      'audio regenerated at the same path replaces the stale backup',
      () async {
        const target = LoudnessTarget(lufs: -18);
        final clip = await tone('clip.wav', 'sine=f=440:r=24000');
        await normalizer.normalizeFile(clip, target);
        expect(LoudnessNormalizer.sourcePathFor(clip), isNot(clip));

        // Simulate Novel Reader's forced regeneration writing new audio
        // over the same file.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tone('clip.wav', 'anoisesrc=d=2:c=pink:r=24000:a=0.4');
        expect(LoudnessNormalizer.sourcePathFor(clip), clip);
        final fresh = await File(clip).readAsBytes();

        await normalizer.normalizeFile(clip, target);
        final backup = File(LoudnessNormalizer.backupPathFor(clip));
        expect(await backup.readAsBytes(), fresh);
        expect(LoudnessNormalizer.sourcePathFor(clip), backup.path);
      },
      skip: _ffmpegOnPath() ? false : 'ffmpeg not on PATH',
    );

    test('silence is skipped and left untouched', () async {
      final silent = await tone('silent.wav', 'anullsrc=r=24000:cl=mono');
      final before = await File(silent).readAsBytes();
      final outcome = await normalizer.normalizeFile(
        silent,
        const LoudnessTarget(lufs: -16),
      );
      expect(outcome.kind, LoudnessOutcomeKind.silent);
      expect(await File(silent).readAsBytes(), before);
    }, skip: _ffmpegOnPath() ? false : 'ffmpeg not on PATH');
  });
}
