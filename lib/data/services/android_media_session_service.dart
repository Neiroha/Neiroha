import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class AndroidMediaSessionService {
  AndroidMediaSessionService() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static const _channel = MethodChannel('neiroha/android_media_session');

  final StreamController<String> _controls =
      StreamController<String>.broadcast();

  Stream<String> get controls => _controls.stream;

  bool get isSupported => Platform.isAndroid;

  Future<void> startOrUpdateNovelSession({
    required String title,
    String? subtitle,
    required bool isPlaying,
  }) async {
    if (!isSupported) return;
    await _channel.invokeMethod('startOrUpdateNovelSession', {
      'title': title,
      'subtitle': subtitle ?? '',
      'isPlaying': isPlaying,
    });
  }

  Future<void> stopNovelSession() async {
    if (!isSupported) return;
    await _channel.invokeMethod('stopNovelSession');
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    unawaited(_controls.close());
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'control') return;
    final control = call.arguments?.toString();
    if (control == null || control.isEmpty) return;
    if (_controls.isClosed) return;
    _controls.add(control);
  }
}
