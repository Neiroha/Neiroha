import 'dart:async';

import 'package:neiroha/domain/synthesis/speech_check.dart';

/// Recent ASR read-back results per character, for the chain editor.
class SpeechCheckLog {
  SpeechCheckLog._();
  static final instance = SpeechCheckLog._();
  static const keep = 20;

  final _byAsset = <String, List<SpeechCheck>>{};
  final _changes = StreamController<String>.broadcast();

  void add(SpeechCheck check) {
    final id = check.voiceAssetId;
    if (id == null) return;
    final list = _byAsset.putIfAbsent(id, () => []);
    list.add(check);
    if (list.length > keep) list.removeRange(0, list.length - keep);
    _changes.add(id);
  }

  /// Newest last.
  List<SpeechCheck> recent(String voiceAssetId) =>
      List.unmodifiable(_byAsset[voiceAssetId] ?? const []);

  /// The character's checks, now and whenever a new one arrives.
  Stream<List<SpeechCheck>> watch(String voiceAssetId) async* {
    yield recent(voiceAssetId);
    yield* _changes.stream
        .where((id) => id == voiceAssetId)
        .map((_) => recent(voiceAssetId));
  }
}
