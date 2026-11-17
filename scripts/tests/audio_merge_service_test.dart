import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/services/audio_merge_service.dart';
import 'package:path/path.dart' as p;

bool _ffmpegOnPath() {
  try {
    return Process.runSync('ffmpeg', const ['-version']).exitCode == 0;
  } catch (_) {
    return false;
  }
}

void main() {
  test('clip filter adds fades and the gap except after the last clip', () {
    const o = AudioMergeOptions(gapSeconds: 0.5, fadeInMs: 10, fadeOutMs: 30);
    final mid = AudioMergeService.buildClipFilter(o, last: false);
    expect(mid, contains('afade=t=in:st=0:d=0.010'));
    expect(mid, contains('areverse,afade=t=in:st=0:d=0.030,areverse'));
    expect(mid, endsWith('apad=pad_dur=0.500'));
    expect(
      AudioMergeService.buildClipFilter(o, last: true),
      isNot(contains('apad')),
    );
    expect(const AudioMergeOptions().isPlain, isTrue);
  });

  test('merged length is the clips plus one gap between each', () async {
    final dir = await Directory.systemTemp.createTemp('neiroha_merge_test_');
    addTearDown(() => dir.delete(recursive: true));
    Future<String> tone(String name, double sec, int rate) async {
      final out = p.join(dir.path, name);
      final r = await Process.run('ffmpeg', [
        '-v',
        'error',
        '-y',
        '-f',
        'lavfi',
        '-i',
        'sine=f=440:r=$rate:d=$sec',
        out,
      ]);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      return out;
    }

    // Mixed sample rates and containers on purpose.
    final a = await tone('a.wav', 1.0, 24000);
    final b = await tone('b.mp3', 1.5, 44100);
    final c = await tone('c.wav', 0.5, 16000);
    final out = p.join(dir.path, 'merged.wav');
    double? last;
    await AudioMergeService(resolveFfmpeg: () async => 'ffmpeg').merge(
      inputs: [a, b, c],
      outputPath: out,
      options: const AudioMergeOptions(
        gapSeconds: 0.4,
        fadeInMs: 10,
        fadeOutMs: 30,
      ),
      encoderArgs: const ['-c:a', 'pcm_s16le'],
      onProgress: (v) => last = v,
    );
    expect(last, 1.0);
    final probe = await Process.run('ffprobe', [
      '-v',
      'error',
      '-show_entries',
      'format=duration',
      '-of',
      'csv=p=0',
      out,
    ]);
    final duration = double.parse('${probe.stdout}'.trim());
    // 1.0 + 0.4 + 1.5 + 0.4 + 0.5; mp3 decoding may add a few ms.
    expect(duration, closeTo(3.8, 0.08));
  }, skip: _ffmpegOnPath() ? false : 'ffmpeg not on PATH');
}
