import 'package:flutter/foundation.dart';

import 'package:neiroha/domain/enums/adapter_type.dart';

enum NeirohaPlatform { windows, linux, macos, android, ios, fuchsia, unknown }

/// Product-level platform capability switches.
///
/// This keeps platform decisions out of individual screens: UI can ask whether
/// a capability exists, while adapters/services still perform hard runtime
/// guards before invoking platform-specific APIs.
class PlatformCapabilities {
  const PlatformCapabilities(this.platform);

  factory PlatformCapabilities.current() {
    return PlatformCapabilities(_platformFromFlutter(defaultTargetPlatform));
  }

  final NeirohaPlatform platform;

  static NeirohaPlatform _platformFromFlutter(TargetPlatform platform) {
    return switch (platform) {
      TargetPlatform.windows => NeirohaPlatform.windows,
      TargetPlatform.linux => NeirohaPlatform.linux,
      TargetPlatform.macOS => NeirohaPlatform.macos,
      TargetPlatform.android => NeirohaPlatform.android,
      TargetPlatform.iOS => NeirohaPlatform.ios,
      TargetPlatform.fuchsia => NeirohaPlatform.fuchsia,
    };
  }

  String get platformLabel => switch (platform) {
    NeirohaPlatform.windows => 'Windows',
    NeirohaPlatform.linux => 'Linux',
    NeirohaPlatform.macos => 'macOS',
    NeirohaPlatform.android => 'Android',
    NeirohaPlatform.ios => 'iOS',
    NeirohaPlatform.fuchsia => 'Fuchsia',
    NeirohaPlatform.unknown => 'this platform',
  };

  /// Neiroha deliberately uses an external ffmpeg CLI instead of bundling one.
  /// That model is a desktop-only fit; Android should use subtitle/audio
  /// package export or future server-side rendering instead.
  bool get supportsFfmpegCli => switch (platform) {
    NeirohaPlatform.windows ||
    NeirohaPlatform.linux ||
    NeirohaPlatform.macos => true,
    _ => false,
  };

  bool get supportsLocalVideoExport => supportsFfmpegCli;

  bool get supportsLocalAudioMuxing => supportsFfmpegCli;

  /// Only Windows SAPI is implemented today. Android/Apple system TTS should
  /// be added behind native MethodChannels before becoming visible here.
  bool get supportsSystemTtsAdapter => platform == NeirohaPlatform.windows;

  String? get systemTtsProviderName {
    return supportsSystemTtsAdapter ? 'Windows SAPI' : null;
  }

  bool supportsTtsAdapter(AdapterType type) {
    return switch (type) {
      AdapterType.systemTts => supportsSystemTtsAdapter,
      _ => true,
    };
  }

  bool supportsAdapterName(String adapterTypeName) {
    for (final type in AdapterType.values) {
      if (type.name == adapterTypeName) return supportsTtsAdapter(type);
    }
    return false;
  }

  List<AdapterType> get visibleAdapterTypes {
    return [
      for (final type in AdapterType.values)
        if (supportsTtsAdapter(type)) type,
    ];
  }

  List<AdapterType> editableAdapterTypes(AdapterType currentType) {
    final types = visibleAdapterTypes;
    if (types.contains(currentType)) return types;
    return [...types, currentType];
  }

  String displayNameForAdapter(AdapterType type) {
    if (type == AdapterType.systemTts) {
      return systemTtsProviderName ?? type.displayName;
    }
    return type.displayName;
  }
}
