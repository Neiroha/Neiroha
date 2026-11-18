import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/domain/platform/platform_capabilities.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  test(
    'Android target keeps remote TTS and hides desktop-only capabilities',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final capabilities = PlatformCapabilities.current();
      expect(capabilities.platform, NeirohaPlatform.android);
      expect(capabilities.supportsFfmpegCli, isFalse);
      expect(capabilities.supportsLocalVideoExport, isFalse);
      expect(capabilities.supportsMicrophoneRecording, isFalse);
      expect(capabilities.visibleAdapterTypes, contains(AdapterType.openaiTts));
      expect(
        capabilities.visibleAdapterTypes,
        isNot(contains(AdapterType.systemTts)),
      );
    },
  );
}
