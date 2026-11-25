import 'dart:convert';

import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/providers/on_device/on_device_plugin.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/ai/models/capability_model.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';

/// A capability resolved to a concrete connection and model.
class RoutedModel<T extends CapabilityModel> {
  const RoutedModel(this.connection, this.model);
  final ProviderConnection connection;
  final T model;
}

/// Picks a model for a capability: explicit choice → configured default
/// (for the purpose, then for the capability) → the capability's automatic
/// order: connections by priority, each one's first model.
class CapabilityRouter {
  CapabilityRouter(
    this.connections, {
    this.defaults = const {},
    this.purposeDefaults = const {},
    this.disabled = const {},
    this.extraModels = const {},
    this.priority = const {},
    this.modelOrder = const {},
  });

  final List<ProviderConnection> connections;

  /// capability → (connection id, model id).
  final Map<AiCapability, (String, String)> defaults;

  /// `<capability>/<purpose>` → (connection id, model id).
  final Map<String, (String, String)> purposeDefaults;

  /// Connection id → capabilities switched off on it.
  final Map<String, Set<AiCapability>> disabled;

  /// Connection id → models added beyond its catalog.
  final Map<String, List<ModelDescriptor>> extraModels;

  /// Capability → connection id → place in its automatic order.
  final Map<AiCapability, Map<String, int>> priority;

  /// `<connection id>/<capability>` → model ids, most preferred first.
  final Map<String, List<String>> modelOrder;

  /// Enabled rows plus the on-device connection (added once, unless a
  /// system-TTS row already provides it), with the v34 capability tables.
  factory CapabilityRouter.fromProviders(
    Iterable<db.TtsProvider> rows, {
    Map<AiCapability, (String, String)> defaults = const {},
    Iterable<db.CapabilityDefault> defaultRows = const [],
    Iterable<db.ConnectionCapability> capabilityRows = const [],
    Iterable<db.ProviderModel> modelRows = const [],
  }) {
    final connections = [
      for (final row in rows)
        if (row.enabled &&
            AdapterType.values.asNameMap()[row.adapterType] != null)
          connectionForProvider(row),
    ];
    if (!connections.any((c) => c.plugin is OnDevicePlugin)) {
      connections.add(OnDevicePlugin.builtIn());
    }
    final byId = {for (final c in connections) c.id: c};
    AiCapability? cap(String name) => AiCapability.values.asNameMap()[name];
    final disabled = <String, Set<AiCapability>>{};
    final priority = <AiCapability, Map<String, int>>{};
    final modelOrder = <String, List<String>>{};
    for (final r in capabilityRows) {
      final c = cap(r.capability);
      if (c == null) continue;
      if (!r.enabled) disabled.putIfAbsent(r.connectionId, () => {}).add(c);
      if (r.position case final p?) {
        priority.putIfAbsent(c, () => {})[r.connectionId] = p;
      }
      if (_decodeOrder(r.modelOrder) case final ids?) {
        modelOrder['${r.connectionId}/${c.name}'] = ids;
      }
    }
    final extra = <String, List<ModelDescriptor>>{};
    for (final r in modelRows) {
      final c = cap(r.capability);
      final model = c == null
          ? null
          : byId[r.connectionId]?.describe(c, r.modelId);
      if (model == null) continue;
      extra
          .putIfAbsent(r.connectionId, () => [])
          .add(
            model.copyWith(
              displayName: r.displayName,
              source: DescriptorSource.user,
              shutdownAt: r.shutdownAt?.toUtc().toIso8601String(),
            ),
          );
    }
    return CapabilityRouter(
      connections,
      defaults: {
        ...defaults,
        for (final r in defaultRows)
          if (cap(r.capability) case final c? when r.purpose.isEmpty)
            c: (r.connectionId, r.modelId),
      },
      purposeDefaults: {
        for (final r in defaultRows)
          if (r.purpose.isNotEmpty)
            '${r.capability}/${r.purpose}': (r.connectionId, r.modelId),
      },
      disabled: disabled,
      extraModels: extra,
      priority: priority,
      modelOrder: modelOrder,
    );
  }

