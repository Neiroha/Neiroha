import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/domain/platform/platform_capabilities.dart';

void main() {
  test('desktop platforms support external ffmpeg cli', () {
    for (final platform in [
      NeirohaPlatform.windows,
      NeirohaPlatform.linux,
      NeirohaPlatform.macos,
    ]) {
      final capabilities = PlatformCapabilities(platform);

      expect(
        capabilities.supportsFfmpegCli,
        isTrue,
        reason: '${capabilities.platformLabel} should expose desktop ffmpeg',
      );
      expect(capabilities.supportsLocalVideoExport, isTrue);
      expect(capabilities.supportsLocalAudioMuxing, isTrue);
    }
  });

  test('mobile and unsupported platforms hide ffmpeg cli features', () {
    for (final platform in [
      NeirohaPlatform.android,
      NeirohaPlatform.ios,
      NeirohaPlatform.fuchsia,
      NeirohaPlatform.unknown,
    ]) {
      final capabilities = PlatformCapabilities(platform);

      expect(capabilities.supportsFfmpegCli, isFalse);
      expect(capabilities.supportsLocalVideoExport, isFalse);
      expect(capabilities.supportsLocalAudioMuxing, isFalse);
    }
  });

  test('system tts is visible only on Windows', () {
    final windows = PlatformCapabilities(NeirohaPlatform.windows);
    final android = PlatformCapabilities(NeirohaPlatform.android);

    expect(windows.supportsSystemTtsAdapter, isTrue);
    expect(windows.systemTtsProviderName, 'Windows SAPI');
    expect(windows.visibleAdapterTypes, contains(AdapterType.systemTts));

    expect(android.supportsSystemTtsAdapter, isFalse);
    expect(android.systemTtsProviderName, isNull);
    expect(android.visibleAdapterTypes, isNot(contains(AdapterType.systemTts)));
  });

  test('current unsupported adapter stays editable for existing rows', () {
    final android = PlatformCapabilities(NeirohaPlatform.android);

    expect(
      android.editableAdapterTypes(AdapterType.systemTts),
      contains(AdapterType.systemTts),
    );
    expect(
      android.editableAdapterTypes(AdapterType.openaiCompatible),
      isNot(contains(AdapterType.systemTts)),
    );
  });
}
