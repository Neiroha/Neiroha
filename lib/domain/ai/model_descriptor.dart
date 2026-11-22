import 'package:neiroha/domain/ai/capability.dart';

enum ModelLifecycle { preview, ga, deprecated }

/// Where a descriptor came from; mirrors `CapabilitySource` ordering.
enum DescriptorSource { catalog, provider, observed, user }

/// One model mounted under one capability. UI, routing and validation read
/// only this, never adapter-type switches or model-name guesses.
class ModelDescriptor {
  const ModelDescriptor({
    required this.id,
    required this.capability,
    required this.protocol,
    this.displayName = '',
    this.features = const {},
    this.platforms = allPlatforms,
    this.lifecycle = ModelLifecycle.ga,
    this.shutdownAt,
    this.replacement,
    this.source = DescriptorSource.catalog,
    this.isDefault = false,
  });

  final String id;
  final AiCapability capability;
  final AiProtocol protocol;
  final String displayName;
  final Set<String> features;
  final Set<AiPlatform> platforms;
  final ModelLifecycle lifecycle;

  /// ISO date (`yyyy-MM-dd`) after which the vendor stops serving the model.
  final String? shutdownAt;
  final String? replacement;
  final DescriptorSource source;

  /// The provider's recommended model for [capability].
  final bool isDefault;

  String get label => displayName.isEmpty ? id : displayName;
  bool has(String feature) => features.contains(feature);

  bool shutDownBy(DateTime now) =>
      shutdownAt != null && !now.isBefore(DateTime.parse(shutdownAt!));

  /// A model id typed in by the user that the catalog does not know.
  factory ModelDescriptor.manual(
    String id,
    AiCapability capability,
    AiProtocol protocol,
  ) => ModelDescriptor(
    id: id,
    capability: capability,
    protocol: protocol,
    source: DescriptorSource.user,
  );

  @override
  String toString() => '${capability.name}:$id';
}
