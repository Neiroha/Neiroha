class LlmStructuredResult {
  const LlmStructuredResult(
    this.object, {
    required this.finishReason,
    this.usage = const {},
    this.responseFormat = 'json_schema',
  });
  final Map<String, dynamic> object;
  final String finishReason;
  final Map<String, dynamic> usage;
  final String responseFormat;
}

/// One message in an OpenAI-compatible chat-completions request.
class LlmChatMessage {
  final String role; // system | user | assistant
  final String content;

  const LlmChatMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// Thrown when the LLM response is missing the expected fields, the HTTP
/// call fails, or the JSON cannot be parsed.
class LlmChatException implements Exception {
  final String message;
  final int? statusCode;
  final bool transportFailure;
  const LlmChatException(
    this.message, {
    this.statusCode,
    this.transportFailure = false,
  });
  @override
  String toString() => 'LlmChatException: $message';
}
