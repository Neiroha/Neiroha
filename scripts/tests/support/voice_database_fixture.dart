// In-memory database helpers shared by the voice database tests.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;

db.AppDatabase memoryDatabase() {
  final database = db.AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(database.close);
  return database;
}

Future<void> insertProvider(db.AppDatabase database, String providerId) {
  return database.insertProvider(
    db.TtsProvidersCompanion(
      id: Value(providerId),
      name: Value(providerId),
      adapterType: const Value('openaiCompatible'),
      baseUrl: const Value('http://localhost'),
    ),
  );
}
