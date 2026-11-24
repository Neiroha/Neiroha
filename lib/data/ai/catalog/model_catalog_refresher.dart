import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/capabilities/catalog_normalizer.dart';

import 'llm_traits_catalog.dart';

/// Keeps a normalized models.dev catalog fresh: downloaded at most once a
/// day, stored in app settings with its date, and layered over the bundled
/// snapshots. Public data only: no credentials leave the app.
class ModelCatalogRefresher {
  ModelCatalogRefresher(
    this.database, {
    Dio? http,
    DateTime Function()? now,
    this.maxAge = const Duration(days: 1),
  }) : _http = http ?? Dio(),
       _now = now ?? DateTime.now;

  static const url = 'https://models.dev/api.json';
  static const key = 'model.catalog.modelsdev';
  static const checkedKey = 'model.catalog.modelsdev.checkedAt';

  final db.AppDatabase database;
  final Dio _http;
  final DateTime Function() _now;
  final Duration maxAge;

  /// The cached download, or null when none was stored or it is corrupt.
  Future<LlmTraitsCatalog?> cached() async {
    try {
      final raw = await database.getSetting(key);
      if (raw == null || raw.isEmpty) return null;
      return LlmTraitsCatalog.fromSnapshot(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// Downloads when the last attempt is older than [maxAge] (or [force]).
  /// Returns true when a new catalog was stored. Failures (offline, no
  /// database yet) keep whatever is cached.
  Future<bool> refresh({bool force = false}) async {
    try {
      final checked = DateTime.tryParse(
        await database.getSetting(checkedKey) ?? '',
      );
      if (!force && checked != null && _now().difference(checked) < maxAge) {
        return false;
      }
      await database.setSetting(checkedKey, _now().toUtc().toIso8601String());
      final response = await _http.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      final bytes = response.data ?? const [];
      if (bytes.isEmpty || bytes.length > 32 * 1024 * 1024) return false;
      final snapshot = normalizeModelsDevCatalog(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
        digest: sha256.convert(bytes).toString(),
      );
      await database.setSetting(key, jsonEncode(snapshot));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Fresh download (when cached) over the bundled snapshots.
  Future<LlmTraitsCatalog> catalog() async {
    final bundled = await LlmTraitsCatalog.bundled();
    final fresh = await cached();
    return fresh == null ? bundled : fresh.over(bundled);
  }
}
