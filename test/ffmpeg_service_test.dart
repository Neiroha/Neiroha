import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/storage/ffmpeg_service.dart';

void main() {
  test('parseDshowAudioInputs reads headerless dshow device output', () {
    const output = '''
[dshow @ 000001] "HD Webcam" (video)
[dshow @ 000001]   Alternative name "@device_video"
[dshow @ 000001] "Microphone Array (Realtek Audio)" (audio)
[dshow @ 000001]   Alternative name "@device_audio_1"
[dshow @ 000001] "USB Microphone" (audio)
[dshow @ 000001]   Alternative name "@device_audio_2"
''';

    final devices = FFmpegService.parseDshowAudioInputs(output);

    expect(devices, hasLength(2));
    expect(devices[0].name, 'Microphone Array (Realtek Audio)');
    expect(devices[0].recordingNames, [
      'Microphone Array (Realtek Audio)',
      '@device_audio_1',
    ]);
    expect(devices[1].name, 'USB Microphone');
    expect(devices[1].recordingNames, ['USB Microphone', '@device_audio_2']);
  });

  test('parseDshowAudioInputs ignores duplicate and non-audio devices', () {
    const output = '''
[dshow @ 000001] "HD Webcam" (video)
[dshow @ 000001]   Alternative name "@device_video"
[dshow @ 000001] "USB Microphone" (audio)
[dshow @ 000001]   Alternative name "@device_audio"
[dshow @ 000001] "USB Microphone" (audio)
[dshow @ 000001]   Alternative name "@duplicate_should_not_attach"
[dshow @ 000001] "No capture pins" (none)
[dshow @ 000001]   Alternative name "@none_should_not_attach"
''';

    final devices = FFmpegService.parseDshowAudioInputs(output);

    expect(devices, hasLength(1));
    expect(devices.single.name, 'USB Microphone');
    expect(devices.single.alternativeName, '@device_audio');
  });

  test('reduceToPeaks decodes little-endian pcm16 buckets', () {
    final peaks = FFmpegService.reduceToPeaks([
      0x00, 0x00, // 0
      0xff, 0x7f, // 32767
      0x00, 0x80, // -32768
      0x00, 0x40, // 16384
    ], 2);

    expect(peaks, hasLength(2));
    expect(peaks[0], closeTo(32767 / 32768, 0.0001));
    expect(peaks[1], 1.0);
  });

  test('PeakReducer handles sample bytes split across chunks', () {
    final reducer = PeakReducer(2, 2);

    reducer.addBytes([0x00]);
    reducer.addBytes([0x80, 0xff]);
    reducer.addBytes([0x7f]);

    final peaks = reducer.finish();
    expect(peaks[0], 1.0);
    expect(peaks[1], closeTo(32767 / 32768, 0.0001));
  });
}
