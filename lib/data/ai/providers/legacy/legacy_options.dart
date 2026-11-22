import 'package:neiroha/data/ai/core/connection_config.dart';

/// Option keys a legacy `TtsProviders` row contributes to [ConnectionConfig].
abstract final class LegacyOptions {
  static const adapterType = 'adapterType';
  static const defaultModel = 'defaultModel';
}
