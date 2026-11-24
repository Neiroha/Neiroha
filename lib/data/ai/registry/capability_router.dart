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
/// (for the purpose, then for the capability) → first enabled connection's
/// recommended model.
class CapabilityRouter {
  CapabilityRouter(
    this.connections, {
    this.defaults = const {},
    this.purposeDefaults = const {},
    this.disabled = const {},
    this.extraModels = const {},
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
    for (final r in capabilityRows) {
      if (cap(r.capability) case final c? when !r.enabled) {
        disabled.putIfAbsent(r.connectionId, () => {}).add(c);
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
    );
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

  /// [c]'s models for [cap]: its catalog, then the ones added to it.
  List<ModelDescriptor> modelsOf(ProviderConnection c, AiCapability cap) {
    if (!offers(c, cap)) return const [];
    final own = c.models(cap);
    return [
      ...own,
      for (final m in extraModels[c.id] ?? const <ModelDescriptor>[])
        if (m.capability == cap && !own.any((o) => o.id == m.id)) m,
    ];
  }

  /// Connections that can serve [cap], in list order.
  List<ProviderConnection> serving(AiCapability cap) => [
    for (final c in connections)
      if (modelsOf(c, cap).isNotEmpty) c,
  ];

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
      return null;
    }
    for (final c in serving(cap)) {
      final model = c.typed<T>(cap);
      if (model != null) return RoutedModel(c, model);
    }
    return null;
  }
}
