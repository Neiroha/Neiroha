enum CapabilitySupport { unknown, supported, unsupported }

enum CapabilitySource { catalog, provider, observed, user }

enum ModelAvailability {
  unverified,
  available,
  authenticationFailed,
  rateLimited,
  networkFailed,
}

enum ServiceRoute { chatCompletions, responses, speech, realtime, native }

class CapabilityEvidence {
  const CapabilityEvidence(this.support, this.source, {this.checkedAt});
  final CapabilitySupport support;
  final CapabilitySource source;
  final DateTime? checkedAt;
  Map<String, Object?> toJson() => {
    'support': support.name,
    'source': source.name,
    'checkedAt': checkedAt?.toIso8601String(),
  };
  factory CapabilityEvidence.fromJson(Map<String, dynamic> json) =>
      CapabilityEvidence(
        CapabilitySupport.values.byName(json['support'] as String),
        CapabilitySource.values.byName(json['source'] as String),
        checkedAt: json['checkedAt'] == null
            ? null
            : DateTime.parse(json['checkedAt'] as String),
      );
}

class ModelCapability {
  const ModelCapability({
    required this.connectionId,
    required this.modelId,
    required this.route,
    this.facts = const {},
    this.availability = ModelAvailability.unverified,
  });
  final String connectionId;
  final String modelId;
  final ServiceRoute route;
  final Map<String, CapabilityEvidence> facts;
  final ModelAvailability availability;
  CapabilitySupport support(String feature) =>
      facts[feature]?.support ?? CapabilitySupport.unknown;

  ModelCapability merge(ModelCapability newer) {
    if (connectionId != newer.connectionId ||
        modelId != newer.modelId ||
        route != newer.route) {
      throw ArgumentError(
        'Capabilities belong to different connection/model/routes.',
      );
    }
    final merged = Map<String, CapabilityEvidence>.of(facts);
    for (final entry in newer.facts.entries) {
      final old = merged[entry.key];
      if (old == null ||
          entry.value.source.index > old.source.index ||
          (entry.value.source == old.source &&
              (entry.value.checkedAt ?? DateTime(0)).compareTo(
                    old.checkedAt ?? DateTime(0),
                  ) >=
                  0)) {
        merged[entry.key] = entry.value;
      }
    }
    return ModelCapability(
      connectionId: connectionId,
      modelId: modelId,
      route: route,
      facts: merged,
      availability: newer.availability == ModelAvailability.unverified
          ? availability
          : newer.availability,
    );
  }

  Map<String, Object?> toJson() => {
    'connectionId': connectionId,
    'modelId': modelId,
    'route': route.name,
    'availability': availability.name,
    'facts': facts.map((key, value) => MapEntry(key, value.toJson())),
  };
  factory ModelCapability.fromJson(Map<String, dynamic> json) =>
      ModelCapability(
        connectionId: json['connectionId'] as String,
        modelId: json['modelId'] as String,
        route: ServiceRoute.values.byName(json['route'] as String),
        availability: ModelAvailability.values.byName(
          json['availability'] as String,
        ),
        facts: (json['facts'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(
            k,
            CapabilityEvidence.fromJson(Map<String, dynamic>.from(v as Map)),
          ),
        ),
      );
}
