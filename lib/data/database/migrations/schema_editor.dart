import 'package:drift/drift.dart';

/// Applies frozen schema definitions without borrowing columns from new versions.
class SchemaEditor {
  SchemaEditor(this.database);

  final GeneratedDatabase database;
  final _columns = <String, Map<String, QueryRow>>{};

  Future<bool> tableExists(String table) async =>
      (await database
          .customSelect(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
            variables: [Variable(table)],
          )
          .getSingleOrNull()) !=
      null;

  Future<Map<String, QueryRow>> _tableInfo(String table) async =>
      _columns[table] ??= {
        for (final row
            in await database
                .customSelect('PRAGMA table_info(${quote(table)})')
                .get())
          row.read<String>('name'): row,
      };

  Future<Set<String>> columns(String table) async =>
      (await _tableInfo(table)).keys.toSet();

  Future<QueryRow?> column(String table, String name) async =>
      (await _tableInfo(table))[name];

  void forgetColumns(String table) => _columns.remove(table);

  Future<void> ensureTable(String table, String sql) async {
    if (await tableExists(table)) return;
    await database.customStatement(sql);
    forgetColumns(table);
  }

  /// Well-formed predecessors have this table. For incomplete release schemas,
  /// the dedicated repair pass creates missing tables at the correct baseline.
  Future<void> addColumns(String table, Map<String, String> definitions) async {
    final existing = await columns(table);
    if (existing.isEmpty) return;
    for (final entry in definitions.entries) {
      if (existing.contains(entry.key)) continue;
      await database.customStatement(
        'ALTER TABLE ${quote(table)} ADD COLUMN ${quote(entry.key)} ${entry.value}',
      );
      forgetColumns(table);
    }
  }

  /// Caller wraps all steps in a transaction with foreign keys disabled for
  /// the rebuild. Retain rows, indexes and triggers, or roll back together.
  Future<void> rebuildTable(String table, String targetDefinition) async {
    final source = await columns(table);
    if (source.isEmpty) {
      await ensureTable(table, targetDefinition);
      return;
    }
    final temp = '_neiroha_migration_$table';
    final dependentSql = await database
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE tbl_name = ? "
          "AND type IN ('index', 'trigger') AND sql IS NOT NULL",
          variables: [Variable(table)],
        )
        .get();
    await database.customStatement(
      targetDefinition.replaceFirst(
        'CREATE TABLE ${quote(table)}',
        'CREATE TABLE ${quote(temp)}',
      ),
    );
    if (!(await columns(temp)).containsAll(source)) {
      throw StateError(
        'Unexpected columns in $table. Migration stopped to preserve them.',
      );
    }
    final names = source.map(quote).join(', ');
    await database.customStatement(
      'INSERT INTO ${quote(temp)} ($names) SELECT $names FROM ${quote(table)}',
    );
    await database.customStatement('DROP TABLE ${quote(table)}');
    await database.customStatement(
      'ALTER TABLE ${quote(temp)} RENAME TO ${quote(table)}',
    );
    forgetColumns(table);
    forgetColumns(temp);
    for (final object in dependentSql) {
      await database.customStatement(object.read<String>('sql'));
    }
  }

  static String quote(String name) => '"${name.replaceAll('"', '""')}"';
}
