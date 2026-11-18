import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

/// Platform-neutral transport for the shared player's state and media keys.
class MediaSessionService {
  MediaSessionService({MethodChannel? channel, bool? supported})
    : _channel =
          channel ??
          MethodChannel(
            Platform.isMacOS
                ? 'neiroha/macos_media_session'
                : 'neiroha/android_media_session',
          ),
      isSupported = supported ?? (Platform.isAndroid || Platform.isMacOS) {
    _channel.setMethodCallHandler(_handleMethodCall);
  }
  final MethodChannel _channel;
  final bool isSupported;
  final _controls = StreamController<String>.broadcast();
  Stream<String> get controls => _controls.stream;

  Future<void> startOrUpdateNovelSession({
    required String title,
    String? subtitle,
    required bool isPlaying,
    Duration position = Duration.zero,
    Duration duration = Duration.zero,
  }) async {
    if (!isSupported) return;
    await _channel.invokeMethod('startOrUpdateNovelSession', {
      'title': title,
      'subtitle': subtitle ?? '',
      'isPlaying': isPlaying,
      'positionMs': position.inMilliseconds,
      'durationMs': duration.inMilliseconds,
    });
  }

  Future<void> stopNovelSession() async {
    if (isSupported) await _channel.invokeMethod('stopNovelSession');
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    unawaited(_controls.close());
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'control' || _controls.isClosed) return;
    final control = call.arguments?.toString();
    if ([
      'play',
      'pause',
      'toggle',
      'previous',
      'next',
      'stop',
    ].contains(control)) {
      _controls.add(control!);
    }
  }
}
