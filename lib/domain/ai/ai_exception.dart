class AiProviderException implements Exception {
  const AiProviderException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() =>
      statusCode == null ? message : 'HTTP $statusCode: $message';
}

/// No enabled connection offers a model for the capability a feature needs.
class CapabilityUnavailableException implements Exception {
  const CapabilityUnavailableException(this.capability);

  /// [AiCapability] name (`stt`, `llm`…), kept as a string so this file has
  /// no dependency on the enum.
  final String capability;
  @override
  String toString() => 'No enabled provider offers $capability.';
}
