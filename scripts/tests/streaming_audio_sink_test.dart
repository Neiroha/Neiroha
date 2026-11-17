import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:neiroha/data/services/synthesis/soloud_audio_sink.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'support/test_capabilities.dart';

/// Explicit opt-in: plays quiet tones on the test machine.
void main() {
  final capabilities = TestCapabilities.current();
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => Directory.systemTemp.path,
      );

  test(
    'native MP3 decoder consumes arbitrary network chunks continuously',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'neiroha_mp3_stream_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/tone.mp3');
      final encoded = await Process.run('ffmpeg', [
        '-hide_banner',
        '-loglevel',
        'error',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:sample_rate=44100:duration=2',
        '-filter:a',
        'volume=0.01',
        '-codec:a',
        'libmp3lame',
        '-b:a',
        '128k',
        file.path,
      ]);
      expect(encoded.exitCode, 0, reason: '${encoded.stderr}');
      final sink = SoloudAudioSink();
      addTearDown(sink.stop);
      await sink.open(const TtsAudioFormat(AudioEncoding.mp3));
      final bytes = await file.readAsBytes();
      var checkedBeforeEof = false;
      for (var offset = 0; offset < bytes.length; offset += 513) {
        await sink.add(
          Uint8List.sublistView(
            bytes,
            offset,
            math.min(offset + 513, bytes.length),
          ),
        );
        if (!checkedBeforeEof && offset > bytes.length ~/ 2) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          expect(sink.position, greaterThan(Duration.zero));
          checkedBeforeEof = true;
        }
      }
      await sink.finish();
      await sink.drained.timeout(const Duration(seconds: 3));
      expect(sink.bufferedUntil.inMilliseconds, closeTo(2000, 130));
    },
    skip: capabilities.audioSkipReason(requiresFfmpeg: true),
  );

  test('native PCM sink starts before EOF, pauses, drains and stops', () async {
    final sink = SoloudAudioSink();
    addTearDown(sink.stop);
    await sink.open(
      const TtsAudioFormat(
        AudioEncoding.pcmS16le,
        sampleRate: 22050,
        channels: 1,
      ),
    );
    final bytes = Uint8List(22050 * 2 * 3 ~/ 5);
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < bytes.length ~/ 2; i++) {
      data.setInt16(
        i * 2,
        (200 * math.sin(i * 2 * math.pi * 440 / 22050)).round(),
        Endian.little,
      );
    }
    // Odd network boundaries must preserve PCM sample alignment.
    await sink.add(Uint8List.sublistView(bytes, 0, 4097));
    await sink.add(Uint8List.sublistView(bytes, 4097));
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(sink.position, greaterThan(Duration.zero));
    await sink.pause(true);
    final paused = sink.position;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect((sink.position - paused).inMilliseconds.abs(), lessThan(60));
    await sink.pause(false);
    await sink.finish();
    await sink.drained.timeout(const Duration(seconds: 3));
    expect(sink.bufferedUntil.inMilliseconds, closeTo(600, 100));
    await sink.stop();
    await sink.stop();
  }, skip: capabilities.audioSkipReason());
}
