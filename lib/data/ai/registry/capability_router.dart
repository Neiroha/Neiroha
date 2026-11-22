import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/providers/on_device/on_device_plugin.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/models/capability_model.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';

/// A capability resolved to a concrete connection and model.
class RoutedModel<T extends CapabilityModel> {
  const RoutedModel(this.connection, this.model);
  final ProviderConnection connection;
  final T model;
}

/// Picks a model for a capability: explicit choice → configured default →
/// first enabled connection's recommended model.
class CapabilityRouter {
  CapabilityRouter(this.connections, {this.defaults = const {}});

  final List<ProviderConnection> connections;

  /// capability → (connection id, model id).
  final Map<AiCapability, (String, String)> defaults;

  /// Enabled rows plus the on-device connection (added once, unless a
  /// system-TTS row already provides it).
  factory CapabilityRouter.fromProviders(
    Iterable<db.TtsProvider> rows, {
    Map<AiCapability, (String, String)> defaults = const {},
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
    return CapabilityRouter(connections, defaults: defaults);
  }

  /// Connections that can serve [cap], in list order.
  List<ProviderConnection> serving(AiCapability cap) => [
    for (final c in connections)
      if (c.capabilities.contains(cap) && c.models(cap).isNotEmpty) c,
  ];

  RoutedModel<T>? resolve<T extends CapabilityModel>(
    AiCapability cap, {
    String? connectionId,
    String? modelId,
  }) {
    final chosen = connectionId != null
        ? (connectionId, modelId)
        : defaults[cap];
    if (chosen != null) {
      for (final c in connections) {
        if (c.id != chosen.$1) continue;
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
