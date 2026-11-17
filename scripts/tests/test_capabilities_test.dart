import 'package:flutter_test/flutter_test.dart';
import 'support/test_capabilities.dart';

void main() {
  for (final platform in ['windows', 'macos', 'linux']) {
    test('$platform keeps PCM available without the MP3 encoder', () {
      final capabilities = TestCapabilities(
        operatingSystem: platform,
        audioEnabled: true,
        ffmpegAvailable: false,
      );
      expect(capabilities.audioSkipReason(), isFalse);
      expect(
        capabilities.audioSkipReason(requiresFfmpeg: true),
        contains('FFmpeg'),
      );
      expect(
        TestCapabilities(
          operatingSystem: platform,
          audioEnabled: true,
          ffmpegAvailable: true,
        ).audioSkipReason(requiresFfmpeg: true),
        isFalse,
      );
    });
  }
  test('hardware checks require explicit opt-in', () {
    expect(
      const TestCapabilities(
        operatingSystem: 'macos',
        audioEnabled: false,
        ffmpegAvailable: true,
      ).audioSkipReason(),
      contains('NEIROHA_AUDIO_SMOKE=1'),
    );
  });
  test('mobile hosts report an unsupported hardware test capability', () {
    for (final platform in ['android', 'ios', 'fuchsia']) {
      expect(
        TestCapabilities(
          operatingSystem: platform,
          audioEnabled: true,
          ffmpegAvailable: true,
        ).audioSkipReason(),
        contains('desktop host'),
      );
    }
  });
}
