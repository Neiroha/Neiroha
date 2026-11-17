import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/capabilities/model_capability.dart';

/// Account and base URL changes invalidate old evidence without storing secrets.
class CapabilityRepository {
  const CapabilityRepository(this.database);
  final db.AppDatabase database;
  String scope(db.TtsProvider provider) =>
      '${provider.id}:${sha256.convert(utf8.encode('${provider.baseUrl}\n${provider.apiKey}'))}';
  String _key(db.TtsProvider p, String model, ServiceRoute route) =>
      'model.capability.${sha256.convert(utf8.encode('${scope(p)}\n$model\n${route.name}'))}';
  Future<ModelCapability> load(
    db.TtsProvider p,
    String model,
    ServiceRoute route,
  ) async {
    final value = await database.getSetting(_key(p, model, route));
    return value == null
        ? ModelCapability(connectionId: scope(p), modelId: model, route: route)
        : ModelCapability.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  Future<void> save(db.TtsProvider p, ModelCapability record) =>
      database.transaction(() async {
        if (record.connectionId != scope(p)) {
          throw ArgumentError('Connection changed.');
        }
        final current = await load(p, record.modelId, record.route);
        await database.setSetting(
          _key(p, record.modelId, record.route),
          jsonEncode(current.merge(record).toJson()),
        );
      });
  Future<void> markSuccess(
    db.TtsProvider p,
    String model,
    ServiceRoute route,
    List<String> features,
  ) => save(
    p,
    ModelCapability(
      connectionId: scope(p),
      modelId: model,
      route: route,
      availability: ModelAvailability.available,
      facts: {
        for (final feature in features)
          feature: CapabilityEvidence(
            CapabilitySupport.supported,
            CapabilitySource.observed,
            checkedAt: DateTime.now().toUtc(),
          ),
      },
    ),
  );
  Future<void> markFailure(
    db.TtsProvider p,
    String model,
    ServiceRoute route,
    int? status,
  ) => save(
    p,
    ModelCapability(
      connectionId: scope(p),
      modelId: model,
      route: route,
      availability: switch (status) {
        401 || 403 => ModelAvailability.authenticationFailed,
        429 => ModelAvailability.rateLimited,
        _ => ModelAvailability.networkFailed,
      },
    ),
  );
}
