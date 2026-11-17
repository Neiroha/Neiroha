import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:neiroha/data/adapters/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/capabilities/model_capability.dart';

import 'capability_repository.dart';

class DiscoveredModel {
  const DiscoveredModel({
    required this.id,
    required this.name,
    required this.capability,
  });
  final String id;
  final String name;
  final ModelCapability capability;
}

class ModelDiscoveryService {
  ModelDiscoveryService(
    this.database,
    this.capabilities, {
    Future<String> Function()? loadCatalog,
  }) : _loadCatalog =
           loadCatalog ??
           (() => rootBundle.loadString(
             'assets/model_catalog/model_capabilities.snapshot.json',
           ));
  final db.AppDatabase database;
  final CapabilityRepository capabilities;
  final Future<String> Function() _loadCatalog;
  Map<String, dynamic>? _catalog;

  Future<List<DiscoveredModel>> discover(
    db.TtsProvider provider,
    ServiceRoute route,
  ) async {
    final uri = Uri.parse(
      provider.baseUrl.endsWith('/')
          ? provider.baseUrl
          : '${provider.baseUrl}/',
    );
    final dio = Dio(
      BaseOptions(
        baseUrl: uri.toString(),
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
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
      Response<dynamic> response;
      try {
        response = await dio.get(
          'models',
          queryParameters: uri.host == 'openrouter.ai'
              ? {'output_modalities': 'all'}
              : null,
        );
      } on DioException catch (error) {
        if (error.response?.statusCode != 404) rethrow;
        response = await dio.get('v1/models');
      }
      final data = response.data;
      final list = data is Map ? data['data'] ?? data['models'] : data;
      if (list is! List) {
        throw const FormatException('Model list was not an array.');
      }
      final catalog = await _readCatalog();
      final result = <DiscoveredModel>[];
      final seen = <String>{};
      for (final raw in list) {
        if (raw is! Map) continue;
        final id = raw['id'];
        if (id is! String || id.isEmpty || !seen.add(id)) continue;
        final facts = <String, CapabilityEvidence>{};
        final publicProvider = switch (uri.host) {
          'api.openai.com' => 'openai',
          'openrouter.ai' => 'openrouter',
          _ => null,
        };
        // Aliases at custom gateways are never matched to official facts by name.
        final entry = publicProvider == null
            ? null
            : catalog['$publicProvider::$id'];
        if (entry is Map && entry['facts'] is Map) {
          final endpoints = (entry['endpoints'] as List?)?.cast<String>() ?? [];
          if (endpoints.isEmpty || _serves(endpoints, route)) {
            for (final field in (entry['facts'] as Map).entries) {
              facts['${field.key}'] = CapabilityEvidence(
                CapabilitySupport.values.byName('${field.value}'),
                CapabilitySource.catalog,
              );
            }
          }
        }
        final architecture = raw['architecture'];
        final outputs = architecture is Map
            ? architecture['output_modalities']
            : raw['supported_output_modalities'];
        if (outputs is List) {
          facts['text'] = CapabilityEvidence(
            outputs.contains('text')
                ? CapabilitySupport.supported
                : CapabilitySupport.unsupported,
            CapabilitySource.provider,
          );
          if (outputs.contains('audio') || outputs.contains('speech')) {
            facts['audioOutput'] = const CapabilityEvidence(
              CapabilitySupport.supported,
              CapabilitySource.provider,
            );
          }
        }
        final endpoints = raw['endpoints'] ?? raw['supported_endpoints'];
        if (endpoints is List &&
            _serves(
              endpoints.whereType<String>().toList(),
              ServiceRoute.speech,
            )) {
          facts['speech'] = const CapabilityEvidence(
            CapabilitySupport.supported,
            CapabilitySource.provider,
          );
        }
        final parameters = raw['supported_parameters'];
        if (parameters is List &&
            (parameters.contains('response_format') ||
                parameters.contains('structured_outputs'))) {
          facts['structuredOutput'] = const CapabilityEvidence(
            CapabilitySupport.supported,
            CapabilitySource.provider,
          );
        }
        final discovered = ModelCapability(
          connectionId: capabilities.scope(provider),
          modelId: id,
          route: route,
          facts: facts,
        );
        final saved = (await capabilities.load(
          provider,
          id,
          route,
        )).merge(discovered);
        await capabilities.save(provider, saved);
        result.add(
          DiscoveredModel(
            id: id,
            name: raw['name'] as String? ?? id,
            capability: saved,
          ),
        );
      }
      await database.setSetting(
        _inventoryKey(provider, route),
        jsonEncode(result.map((m) => {'id': m.id, 'name': m.name}).toList()),
      );
      return result;
    } finally {
      dio.close(force: true);
    }
  }

  Future<List<DiscoveredModel>> cached(
    db.TtsProvider provider,
    ServiceRoute route,
  ) async {
    final raw = await database.getSetting(_inventoryKey(provider, route));
    final declaration = await database.getSetting(
      'model.declaration.inventory.${capabilities.scope(provider)}.${route.name}',
    );
    final rows = <String, Map>{
      for (final row in [
        ...(raw == null ? [] : jsonDecode(raw) as List),
        ...(declaration == null ? [] : jsonDecode(declaration) as List),
      ])
        row['id'] as String: row as Map,
    };
    return [
      for (final row in rows.values)
        DiscoveredModel(
          id: row['id'] as String,
          name: row['name'] as String,
          capability: await capabilities.load(
            provider,
            row['id'] as String,
            route,
          ),
        ),
    ];
  }

  Future<List<ModelInfo>> modelsForProvider(db.TtsProvider provider) async {
    if (![
      'openaiTts',
      'openaiCompatible',
      'chatCompletionsTts',
    ].contains(provider.adapterType)) {
      return createAdapter(provider).getModels();
    }
    return (await discover(
      provider,
      ServiceRoute.speech,
    )).map((m) => ModelInfo(id: m.id, name: m.name)).toList();
  }

  Future<Map<String, dynamic>> _readCatalog() async {
    if (_catalog != null) return _catalog!;
    try {
      final data = jsonDecode(await _loadCatalog());
      if (data is! Map || data['version'] != 1 || data['models'] is! Map) {
        throw const FormatException('Invalid model catalog schema.');
      }
      return _catalog = Map<String, dynamic>.from(data['models'] as Map);
    } on FormatException {
      rethrow;
    }
  }

  String _inventoryKey(db.TtsProvider provider, ServiceRoute route) =>
      'model.inventory.${capabilities.scope(provider)}.${route.name}';
  static bool _serves(List<String> endpoints, ServiceRoute route) =>
      endpoints.any(
        (path) => switch (route) {
          ServiceRoute.chatCompletions => path.endsWith('/chat/completions'),
          ServiceRoute.responses => path.endsWith('/responses'),
          ServiceRoute.speech => path.endsWith('/audio/speech'),
          ServiceRoute.realtime => path.contains('/realtime'),
          ServiceRoute.native => false,
        },
      );
}
