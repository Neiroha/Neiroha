import 'dart:async';

import 'package:neiroha/domain/ai/models/capability_model.dart';

abstract interface class SpeechTranslator implements CapabilityModel {
  /// One session per target language (ISO code such as `es`).
  Future<AudioStreamSession> open({required String targetLanguage});
}
