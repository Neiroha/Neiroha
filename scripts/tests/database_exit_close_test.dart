// Quitting closes SQLite even while a stream query's listener is paused
// (Riverpod pauses providers nobody watches); a plain close() would wait
// for that listener forever. It also waits until the SQLite isolate has
// exited: drift answers a close before the file is shut, and ending the
// process then crashes in sqlite3_close.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/data/database/database_connection.dart';

void main() {
  test('closeConnection does not wait for paused stream listeners', () async {
    final dir = await Directory.systemTemp.createTemp('neiroha_exit');
    addTearDown(() => dir.delete(recursive: true));
    final db = AppDatabase.forTesting(
      openNeirohaDatabase(File('${dir.path}/neiroha.db')),
    );
    final paused = db.select(db.voiceBanks).watch().listen((_) {});
    final live = db.select(db.voiceAssets).watch().listen((_) {});
    await db.getSetting('probe');
    paused.pause();

    // The plain close would hang here; closing the connection does not.
    await db.closeConnection().timeout(const Duration(seconds: 3));
    expect(() => db.getSetting('probe'), throwsA(anything));
    await live.cancel();
    paused.resume();
    await paused.cancel();
  });

  test('closeConnection returns only after the SQLite isolate exits', () async {
    final dir = await Directory.systemTemp.createTemp('neiroha_exit');
    addTearDown(() => dir.delete(recursive: true));
    final db = AppDatabase.forTesting(
      openNeirohaDatabase(File('${dir.path}/neiroha.db')),
    );
    // Many cached statements make the shutdown slow enough to race.
    for (var i = 0; i < 200; i++) {
      await db.setSetting('k$i', 'v$i');
      await db.getSetting('k$i');
    }
    var exited = false;
    final watcher = databaseIsolatesExited().then((_) => exited = true);
    expect(exited, isFalse);
    await db.closeConnection().timeout(const Duration(seconds: 5));
    await Future<void>.delayed(Duration.zero);
    expect(exited, isTrue);
    await watcher;
    // Nothing is left running to wait for.
    await databaseIsolatesExited().timeout(const Duration(milliseconds: 50));
  });
}
