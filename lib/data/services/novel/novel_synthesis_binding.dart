import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/capabilities/task_profile.dart';

class NovelSynthesisBinding {
  const NovelSynthesisBinding(this.asset, this.provider, this.profile);
  final db.VoiceAsset asset;
  final db.TtsProvider provider;
  final TaskProfile? profile;

  /// The task profile as cache-key input; empty without one.
  String get profileSignature =>
      profile == null ? '' : jsonEncode(profile!.toJson());
  static NovelSynthesisBinding resolve(
    db.VoiceAsset asset,
    db.TtsProvider provider,
    List<db.TtsProvider> providers,
    TaskProfile? profile,
  ) {
    if (profile == null) return NovelSynthesisBinding(asset, provider, null);
    profile.validate();
    final connection = providers
        .where((p) => p.id == profile.providerId)
        .firstOrNull;
    if (connection == null) throw StateError('Task connection was deleted.');
    return NovelSynthesisBinding(
      asset.copyWith(
        providerId: connection.id,
        modelName: Value(profile.model),
      ),
      connection,
      profile,
    );
  }
}
