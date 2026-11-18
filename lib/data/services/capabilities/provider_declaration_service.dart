import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/capabilities/model_capability.dart';
import 'capability_repository.dart';
import 'model_discovery_service.dart';

/// Read-only, opt-in declaration for gateways. Never modifies a backend.
class ProviderDeclarationService {
  const ProviderDeclarationService(this.database, this.capabilities);
  final db.AppDatabase database;
  final CapabilityRepository capabilities;
  Future<List<DiscoveredModel>> read(
    db.TtsProvider provider,
    ServiceRoute route,
  ) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: provider.baseUrl.endsWith('/')
            ? provider.baseUrl
            : '${provider.baseUrl}/',
        followRedirects: false,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        responseType: ResponseType.plain,
        headers: {
          if (provider.apiKey.isNotEmpty)
            (provider.adapterType == 'chatCompletionsTts'
                ? 'api-key'
                : 'Authorization'): provider.adapterType == 'chatCompletionsTts'
                ? provider.apiKey
                : 'Bearer ${provider.apiKey}',
        },
      ),
    );
    try {
      final response = await dio.get<String>(
        '.well-known/neiroha-capabilities',
      );
      final raw = response.data ?? '';
      if (raw.length > 2 * 1024 * 1024) {
        throw const FormatException('Capability declaration too large.');
      }
      final object = jsonDecode(raw);
      if (object is! Map ||
          object['version'] != 1 ||
          object['models'] is! List ||
          (object['models'] as List).length > 5000) {
        throw const FormatException('Invalid capability declaration.');
      }
      final result = <DiscoveredModel>[];
      final seen = <String>{};
      for (final model in object['models'] as List) {
        if (model is! Map ||
            model['id'] is! String ||
            model['routes'] is! Map ||
            (model['id'] as String).isEmpty ||
            !seen.add(model['id'] as String)) {
          throw const FormatException('Invalid or duplicate declared model.');
        }
        final features = (model['routes'] as Map)[route.name];
        if (features == null) continue;
        if (features is! Map) {
          throw const FormatException('Invalid route features.');
        }
        final facts = <String, CapabilityEvidence>{};
        for (final entry in features.entries) {
          if (!{
            'text',
            'speech',
            'streaming',
            'structuredOutput',
            'functionCalling',
            'audioInput',
            'audioOutput',
            'instructions',
          }.contains(entry.key)) {
            continue;
          }
          if (entry.value != null && entry.value is! bool) {
            throw const FormatException('Capability must be bool or null.');
          }
          facts[entry.key as String] = CapabilityEvidence(
            entry.value == null
                ? CapabilitySupport.unknown
                : entry.value == true
                ? CapabilitySupport.supported
                : CapabilitySupport.unsupported,
            CapabilitySource.provider,
            checkedAt: DateTime.now().toUtc(),
          );
        }
        final record = ModelCapability(
          connectionId: capabilities.scope(provider),
          modelId: model['id'] as String,
          route: route,
          facts: facts,
        );
        result.add(
          DiscoveredModel(
            id: record.modelId,
            name: model['name'] as String? ?? record.modelId,
            capability: (await capabilities.load(
              provider,
              record.modelId,
              route,
            )).merge(record),
          ),
        );
      }
      // Validate the whole document before updating any model.
      await database.transaction(() async {
        for (final m in result) {
          await capabilities.save(provider, m.capability);
        }
        await database.setSetting(
          'model.declaration.inventory.${capabilities.scope(provider)}.${route.name}',
          jsonEncode([
            for (final m in result) {'id': m.id, 'name': m.name},
          ]),
        );
      });
      return result;
    } finally {
      dio.close(force: true);
    }
  }
}
