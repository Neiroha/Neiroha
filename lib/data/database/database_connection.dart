import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import '../storage/path_service.dart';
import 'schema_version.dart';

/// VACUUM INTO captures a consistent snapshot, including WAL contents, before
/// Drift starts its migration transaction. Existing backup files are retained.
QueryExecutor openNeirohaDatabase(File file) =>
    NativeDatabase.createInBackground(
      file,
      setup: (sqlite) {
        final version =
            sqlite.select('PRAGMA user_version').first['user_version'] as int;
        if (version > 0 && version < neirohaSchemaVersion) {
          final backup = File('${file.path}.before-v$neirohaSchemaVersion.bak');
          if (!backup.existsSync()) {
            sqlite.execute('VACUUM INTO ?', [backup.path]);
          }
        }
      },
    );

LazyDatabase openAppConnection() {
  return LazyDatabase(() async {
    await PathService.instance.init();
    final dataDir = PathService.instance.dataRoot;
    final file = await _resolveDatabaseFile(dataDir);
    return openNeirohaDatabase(file);
  });
}

Future<File> _resolveDatabaseFile(Directory dataDir) async {
  final currentFile = File(p.join(dataDir.path, 'neiroha.db'));
  if (await currentFile.exists()) return currentFile;

  // Portable release folders must start clean. Earlier builds stored the DB
  // inside the Flutter bundle's `data/` directory and tried to copy legacy
  // app-support DBs automatically, which made fresh release extractions pick
  // up local development/user test databases.
  if (PathService.instance.isPortable) {
    return currentFile;
  }

  for (final legacyFile in _legacyDatabaseCandidates(dataDir)) {
    if (await legacyFile.exists()) {
      await legacyFile.copy(currentFile.path);
      return currentFile;
    }
  }

  return currentFile;
}

Iterable<File> _legacyDatabaseCandidates(Directory dataDir) sync* {
  // The previous (v0.1.x) database lived directly in the OS app-support
  // directory, not inside a `data/` subfolder. Copy from there if present.
  final legacySupport = PathService.instance.legacyAppSupportDir;
  yield File(p.join(legacySupport.path, 'neiroha.db'));
  yield File(p.join(legacySupport.path, 'q_vox_lab.db'));
  // Also check the parent of data/ for apps that used to put the DB in the
  // appRoot (portable-mode pre-migration).
  yield File(p.join(dataDir.parent.path, 'neiroha.db'));
  yield File(p.join(dataDir.parent.path, 'q_vox_lab.db'));

  final candidateDirs = <String>{};

  void addCandidate(String path) {
    if (path != legacySupport.path) {
      candidateDirs.add(path);
    }
  }

  addCandidate(
    legacySupport.path.replaceAll(
      'com.neiroha.neiroha',
      'com.qvoxlab.q_vox_lab',
    ),
  );
  addCandidate(
    legacySupport.path.replaceAll(
      '${Platform.pathSeparator}neiroha',
      '${Platform.pathSeparator}q_vox_lab',
    ),
  );
  addCandidate(
    legacySupport.path.replaceAll(
      '${Platform.pathSeparator}Neiroha',
      '${Platform.pathSeparator}q_vox_lab',
    ),
  );

  for (final dirPath in candidateDirs) {
    yield File(p.join(dirPath, 'neiroha.db'));
    yield File(p.join(dirPath, 'q_vox_lab.db'));
  }
}
