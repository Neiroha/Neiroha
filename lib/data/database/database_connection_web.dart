import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

LazyDatabase openAppConnection() => LazyDatabase(() async {
  final database = await WasmDatabase.open(
    databaseName: 'neiroha',
    sqlite3Uri: Uri.base.resolve('sqlite3.wasm'),
    driftWorkerUri: Uri.base.resolve('drift_worker.js'),
  );
  final storage = database.chosenImplementation;
  if (storage == WasmStorageImplementation.inMemory ||
      storage == WasmStorageImplementation.unsafeIndexedDb) {
    await database.resolvedExecutor.close();
    throw StateError('Browser storage for Neiroha is unavailable.');
  }
  return database.resolvedExecutor;
});

/// The browser database has no isolate to wait for.
Future<void> databaseIsolatesExited() async {}
