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
  await _bindCloseFunctions();
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

/// Runs, once and before the real database opens, the SQLite functions that
/// closing it uses.
///
/// Dart looks each function up the first time it is called. When the app's
/// files are replaced while it runs (an update or a rebuild), a lookup made
/// at quit loads a second copy of SQLite that was never initialised, and
/// closing the real database through it crashes in sqlite3_close. Calling
/// them now binds them to the copy that opens the database.
Future<void> _bindCloseFunctions() async {
  final probe = NativeDatabase.memory();
  try {
    await probe.ensureOpen(const _ProbeUser());
    // A cached statement, so closing also finalises one.
    await probe.runSelect('SELECT 1', const []);
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