  static List<String>? _decodeOrder(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final list = jsonDecode(json);
      return list is List ? list.whereType<String>().toList() : null;
    } on FormatException {
      return null;
    }
  }

  /// The router over the database's current rows.
  static Future<CapabilityRouter> load(db.AppDatabase database) async =>
      CapabilityRouter.fromProviders(
        await database.getAllProviders(),
        defaultRows: await database.getCapabilityDefaults(),
        capabilityRows: await database.getConnectionCapabilities(),
        modelRows: await database.getProviderModels(),
      );

  /// Whether [c] serves [cap] and it is not switched off.
  bool offers(ProviderConnection c, AiCapability cap) =>
      c.capabilities.contains(cap) && !(disabled[c.id]?.contains(cap) ?? false);

  /// [c]'s models for [cap] in their set order: its catalog, then the ones
  /// added to it.
  List<ModelDescriptor> modelsOf(ProviderConnection c, AiCapability cap) {
    if (!offers(c, cap)) return const [];
    final own = c.models(cap);
    final all = [
      ...own,
      for (final m in extraModels[c.id] ?? const <ModelDescriptor>[])
        if (m.capability == cap && !own.any((o) => o.id == m.id)) m,
    ];
    final order = modelOrder['${c.id}/${cap.name}'];
    if (order == null || order.isEmpty) return all;
    int rank(ModelDescriptor m) {
      final i = order.indexOf(m.id);
      return i < 0 ? order.length : i;
    }

    return _stableSort(all, rank);
  }

  /// Connections offering [cap] in its automatic order: by set priority,
  /// then list order. Includes those with the capability switched off.
  List<ProviderConnection> ordered(AiCapability cap) {
    final places = priority[cap] ?? const <String, int>{};
    final offering = [
      for (final c in connections)
        if (c.capabilities.contains(cap)) c,
    ];
    return _stableSort(offering, (c) => places[c.id] ?? 1 << 30);
  }

  /// Connections that can serve [cap], in its automatic order.
  List<ProviderConnection> serving(AiCapability cap) => [
    for (final c in ordered(cap))
      if (modelsOf(c, cap).isNotEmpty) c,
  ];

  static List<E> _stableSort<E>(List<E> items, int Function(E) key) {
    final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
    indexed.sort((a, b) {
      final byKey = key(a.$2).compareTo(key(b.$2));
      return byKey != 0 ? byKey : a.$1.compareTo(b.$1);
    });
    return [for (final (_, e) in indexed) e];
  }

  RoutedModel<T>? resolve<T extends CapabilityModel>(
    AiCapability cap, {
    String? connectionId,
    String? modelId,
    String? purpose,
  }) {
    final chosen = connectionId != null
        ? (connectionId, modelId)
        : purposeDefaults['${cap.name}/$purpose'] ?? defaults[cap];
    if (chosen != null) {
      for (final c in connections) {
        if (c.id != chosen.$1) continue;
        if (!offers(c, cap)) return null;
        final model = c.typed<T>(cap, chosen.$2);
        return model == null ? null : RoutedModel(c, model);
      }
      // An explicit pick of a connection that is gone stays unresolved; a
      // default left behind by a deleted connection falls back.
      if (connectionId != null) return null;
    }
    return automatic<T>(cap);
  }

  /// What [cap] runs on with no default set: the first connection in its
  /// automatic order, with that connection's first model.
  RoutedModel<T>? automatic<T extends CapabilityModel>(AiCapability cap) {
    for (final c in serving(cap)) {
      // A set model order puts its first model ahead of the recommended
      // one; a connection with no recommended model (an OpenAI-compatible
      // server) uses the first model added to it.
      final first =
          modelOrder['${c.id}/${cap.name}'] != null ||
              c.defaultModel(cap) == null
          ? modelsOf(c, cap).first.id
          : null;
      final model = c.typed<T>(cap, first);
      if (model != null) return RoutedModel(c, model);
    }
    return null;
  }
}
