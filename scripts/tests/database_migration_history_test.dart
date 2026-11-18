import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/data/database/schema_version.dart';

void main() {
  final history =
      jsonDecode(
            File(
              'scripts/tests/fixtures/database_schemas/history.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final ddl = (history['ddl'] as List).cast<String>();
  final versions = history['versions'] as Map<String, dynamic>;
  Iterable<String> schema(int version) sync* {
    for (final index in versions['$version']['ddl'] as List) {
      yield ddl[index as int];
    }
  }

  late Map<String, Object> currentSchema;
  setUpAll(() async {
    final fresh = AppDatabase.forTesting(NativeDatabase.memory());
    try {
      currentSchema = await _describeSchema(fresh);
    } finally {
      await fresh.close();
    }
  });

  for (final key in versions.keys) {
    final version = int.parse(key);
    test(
      'v$version (${versions[key]['commit']}) preserves data through v$neirohaSchemaVersion',
      () async {
        final db = AppDatabase.forTesting(
          NativeDatabase.memory(
            setup: (sqlite) {
              for (final sql in schema(version)) {
                sqlite.execute(sql);
              }
              sqlite.userVersion = version;
              sqlite.execute('PRAGMA foreign_keys = ON');
              sqlite.execute(
                "INSERT INTO tts_providers (id, name, adapter_type, base_url, enabled) "
                "VALUES ('provider', '自定义连接', 'openaiCompatible', 'http://localhost:8080/v1', 1)",
              );
              sqlite.execute(
                "INSERT INTO model_bindings (id, provider_id, model_key) "
                "VALUES ('binding', 'provider', 'model')",
              );
              sqlite.execute(
                "INSERT INTO voice_assets (id, name, provider_id, model_binding_id, task_mode) "
                "VALUES ('voice', '测试角色', 'provider', 'binding', 'presetVoice')",
              );
              sqlite.execute(
                "INSERT INTO tts_jobs (id, voice_asset_id, input_text, status, created_at) "
                "VALUES ('job', 'voice', '保留这句原文', 'pending', 123)",
              );
              if (version >= 17) {
                sqlite.execute(
                  "INSERT INTO voice_banks (id, name, created_at) VALUES ('bank', '配音', 123)",
                );
                sqlite.execute(
                  "INSERT INTO novel_projects (id, name, bank_id, reader_theme, created_at, updated_at) "
                  "VALUES ('book', '小说', 'bank', 'comfort', 123, 123)",
                );
                sqlite.execute(
                  "INSERT INTO novel_chapters (id, project_id, order_index, title, raw_text) "
                  "VALUES ('chapter', 'book', 0, '章节', '𠮷野🌸')",
                );
              }
            },
          ),
        );
        addTearDown(db.close);
        expect(await _describeSchema(db), currentSchema);
        expect(await _pragma(db, 'user_version'), neirohaSchemaVersion);
        expect(await _pragma(db, 'foreign_keys'), 1);
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        expect(
          await db
              .customSelect('PRAGMA integrity_check')
              .getSingle()
              .then((r) => r.data.values.single),
          'ok',
        );
        final provider = (await db.select(db.ttsProviders).get()).singleWhere(
          (p) => p.id == 'provider',
        );
        expect(provider.name, '自定义连接');
        expect(provider.enabled, isTrue);
        expect(
          (await db.select(db.voiceAssets).get()).single.modelBindingId,
          'binding',
        );
        expect((await db.select(db.ttsJobs).get()).single.inputText, '保留这句原文');
        if (version >= 17) {
          expect(
            (await db.select(db.novelChapters).get()).single.rawText,
            '𠮷野🌸',
          );
          expect(
            (await db.select(db.novelProjects).get()).single.readerTheme,
            version < 18 ? 'dark' : 'comfort',
          );
        }
      },
    );
  }

  test(
    'a failed late step rolls back previous table changes and the version',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'neiroha_schema_rollback_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/history.db');
      final db = AppDatabase.forTesting(
        NativeDatabase(
          file,
          setup: (sqlite) {
            for (final sql in schema(25)) {
              sqlite.execute(sql);
            }
            sqlite.userVersion = 25;
            sqlite.execute(
              "INSERT INTO tts_providers (id, name, adapter_type, base_url, default_model_name) "
              "VALUES ('default-cosyvoice', 'Custom', 'cosyvoice', 'http://localhost:19890', 'default')",
            );
            sqlite.execute(
              "CREATE TRIGGER migration_failure BEFORE UPDATE ON tts_providers "
              "BEGIN SELECT RAISE(ABORT, 'test v29 failure'); END",
            );
          },
        ),
      );
      try {
        await expectLater(
          db.customSelect('SELECT 1').get(),
          throwsA(
            predicate((Object e) => e.toString().contains('test v29 failure')),
          ),
        );
      } finally {
        await db.close();
      }
      final raw = NativeDatabase(file);
      addTearDown(raw.close);
      await raw.ensureOpen(_RawDatabase(25));
      expect(
        (await raw.runSelect('PRAGMA user_version', [])).single['user_version'],
        25,
      );
      expect(
        (await raw.runSelect(
          'PRAGMA table_info(novel_projects)',
          [],
        )).map((r) => r['name']),
        isNot(contains('playback_gap_seconds')),
      );
      expect(
        (await raw.runSelect(
          'SELECT base_url FROM tts_providers',
          [],
        )).single['base_url'],
        'http://localhost:19890',
      );
    },
  );

  test('a newer schema is refused and keeps its original version', () async {
    final directory = await Directory.systemTemp.createTemp(
      'neiroha_newer_schema_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/newer.db');
    const newer = neirohaSchemaVersion + 1;
    final db = AppDatabase.forTesting(
      NativeDatabase(
        file,
        setup: (sqlite) {
          sqlite.userVersion = newer;
          sqlite.execute('CREATE TABLE newer_table (id INTEGER PRIMARY KEY)');
        },
      ),
    );
    try {
      await expectLater(db.customSelect('SELECT 1').get(), throwsStateError);
    } finally {
      await db.close();
    }
    final raw = NativeDatabase(file);
    addTearDown(raw.close);
    await raw.ensureOpen(_RawDatabase(newer));
    expect(
      (await raw.runSelect('PRAGMA user_version', [])).single['user_version'],
      newer,
    );
    expect(
      (await raw.runSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
        [],
      )).single['name'],
      'newer_table',
    );
  });
}

Future<int> _pragma(AppDatabase db, String key) async =>
    (await db.customSelect('PRAGMA $key').getSingle()).read<int>(key);

Future<Map<String, Object>> _describeSchema(AppDatabase db) async {
  final tables = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
      )
      .get();
  return {
    for (final row in tables)
      row.read<String>('name'): {
        'columns': {
          for (final c
              in await db
                  .customSelect(
                    'PRAGMA table_info(${row.read<String>('name')})',
                  )
                  .get())
            c.read<String>('name'): [
              c.data['type'],
              c.data['notnull'],
              c.data['dflt_value'],
              c.data['pk'],
            ],
        },
        'foreignKeys':
            (await db
                    .customSelect(
                      'PRAGMA foreign_key_list(${row.read<String>('name')})',
                    )
                    .get())
                .map((r) => jsonEncode(r.data..remove('id')))
                .toList()
              ..sort(),
      },
  };
}

class _RawDatabase extends QueryExecutorUser {
  _RawDatabase(this.schemaVersion);
  @override
  final int schemaVersion;
  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
