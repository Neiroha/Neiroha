import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import '../storage/path_service.dart';
import 'schema_version.dart';

/// The SQLite isolates still running; each future completes once its
/// isolate has exited, which is after its file is closed.
final _runningIsolates = <Future<void>>{};

/// Completes once every database isolate has exited.
///
/// Drift answers a close as soon as its isolate *starts* shutting down, so
/// quitting right after it can end the process while the isolate is still
/// in sqlite3_close, which crashes. Waiting here closes that gap.
Future<void> databaseIsolatesExited() => Future.wait(_runningIsolates.toList());

/// Opens [file] in a background isolate, as drift's createInBackground does,
/// but keeps track of the isolate so [databaseIsolatesExited] can wait for it.
QueryExecutor openNeirohaDatabase(File file) =>
    DatabaseConnection.delayed(_spawnDatabaseIsolate(file.absolute.path));

Future<DatabaseConnection> _spawnDatabaseIsolate(String path) async {
  final ready = ReceivePort();
  final exit = ReceivePort();
  try {
    await Isolate.spawn(
      _serveDatabase,
      (path, ready.sendPort),
      onExit: exit.sendPort,
      debugName: 'Drift isolate for $path',
    );
  } catch (_) {
    ready.close();
    exit.close();
    rethrow;
  }
  final exited = exit.first.then<void>((_) {});
  _runningIsolates.add(exited);
  unawaited(exited.whenComplete(() => _runningIsolates.remove(exited)));
  // An isolate that dies while opening never answers; fail instead of
  // waiting forever.
  final answer = await Future.any<Object?>([
    ready.first,
    exited.then((_) => throw StateError('The database isolate exited.')),
  ]);
  ready.close();
  return (answer as DriftIsolate).connect(singleClientMode: true);
}

Future<void> _serveDatabase((String, SendPort) start) async {
  final (path, reply) = start;
  final file = File(path);
  await _bindSqliteFunctions();
  reply.send(
    DriftIsolate.inCurrent(
      () => DatabaseConnection(
        NativeDatabase(file, setup: _backupBeforeMigration(file)),
      ),
      shutdownAfterLastDisconnect: true,
      killIsolateWhenDone: true,
    ),
  );
}

/// Runs, once and before the real database opens, every kind of SQLite
/// call drift makes: opening, binding and reading each value type, writes
/// with their row counts, a reused statement, a batch, transactions, an
/// error, and closing.
///
/// Dart looks each SQLite function up the first time it is called. When the
/// app's files are replaced while it runs (an update or a rebuild), a later
/// first lookup loads a second copy of SQLite that was never initialised,
/// and handing it the real database crashes (seen in sqlite3_close at
/// quit). Calling them all now binds them to the copy that opens the file.
/// Isolates spawned from this one share the bindings.
Future<void> _bindSqliteFunctions() async {
  final probe = NativeDatabase.memory();
  try {
    await probe.ensureOpen(const _ProbeUser());
    await probe.runCustom(
      'CREATE TABLE t (i INTEGER, r REAL, s TEXT, b BLOB, n TEXT)',
    );
    final args = [
      1,
      0.5,
      'a',
      Uint8List.fromList(const [1, 2]),
      null,
    ];
    await probe.runInsert('INSERT INTO t VALUES (?, ?, ?, ?, ?)', args);
    // The same cached statement again: reset and rebind.
    await probe.runInsert('INSERT INTO t VALUES (?, ?, ?, ?, ?)', args);
    await probe.runSelect('SELECT * FROM t WHERE i = ?', const [1]);
    await probe.runUpdate('UPDATE t SET s = ? WHERE i = ?', const ['b', 1]);
    await probe.runBatched(
      BatchedStatements(
        ['DELETE FROM t WHERE i = ?'],
        [
          ArgumentsForBatchedStatement(0, const [1]),
        ],
      ),
    );
    for (final commit in [true, false]) {
      final transaction = probe.beginTransaction();
      await transaction.ensureOpen(const _ProbeUser());
      await transaction.runDelete('DELETE FROM t', const []);
      await (commit ? transaction.send() : transaction.rollback());
    }
    try {
      await probe.runSelect('SELECT * FROM missing_table', const []);
    } catch (_) {
      // Expected: binds the functions that describe an error.
    }
  } finally {
    await probe.close();
  }
}

class _ProbeUser implements QueryExecutorUser {
  const _ProbeUser();
  @override
  int get schemaVersion => 1;
  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) =>
      Future.value();
}

/// VACUUM INTO captures a consistent snapshot, including WAL contents, before
/// Drift starts its migration transaction. Existing backup files are retained.
DatabaseSetup _backupBeforeMigration(File file) => (sqlite) {
  final version =
      sqlite.select('PRAGMA user_version').first['user_version'] as int;
  if (version > 0 && version < neirohaSchemaVersion) {
    final backup = File('${file.path}.before-v$neirohaSchemaVersion.bak');
    if (!backup.existsSync()) {
      sqlite.execute('VACUUM INTO ?', [backup.path]);
    }
  }
};

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
