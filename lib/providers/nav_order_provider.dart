import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/presentation/navigation/app_navigation.dart';
import 'package:neiroha/providers/app_providers.dart';

/// The sidebar's upper group: every page in its order, and the pages
/// hidden from it. AI services and Settings stay pinned at the bottom and
/// cannot be hidden.
class NavLayout {
  const NavLayout(this.order, [this.hidden = const {}]);

  final List<NavTab> order;
  final Set<NavTab> hidden;

  /// The pages the sidebar shows, in order.
  List<NavTab> get visible => [
    for (final tab in order)
      if (!hidden.contains(tab)) tab,
  ];

  bool get isDefault => hidden.isEmpty && listEquals(order, NavOrder.defaults);
}

/// The sidebar layout chosen in Settings.
class NavOrder extends AsyncNotifier<NavLayout> {
  static const settingKey = 'ui.sidebar.order';
  static const hiddenKey = 'ui.sidebar.hidden';

  static const defaults = [
    NavTab.novelReader,
    NavTab.dialogTts,
    NavTab.characterChat,
    NavTab.phaseTts,
    NavTab.videoDub,
    NavTab.subtitles,
    NavTab.music,
    NavTab.voiceAssets,
    NavTab.voiceBank,
  ];

  /// Stored names in order; unknown names are dropped. A page added since
  /// the order was saved goes right after the page it follows by default.
  static List<NavTab> parse(String? raw) {
    final order = <NavTab>{
      for (final name in (raw ?? '').split(','))
        if (NavTab.fromName(name.trim()) case final tab?
            when defaults.contains(tab))
          tab,
    }.toList();
    if (order.isEmpty) return defaults;
    for (final (i, tab) in defaults.indexed) {
      if (order.contains(tab)) continue;
      final before = defaults
          .take(i)
          .lastWhere(order.contains, orElse: () => tab);
      order.insert(before == tab ? 0 : order.indexOf(before) + 1, tab);
    }
    return order;
  }

  /// Stored hidden pages; unknown names and pinned pages are dropped.
  static Set<NavTab> parseHidden(String? raw) => {
    for (final name in (raw ?? '').split(','))
      if (NavTab.fromName(name.trim()) case final tab?
          when defaults.contains(tab))
        tab,
  };

  NavLayout get _current => state.value ?? const NavLayout(defaults);

  @override
  Future<NavLayout> build() async {
    try {
      final database = ref.read(databaseProvider);
      return NavLayout(
        parse(await database.getSetting(settingKey)),
        parseHidden(await database.getSetting(hiddenKey)),
      );
    } catch (_) {
      return const NavLayout(defaults);
    }
  }

  Future<void> save(NavLayout layout) async {
    state = AsyncData(layout);
    final database = ref.read(databaseProvider);
    await database.setSetting(
      settingKey,
      layout.order.map((t) => t.name).join(','),
    );
    await database.setSetting(
      hiddenKey,
      layout.hidden.map((t) => t.name).join(','),
    );
  }

  Future<void> move(int from, int to) {
    final layout = _current;
    final order = [...layout.order];
    order.insert(to, order.removeAt(from));
    return save(NavLayout(order, layout.hidden));
  }

  Future<void> setHidden(NavTab tab, bool hidden) {
    final layout = _current;
    if (!defaults.contains(tab)) return Future.value();
    return save(
      NavLayout(layout.order, {
        ...layout.hidden.where((t) => t != tab),
        if (hidden) tab,
      }),
    );
  }

  Future<void> reset() => save(const NavLayout(defaults));
}

final navOrderProvider = AsyncNotifierProvider<NavOrder, NavLayout>(
  NavOrder.new,
);

/// The pages the sidebar shows, in order; defaults until loaded.
List<NavTab> navMainTabs(WidgetRef ref) =>
    (ref.watch(navOrderProvider).value ?? const NavLayout(NavOrder.defaults))
        .visible;

/// Where to land when [tab] was asked for but is hidden: the first page
/// the sidebar shows, or Settings when every page is hidden.
NavTab navShownTab(NavLayout layout, NavTab tab) {
  if (!layout.hidden.contains(tab)) return tab;
  return layout.visible.firstOrNull ?? NavTab.settings;
}
