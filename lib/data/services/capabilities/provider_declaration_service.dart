import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/capabilities/model_capability.dart';
import 'capability_declaration.dart';
import 'capability_repository.dart';
import 'model_discovery_service.dart';

/// Read-only, opt-in declaration for gateways and self-hosted engines
/// (`.well-known/neiroha-capabilities`, see [CapabilityDeclaration]).
/// Never modifies a backend.
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
      final declaration = CapabilityDeclaration.parse(jsonDecode(raw));
      final now = DateTime.now().toUtc();
      final result = <DiscoveredModel>[];
      final declared = <DeclaredModel>[];
      for (final model in declaration.models) {
        final facts = CapabilityDeclaration.evidence(model, route, now);
        if (facts == null) continue;
        final record = ModelCapability(
          connectionId: capabilities.scope(provider),
          modelId: model.id,
          route: route,
          facts: facts,
        );
        declared.add(model);
        result.add(
          DiscoveredModel(
            id: model.id,
            name: model.name,
            capability: (await capabilities.load(
              provider,
              model.id,
              route,
            )).merge(record),
            voices: [for (final v in model.voices) v.label],
            languages: model.languages,
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
            for (final m in declared)
              {
                'id': m.id,
                'name': m.name,
                if (m.languages.isNotEmpty) 'languages': m.languages,
                if (m.voices.isNotEmpty)
                  'voices': [for (final v in m.voices) v.toJson()],
                if (m.paths.isNotEmpty) 'paths': m.paths,
                if (m.streamFormats.isNotEmpty) 'streaming': m.streamFormats,
              },
          ]),
        );
        // Declared voices join the provider's voice list (additive, like
        // adapter discovery: nothing the user already has is removed).
        final existing = {
          for (final b in await database.getBindingsForProvider(provider.id))
            if (b.supportedTaskModes == 'voice') b.modelKey,
        };
        for (final m in declared) {
          for (final v in m.voices) {
            if (!existing.add(v.label)) continue;
            await database.insertBinding(
              db.ModelBindingsCompanion(
                id: Value(const Uuid().v4()),
                providerId: Value(provider.id),
                modelKey: Value(v.label),
                supportedTaskModes: const Value('voice'),
              ),
            );
          }
        }
      });
      return result;
    } finally {
      dio.close(force: true);
    }
  }
}
