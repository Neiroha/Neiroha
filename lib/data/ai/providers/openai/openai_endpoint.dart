/// Base URL + key shared by every OpenAI-protocol model of a connection.
class OpenAiEndpoint {
  const OpenAiEndpoint(this.baseUrl, this.apiKey);
  final String baseUrl;
  final String apiKey;
}
