// The sidebar order: stored names, new pages, moves and reset.
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/navigation/app_navigation.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/nav_order_provider.dart';

void main() {
  test('stored order wins; unknown names drop, missing pages append', () {
    expect(NavOrder.parse(null), NavOrder.defaults);
    final order = NavOrder.parse(
      'voiceBank, nope,dialogTts,voiceBank,settings',
    );
    expect(order.take(2), [NavTab.voiceBank, NavTab.dialogTts]);
    expect(order, hasLength(NavOrder.defaults.length));
    expect(order, isNot(contains(NavTab.settings)));
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
    expect(first.read(navOrderProvider).value!.first, NavTab.voiceBank);

    final again = open();
    expect((await again.read(navOrderProvider.future)).first, NavTab.voiceBank);
    await again.read(navOrderProvider.notifier).reset();
    expect(again.read(navOrderProvider).value, NavOrder.defaults);
  });
}
