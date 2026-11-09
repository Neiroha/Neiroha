import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/adapters/openai_tts_adapter.dart';
import 'package:neiroha/data/adapters/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:path/path.dart' as p;

const _id = 'default-openai-official';

Future<db.TtsProvider?> _openAiRow(db.AppDatabase database) async {
  final rows = await database.select(database.ttsProviders).get();
  return rows.where((r) => r.id == _id).firstOrNull;
}

void main() {
  test('new databases seed a disabled official OpenAI provider', () async {
    final database = db.AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final row = await _openAiRow(database);
    expect(row, isNotNull);
    expect(row!.adapterType, 'openaiTts');
    expect(row.baseUrl, 'https://api.openai.com/v1');
    expect(row.defaultModelName, OpenAiTtsAdapter.defaultModel);
    expect(row.enabled, isFalse);
    expect(createAdapter(row), isA<OpenAiTtsAdapter>());
  });

  test(
    'upgrading from v31 adds the row once and keeps positions unique',
    () async {
      final dir = await Directory.systemTemp.createTemp('neiroha_seed_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File(p.join(dir.path, 'neiroha.db'));

      // Build a current database, then roll it back to look like v31.
      var database = db.AppDatabase.forTesting(NativeDatabase(file));
      await (database.delete(
        database.ttsProviders,
      )..where((t) => t.id.equals(_id))).go();
      await database.customStatement('PRAGMA user_version = 31');
      await database.close();

      database = db.AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(database.close);
      final rows = await database.select(database.ttsProviders).get();
      expect(rows.where((r) => r.id == _id), hasLength(1));
      final positions = rows.map((r) => r.position).toList();
      expect(positions.toSet(), hasLength(positions.length));
      final openAi = rows.singleWhere((r) => r.id == _id);
      expect(openAi.position, positions.reduce((a, b) => a > b ? a : b));
    },
  );
}
