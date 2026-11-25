// The sidebar layout: stored order and hidden pages, new pages, moves,
// hiding and reset.
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/navigation/app_navigation.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/nav_order_provider.dart';

void main() {
  test('stored order wins; unknown names drop, missing pages slot in', () {
    expect(NavOrder.parse(null), NavOrder.defaults);
    final order = NavOrder.parse(
      'voiceBank, nope,dialogTts,voiceBank,settings',
    );
    expect(
      order.indexOf(NavTab.voiceBank),
      lessThan(order.indexOf(NavTab.dialogTts)),
    );
    expect(order, hasLength(NavOrder.defaults.length));
    expect(order, isNot(contains(NavTab.settings)));
  });

  test('a page added later lands after its default neighbour', () {
    // An order saved before Character Chat existed.
    final order = NavOrder.parse(
      'voiceBank,dialogTts,novelReader,phaseTts,videoDub,subtitles,music,'
      'voiceAssets',
    );
    expect(order.take(3), [
      NavTab.voiceBank,
      NavTab.dialogTts,
      NavTab.characterChat,
    ]);
  });

  test('a move is saved and survives a restart', () async {
    final database = db.AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    ProviderContainer open() {
      final c = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      addTearDown(c.dispose);
      return c;
    }

    final first = open();
    await first.read(navOrderProvider.future);
    // Voice bank (last) to the top.
    await first
        .read(navOrderProvider.notifier)
        .move(NavOrder.defaults.length - 1, 0);
    expect(first.read(navOrderProvider).value!.order.first, NavTab.voiceBank);
    await first.read(navOrderProvider.notifier).setHidden(NavTab.music, true);
    // Pinned pages cannot be hidden.
    await first
        .read(navOrderProvider.notifier)
        .setHidden(NavTab.settings, true);

    final again = open();
    final layout = await again.read(navOrderProvider.future);
    expect(layout.order.first, NavTab.voiceBank);
    expect(layout.hidden, {NavTab.music});
    expect(layout.visible, isNot(contains(NavTab.music)));
    expect(layout.order, contains(NavTab.music)); // keeps its place
    await again.read(navOrderProvider.notifier).reset();
    final reset = again.read(navOrderProvider).value!;
    expect(reset.order, NavOrder.defaults);
    expect(reset.hidden, isEmpty);
  });

  test('stored hidden pages drop unknown and pinned names', () {
    expect(NavOrder.parseHidden('music, nope,settings,subtitles,'), {
      NavTab.music,
      NavTab.subtitles,
    });
    expect(NavOrder.parseHidden(null), isEmpty);
  });

  test('a hidden startup page falls back to the first shown page', () {
    final layout = NavLayout(NavOrder.defaults, {NavTab.novelReader});
    expect(navShownTab(layout, NavTab.music), NavTab.music);
    expect(navShownTab(layout, NavTab.novelReader), NavTab.dialogTts);
    expect(
      navShownTab(
        NavLayout(NavOrder.defaults, NavOrder.defaults.toSet()),
        NavTab.voiceBank,
      ),
      NavTab.settings,
    );
    expect(navShownTab(layout, NavTab.providers), NavTab.providers);
  });
}
