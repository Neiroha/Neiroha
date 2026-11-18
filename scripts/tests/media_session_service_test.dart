import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/services/media_session_service.dart';
import 'package:neiroha/domain/platform/platform_capabilities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final platform in ['android', 'macos']) {
    test(
      '$platform media session shares state and translates remote controls',
      () async {
        final channel = MethodChannel('neiroha/${platform}_media_session');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final service = MediaSessionService(channel: channel, supported: true);
        addTearDown(service.dispose);
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
      },
    );
  }

  test('unsupported platforms do not invoke a native media channel', () async {
    const channel = MethodChannel('neiroha/unsupported_media_session');
    // Deliberately no mock handler: an accidental native call must fail.
    final service = MediaSessionService(channel: channel, supported: false);
    addTearDown(service.dispose);
    await service.startOrUpdateNovelSession(title: 'Book', isPlaying: true);
    await service.stopNovelSession();
  });

  test('default media transport follows the actual host platform', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    for (final platform in ['macos', 'android']) {
      final channel = MethodChannel('neiroha/${platform}_media_session');
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add('$platform:${call.method}');
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }
    final service = MediaSessionService();
    addTearDown(service.dispose);
    await service.startOrUpdateNovelSession(title: 'Book', isPlaying: true);
    await service.stopNovelSession();
    expect(calls, switch (Platform.operatingSystem) {
      'macos' || 'android' => [
        '${Platform.operatingSystem}:startOrUpdateNovelSession',
        '${Platform.operatingSystem}:stopNovelSession',
      ],
      _ => isEmpty,
    });
  });

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
