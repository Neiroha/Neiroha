import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/presentation/navigation/app_navigation.dart';
import 'package:neiroha/providers/app_providers.dart';

/// The order of the pages in the sidebar's upper group, chosen in Settings.
/// AI services and Settings stay pinned at the bottom.
class NavOrder extends AsyncNotifier<List<NavTab>> {
  static const settingKey = 'ui.sidebar.order';

  static const defaults = [
    NavTab.novelReader,
    NavTab.dialogTts,
    NavTab.phaseTts,
    NavTab.videoDub,
    NavTab.subtitles,
    NavTab.music,
    NavTab.voiceAssets,
    NavTab.voiceBank,
  ];

  /// Stored names in order; unknown names are dropped and pages added
  /// since are appended where the defaults put them last.
  static List<NavTab> parse(String? raw) {
    final stored = [
      for (final name in (raw ?? '').split(','))
        if (NavTab.fromName(name.trim()) case final tab?
            when defaults.contains(tab))
          tab,
    ];
    final order = stored.toSet().toList();
    return [...order, ...defaults.where((t) => !order.contains(t))];
  }

  @override
  Future<List<NavTab>> build() async {
    try {
      return parse(await ref.read(databaseProvider).getSetting(settingKey));
    } catch (_) {
      return defaults;
    }
  }

  Future<void> save(List<NavTab> order) async {
    state = AsyncData(order);
    await ref
        .read(databaseProvider)
        .setSetting(settingKey, order.map((t) => t.name).join(','));
  }

  Future<void> move(int from, int to) {
    final order = [...(state.value ?? defaults)];
    order.insert(to, order.removeAt(from));
    return save(order);
  }

  Future<void> reset() => save(defaults);
}

final navOrderProvider = AsyncNotifierProvider<NavOrder, List<NavTab>>(
  NavOrder.new,
);

/// The upper group in its current order, defaults until loaded.
List<NavTab> navMainTabs(WidgetRef ref) =>
    ref.watch(navOrderProvider).value ?? NavOrder.defaults;
