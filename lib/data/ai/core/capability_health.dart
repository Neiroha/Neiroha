enum HealthState { ok, unavailable, failed, unknown }

class CapabilityHealth {
  const CapabilityHealth(this.state, {this.models = const [], this.message});
  final HealthState state;

  /// Catalog models the account can see for this capability.
  final List<String> models;
  final String? message;
  @override
  String toString() =>
      '${state.name}${models.isEmpty ? '' : ' $models'}'
      '${message == null ? '' : ' ($message)'}';
}
