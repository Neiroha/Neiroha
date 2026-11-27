import 'package:drift/drift.dart';

import '../app_database.dart';
import '../database_defaults.dart';
import 'legacy_schema_repair.dart';
import 'schema_editor.dart';
import 'v002.dart';
import 'v004.dart';
import 'v005.dart';
import 'v006.dart';
import 'v009.dart';
import 'v012.dart';
import 'v013.dart';
import 'v014.dart';
import 'v016.dart';
import 'v017.dart';
import 'v018.dart';
import 'v019.dart';
import 'v020.dart';
import 'v021.dart';
import 'v022.dart';
import 'v023.dart';
import 'v024.dart';
import 'v025.dart';
import 'v026.dart';
import 'v027.dart';
import 'v029.dart';
import 'v030.dart';
import 'v031.dart';
import 'v032.dart';
import 'v033.dart';
import 'v034.dart';
import 'v035.dart';
import 'v036.dart';
import 'v037.dart';

typedef _MigrationStep = Future<void> Function(SchemaEditor);

// Keys are destination versions. A null value documents an intentional gap
// or a version bump with no persisted schema or data change.
const _steps = <int, _MigrationStep?>{
  2: upgradeToV2,
  3: null,
  4: upgradeToV4,
  5: upgradeToV5,
  6: upgradeToV6,
  7: null,
  8: null,
  9: upgradeToV9,
  10: null,
  11: null,
  12: upgradeToV12,
  13: upgradeToV13,
  14: upgradeToV14,
  15: null,
  16: upgradeToV16,
  17: upgradeToV17,
  18: upgradeToV18,
  19: upgradeToV19,
  20: upgradeToV20,
  21: upgradeToV21,
  22: upgradeToV22,
  23: upgradeToV23,
  24: upgradeToV24,
  25: upgradeToV25,
  26: upgradeToV26,
  27: upgradeToV27,
  28: null,
  29: upgradeToV29,
  30: upgradeToV30,
  31: upgradeToV31,
  32: upgradeToV32,
  33: upgradeToV33,
  34: upgradeToV34,
  35: upgradeToV35,
  36: upgradeToV36,
  37: upgradeToV37,
};

MigrationStrategy databaseMigrationStrategy(AppDatabase db) =>
    MigrationStrategy(
      onCreate: (m) => db.transaction(() async {
        await m.createAll();
        await db.seedDefaults();
        await db.customStatement('PRAGMA user_version = ${db.schemaVersion}');
      }),
      onUpgrade: (m, from, to) => _upgrade(db, m, from, to),
      beforeOpen: (details) async {
        if (!details.wasCreated && !details.hadUpgrade) {
          await db.transaction(() => repairLegacySchema(db, Migrator(db)));
        }
      },
    );

Future<void> _upgrade(AppDatabase db, Migrator m, int from, int to) async {
  if (from > to) {
    throw StateError(
      'Database schema v$from requires a newer Neiroha (this build supports v$to).',
    );
  }
  for (var version = from + 1; version <= to; version++) {
    if (!_steps.containsKey(version)) {
      throw StateError('Missing database migration to v$version.');
    }
  }
  // Only v2 and v6 rebuild a referenced table. SQLite requires the change
  // outside the transaction and the previous setting is restored on exit.
  final restoreForeignKeys =
      from < 6 &&
      (await db.customSelect('PRAGMA foreign_keys').getSingle()).read<int>(
            'foreign_keys',
          ) ==
          1;
  if (restoreForeignKeys) await db.customStatement('PRAGMA foreign_keys = OFF');
  try {
    await db.transaction(() async {
      final editor = SchemaEditor(db);
      // Address release files that were stamped despite missing tables before
      // later data transforms need them.
      if (from >= 26 && from <= 32) await upgradeToV26(editor);
      for (var version = from + 1; version <= to; version++) {
        await _steps[version]?.call(editor);
      }
      if (to == db.schemaVersion) await repairLegacySchema(db, m);
      // Commit the version marker together with the DDL and data fixes.
      await db.customStatement('PRAGMA user_version = $to');
    });
  } finally {
    if (restoreForeignKeys) {
      await db.customStatement('PRAGMA foreign_keys = ON');
    }
  }
}
