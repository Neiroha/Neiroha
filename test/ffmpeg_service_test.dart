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
}
