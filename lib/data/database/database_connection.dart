import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// VACUUM INTO captures a consistent snapshot, including WAL contents, before
/// Drift starts its migration transaction. Existing backup files are retained.
QueryExecutor openNeirohaDatabase(File file) =>
    NativeDatabase.createInBackground(
      file,
      setup: (sqlite) {
        final version =
            sqlite.select('PRAGMA user_version').first['user_version'] as int;
        if (version > 0 && version < 33) {
          final backup = File('${file.path}.before-v33.bak');
          if (!backup.existsSync()) {
            sqlite.execute('VACUUM INTO ?', [backup.path]);
          }
        }
      },
    );
