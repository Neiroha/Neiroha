class AiProviderException implements Exception {
  const AiProviderException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() =>
      statusCode == null ? message : 'HTTP $statusCode: $message';
}
