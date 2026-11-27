import 'package:drift/drift.dart'
    show QueryExecutorUser, QueryExecutor, OpeningDetails;
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/schema_version.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/database/database_connection.dart';
import 'package:neiroha/data/services/novel/character_repository.dart';
import 'support/novel_fixture.dart';

class _Version32 extends QueryExecutorUser {
  @override
  int get schemaVersion => 32;
  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}

void main() {
  test(
    'v32 upgrade retains novels, creates role tables, and backs up before migration',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'neiroha_migration_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/novels.db');
      var database = db.AppDatabase.forTesting(NativeDatabase(file));
      await seedNovelFixture(database);
      for (final name in [
        'novel_role_edits',
        'novel_voice_bindings',
        'novel_annotations',
        'novel_characters',
      ]) {
        await database.customStatement('DROP TABLE $name');
      }
      await database.customStatement('PRAGMA user_version = 32');
      await database.close();
      database = db.AppDatabase.forTesting(openNeirohaDatabase(file));
      expect(await database.getNovelSegments('book'), hasLength(3));
      final characters = CharacterRepository(database);
      await characters.saveCharacter(projectId: 'book', name: '林舟');
      await database.close();
      final backupFile = File('${file.path}.before-v$neirohaSchemaVersion.bak');
      expect(backupFile.existsSync(), isTrue);
      final backup = NativeDatabase(backupFile);
      await backup.ensureOpen(_Version32());
      expect(
        (await backup.runSelect(
          'PRAGMA user_version',
          [],
        )).single['user_version'],
        32,
      );
      await backup.close();
      database = db.AppDatabase.forTesting(openNeirohaDatabase(file));
      expect(
        (await CharacterRepository(
          database,
        ).load('book')).characters.single.name,
        '林舟',
      );
      await database.close();
    },
  );
}
