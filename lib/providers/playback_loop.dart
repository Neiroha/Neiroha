import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart';

import 'app_providers.dart';

/// Whether single-clip playback restarts when it reaches the end.
///
/// Saved in app settings so the player bar keeps the choice across launches.
final playbackLoopProvider = NotifierProvider<PlaybackLoopNotifier, bool>(
  PlaybackLoopNotifier.new,
);

class PlaybackLoopNotifier extends Notifier<bool> {
  static const settingKey = 'playback.loop';

  bool _changedByUser = false;

  @override
  bool build() {
    unawaited(_load());
    return false;
  }

  Future<void> _load() async {
    try {
      final saved = await ref.read(databaseProvider).getSetting(settingKey);
      if (!_changedByUser && saved != null) state = saved == 'true';
    } catch (_) {
      // Keep the default when settings are unavailable.
    }
  }

  Future<void> set(bool enabled) async {
    _changedByUser = true;
    state = enabled;
    await ref.read(databaseProvider).setSetting(settingKey, '$enabled');
  }

  Future<void> toggle() => set(!state);
}
