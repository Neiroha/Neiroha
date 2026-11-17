import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/services/media_session_service.dart';
import 'package:neiroha/domain/platform/platform_capabilities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'media session shares player state and translates remote controls',
    () async {
      const channel = MethodChannel('neiroha/test_media_session');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final service = MediaSessionService(channel: channel, supported: true);
      final controls = <String>[];
      final subscription = service.controls.listen(controls.add);
      await service.startOrUpdateNovelSession(
        title: 'Book',
        subtitle: 'Chapter',
        isPlaying: true,
        position: const Duration(seconds: 2),
        duration: const Duration(seconds: 4),
      );
      expect(calls.single.method, 'startOrUpdateNovelSession');
      expect((calls.single.arguments as Map)['positionMs'], 2000);
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('control', 'next'),
        ),
        (_) {},
      );
      await pumpEventQueue();
      expect(controls, ['next']);
      await service.stopNovelSession();
      expect(calls.last.method, 'stopNovelSession');
      await subscription.cancel();
      service.dispose();
    },
  );

  test('recording availability follows the installed native backends', () {
    expect(
      const PlatformCapabilities(
        NeirohaPlatform.windows,
      ).supportsMicrophoneRecording,
      isTrue,
    );
    expect(
      const PlatformCapabilities(
        NeirohaPlatform.macos,
      ).supportsMicrophoneRecording,
      isTrue,
    );
    expect(
      const PlatformCapabilities(
        NeirohaPlatform.linux,
      ).supportsMicrophoneRecording,
      isFalse,
    );
    expect(
      const PlatformCapabilities(
        NeirohaPlatform.android,
      ).supportsMicrophoneRecording,
      isFalse,
    );
  });
}
